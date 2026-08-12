---
title: 演进简史
description: 从 2022 年 ReAct 与 Toolformer 到 2026 年的 harness 话语：梳理智能体骨架五年演化中的每个关键转折点——当时大家以为的解法，以及后来被证伪或证实的东西。
---

# 演进简史

Agent harness 不是某个人发明的，它是被一连串**失败的解法**逼出来的。每一代 agent 系统都在回答同一组问题——上下文放什么、工具怎么接、循环怎么转、控制权给谁——只是每个时代的答案都被下一个时代部分推翻。

这篇简史按时间线走一遍这些转折点。每个节点我们都问两个问题：**当时大家以为的解法是什么？后来什么东西被证伪、什么被证实？** 这两个问题比事件本身重要，因为其中好几个"当时以为"，今天仍在以新包装重新流行。

```text
2022.10  ReAct 论文               reasoning + acting 交替，agent loop 的原型
2022.10  LangChain 开源           第一代 harness 框架
2023.02  Toolformer               工具使用变成可训练的能力
2023.03  GPT-4 / ChatGPT API      自主 agent 的经济学成立
2023.03  BabyAGI / AutoGPT        第一次爆发与第一次幻灭
2023.06  OpenAI function calling  工具调用成为 API 原语
2023.10  SWE-bench                第一把可复现的标尺
2024.03  Devin                    "AI 软件工程师" 的产品化宣言
2024.04  SWE-agent / OpenDevin    开源反攻，ACI 概念提出
2024.11  Cursor agent 模式 / MCP  形态收敛 + 协议标准化（同一周）
2024.12  Building Effective Agents  workflow vs agent 之争定调
2025.02  Claude Code              终端原生 coding agent 定型
2025.03  METR 长时程测量           前沿转向长任务可靠性
2025.06  context engineering      话语转向：提示工程退场
2025.09  Claude Agent SDK         "harness" 成为正式术语
```

## 2022：地基——ReAct 与 Toolformer

### ReAct：loop 的诞生

