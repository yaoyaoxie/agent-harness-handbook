---
recommended: true
title: 精选资源清单
description: 一份策展式而非罗列式的 Agent Harness 阅读地图：只收录一手、有立场的工程博客、开源实现、协议规范与论文入口，每条都注明为什么值得读、什么时候读。
---

# 精选资源清单

互联网上关于 AI agent 的资料以每周数百篇的速度增长，其中绝大多数不值得读——要么是营销软文，要么是把别人的文章再嚼一遍。这份清单是**策展式**的：宁缺毋滥，每条都回答两个问题——**为什么值得读、什么时候读**。

::: info 选品标准
- **一手优先。** 作者必须亲手构建过生产级 agent 系统（Anthropic、Cognition、Manus 的工程团队），或者是长期独立跟踪该领域、定义了讨论用词的写作者（Simon Willison、Drew Breunig）。转述和汇编一律不收。
- **立场鲜明。** 收有观点、可能错的文章，不收面面俱到但什么都没说的文章。有立场的错误比正确的废话更能教你看清问题。
- **与手册互证。** 每条资源都对应本手册的某个章节。建议的用法是：先读手册章节建立框架，再读原始资源看一手细节，回来对照两者的异同——不一致的地方往往就是真正值得思考的问题。
:::

```text
                        推荐阅读路径
                                                            
  ① 建立全局地图          ② 深入单一主题          ③ 对照真实实现
  Lilian Weng 综述  ──>   Anthropic / Cognition  ──>  读开源仓库代码
  Chip Huyen 长文         / Manus 工程博客            (SWE-agent 等)
        │                       │                        │
        ▼                       ▼                        ▼
  知道 harness 有哪些部件  知道每个部件怎么设计    知道设计如何落地为代码
                                                            
  ④ 读协议与规范原文（MCP / A2A / Agent Skills）——harness 的接口层
  ⑤ 按 /papers 入口读论文——从工程回到学术脉络
  ⑥ 订阅社区信源（Latent Space、Simon Willison）——持续跟踪演化
```

## 一、工程博客与长文

先看一张阵营地图，知道各家站在什么立场上说话，再读正文就不容易被任何一家带走：

| 阵营 | 核心立场 | 读它学什么 |
| --- | --- | --- |
| Anthropic 工程博客 | 简单 agent loop + 精心管理的上下文，结构最少化 | harness 设计的完整方法论，术语校准 |
| Cognition（Devin） | 单线程优先，上下文连续性高于并行能力 | 对多 agent 热潮的清醒反驳 |
| Manus | 成本与 KV-cache 驱动的工程现实主义 | 生产环境的成本、延迟、稳定性优化 |
| LangChain 博客 | 为框架与图结构辩护，强调控制流的显式化 | 框架派的视角，理解"要不要用框架"的争论 |

### 先读这两篇，建立全局地图

