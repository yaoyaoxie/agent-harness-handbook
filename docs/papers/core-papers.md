---
title: 经典论文精读
description: 精读 7 篇塑造 Agent Harness 设计范式的经典论文：ReAct、MRKL、Toolformer、Reflexion、Generative Agents、Voyager、SWE-agent，讲透机制、数据与对系统设计的启示。
---

# 经典论文精读

今天的每一个主流 coding agent——Claude Code、Cursor、OpenHands——骨架里的几乎每一块组件，都能在这些论文里找到原型。读这些论文不是为了了解历史，而是为了看清：**哪些设计是被实验验证过的，哪些只是工程界的惯性**。

本页选取 7 篇对 harness 设计影响最深的论文逐篇精读。每篇按同一结构展开：要解决什么问题 → 核心机制 → 关键实验结论 → 对 harness 设计的启示。最后一部分是重点——一篇论文的价值不在于它刷了多少分，而在于它改变了后来人构建 agent 的方式。

## 地图：论文与 harness 组件的对应关系

| 论文 | 年份 | 定义了什么 | 对应组件 |
|---|---|---|---|
| MRKL | 2022 | 路由器 + 专家工具的模块化架构 | [工具系统](/components/tools) |
| ReAct | 2022 | Thought–Action–Observation 循环 | [Agent 循环](/components/agent-loop) |
| Toolformer | 2023 | 模型自学何时调用工具 | [工具系统](/components/tools) |
| Reflexion | 2023 | 语言化的失败反思与情景记忆 | [记忆系统](/components/memory) |
| Generative Agents | 2023 | 记忆流 + 反思 + 规划 | [记忆](/components/memory)、[规划](/components/planning) |
| Voyager | 2023 | 技能库与终身学习 | [Skills](/components/skills)、[记忆](/components/memory) |
| SWE-agent | 2024 | Agent-Computer Interface | [工具系统](/components/tools)、[案例：SWE-agent](/case-studies/swe-agent) |

---

## 1. ReAct：推理与行动的交织（2022）

::: info 论文信息
**ReAct: Synergizing Reasoning and Acting in Language Models** — Shunyu Yao 等（普林斯顿大学 & Google Research Brain），2022 年 10 月发布（arXiv:2210.03629），ICLR 2023 录用。
:::

### 要解决什么问题

2022 年，链式思考（chain-of-thought, CoT）刚被证明能大幅提升推理能力，但 CoT 是一个**封闭系统**：模型只能基于参数里的知识推理，一旦记错事实就一路错下去（幻觉级联）。另一边，已有的行动型 agent（如 ALFWorld 上的模仿学习/强化学习方法）会在环境里执行动作，但**没有显式的推理痕迹**，无法规划、无法处理意外、无法解释自己在做什么。

ReAct 的问题很直接：推理和行动能不能放在同一个生成序列里，互相喂给对方？

### 核心机制

用一个 few-shot 提示模板，让模型交替生成三种文本：

```
Thought 1: 我需要找到《少女前线》的研发商，先搜索。
Action 1: search["少女前线 研发商"]
Observation 1: 《少女前线》由散爆网络（MICA Team）开发……

Thought 2: 散爆网络的创始公司注册时间我需要确认，再搜。
Action 2: lookup["散爆网络 成立时间"]
Observation 2: 散爆网络成立于 2015 年……

Thought 3: 两个事实都有了，可以回答。
Action 3: finish["2015 年"]
```

关键设计只有三条，每一条都值得展开：

1. **Thought 是自由文本，不是结构化状态**。模型随时可以用自然语言维护"我现在计划是什么、卡在哪、下一步怎么办"。这是一个极其便宜的"工作记忆"实现——零额外基础设施。
2. **Action 是稀疏的、与任务相关的小词表**。HotpotQA 只有 `search / lookup / finish` 三个动作；ALFWorld 是环境动作集。动作空间小，模型才学得会什么时候该停。
3. **Observation 由环境写回，模型对上下文无条件信任**。这既是能力来源，也是后来所有提示注入（prompt injection）问题的根源。

### 关键实验结论

- 知识型任务（HotpotQA、FEVER，用 PaLM-540B + Wikipedia API）：ReAct 显著减少 CoT 的幻觉问题，与 CoT 平分秋色或更优；ReAct + CoT-SC 的组合在 FEVER 上达到最佳。
- 决策型任务（ALFWorld、WebShop）：ReAct 大幅领先——ALFWorld 成功率比最好的模仿/强化学习基线**绝对提升 34 个百分点**，WebShop 绝对提升约 10 个百分点，而当时其他方法甚至还没超过人类专家水平的一半。

