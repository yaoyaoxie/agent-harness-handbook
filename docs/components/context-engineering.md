---
recommended: true
title: 上下文工程
description: 上下文是 agent 最稀缺的资源，harness 的核心职责是决定每个 step 模型看到什么：解剖上下文的真实构成、poisoning/distraction/confusion/clash 四种失效模式、压缩与截断策略、KV cache 命中率的工程考量，以及 RAG 与 just-in-time 检索的取舍。
---

# 上下文工程

在 harness 的所有职责里，上下文工程（context engineering）是最核心的一条：**agent 的每一步决策质量，上限不由模型决定，而由那一刻模型看到的 token 决定。** Anthropic 在[《Effective context engineering for AI agents》](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)里给出了一个精确的定义：context engineering 是在 LLM 推理过程中，对进入上下文窗口的 token 集合进行策展（curating）与维护的全部策略——目标是为每个 step 找到**最小的、高信号的 token 集合**，最大化期望行为出现的概率。

为什么用"工程"这个词？因为这不是写一段好提示词就结束的一次性工作。[Agent 循环](/components/agent-loop)每转一圈，都可能产生新的工具结果、新的观察、新的错误，候选进入上下文的信息不断膨胀，而窗口是固定的、注意力是有限的——谁进、谁出、谁被压缩、谁被外置，每一步都是 harness 必须回答的问题。

## 上下文是最稀缺的资源

"稀缺"有两层含义，一层是硬性的，一层是软性的。

**硬性的：窗口有物理上限。** 即便窗口开到 100 万 token，长任务的工具轨迹（几十轮 shell 输出、文件内容、搜索结果）照样能把它塞满。塞满之后要么截断、要么压缩，都是有损操作。

**软性的：注意力预算先于窗口耗尽。** Anthropic 援引 needle-in-a-haystack 类基准测试指出"context rot"现象：随着上下文中 token 数增加，模型准确回忆其中信息的能力持续下降——这不是断崖，而是一条性能斜坡。架构层面的原因很直白：transformer 里 n 个 token 产生 n² 的成对注意力关系，上下文越长，每个关系分到的"注意力预算"越薄；而且训练数据里短序列远比长序列常见，模型对超长程依赖的"经验"本来就少。

所以正确的思维模型不是"窗口有多大就能装多少"，而是：**每往上下文里多塞一个 token，都在消耗一份有限的注意力预算。** 上下文工程的全部技巧，本质上都是在这份预算约束下做取舍。

## 上下文里到底有什么

在讨论"怎么管"之前，先解剖一次真实的 agent 请求，看看上下文里到底装了什么：