**[Lilian Weng: LLM Powered Autonomous Agents](https://lilianweng.github.io/posts/2023-06-23-agent/)**（2023 年 6 月）。Agent 领域被引用最多的综述长文，提出了"规划 + 记忆 + 工具使用"的三分框架——这个拆法至今仍是大多数讨论（包括本手册[组件章](/guide/anatomy)）的默认坐标系。注意它写于 2023 年，早于 Claude Code 这一代产品：里面的案例（AutoGPT、BabyAGI）已经过时，部分判断（如对向量检索式记忆的倚重）已被后来的工程实践修正。**什么时候读**：入门第一站；读的时候带着"哪些已被推翻"的问题意识。

**[Chip Huyen: Agents](https://huyenchip.com/2025/01/07/agents.html)**（2025 年 1 月）。摘自其著作 *AI Engineering*，比 Lilian Weng 更偏工程：工具的三类划分（知识增强 / 能力扩展 / 写操作）、规划与执行的解耦、复合错误（每步 95% 准确率，100 步后只剩 0.6%）的量化直觉。**什么时候读**：读完 Lilian Weng 之后，用它把框架拧紧一圈。

### Anthropic 工程博客：harness 工程的第一手产地

本站引用密度最高的来源，没有之一。Anthropic 是少数把 harness 设计当作独立工程主题、并持续公开细节的公司。按主题分七篇：

- **[Building effective agents](https://www.anthropic.com/research/building-effective-agents)**（2024 年 12 月）。划清了 workflow 与 agent 的边界，给出"先找能用的最简单方案"的总原则。这篇文章最大的价值是**校准术语**——读完你会知道业界说的"agent"具体指什么。**什么时候读**：与[什么是 Agent Harness](/guide/what-is-harness) 对照，两者互为表里。
- **[Writing tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents)**（2025 年）。核心观点：agent-工具接口和人机接口一样值得精心设计；甚至可以用 agent 自己来评测和改进工具描述。**什么时候读**：设计任何自定义工具之前，配合[工具系统](/components/tools)读。
- **[Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)**（2025 年 9 月）。把 context engineering 定义为"prompt engineering 的自然演进"，系统讲了 compaction、结构化笔记、子代理三种长程任务技术。**什么时候读**：[上下文工程](/components/context-engineering)一章的官方底本。
- **[How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)**（2025 年 6 月）。orchestrator-worker 架构的完整复盘，含硬数据：内部评测中多 agent 系统超出单 agent 90.2%；token 经济学（agent 约烧 4 倍于聊天的 token，多 agent 约 15 倍）。**什么时候读**：考虑上[子代理](/components/subagents)之前，先算清楚这笔账。
- **[Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)**（2025 年 11 月）。**全清单中与本手册主题最直接相关的一篇**——标题里就有 harness。讲 Claude Agent SDK 如何跨多个上下文窗口工作：initializer agent 铺设环境、feature list 防"提前宣布胜利"、progress file + git 历史做会话间交接。**什么时候读**：读完[记忆系统](/components/memory)和[规划](/components/planning)之后，看这些机制如何组装成一个完整的长时间跨度 harness。
- **[Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)**（2025 年 11 月）。指出了 MCP 的一个真实代价：工具定义和中间结果全部经过上下文，token 成本随工具数线性膨胀；给出的解法是让 agent 写代码调用工具，把中间结果留在上下文之外。**什么时候读**：你的 MCP 工具越接越多、账单和上下文一起爆炸时，配合[工具系统](/components/tools)读。
- **[Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)**（持续更新）。使用者视角的最佳实践：先探索后规划、给 agent 可验证的检查点、CLAUDE.md 怎么写。**什么时候读**：开始重度使用 Claude Code 时，配合 [Claude Code 案例](/case-studies/claude-code)。

### Cognition：必要的反方

**[Don't Build Multi-Agents](https://cognition.ai/blog/dont-build-multi-agents)**（Walden Yan，2025 年 6 月）。与上面 Anthropic 的多 agent 文章几乎同期发表，结论相反：Devin 的团队认为多 agent 架构默认脆弱，提出两条原则——"共享完整上下文（而不是只传消息）"和"行为携带隐含决策"。两篇文章其实并不矛盾：Anthropic 的任务（广度优先的 research）天然可并行，Cognition 的任务（强耦合的 coding）不是。**什么时候读**：与 Anthropic 那篇对照着读——判断多 agent 架构是否适合你的任务，是[子代理](/components/subagents)一章最重要的决策。

### Manus：生产环境的脏经验

**[Context Engineering for AI Agents: Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)**（Yichao 'Peak' Ji，2025 年 7 月）。一个把 agent 框架重写四次的团队交出的经验清单：KV-cache 命中率是生产 agent 最重要的单一指标；工具用"遮蔽"而非"移除"（mask, don't remove）；用 todo.md 把目标"复述"到上下文尾部对抗注意力漂移；把错误轨迹留在上下文里，因为"擦掉失败就是擦掉证据"。**什么时候读**：当你从"能跑"进入"要优化成本与稳定性"的阶段——这里没有一条是理论，全部来自线上事故。

### LangChain：框架视角的另一极

前面三家都是"产品公司写自己的 harness"，LangChain 是卖框架的，立场天然不同——它要论证的是"你需要显式的控制流抽象"。这个立场被前三家部分反驳过，但它的两篇博客仍然值得读：

- **[Context Engineering for Agents](https://blog.langchain.com/context-engineering-for-agents/)**（Lance Martin，2025 年 6 月）。把 context engineering 拆解为 write / select / compress / isolate 四个动作，是目前对这个概念最干净的分类法之一，Anthropic 和 Manus 的技术都能被装进这个格子里。**什么时候读**：[上下文工程](/components/context-engineering)的配套读物，用它做 checklist。
- **[How to think about agent frameworks](https://blog.langchain.com/how-to-think-about-agent-frameworks/)**（2025 年）。坦率地讨论了"框架到底帮你什么"——承认简单 loop 的价值，同时论证持久化、人机协作、观测这些横切设施自己手写并不便宜。**什么时候读**：纠结"用 LangGraph 还是自己写"时读，配合 [LangGraph 案例](/case-studies/langgraph) 与[动手搭建一个 Harness](/practice/build-your-own) 形成自己的判断。

### 独立写作者：定义了讨论用词的人

- **Drew Breunig 的 context engineering 二篇**：[How Long Contexts Fail](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html)（2025 年 6 月 22 日）把长上下文失败归纳为四种模式——context poisoning、distraction、confusion、clash；一周后的续篇 [How to Fix Your Context](https://www.dbreunig.com/2025/06/26/how-to-fix-your-context.html) 给出对应的六种修复战术。**什么时候读**：你的 agent "聊着聊着变笨"时，先按这四模式做归因。
- **[Simon Willison: The lethal trifecta](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)**（2025 年 6 月）。prompt injection 一词的提出者指出：私有数据访问 + 不可信内容 + 对外通信，三者齐备的 agent 必然可被利用来偷数据。这不是假设——他列举了对 Microsoft 365 Copilot、GitHub MCP 等真实系统的攻击案例。**什么时候读**：给 agent 接任何新工具之前，先数一遍这三样凑齐了几样。详见[权限与人机协作](/components/permissions)。
- **[Shunyu Yao: The Second Half](https://ysymyth.github.io/The-Second-Half/)**（2025 年 4 月）。ReAct 作者的判断：AI 的"上半场"是比谁的方法新，"下半场"是比谁的问题定义得好——评测比训练更重要。这篇文章解释了为什么 SWE-bench 这类 harness 驱动的评测成了行业焦点。**什么时候读**：关心方向判断、想理解"为什么人人都在刷榜"时，配合[前沿论文](/papers/frontier)。
- **[OpenAI: A Practical Guide to Building Agents](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf)**（2025 年，PDF）。立场相对保守的入门指南：单 agent 优先、guardrails 分层、逐步加复杂度。技术深度不如上面几篇，但结构清晰、无黑话。**什么时候读**：需要向团队里不熟悉 agent 的同事解释基本概念时，这篇是最好的敲门砖。

## 二、开源实现：读代码，比读文章更快

文章告诉你"应该怎么设计"，代码告诉你"实际长什么样"。harness 工程的大量细节——错误恢复、上下文压缩、工具结果截断——只在代码里存在。以下项目均对应本手册的案例章：

| 项目 | 读它什么 | 站内对照 |
| --- | --- | --- |
| [SWE-agent](https://github.com/SWE-agent/SWE-agent) | ACI（agent-computer interface）概念的原型：为模型设计的专用命令与编辑格式。代码量小，最适合作为第一个通读的 harness | [SWE-agent 案例](/case-studies/swe-agent) |
| [OpenHands](https://github.com/OpenHands/OpenHands) | 完整生产级 harness：事件流架构、沙箱运行时、可插拔 agent。仓库已从 All-Hands-AI 组织迁至 OpenHands 组织 | [OpenHands 案例](/case-studies/openhands) |
| [Aider](https://github.com/Aider-AI/aider) | 终端 coding agent 的克制设计：repo map 如何用少量 token 表达整个代码库结构 | [Aider 案例](/case-studies/aider) |
| [LangGraph](https://github.com/langchain-ai/langgraph) | 框架派代表：把 agent 建模为状态机图。对照[模型 vs. Harness](/guide/model-vs-harness)中"框架是写 harness 的工具，不是 harness 本身"的辨析 | [LangGraph 案例](/case-studies/langgraph) |
| [anthropics/claude-code](https://github.com/anthropics/claude-code) | Claude Code 源码不开放，但这个仓库的 issue tracker 是观察真实用户痛点的富矿 | [Claude Code 案例](/case-studies/claude-code) |
| [anthropics/skills](https://github.com/anthropics/skills) | 官方 Agent Skills 示例仓库——学 SKILL.md 的写法，最好的教材是这些成品 | [Skills](/components/skills) |

Devin 本身闭源，可读的是 Cognition 的发布文 [Introducing Devin](https://www.cognition.ai/blog/introducing-devin)（2024 年 3 月），配合 [Devin 案例](/case-studies/devin)中对它后续公开技术分享的分析。

::: tip 读 harness 代码的顺序
不要从 `main` 函数顺着读。先搜出 **agent loop** 在哪里（关键词：`while`、`step`、`tool_call`），再看**工具是如何定义和注册**的，最后看**每轮调用的上下文是怎么组装**的。这三个位置就是 harness 的脊柱，其余都是肋骨。想更进一步，照着[动手搭建一个 Harness](/practice/build-your-own) 自己写一遍——几十行代码就能跑起来。
:::

## 三、协议与规范：harness 的接口层

2024 年底以来，harness 与环境、与其他 agent 之间的接口开始标准化。这一层的变化比模型层慢，但一旦沉淀下来就是长期基础设施：

| 规范 | 解决的问题 | 提出方与现状 | 什么时候需要关心 |
| --- | --- | --- | --- |
| [MCP（Model Context Protocol）](https://modelcontextprotocol.io) | agent ↔ 工具/数据源的标准接口 | Anthropic 2024 年 11 月开源；发布一年内被 OpenAI、Google 等主要厂商采纳，已成事实标准 | 给 agent 接外部工具、数据源时——先读官方 spec 再读二手解读 |
| [A2A（Agent2Agent）](https://a2a-protocol.org/latest/) | agent ↔ agent 的跨框架通信 | Google 提出，已捐赠给 Linux Foundation 治理 | 构建多个独立 agent 互相协作的系统时。注意官方明说：它不是 sub-agent 协议，管的是独立 agent 之间的事 |
| [Agent Skills](https://agentskills.io) | 知识与工作流的封装格式（`SKILL.md` + 资源文件夹） | Anthropic 提出并开放为独立规范，已被多家 agent 产品采纳 | 想把领域知识做成可复用、可分发的包时，配合 [Skills](/components/skills) |

::: warning 协议不是接入越多越好
MCP 降低了接工具的门槛，但也放大了两个已知风险：Manus 的 "mask, don't remove" 警告的是工具膨胀拖垮选择准确率；Simon Willison 的 lethal trifecta 警告的是工具组合打开安全缺口。接每一个 MCP server 之前，这两关都要过一遍。
:::

## 四、论文入口

本手册的论文部分就是为此准备的：

- **[论文导读](/papers/)**——为什么做工程也要读论文、怎么读；
- **[核心论文](/papers/core-papers)**——ReAct、Toolformer、Reflexion 等奠基性工作的导读；
- **[前沿论文](/papers/frontier)**——harness 视角下的最新研究动态。

如果只想读三篇原文，按这个顺序：

1. **[ReAct](https://arxiv.org/abs/2210.03629)**（arXiv:2210.03629，ICLR 2023）——"思考-行动-观察"循环的原点，今天所有 agent loop 的祖先；
2. **[SWE-bench](https://arxiv.org/abs/2310.06770)**（arXiv:2310.06770，ICLR 2024）—— coding agent 评测的事实标准，理解它才能理解各家战报在说什么；
3. **[SWE-agent](https://arxiv.org/abs/2405.15793)**（arXiv:2405.15793，NeurIPS 2024）——证明 harness 设计（ACI）本身就是研究贡献的那篇论文。

读这些论文时建议始终带着同一个问题：**如果拿掉 scaffold，模型本身还剩多少能力？** 这是 harness 视角读论文的核心动作——把论文报告的性能数字拆成"模型的贡献"和"harness 的贡献"两笔账。这个习惯会改变你读一切 agent 论文和 benchmark 战报的方式（参见[模型 vs. Harness](/guide/model-vs-harness)）。

## 五、社区、播客与演讲

harness 工程还没有教科书，知识流动主要靠人和播客。以下信源值得长期订阅：

- **[Latent Space](https://www.latent.space/podcast)**（swyx 与 Alessio）。AI 工程师社区的核心播客，对 agent 基础设施的跟踪密度最高。其 2023 年的檄文 [The Rise of the AI Engineer](https://www.latent.space/p/ai-engineer) 定义了"AI Engineer"这个角色——某种意义上，本手册研究的就是这个岗位的核心手艺。
- **[Andrej Karpathy: Software Is Changing (Again)](https://www.youtube.com/watch?v=LCEmiRjPEtQ)**（YC AI Startup School，2025 年 6 月，[YC 文字版](https://www.ycombinator.com/library/MW-andrej-karpathy-software-is-changing-again)）。Software 3.0 的提出：LLM 是新计算机，自然语言是新的编程接口。对 harness 设计者最有启发的概念是 **autonomy slider**——好产品的自治程度是可调节的滑杆，而不是"全自动/全手动"的开关。这与[权限与人机协作](/components/permissions)的设计哲学完全一致。
- **[Simon Willison 博客的 agents 标签](https://simonwillison.net/tags/agents/)**。更新频率最高、链接品味最好的持续信源，几乎每篇重要文章他都会给出内行点评。订阅它比订阅任何 newsletter 都划算。

::: info 一个诚实的建议
这份清单会过时——harness 领域以季度为单位演化。2026 年再回来看时，请优先检查"协议与规范"一节（标准沉淀最慢、过时风险最低）和各团队的工程博客（更新最勤）。清单本身的形式不会过时：**一手、有立场、可对照**，用这三条标准你可以随时重建一份新的。
:::

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——本手册的总纲，理解 harness 这个词的定义与边界
- [Agent Loop](/components/agent-loop)——所有工程博客最终都在讨论的同一个循环
- [Harness 的解剖](/guide/anatomy)——资源中提到的各个部件在整体架构中的位置
- [上下文工程](/components/context-engineering)——Anthropic、Manus、Drew Breunig 三方经验的系统化整理
- [工具系统](/components/tools)——"Writing tools for AI agents" 的展开
- [子代理](/components/subagents)——Anthropic 与 Cognition 关于多 agent 的争论全貌
- [权限与人机协作](/components/permissions)——lethal trifecta 与 autonomy slider 的工程落地
- [案例研究索引](/case-studies/claude-code)——从 Claude Code 开始读真实产品的 harness 设计
- [设计原则](/practice/design-principles)——把这份清单里各家的经验沉淀为可执行的原则
- [术语表](/resources/glossary)——读英文原文时遇到生词先查这里

## 参考资料

- [Anthropic: Building effective agents](https://www.anthropic.com/research/building-effective-agents)
- [Anthropic: Writing tools for AI agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- [Anthropic: Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Anthropic: How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)
- [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic: Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [Anthropic: Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Cognition: Don't Build Multi-Agents](https://cognition.ai/blog/dont-build-multi-agents)
- [Cognition: Introducing Devin](https://www.cognition.ai/blog/introducing-devin)
- [Manus: Context Engineering for AI Agents](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [LangChain: Context Engineering for Agents](https://blog.langchain.com/context-engineering-for-agents/) / [How to think about agent frameworks](https://blog.langchain.com/how-to-think-about-agent-frameworks/)
- [Drew Breunig: How Long Contexts Fail](https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html) / [How to Fix Your Context](https://www.dbreunig.com/2025/06/26/how-to-fix-your-context.html)
- [Simon Willison: The lethal trifecta for AI agents](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- [Lilian Weng: LLM Powered Autonomous Agents](https://lilianweng.github.io/posts/2023-06-23-agent/)
- [Chip Huyen: Agents](https://huyenchip.com/2025/01/07/agents.html)
- [Shunyu Yao: The Second Half](https://ysymyth.github.io/The-Second-Half/)
- [OpenAI: A Practical Guide to Building Agents (PDF)](https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf)
- [Model Context Protocol 官方站点](https://modelcontextprotocol.io)
- [A2A Protocol 官方站点](https://a2a-protocol.org/latest/)
- [Agent Skills 规范](https://agentskills.io)
- [ReAct (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629) / [SWE-bench (arXiv:2310.06770)](https://arxiv.org/abs/2310.06770) / [SWE-agent (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
- [Latent Space Podcast](https://www.latent.space/podcast) / [The Rise of the AI Engineer](https://www.latent.space/p/ai-engineer)
- [Andrej Karpathy: Software Is Changing (Again)（YC AI Startup School 2025）](https://www.youtube.com/watch?v=LCEmiRjPEtQ)