### 对 harness 设计的启示

- **Agent 循环的最小骨架就此定型**。今天所有工具调用循环（包括原生 function calling）都是 ReAct 的工业化版本：Thought 被内化进模型推理，Action 被形式化成 JSON schema 的工具调用，Observation 被截断/压缩后回灌。想透彻理解这个循环，见 [Agent 循环](/components/agent-loop)。
- **"推理痕迹写进上下文"是免费的上下文工程**。ReAct 证明了让模型"边想边做边记录"比只做不想、只想不做都强——这是 [上下文工程](/components/context-engineering) 的第一课：上下文不只是给模型看的资料，也是模型自己的草稿纸。
- **动作空间要小而专**。ReAct 只用三五个动作就能完成任务，这与 SWE-agent 后来提出的 ACI（见第 7 篇）遥相呼应：给模型的界面越像"为模型设计的"，成功率越高，而不是把人类的整个 shell 扔给它。

---

## 2. MRKL：神经符号的模块化架构（2022）

::: info 论文信息
**MRKL Systems: A modular, neuro-symbolic architecture that combines large language models, external knowledge sources and discrete reasoning** — Ehud Karpas 等（AI21 Labs），2022 年 5 月发布（arXiv:2205.00445）。
:::

### 要解决什么问题

MRKL 要回答的是一个结构性问题：LLM 什么都懂一点，但**算术会算错、事实会过时、推理会漂移**。与其期待一个更大的模型把所有问题都学会，能不能把模型当"调度员"，把确定性的活交给确定性的系统？

### 核心机制

MRKL（Modular Reasoning, Knowledge and Language，发音同 "miracle"）是一个三段式架构：

```
                 用户问题
                    │
             ┌──────▼──────┐
             │   Router    │  ← LLM 扮演路由器
             │ (Jurassic-1)│     判断该交给哪个专家
             └──────┬──────┘
        ┌───────────┼────────────┐
        ▼           ▼            ▼
   ┌─────────┐ ┌──────────┐ ┌──────────┐
   │ 计算器   │ │ 知识库/   │ │ 通用 LLM │  ← 专家模块
   │(离散符号)│ │ API 专家  │ │ 兜底专家  │
   └─────────┘ └──────────┘ └──────────┘
```

- **Router**：一个 LLM，负责把输入路由到合适的专家（expert）。论文给出了训练路由器的方案，但也指出 prompt-based 路由已经可用。
- **专家模块**：计算器、天气/汇率 API、数据库检索，以及"通用 LLM 兜底专家"。每个专家只管自己擅长的确定性任务。
- **神经符号（neuro-symbolic）结合**：神经部分负责理解意图，符号部分负责执行确定性计算——各取所长。

### 关键实验结论

论文报告，用 6B 参数的 Jurassic-1 加上计算器专家组成的 MRKL 系统，在算术类应用题上超过了 175B 的 GPT-3——一个**小 30 倍的模型靠外挂确定性工具反超了大模型**。这个结果在 2022 年是反直觉的：当时主流叙事还是"模型规模即一切"。

### 对 harness 设计的启示

- **MRKL 是"工具系统"这个概念第一次被完整定义**：谁决定调用（router）、调什么（专家）、结果怎么回来（再交给 LLM 整合）。今天的工具调用协议（function calling、MCP）只是把这个架构标准化了。详见 [工具系统](/components/tools)。
- **路由是这个架构里最脆弱的一环**。论文自己也承认：加一个专家就要重训或重调路由器。这个痛点一直延续到今天——工具多了之后模型选错工具、传错参数，本质都是路由问题，见 [常见陷阱](/practice/pitfalls)。
- **"通用 LLM 兜底专家"是工程上的诚实**：不是所有输入都能被路由到确定性专家，兜底专家保证了系统的完备性。今天设计 harness 时同样需要想好：工具都处理不了的时候，系统该怎么办。

---

## 3. Toolformer：模型自学使用工具（2023）

::: info 论文信息
**Toolformer: Language Models Can Teach Themselves to Use Tools** — Timo Schick 等（Meta AI），2023 年 2 月发布（arXiv:2302.04761），NeurIPS 2023 录用。
:::