```text
┌────────────────────────── 一次 LLM 调用的上下文 ──────────────────────────┐
│                                                                         │
│  ① 系统提示（system prompt）                                             │
│     行为准则、输出格式、工具使用纪律、安全边界          ← 稳定，占固定开销  │
│                                                                         │
│  ② 工具 schema                                                          │
│     每个工具的名称/描述/参数定义，全部序列化在上下文头部   ← 工具越多越臃肿  │
│                                                                         │
│  ③ 注入的"环境记忆"                                                       │
│     CLAUDE.md、用户偏好、记忆文件、日期、工作目录信息      ← 每次请求重复注入 │
│                                                                         │
│  ④ 对话历史与工具结果（动态增长的主体）                                     │
│     user/assistant 消息 + 每一轮工具调用及其返回                          │
│     ├─ 文件内容、grep 结果、shell 输出（常常一次几千 token）               │
│     ├─ 错误信息与 stack trace（删掉它们是有争议的决策）                    │
│     └─ 模型自己此前的推理与计划（todo list 等外化工件）                    │
│                                                                         │
│  ⑤ 本轮用户输入                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

这个解剖图里最重要的认识是：**除了第⑤格，其余每一格的内容都由 harness 决定。** 系统提示怎么写、工具暴露哪些、记忆文件注入哪些片段、工具结果原样回灌还是裁剪、历史什么时候压缩——模型对这些一概没有发言权。说"上下文工程是 harness 的核心职责"，就是这个意思。

反过来说，这也解释了为什么同一个模型在不同 harness 里表现天差地别：模型是一样的，但"每一步看到什么"完全不同。

## 上下文失效的四种模式

Drew Breunig 在[《How Long Contexts Fail》](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html)中把长上下文的失效方式整理成四类，这个分类已经成了讨论该问题的事实标准词汇表。逐一拆解，并附上原始证据：

### Context Poisoning（投毒）：错误进入上下文并被反复引用

一个幻觉或错误一旦被写进上下文，就会被后续生成当作事实反复引用，自我强化。Google DeepMind 在 Gemini 2.5 技术报告里记录了一个经典案例：玩宝可梦的 Gemini agent 偶尔会对游戏状态产生幻觉，一旦这个错误状态进入"目标/摘要"区域，agent 会"执着于达成不可能或无关的目标"，而且"往往需要很长时间才能纠正"。

对 harness 的启示：**进入上下文的每一条信息都应该有可信度管理**。工具返回的垃圾数据、模型自己早前写下的错误假设、子 agent 交回来的不可靠结论，都是潜在的毒源。

### Context Distraction（分心）：上下文淹没训练所得

上下文长到一定程度，模型会过度依赖上下文里的历史，而忽略训练中学到的能力。Gemini 2.5 报告的观察是：当上下文显著超过 10 万 token 后，agent 倾向于**重复历史中出现过的动作**，而不是综合出新的计划。Databricks 的[长上下文研究](https://www.databricks.com/blog/long-context-rag-performance-llms)（Breunig 文中引用）给出了更冷峻的数字：Llama 3.1 405B 的正确率在约 32k token 时就开始下滑，小模型更早。

这是"窗口越大越好"迷思最有力的反证：**模型在窗口远未填满时就已经开始变笨了。** 超长窗口的真正价值场景是摘要与事实检索，而不是长链条的生成式推理。

### Context Confusion（困惑）：无关内容污染响应

放进上下文的任何东西，模型都不得不"处理"它——无关文档、用不上的工具定义，都会影响输出。最实证的一类证据来自工具数量：Berkeley Function-Calling Leaderboard 显示，**每个模型在提供超过一个工具时表现都会变差**，而且即便场景里没有任何相关工具，模型也偶尔会强行发起调用。Breunig 还引了一项 GeoEngine 基准实验：量化版 Llama 3.1 8B 面对 46 个工具定义时任务失败（尽管远未到上下文上限），缩减到 19 个就成功了。

对 MCP 热潮这是一针清醒剂：把几百个工具描述一股脑塞进上下文，不等于给 agent 赋能，更多时候是在制造困惑。这也是[工具系统](/components/tools)反复强调"少而精、边界清晰"的原因。

### Context Clash（冲突）：上下文内部自相矛盾

比"无关"更糟的是"打架"：新进来的信息与上下文里已有的信息直接冲突。Microsoft 与 Salesforce 合作的论文[《LLMs Get Lost in Multi-Turn Conversation》](https://arxiv.org/abs/2505.06120)（arXiv:2505.06120）给出了触目惊心的量化结果：把完全相同的任务信息从"一次性给全"改成"分多轮碎片式给出"后，所有顶级模型的表现平均下跌 **39%**，o3 从 98.1 跌到 64.1。作者的诊断是：模型在早期轮次就会做假设、过早给出不完整的解法，而这些错误答案**留在上下文里**，持续影响后续生成——"走错了弯就迷路了，而且不会自己绕回来"。

::: warning 这对 agent 是双重坏消息
Agent 的上下文天然就是"碎片式组装"的：来自不同文档、不同工具、不同子 agent 的信息在时间上先后进入，互相矛盾的概率远高于单轮场景。而且 agent 自己早轮的错误尝试也是 clash 的来源。多轮退化不是聊天机器人的专利病，它写在 agent 的工作方式里。
:::

四种模式汇总成一张速查表，方便在 agent 行为异常时对照诊断：

| 失效模式 | 一句话定义 | 典型症状 | 首选对策 |
| --- | --- | --- | --- |
| Poisoning（投毒） | 幻觉/错误进入上下文并被反复引用 | 执着于不可能的目标，错误自我强化 | 信息源可信度管理；摘要时校验关键事实 |
| Distraction（分心） | 上下文过长，模型重复历史动作 | 不再生成新计划，原地打转 | compaction；清理冗余历史 |
| Confusion（困惑） | 无关内容被模型当真处理 | 调用无关工具、引用无关文档 | 精简工具集（loadout）；只检索该检索的 |
| Clash（冲突） | 上下文内部信息互相矛盾 | 被早期错误答案"锚定"，无法纠正 | 隔离冲突源；子 agent 分而治之 |

注意它们经常组合出现：一次 poisoning 会在后续轮次制造 clash，过长的历史同时喂养 distraction 和 confusion。诊断的价值在于选对杠杆——加大窗口对其中任何一种都没有帮助。

## 压缩与截断：长任务的生存策略

任务一长，上下文迟早逼近上限。harness 的三板斧是：压缩（compaction）、裁剪（pruning/masking）、外置（offloading）。

**Compaction（压缩重写）。** 上下文接近窗口上限时，把整个对话历史交给模型摘要，用摘要开启一个新窗口。Claude Code 的实现是业界参照系：模型保留架构决策、未解决的 bug、实现细节，丢弃冗余的工具输出，然后带着压缩后的上下文加上最近访问过的 5 个文件继续工作。Anthropic 给出的调优建议很务实：先在复杂轨迹上**最大化召回**（确保摘要抓住每一条相关信息），再迭代提升精度（删掉多余内容）——过度压缩丢掉的东西，往往十步之后才知道它重要。

**Tool result clearing / masking（工具结果清理）。** 最轻量、最安全的压缩：一旦某个工具调用深埋在历史里，模型通常不再需要看到它的原始输出——把旧的工具结果替换成占位符即可。Anthropic 已将其作为 Claude 平台的功能发布。注意这是"清理"不是"删除"：调用记录（调了什么、参数是什么）保留，只有冗长的返回体被隐去。

**可恢复的外置（restorable offloading）。** Manus 在[构建经验总结](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)里提出了一个更激进的原则：**任何不可逆的压缩都有风险**，因为你无法预知哪条观察十步之后会变成关键。他们的解法是"把文件系统当作终极上下文"——网页内容可以从上下文丢弃，只要 URL 还在；文档内容可以省略，只要路径还在沙箱里。压缩因此变成**可恢复的**：丢的是内容，留的是索引。这个思路和 [记忆系统](/components/memory) 的笔记式外化（NOTES.md、todo 文件）是同一哲学：上下文只放"现在需要的"，其余全部外置成可检索的引用。

一个容易被忽略的对冲原则同样来自 Manus：**别把错误清出上下文。** 清理轨迹、隐藏失败，会让模型失去"这件事试过、不行"的证据，从而重复踩坑。失败的工具调用连同报错留在上下文里，是模型自我修正的先决条件。压缩策略要丢的是"冗余的成功细节"，而不是"失败的事实"。

## KV cache：为什么稳定前缀值钱

上下文工程不只是质量游戏，还是成本游戏。agent 工作负载有一个独特的经济性：输入极长、输出极短。Manus 报告的平均输入输出比约 **100:1**——每一步都是把整段历史重新 prefill 一遍，只为产出一个几十 token 的工具调用。

这让 **KV cache 命中率成为生产级 agent 最重要的单一指标之一**（Manus 的原话）。缓存命中直接决定 TTFT 和成本：以 Claude Sonnet 为例，缓存输入 token 约 0.30 美元/百万，未缓存约 3 美元——**10 倍价差**。而 KV cache 的机制决定了一个硬约束：前缀从第一个不同的 token 起全部失效。

由此推出三条工程纪律：

1. **保持前缀绝对稳定。** 最常见的自杀行为是在系统提示开头放一个精确到秒的时间戳——每步都变，缓存全废。日期这类易变信息要么放尾部，要么干脆不放。
2. **上下文只追加，不改写。** 不要回头修改历史的动作或观察；序列化必须确定性（JSON 键序不稳定都能悄悄击穿缓存）。
3. **工具定义放头部 = 工具集不能中途变。** 大多数模型的工具定义序列化在上下文前部，动态增删工具会让之后所有内容的缓存失效。Manus 的对策是"mask, don't remove"：工具定义不动，在解码阶段用 logits 掩码限制可选动作集——既实现了"当前只能用这几个工具"，又保住了缓存。

::: info 这个约束如何塑造产品设计
"稳定前缀"解释了为什么主流 coding agent 的系统提示都是一份静态长文 + 尾部追加动态内容，而不是每步动态拼装；也解释了为什么[规划](/components/planning)里的 todo list 放在对话流里（可追加、可覆写）而不是塞进系统提示（会击穿缓存）。上下文里的每个内容块，位置本身就是工程决策。
:::

## 复诵：操纵注意力的廉价手段

上下文里信息的位置不是中性的。"lost in the middle"现象告诉我们：模型对上下文**开头和结尾**的内容利用得最好，中段最差。这给了 harness 一个不动架构、只动内容就能操纵注意力的杠杆——**把最重要的东西复诵（recitation）到上下文的尾部。**

Manus 把这条做成了显式机制：处理复杂任务时，agent 会创建一份 todo.md，每推进一步就重写一遍。Manus 的任务平均要 50 次左右工具调用，原始目标很容易被几十轮观察淹没；而不断重写 todo list，等于**把全局计划持续复诵到上下文的最近位置**，推回模型的近期注意力范围内，对抗目标漂移。注意这里没有任何模型侧的技巧——纯粹是通过控制"上下文尾部此刻有什么"来偏置模型的注意力。

这从上下文工程的角度解释了[规划与任务分解](/components/planning)里 TodoWrite 为什么有效：todo list 不是给用户看的进度条，而是一份被刻意安放在高注意力区域的工件。同理，"压缩后保留最近访问的文件""摘要开启新窗口"也都是同一个原理的应用——**决定什么出现在上下文末端，就是在决定模型下一步最会"想到"什么。**

## 只检索该检索的：RAG vs. just-in-time

"怎么把相关信息弄进上下文"有两种基本路线：

**预检索（RAG 式）：** 推理前用 embedding 把可能相关的文档检出来，一次性注入。优点是快、确定；缺点是"猜"——检索发生在模型开始理解任务之前，猜错的代价是无关内容占用注意力预算（也就是前面说的 confusion）。

**即时检索（just-in-time）：** 上下文里只放轻量标识符（文件路径、URL、查询语句），让 agent 在运行时通过工具按需加载。Anthropic 观察到行业正明显转向这条路线，Claude 自己用它在大型数据库上做复杂分析：模型写针对性查询、存储结果、用 `head`/`tail` 这类命令只取需要的数据切片，全程不把完整数据对象搬进上下文。

即时检索还有一个隐性红利：**渐进披露（progressive disclosure）**。文件大小暗示复杂度、命名规范暗示用途、时间戳暗示时效——`tests/test_utils.py` 和 `src/core_logic/` 下的同名文件含义完全不同。agent 像人一样靠文件系统这个"外部索引"逐层建立理解，工作记忆里只留必要子集。

代价同样明确：运行时探索比预计算检索慢，而且如果工具和启发式设计不好，agent 会把上下文浪费在死胡同里。所以现实答案是**混合**：Claude Code 就是标杆——CLAUDE.md 这类稳定信息直接前置注入，而代码内容靠 glob/grep 即时获取，顺带绕开了索引过期和复杂语法树的问题。

| 维度 | 预检索（RAG） | 即时检索（just-in-time） |
| --- | --- | --- |
| 时机 | 推理前一次性注入 | 运行时按需加载 |
| 延迟 | 低（预计算） | 高（多轮探索） |
| 相关性 | 取决于检索器的"猜测" | 模型自己判断，通常更准 |
| 上下文开销 | 一次到位，可能塞入无关内容 | 按需增长，但探索本身耗 token |
| 数据时效 | 依赖索引新鲜度 | 永远读的是当前状态 |
| 适用 | 内容相对静态（法务、金融文档） | 动态环境（代码库、数据库、网页） |

同样的逻辑也适用于工具集本身：Breunig 在下篇[《How to Fix Your Context》](https://www.dbreunig.com/2025/06/26/how-to-fix-your-context.html)中称之为 **tool loadout**——像游戏开局配装一样，只给当前任务配上相关工具的定义。RAG-MCP 的实验发现工具超过 30 个时描述开始互相重叠、选择准确率骤降，检索式挑选工具能把选择准确率提升约 3 倍。但要注意这与 KV cache 纪律的冲突：工具 loadout 适合在**会话/任务开始时**选定，而不是在循环中途动态增删。

## 设计要点小结

把全文收敛成一份可执行的清单：

- **把上下文当预算管理。** 每个 token 都消耗注意力；目标是"最小的高信号集合"，不是"尽量装满窗口"。
- **故障先于窗口耗尽出现。** 用四种失效模式（poisoning / distraction / confusion / clash）诊断 agent 的行为异常，而不是一味换更大的窗口。
- **压缩要分层：** 旧的工具结果先清理（无损），实在不够再 compaction（有损），外置成文件/URL 索引优先于摘要丢弃（可恢复）。
- **前缀稳定是成本纪律。** 系统提示与工具定义冻结在头部，动态内容一律尾部追加；别在头部放时间戳。
- **默认 just-in-time，显式例外才预注入。** 稳定且必用的（规约、记忆文件）前置；其余给标识符，让模型自己拉。
- **错误留在上下文里。** 失败轨迹是模型自我修正的证据，压缩时优先保留"什么不行"。
- **隔离是最强力的管理。** 当单上下文怎么管都管不好时，把任务拆给拥有干净窗口的[子 agent](/components/subagents)——Anthropic 的多 agent 研究系统就是靠"每个子 agent 探索几万 token、只交回一两千 token 的蒸馏结论"工作的。

## 延伸阅读

- [Agent 循环](/components/agent-loop)——上下文是在这个循环里一圈圈被组装和消耗的
- [记忆系统](/components/memory)——structured note-taking 与外置存储：上下文装不下的东西去哪了
- [工具系统](/components/tools)——工具 schema 的设计如何同时影响 confusion 与缓存
- [规划与任务分解](/components/planning)——todo list 本质是"把目标持续复诵到上下文的最近位置"
- [子 Agent](/components/subagents)——context quarantine：用隔离的上下文窗口消化大规模探索
- [Claude Code 案例](/case-studies/claude-code)——compaction、CLAUDE.md 与混合检索策略的完整产品实现
- [设计原则](/practice/design-principles)——上下文工程决策在整套 harness 设计中的位置

## 参考资料

- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)——"最小高信号 token 集"、compaction、just-in-time 检索的系统阐述
- [Drew Breunig: How Long Contexts Fail](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html)——poisoning / distraction / confusion / clash 四种失效模式的定义与证据汇总
- [Drew Breunig: How to Fix Your Context](https://www.dbreunig.com/2025/06/26/how-to-fix-your-context.html)——RAG、tool loadout、quarantine、pruning、summarization、offloading 六类对策
- [Manus: Context Engineering for AI Agents — Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)——KV cache 命中率、mask-don't-remove、文件系统作为上下文、"错误留在上下文里"
- [LLMs Get Lost in Multi-Turn Conversation (arXiv:2505.06120)](https://arxiv.org/abs/2505.06120)——Microsoft/Salesforce：多轮碎片式信息导致平均 39% 性能下跌
- [Databricks: Long Context RAG Performance of LLMs](https://www.databricks.com/blog/long-context-rag-performance-llms)——模型在远未填满窗口时性能即开始下滑的实证