2022 年 10 月，Yao 等人发表了 [ReAct](https://arxiv.org/abs/2210.03629)（ICLR 2023 收录）：让模型交替生成"思考轨迹"（reasoning trace）和"动作"（action），动作作用于外部环境，观察结果再回灌给模型继续推理。

**当时以为的解法**：这主要被视为一种提示技巧——在 prompt 里放几个"思考—行动—观察"的示例，模型就会照做。它和 chain-of-thought 一样，被归在 prompt engineering 的文件夹里。

**后来证实的**：ReAct 真正的遗产不是那几个 prompt 示例，而是那个**交替结构本身**——"模型出动作、harness 执行动作、观察回灌、模型再决策"。今天所有 coding agent 的主循环（详见 [Agent Loop](/components/agent-loop)）都是这个结构的加厚版。**后来被内化的**：ReAct 里手写的"思考轨迹"，在推理模型（o1、R1）时代被训练进了模型内部，不再需要提示工程去诱发——这是"prompt 技巧被模型吸收"的第一次演示，后面会反复发生。

### Toolformer：工具使用的另一条路线

2023 年 2 月，Meta 发表 [Toolformer](https://arxiv.org/abs/2302.04761)：让模型自监督地学会何时调用计算器、搜索引擎等 API——调用有没有用，用"是否降低了后续 token 的预测损失"来判定，有用的调用才留进训练数据。

**当时以为的解法**：两条路线摆在一起——ReAct 派认为工具使用靠 harness（prompt + 解析 + 执行），Toolformer 派认为靠训练（把能力烙进权重）。

**后来证实的**：答案是"都要"。工具调用的**能力**确实被训练进了模型（function calling 时代的模型不再需要 ReAct 式示例才会调工具），但工具的**接入、执行、结果回灌、失败处理**永远留在模型外面。Toolformer 赢了"能力在哪"的问题，ReAct 赢了"系统怎么搭"的问题。

::: info 同期的一条暗线
2022 年 10 月 Harrison Chase 开源了 LangChain——最初只是把 LLM 调用串成链的 Python 库。它是"为模型搭架子"这件事第一次变成框架工程。后来它因抽象过重饱受批评，但"harness 值得一个框架"这个判断被整个行业继承了。
:::

## 2023：AutoGPT 之夏——爆发与幻灭

### 爆发的引信是经济学

2023 年 3 月 1 日 ChatGPT API 开放，3 月 14 日 GPT-4 发布。两件事合起来意味着：个人开发者第一次能以可承受的价格，把足够强的模型放进一个循环里烧 token。几周内，自主 agent 如雨后春笋：

- 3 月 28 日，Yohei Nakajima 发布 [BabyAGI](https://github.com/yoheinakajima/babyagi)：约一百多行 Python，实现"任务创建 → 执行 → 重排优先级"的闭环；
- 3 月 30 日，Toran Bruce Richards 发布 [AutoGPT](https://github.com/Significant-Gravitas/AutoGPT)：给 GPT-4 一个目标，让它自己提示自己跑下去——联网、读写文件、执行代码。它成为当时 GitHub 历史上增长最快的项目，几周内突破 10 万 star。

**当时以为的解法**：全自主——给个目标，人走开，agent 自己规划、自己执行、自己纠错，直到完成。配套信念有两个：一是**规划能力被高估**——以为模型能制定并执行多步计划；二是**prompt engineering 是核心技能**——以为写好系统提示词就解决了大半问题。

**后来证伪的**：几乎所有用户很快撞上了同一组失败模式——agent 在某个失败步骤上死磕半小时、上下文溢出后忘记最初目标、规划本身成为沉没成本、API 账单失控。BabyAGI 式"每执行一步就重新生成任务队列"的设计，让 agent 永远在调整计划而不是干活（这段教训详见[规划与任务分解](/components/planning)）。到 2023 年下半年，"AutoGPT 类全自主 agent"作为产品路线事实上破产了。

**后来证实的**：同样从那个夏天活下来三样东西——**循环**是对的（目标驱动的 agent loop 确实是正确抽象）；**工具**是对的（联网、文件、代码执行确实是能力放大器）；**人不该走开**——完全无人值守被证伪，这直接孕育了后来所有产品的权限与审批设计（见[权限与人机协作](/components/permissions)）。

### 年中的两件"静悄悄"的大事

幻灭期里发生的两件事，比 AutoGPT 本身影响更深远：

**2023 年 6 月，OpenAI 上线 [function calling](https://openai.com/blog/function-calling-and-other-api-updates)。** 工具调用从"prompt 里约定格式、harness 里写正则解析"的民间协议，变成 API 级别的结构化原语。harness 解析模型输出的可靠性问题被厂商收编，工具系统（见[工具系统](/components/tools)）从此有了标准接口的地基——MCP 是这条线的终点。

**2023 年 7 月，[Lost in the Middle](https://arxiv.org/abs/2307.03172) 发表。** 论文证明模型对长上下文中间部分的信息利用率显著低于头尾。这是"上下文不是越多越好"的早期硬证据——两年后 context engineering 话语的理论先声（见[上下文工程](/components/context-engineering)）。

## 2024：SWE-bench 与 coding agent 的突围

### 标尺先于突破

2023 年 10 月，普林斯顿团队发布 [SWE-bench](https://arxiv.org/abs/2310.06770)：用真实 GitHub issue 作为任务、以真实单测通过与否作为判据。它的意义不在难度，而在**可复现、可比较**——agent 系统第一次有了一把公认的尺。这把尺直接改变了演化的动力：harness 从"demo 工程"变成了"可以被系统性优化的对象"。

### 2024 年 3–4 月：六周定格局

- 3 月 12 日，Cognition 发布 [Devin](https://cognition.com/blog/introducing-devin)，号称"第一个 AI 软件工程师"，在 SWE-bench 上拿到 13.86%（当时最好的 GPT-4 基线只有个位数）。演示视频病毒式传播，也迅速引发对其演示选择性的质疑。
- 4 月，普林斯顿开源 [SWE-agent](https://arxiv.org/abs/2405.15793)（NeurIPS 2024），用 GPT-4 在完整 SWE-bench 上解决 12.29%——与 Devin 的发布数字同一量级，但代码完全公开。它的论文提出了 **Agent-Computer Interface（ACI）** 概念：为模型设计的命令与反馈格式，和 prompt engineering 一样直接影响成绩。**工具接口设计本身被扶正为研究对象**——这是 harness 工程的学术正名（见 [SWE-agent 案例](/case-studies/swe-agent)）。
- 同期，开源社区在 Devin 发布后数周内做出 OpenDevin（后更名 [OpenHands](/case-studies/openhands)），把"自主软件工程师"变成了公共实验场。

**当时以为的解法**：Devin 的叙事——把 agent 包装成一个"远程员工"，给它自己的 shell、浏览器和编辑器，人只做甲方。

**后来证伪的**：完全拟人化的"AI 员工"包装。开发者不想要一个交出控制权的黑箱同事，想要的是长在自己工作流里、随时可干预的工具。Devin 的高定价与早期实测落差（Answer.AI 等第三方评测显示实际任务失败率很高）证明了这一点。

**后来证实的**：coding 是 agent 第一个真正跑通的垂直场景，原因恰恰是 harness 层面的——代码环境**可执行、可验证、反馈即时**，agent loop 的"观察"环节质量极高。同一年，通用 web 操作类 agent 依然没有突破，反证了这一点：不是模型忽然会干活了，是代码这个环境恰好适合 loop。

### 年底定调：workflow vs agent

2024 年 12 月，Anthropic 发表 [Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)，给了一场持续一年的争论划了界限：

> **Workflow** 是"LLM 和工具被预定义代码路径编排"的系统；**agent** 是"LLM 动态指挥自己的流程和工具使用"的系统。

文章的立场——**先找能用的最简单方案，只在确有必要时增加复杂度**——成为此后 harness 设计的默认宪法。它实质上宣判了 2023 年式重型多代理框架的失败，也预告了 2025 年收敛的方向：简单的 loop + 好的工具 + 好的上下文，胜过精巧的预定义流程。

## 2024 底–2025：形态收敛与话语转向

### 同一周的两个信号

2024 年 11 月的最后一周发生了两件看似无关的事：

- 11 月 24 日，Cursor 发布 0.43 版本，Composer 加入早期 **agent 模式**：自己选上下文、自己跑终端命令（见 [Cursor 案例](/case-studies/cursor)）；
- 11 月 25 日，Anthropic 发布 [Model Context Protocol（MCP）](https://www.anthropic.com/news/model-context-protocol)：一个开放标准，统一"应用如何向模型暴露工具、数据与上下文"，常被比作 AI 应用的 USB-C 接口。

一个是产品形态，一个是接入协议，指向同一件事：**工具与上下文的接入层正在标准化、通用化**。三个月后（2025 年 2 月 24 日），[Claude Code](https://www.anthropic.com/news/claude-3-7-sonnet) 以研究预览形式发布，把这套收敛形态钉死在终端里（见 [Claude Code 案例](/case-studies/claude-code)）。

### 收敛出的通用形态

到 2025 年中，主流 coding agent 在设计上惊人地一致，与 2023 年的 AutoGPT 形成镜像：

```text
        2023 AutoGPT                     2025 收敛形态
┌──────────────────────────┐   ┌──────────────────────────┐
│ 自提示循环，无人值守       │   │ 单 agent loop + 人类在场   │
│ 宏伟的多步计划            │   │ 轻量 todo list，滚动修订    │
│ 庞大的专用工具集           │   │ 少量通用原始工具            │
│ （几十个插件）             │   │ (读/写/grep/bash)          │
│ 向量数据库存"记忆"         │   │ 一个 markdown 文件 + 压缩   │
│ 无权限概念，自动执行        │   │ 工具白名单 + 逐条审批       │
│ 每步重规划                │   │ 模型自主决定下一步          │
└──────────────────────────┘   └──────────────────────────┘
     智能在 harness 里               智能留给模型，
     （结果模型接不住）               harness 做薄做稳
```

右列就是今天的默认答案：**harness 保持薄而稳，把判断留给模型，把控制留给人**。值得注意的是左列每一项当年都被认为是"更先进"的设计——演化方向是**减法**，不是加法。

### 话语转向：从 prompt engineering 到 context engineering

2025 年 6 月 18 日，Shopify CEO Tobi Lütke [发帖](https://x.com/tobi/status/1935533422589399127)："我更喜欢 context engineering 这个词，它更好地描述了核心技能：提供全部上下文、让任务对 LLM 而言可解的艺术。"一周后 Andrej Karpathy [跟帖](https://x.com/karpathy/status/1937902205765607626)背书：工业级 LLM 应用里真正的活儿，是"用恰好正确的信息填满上下文窗口的精细艺术与科学"。

这次改名不是修辞游戏。**prompt engineering 预设了"模型在真空里回答一个问题"；context engineering 承认"模型在一个持续演化的系统里做一连串决策"**——harness 要在每一步动态决定注入什么、压缩什么、隔离什么（见[上下文工程](/components/context-engineering)）。同样在这个月，Cognition 发表 [Don't Build Multi-Agents](https://cognition.ai/blog/dont-build-multi-agents)，把 context engineering 直接称为"构建 AI agent 的工程师的第一要务"。2023 年那本"提示词技巧大全"的文件夹，至此正式移交给了 harness。

## 2025–2026：harness 得名，前沿转向

### "harness"一词的确立

2025 年 9 月，Anthropic 把 Claude Code SDK 更名为 Claude Agent SDK，官方表述是"驱动 Claude Code 的那套 **agent harness**"。这个词随后被 OpenAI Codex 团队等广泛使用（词源与定义详见[什么是 Agent Harness](/guide/what-is-harness)）。

命名看似小事，实则是认知归位：它正式承认了 **agent 的能力是模型与那套外围系统的联合产出**——2025 年底 Confucius Code Agent 论文用对照实验给出量化证据（同一模型只换 scaffold，SWE-bench Pro 成绩差 9 个百分点），2026 年初《Stop Comparing LLM Agents Without Disclosing the Harness》则把"不披露 harness 的跑分不可比较"写进了标题。当年被嘲笑的"套壳"，如今有了自己的名字、论文和度量。

### 前沿一：子代理与多代理的二次出山

2025 年 6 月 13 日，Anthropic 发表[多代理研究系统的工程复盘](https://www.anthropic.com/engineering/multi-agent-research-system)：orchestrator-worker 架构，主 agent 分解问题、派生并行子代理（各有独立上下文窗口）、汇总结果，在其内部研究评测上比单代理提升 90.2%——代价是约 15 倍 token。

**与 2023 年那波多代理热的关键区别**：这次子代理不是"宏伟计划"的执行器，而是**上下文隔离的工具**——把"占用大量 token 的中间过程"（搜索、阅读、试错）隔离到子上下文里，只把结论带回主线（见[子代理](/components/subagents)）。Cognition 前一天刚发文反对多代理（子代理间会做出互相冲突的隐式决策），Anthropic 用生产系统给出了反例——这场 24 小时内观点对撞的公开争论至今没有标准答案，它是当前 harness 设计最活跃的前沿。

### 前沿二：长时程任务

2025 年 3 月，METR 发表 [Measuring AI Ability to Complete Long Tasks](https://arxiv.org/abs/2503.14499)：以"人类完成该任务所需时间"为标尺测量 agent 能可靠完成的任务长度，发现前沿模型的 50% 成功时域约每 7 个月翻一倍（当时最强的 Claude 3.7 Sonnet 约为 50 分钟量级）。

长时程化对 harness 提出了最硬的需求：上下文必然溢出（要压缩与摘要）、会话必然中断（要持久化与恢复，见[记忆系统](/components/memory)）、目标必然漂移（要外化的计划工件）、单上下文必然不够用（要子代理分治）。**长任务是把所有 harness 组件同时压到极限的试金石**——这也是本站把[可观测性](/components/observability)单列的原因：跑几小时的 agent，没有轨迹审计就是黑箱。

::: warning 历史的回旋镖
注意 2023 年的幽灵仍在场：每 7 个月翻一番的时域曲线，正在重新点燃"全自主 AI 员工"的叙事。当时的失败条件是模型能力，被证伪的是"不需要 harness 设计"；这两条结论今天都没有过期。
:::

## 主线：变与不变

回头看这五年，一条清晰的双层运动：

**逐层退役给模型的**（曾是 harness 的职责，后被训练内化）：手写的 reasoning 示例（→ 推理模型）、工具调用的格式约定（→ function calling）、指令遵循的提示技巧（→ 对齐训练）。每一代模型升级，都吃掉 harness 的一部分厚度——为旧模型精心调优的复杂 harness 经常在新模型上变成累赘。

**始终不变的四组问题**，每一代系统都要重新回答：

| 问题 | 2023 的答案 | 2025–26 的答案 |
| --- | --- | --- |
| **上下文**：模型每步看到什么 | 全塞进去 + 向量检索 | 动态组装、压缩、隔离（context engineering） |
| **工具**：模型能做什么 | 几十个专用插件 | 少量通用原语 + MCP 标准接入 |
| **循环**：任务怎么推进 | 自提示 + 每步重规划 | 单 loop + 外化 todo + 事件驱动修订 |
| **控制**：人何时介入 | 全自主，人不介入 | 权限分级 + 关键节点审批 |

模型在变，而且会继续变；但这四组问题不会消失——因为它们的根源不在模型能力，而在**模型与真实环境之间的结构性鸿沟**：上下文窗口有限、环境会变化、动作有后果、责任要有人承担。只要这条鸿沟存在，就需要 harness 去架桥。这就是本站存在的理由：研究 agent，就是研究这套在演化中保持不变的问题。接下来，读 [Harness 的解剖](/guide/anatomy) 把今天的答案逐层拆开，或读 [模型 vs. Harness](/guide/model-vs-harness) 把变与不变的边界切得更细。

## 延伸阅读

- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)
- [Toolformer: Language Models Can Teach Themselves to Use Tools (arXiv:2302.04761)](https://arxiv.org/abs/2302.04761)
- [OpenAI 博客：Function calling and other API updates（2023-06-13）](https://openai.com/blog/function-calling-and-other-api-updates)
- [Lost in the Middle: How Language Models Use Long Contexts (arXiv:2307.03172)](https://arxiv.org/abs/2307.03172)
- [AutoGPT 仓库（Significant-Gravitas/AutoGPT）](https://github.com/Significant-Gravitas/AutoGPT) 与 [BabyAGI 仓库（yoheinakajima/babyagi）](https://github.com/yoheinakajima/babyagi)
- [SWE-bench: Can Language Models Resolve Real-World GitHub Issues? (arXiv:2310.06770)](https://arxiv.org/abs/2310.06770)
- [Cognition：Introducing Devin（2024-03-12）](https://cognition.com/blog/introducing-devin)
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
- [Anthropic：Building Effective Agents（2024-12）](https://www.anthropic.com/research/building-effective-agents)
- [Anthropic：Introducing the Model Context Protocol（2024-11-25）](https://www.anthropic.com/news/model-context-protocol)
- [Cursor Changelog（0.43 版本，2024-11-24）](https://changelog.cursor.sh)
- [Anthropic：Claude 3.7 Sonnet 与 Claude Code（2025-02-24）](https://www.anthropic.com/news/claude-3-7-sonnet)
- [METR：Measuring AI Ability to Complete Long Tasks (arXiv:2503.14499)](https://arxiv.org/abs/2503.14499)
- [Tobi Lütke 与 Andrej Karpathy 关于 context engineering 的帖子（2025-06）](https://x.com/karpathy/status/1937902205765607626)
- [Anthropic：How we built our multi-agent research system（2025-06-13）](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Cognition：Don't Build Multi-Agents（2025-06-12）](https://cognition.ai/blog/dont-build-multi-agents)
- 站内相关页：[什么是 Agent Harness](/guide/what-is-harness)、[规划与任务分解](/components/planning)、[核心论文](/papers/core-papers)、[前沿论文](/papers/frontier)