### 要解决什么问题

MRKL 的路由器需要人工指定规则或标注数据；ReAct 依赖精心手写的 few-shot 示例。能不能让模型**自己学会**在什么位置插入工具调用、调什么、结果如何融合？Toolformer 把工具使用从"提示工程问题"变成了"训练数据自动生成问题"。

### 核心机制

以 GPT-J（6.7B）为基座，分四步：

1. **采样候选调用**：用 few-shot 提示让模型在普通文本里"随手"插入 API 调用（如 `Pittsburgh 的人口是 QA("Pittsburgh 的人口是多少?") → 302,971`）。
2. **执行调用**：真的去调用那 5 个工具——问答系统、计算器、Wikipedia 搜索、机器翻译、日历。
3. **按"是否有用"过滤**：这是全文最精妙的一步。对每个候选调用，比较"带工具结果的续写"与"不带结果的续写"哪个让后续文本的损失更低。只有**确实降低了预测损失**的调用才保留。
4. **用过滤后的数据微调**：模型由此学会"什么时候值得打断自己去查一下"。

注意第 3 步的判据是**纯自监督**的：没有人工标注，"有用"的定义就是"帮模型更好地预测了后面的文本"。

### 关键实验结论

- 6.7B 的 Toolformer 在多个下游任务的零样本（zero-shot）表现上**超过了 175B 的 GPT-3**，尤其在需要精确事实或算术的任务上。
- 模型的工具调用行为是"涌现的自觉性"：它倾向于在数字、日期、事实性名词处插入调用——正是它最容易出错的地方。

### 对 harness 设计的启示

- **工具调用时机可以学，不必全靠提示词硬约束**。Toolformer 是后来所有"工具使用数据合成"工作的祖师爷——今天各家模型厂商训练 function calling 能力时，核心思路仍是"合成候选 → 执行 → 过滤 → 微调"。
- **"降低损失"作为过滤器是个可迁移的工程直觉**。当你在 harness 里做记忆写入、技能沉淀时，同样需要一个客观判据决定"这条经验值不值得存"，而不是来者不拒。这个思想在 Voyager 的技能验证（第 6 篇）里再次出现。
- **模型自己会暴露它的不确定性**。Toolformer 学到的调用位置分布，其实就是一张"模型哪里不可靠"的地图。做可观测性设计时，工具调用的密度和位置是值得记录的信号，见 [可观测性](/components/observability)。

---

## 4. Reflexion：用语言做强化学习（2023）

::: info 论文信息
**Reflexion: Language Agents with Verbal Reinforcement Learning** — Noah Shinn 等（东北大学 & MIT），2023 年 3 月发布（arXiv:2303.11366），NeurIPS 2023 录用。
:::

### 要解决什么问题

ReAct 让 agent 会做事，但**不会在失败后变好**：同样的坑下次还会踩。传统强化学习能解决这个问题，但改权重成本高、慢、且不适合闭源模型。Reflexion 的问题是：能不能不改权重，只用自然语言，让 agent 从失败中学到东西？

### 核心机制

Reflexion 把强化学习的三件套全部"语言化"：

```
   ┌────────────┐
   │  Actor     │  ← 生成轨迹（如 ReAct 循环）
   └─────┬──────┘
         ▼ 环境给出成败信号（标量/文本）
   ┌────────────┐
   │ Evaluator  │  ← 判断这次尝试是否成功
   └─────┬──────┘
         ▼ 失败时
   ┌────────────┐
   │Self-Reflect│  ← 用 LLM 生成一段自然语言反思：
   │            │    "我上次错在没检查返回值就继续了……"
   └─────┬──────┘
         ▼
   ┌────────────┐
   │ 情景记忆    │  ← 反思存入缓冲区，下次尝试时
   │ (episodic) │    注入提示词，指导新轨迹
   └────────────┘
```

三个组件都用同一个 LLM 以不同提示词扮演。**"梯度"变成了文字**：不是参数更新，而是一段写给下次自己的经验教训，存在情景记忆（episodic memory）里。

### 关键实验结论

- **HumanEval 编码任务：Reflexion 达到 91% pass@1，超过 GPT-4 裸跑的 80%**——一个"反思回路"把同样模型的成绩抬了 11 个百分点。
- ALFWorld 决策任务：ReAct + Reflexion 在 134 个任务中完成 130 个（约 97%），大幅超过纯 ReAct。
- HotpotQA：反思显著优于简单的重试基线，说明收益来自"学到了什么"，而不是"多试几次"。

### 对 harness 设计的启示

- **失败是比成功更值钱的信号，但前提是你把它写下来了**。这是 [记忆系统](/components/memory) 设计里最实用的一课：情景记忆不只存"发生了什么"，更要存"上次为什么失败、这次别怎么做"。
- **评估器必须可靠，否则反思是在给幻觉做加法**。Reflexion 的收益建立在"环境能给出可信的成败信号"上（单元测试、任务完成判定）。在没有可靠验证器的任务里，自我反思很容易退化成自我安慰——这是 [常见陷阱](/practice/pitfalls) 里反复强调的一点。
- **循环要有限度**。Reflexion 默认重试次数有限；无界的"反思-重试"循环会烧 token 且收敛不了。今天设计 agent 循环时，最大步数、最大重试、预算上限都是必备件，见 [Agent 循环](/components/agent-loop)。

---

## 5. Generative Agents：记忆流、反思与规划（2023）

::: info 论文信息
**Generative Agents: Interactive Simulacra of Human Behavior** — Joon Sung Park 等（斯坦福大学 & Google Research），2023 年 4 月发布（arXiv:2304.03442），UIST 2023 最佳论文。
:::

### 要解决什么问题

让 25 个 agent 在一个叫 Smallville 的沙盒小镇里"生活"两天游戏时间：起床、做早餐、上班、闲聊、传播消息，甚至自发组织一场情人节派对。要行为**可信（believable）**，agent 必须记得昨天发生了什么、形成对彼此的看法、并为明天做计划——这恰好是 harness 的"记忆 + 规划"两大难题的极端版本。

### 核心机制

架构三件套，全部围绕一个核心数据结构——**记忆流（memory stream）**，即以自然语言逐条记录 agent 全部经历的长列表：

1. **检索（retrieval）**：每次决策前，从记忆流里按三个分数加权取回最相关的记忆——新近性（recency，指数衰减）、相关性（relevance，embedding 余弦相似度）、重要性（importance，LLM 打 1–10 分）。
2. **反思（reflection）**：当积累的重要性分数超过阈值，agent 停下来"想人生"：把近期记忆喂给 LLM，合成更高层的洞察（如"Klaus 一直在研究图书馆项目，他似乎对此很有热情"），再把洞察写回记忆流。
3. **规划（planning）**：自顶向下递归分解——先生成一天的粗计划，再拆成小时级，再拆成 5–15 分钟的动作；遇到意外事件就局部重规划。

### 关键实验结论

- 25 个 agent 在两天内涌现出了论文没有编程的**社会行为**：一条"要办情人节派对"的消息从 1 个 agent 扩散到 8 个，5 个 agent 在正确的时间地点到场；关于"谁竞选村长"的信息也在镇上传开。
- 消融实验（ablation）很关键：去掉反思、规划、检索三者中的任何一个，人类评估员对"行为可信度"的打分都显著下降——**三件套缺一不可，是架构而非装饰**。

### 对 harness 设计的启示

- **记忆不是日志，检索策略才是本体**。"全部存下来 + 按近因/相关/重要加权检索 + 定期压缩成高层抽象"，这套范式直接定义了今天 agent 长期记忆的主流做法，详见 [记忆系统](/components/memory)。
- **反思是"记忆的压缩算法"**。原始经历会无限膨胀，反思把多条观察蒸馏成可复用的判断——这与 Reflexion 的教训记忆互补：一个提炼世界观，一个提炼错误教训。
- **递归分解式规划**（天 → 小时 → 分钟）是 hierarchical planning 的最小实现，也是后来 [规划](/components/planning) 系统普遍采用的形态。注意它的代价：每一步都烧 LLM 调用，Smallville 跑两天花了数千美元的 API 费用——**架构优雅不等于成本可控**。

---

## 6. Voyager：会积累技能的终身学习 agent（2023）

::: info 论文信息
**Voyager: An Open-Ended Embodied Agent with Large Language Models** — Guanzhi Wang 等（NVIDIA、Caltech、UT Austin 等），2023 年 5 月发布（arXiv:2305.16291）。
:::

### 要解决什么问题

之前的 Minecraft agent（主要是强化学习方法）只能完成预先定义好的窄任务，无法**开放探索**、无法**积累可复用的能力**。Voyager 的问题是：一个 agent 能不能自己给自己出题、自己写代码解题、把解出来的技能存起来越滚越大？

### 核心机制

三个组件，全部用 GPT-4 黑盒驱动，不改任何权重：

1. **自动课程（automatic curriculum）**：GPT-4 根据当前状态（位置、物品栏、已完成任务）提出"下一个难易合适的任务"——比如先砍树，再合成木镐，再挖石头。
2. **迭代提示（iterative prompting）**：写代码 → 执行 → 拿环境反馈和报错 → 自我验证任务是否完成 → 失败就带着批评重写，直到成功或放弃。
3. **技能库（skill library）**：验证通过的代码技能存入向量数据库，key 是技能描述的 embedding，value 是代码本身。下次遇到相关任务，检索 top-5 技能作为上下文或直接调用。

Voyager 的动作空间是 **JavaScript 代码**（通过 Mineflayer API），而不是离散的按键动作——这是"代码即行动"（code as action）的先声。

### 关键实验结论

- 与当时的 SOTA（ReAct、Reflexion、AutoGPT 风格基线）相比，Voyager：**发现的独特物品多 3.3 倍，旅行距离长 2.3 倍，解锁关键科技树里程碑快至 15.3 倍**。
- 消融显示技能库是复利来源：有技能库的 Voyager 越跑越快；清空技能库后，agent 又退回到"每次都从零写代码"的状态。
- 零样本泛化：在新世界里，带着旧技能库的 Voyager 开箱即用，显著强于从头开始。

### 对 harness 设计的启示

- **技能库 = 可执行的记忆**。这是 Voyager 对后世影响最深的一个概念：记忆不一定是文本，可以是**验证过能跑通的代码/流程**。今天 Claude Code 的 Skills、各家 agent 的"工具沉淀"功能，思路同源，详见 [Skills](/components/skills)。
- **入库前要验证**。Voyager 只在"自我验证通过"后才把技能写入技能库——Toolformer 的"有用才保留"过滤器的具身版。没有验证的技能库是垃圾场，越检索越误导。
- **用代码而不是 API 列表作为动作空间**，换来了组合性：代码可以循环、分支、复用旧技能。这个判断后来被 CodeAct（2024）系统化验证，见文末延伸阅读。
- **自动课程是"任务规划"的一种现实解**：不给 agent 一个遥不可及的总目标，而是让它持续提出"跳一跳够得着"的子目标。对长程任务的规划器设计有直接参考价值，见 [规划](/components/planning)。

---

## 7. SWE-agent：界面即能力（2024）

::: info 论文信息
**SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering** — John Yang 等（普林斯顿大学），2024 年 5 月发布（arXiv:2405.15793），NeurIPS 2024 录用。
:::

### 要解决什么问题

到 2024 年，GPT-4 级别的模型写代码已经很强，但在真实软件工程基准 SWE-bench（修真实 GitHub issue）上，最好的非交互式检索系统只能解决 3.8%。SWE-agent 的赌注是：**瓶颈不在模型，在界面**——给模型设计的工具集、反馈格式、交互流程（作者称之为 Agent-Computer Interface, ACI）比模型本身更决定成绩。

### 核心机制

SWE-agent 不是"让模型随便用 bash"，而是围绕"LM 容易犯什么错"设计了一套专用界面：

- **文件查看器**：`open` 文件后只显示约 100 行的窗口，配合 `scroll_up / scroll_down / goto`——防止一次塞给模型整个文件导致注意力涣散。
- **受约束的编辑器**：`edit` 命令强制指定精确的行范围替换，避免模型生成大段自由 diff 出错；编辑后自动做 lint 检查，语法错误立即反馈。
- **搜索命令**：`search_dir / search_file` 返回精简结果，而不是 raw grep 输出。
- **反馈格式化**：把环境输出修剪成模型易读的形态；当模型输出格式非法时，返回的报错本身也经过精心设计，教模型自我纠正。

一句话：他们像给人类工程师设计 IDE 一样，给 LLM 设计了一套"模型友好型 IDE"。

### 关键实验结论

- **GPT-4 Turbo + SWE-agent：SWE-bench 完整测试集解决 12.47%（286/2294），Lite 子集解决 18.00%（54/300）**，是当时交互式系统的 SOTA，远超此前非交互式系统的 3.8%。
- 消融：把精心设计的 ACI 换成"裸 shell"基线，成功率**下降 10.7 个百分点**——界面设计贡献了大部分提升。
- 可迁移性：为 GPT-4 Turbo 设计的 ACI 换到 Claude 3 Opus 上也能解决 10.5% 的任务，说明好的界面设计有跨模型的一般性。

### 对 harness 设计的启示

- **ACI 是 harness 思想的最纯粹表达**：同一个模型，换一套界面，成功率差 3 倍以上。"模型能力 = 模型 × harness"这句话最硬的实验证据就来自这篇论文。详细剖析见 [案例：SWE-agent](/case-studies/swe-agent)。
- **为人类设计的接口不等于为模型设计的接口**。grep 的全量输出、bash 的报错格式、编辑器的光标交互，都是按人类认知设计的。给模型用的版本要：限制信息密度、结构化反馈、报错即教程。这条原则通用于所有 [工具系统](/components/tools) 设计。
- **约束是特性不是限制**。限制一次只看 100 行、编辑必须给行范围——看似剥夺了模型自由，实则是把注意力管理外包给了 harness。这与 [上下文工程](/components/context-engineering) 的核心主张一致：上下文里少一点噪音，胜过模型多一点聪明。

---

## 放在一条时间线上看

```
2022.05  MRKL ──────────── 路由器 + 专家：工具系统概念成形
2022.10  ReAct ─────────── 推理与行动交织：agent 循环定型
2023.02  Toolformer ────── 工具调用从提示技巧变成可训练能力
2023.03  Reflexion ─────── 失败的语言化记忆：从错误中学习
2023.04  Generative Agents 记忆流 + 反思 + 规划三件套
2023.05  Voyager ───────── 技能库：可执行的终身记忆
2024.05  SWE-agent ─────── ACI：界面设计即系统能力
```

把这 7 篇连起来看，会发现一条清晰的脉络：**研究重心不断从"模型里有什么"移向"模型外面包着什么"**。ReAct 之前，大家以为能力在参数里；SWE-agent 之后，很难再有研究者否认——harness 本身就是系统能力的主要变量。

::: tip 还想深入？这些也值得读
- **CodeAct**（arXiv:2402.01030, ICML 2024）：系统论证"用可执行 Python 代码作为统一动作空间"优于 JSON/文本动作，成功率更高、所需步数更少——Voyager"代码即行动"思想的通用化。
- **WebGPT**（arXiv:2112.09332, 2021）：用人类反馈训练浏览器交互的 QA agent，"浏览型 agent"的先驱。
- **Tree of Thoughts**（arXiv:2305.10601, NeurIPS 2023）：把单链推理扩展为可搜索的思维树，影响了一代规划器设计。
- **HuggingGPT**（arXiv:2303.17580, NeurIPS 2023）：LLM 作为控制器调度专业模型，MRKL 思路在模型生态上的放大版。

完整文献脉络见 [前沿论文](/papers/frontier)。
:::

## 延伸阅读

- [Agent 循环](/components/agent-loop)——ReAct 循环的工程化实现
- [工具系统](/components/tools)——从 MRKL 到 MCP 的工具架构演进
- [记忆系统](/components/memory)——记忆流、反思、技能库的统一视角
- [规划](/components/planning)——递归分解与自动课程的当代形态
- [Skills](/components/skills)——Voyager 技能库思想的产品化
- [案例：SWE-agent](/case-studies/swe-agent)——ACI 设计的完整案例分析
- [前沿论文](/papers/frontier)——这些经典之后的最新进展

## 参考资料

- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)
- [MRKL Systems (arXiv:2205.00445)](https://arxiv.org/abs/2205.00445)
- [Toolformer: Language Models Can Teach Themselves to Use Tools (arXiv:2302.04761)](https://arxiv.org/abs/2302.04761)
- [Reflexion: Language Agents with Verbal Reinforcement Learning (arXiv:2303.11366)](https://arxiv.org/abs/2303.11366)
- [Generative Agents: Interactive Simulacra of Human Behavior (arXiv:2304.03442)](https://arxiv.org/abs/2304.03442)
- [Voyager: An Open-Ended Embodied Agent with Large Language Models (arXiv:2305.16291)](https://arxiv.org/abs/2305.16291)
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
- [CodeAct (arXiv:2402.01030)](https://arxiv.org/abs/2402.01030)
