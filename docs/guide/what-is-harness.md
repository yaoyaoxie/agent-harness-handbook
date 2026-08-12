---
title: 什么是 Agent Harness
description: Agent Harness（智能体挽具）是包裹 LLM 的完整系统：上下文、工具、循环、记忆与护栏。本文给出精确定义、词源考据、与 model/agent/framework/scaffolding/wrapper 的辨析，以及 harness 决定 agent 能力上限的实证。
---

# 什么是 Agent Harness

一句话定义：**Agent Harness 是大语言模型（LLM）之外、让模型变成"能干活的智能体"的全部软件系统**——它决定模型每一步看到什么上下文、能调用什么工具、按什么循环推进任务、记住什么、何时停下来求助于人。

Anthropic 在官方文档里就是这么用这个词的：Claude Agent SDK 被描述为「驱动 Claude Code 的 agent harness」——SDK 暴露的不是模型，而是模型外面那一整套 agent loop、工具与上下文管理基础设施。OpenAI Codex 团队的工程师也用同样的框架讨论问题：他们把 "agent" 和 "harness" 当作同义词，用来指代模型之外的全部非模型基础设施。

这个术语在 2025 下半年到 2026 年初迅速流行开来，但它指代的东西存在已久。要理解为什么偏偏选了 harness 这个词，得先看看它在其他领域的三个老本行。

## 一、词源：harness 的三重隐喻

英文 harness 源自中古法语 *harneis*（装备、甲胄），在工程与日常语境里有三种主要用法，每一种都精确地对应了 AI agent 语境下的某层含义：

### 1. 马具 / 挽具：驾驭，而非替代

最古老的意思：套在马身上的整套辔头、缰绳和挽具。马提供力量，挽具把力量**引导**成可驾驭的、可控的牵引力。

这是最常被引用的隐喻：LLM 是一匹马力惊人的马，harness 是把它套上犁的那套装备。模型有生成能力，但没有挽具，这股力量无法被安全地转化为有用的工作。这也解释了为什么这个站点选择把 harness 译作「挽具/骨架」而不是「框架」——挽具强调的是**驾驭与引导**，而非结构本身。

### 2. 攀岩安全带：约束即安全

攀岩者的 harness 是一套约束系统：它限制你的运动，但正是这种限制让你在坠落时不至于摔死。

对应到 agent 系统：权限控制、人类审批、工具白名单、沙箱——这些"限制"不是 harness 的副产品，而是它的核心职责之一。一个没有任何约束的 agent 不是更自由的 agent，而是更危险的 agent。关于这一层，详见[权限与人机协作](/components/permissions)。

### 3. 测试夹具（test harness）：包裹被测对象的标准环境

软件工程里早就有 test harness 一词：包裹被测代码、提供输入、捕获输出、断言结果的那层脚手架代码。被测对象是纯粹的核心逻辑，harness 负责一切"外围"事务——数据准备、调用、验证、清理。

AI 评测社区直接继承了这个用法：跑 SWE-bench 时，包住模型、喂给它任务描述、解析它的动作、执行它调用的工具、记录轨迹的那套代码，就叫 harness。这个用法是最"硬核"的，也最直接地揭示了 harness 的工程本质：**它是模型与环境之间的适配层和驱动层**。

::: info 为什么是三个隐喻而不是一个定义？
三重隐喻恰好覆盖了 harness 的三大职责：**引导**（挽具 → agent loop 与规划）、**约束**（安全带 → 权限与护栏）、**适配**（测试夹具 → 上下文构造与工具协议）。任何只强调其中一面的定义都是不完整的。
:::

## 二、精确定义

综合以上，本站采用如下定义：

> **Agent Harness 是围绕 LLM 构建的完整运行系统，它负责：为模型构造每一步的输入上下文、向模型暴露并执行工具、驱动"感知—思考—行动"循环、管理记忆与状态、施加权限与安全约束、以及在需要时把控制权交还给人。**

可以用一个公式表达：

```
Agent = Model + Harness
```

而 Harness 又可进一步拆解为：

```
Harness = 上下文工程 + 工具系统 + 控制循环 + 记忆 + 权限护栏 + 观测性
```

```
┌─────────────────────────── Harness ───────────────────────────┐
│                                                               │
│   ┌─────────────┐   ┌─────────────┐   ┌───────────────────┐   │
│   │ 上下文工程   │   │  工具系统    │   │   记忆 / 状态     │   │
│   │ (prompt组装, │   │ (读写/shell/ │   │ (压缩/笔记/持久化) │   │
│   │  压缩, 注入) │   │  搜索/MCP...) │   │                   │   │
│   └──────┬──────┘   └──────┬──────┘   └─────────┬─────────┘   │
│          └─────────────────┼────────────────────┘             │
│                            ▼                                  │
│                    ┌───────────────┐                          │
│                    │  Agent Loop   │   ← 控制循环：思考→行动    │
│                    │ (驱动与停止)   │      →观察→再思考         │
│                    └───────┬───────┘                          │
│                            ▼                                  │
│                    ┌───────────────┐                          │
│                    │      LLM      │   ← 唯一不属于 harness    │
│                    │   (Model)     │      的部分               │
│                    └───────────────┘                          │
│                                                               │
│   权限 / 人类审批 / 沙箱 / 日志观测（横切关注，贯穿以上全部）      │
└───────────────────────────────────────────────────────────────┘
```

注意这个定义的两个边界：

- **模型不在 harness 之内。** 换模型不换 harness（比如 Claude Code 用不同的后端模型），系统的"性格"——它能干什么、怎么干、何时求助——基本不变；反过来，换 harness 不换模型，行为会天翻地覆。
- **模型权重之外的"模型侧技巧"也不算 harness。** 例如训练期注入的工具使用能力、system prompt 里的通用行为准则如果由 API 提供者固化在服务端，属于模型的"出厂配置"；但你作为应用开发者写给模型的 system prompt、CLAUDE.md、工具描述，全部属于 harness。

## 三、与相邻概念辨析

这是最容易混淆的部分，逐一厘清：

| 概念 | 含义 | 与 Harness 的关系 |
|---|---|---|
| **Model（模型）** | 训练好的权重 + 推理 API，输入 token 输出 token | Harness 的核心引擎，但本身不接触文件系统、网络或任何真实环境 |
| **Agent（智能体）** | 能自主完成任务的完整系统 | Agent = Model + Harness。说"我的 agent 很强"而不区分哪部分强，是当下讨论混乱的根源 |
| **Scaffolding（脚手架）** | 学术界常用词，特指 prompt 模板、工具接口设计、推理策略（如 ReAct）等"为模型搭的架子" | Harness 的**学术近义词**，但 scaffolding 通常偏静态、偏 prompt/交互协议层面；harness 还包含运行时设施：权限、持久化、并发子代理、观测 |
| **Framework（框架）** | LangGraph、CrewAI 这类代码库，提供构建 agent 的抽象和原语 | 框架是**用来写 harness 的工具**，不是 harness 本身。用 LangGraph 写出来的那个具体 agent 系统才是 harness |
| **Wrapper（套壳）** | 贬义词，指在模型 API 外面包一层薄薄的产品壳 | 几乎每个 agent 都曾被嘲笑是 wrapper。本站的立场：**当"壳"厚到包含上下文工程、工具系统、权限与恢复机制时，它不再是壳，而是系统的主体**。harness 工程正是对"套壳羞辱"最正式的回应 |
| **Environment（环境）** | agent 操作的对象：代码库、终端、浏览器、仓库 | 环境在 harness **之外**。harness 是模型与环境之间的中介层 |

几个值得单独说的判断：

**Scaffolding vs. Harness**：在学术论文里（尤其 SWE-agent、Confucius Code Agent 这类工作），scaffold 是标准用词，指同一 benchmark 下可替换的那套 agent 交互层。工业界在 2025 年后逐渐转向 harness 一词，因为它更能涵盖运行时基础设施（沙箱、权限、会话持久化），而不只是 prompt 结构。两者大面积重叠，本站默认视为同义词，仅在引用论文时保留 scaffold 原词。

**Agent vs. Harness**：之所以要切这一刀，是因为评测话语里"agent"经常把模型和系统混在一起报分。arXiv 上 2026 年一篇论文标题就叫《Stop Comparing LLM Agents Without Disclosing the Harness》（不披露 harness 就别比较 agent）——作者的核心论点是：一个 benchmark 分数是模型与 harness 的**联合产出**，但公开发布的数字只记录了模型，把其余全部隐藏了。

## 四、最小 Harness：一个 Agent Loop 伪代码

剥掉所有产品级复杂性，一个能跑起来的 harness 核心只有几十行。以下伪代码展示了最小可行结构：

```python
# 一个最小 agent harness 的核心循环
def run(task: str, model, tools: dict, max_steps: int = 50):
    # ① 上下文：harness 决定模型看到什么
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT + render_tools(tools)},
        {"role": "user",   "content": task},
    ]

    for step in range(max_steps):                # ② 控制循环与停止条件
        response = model.chat(messages)          #    唯一的"模型时刻"

        if response.has_tool_call:               # ③ 模型请求行动
            call = response.tool_call
            if call.name not in tools:           # ④ harness 校验与约束
                result = f"error: unknown tool {call.name}"
            else:
                result = tools[call.name].run(**call.args)  # 真实执行
            messages.append(response)
            messages.append({"role": "tool", "content": result})  # ⑤ 观察回灌
        else:
            return response.text                 # ⑥ 模型认为完成 → 停止

    return "达到步数上限，未完成任务"              # ⑦ harness 的兜底
```

就这七个职责：组装上下文、驱动循环、解析动作、校验执行、回灌观察、判定停止、失败兜底。Claude Code、SWE-agent、Aider 的 loop 本质上都是这个骨架的加厚版——加上上下文压缩、权限审批、子代理、记忆文件、恢复机制——但**每一层加厚都是 harness 决策，不是模型决策**。更多细节见 [Agent Loop](/components/agent-loop)。

::: tip 自己动手
这个最小 loop 真的可以在一个下午内写出来。[动手搭建一个 Harness](/practice/build-your-own) 会带你从零实现它，再逐层加上真正的工程设施。
:::

## 五、为什么 Harness 决定能力上限：实证

"harness 很重要"不是口号，有可核查的数据。

### 同一模型，换 scaffold，分数差出近 10 个百分点

2025 年 12 月的 Confucius Code Agent 论文（arXiv:2512.10398）在 SWE-bench Pro 公开子集上做了干净的对照实验：环境完全一致，只替换 agent scaffold：

| 骨干模型 | Scaffold | 解决率 (Pass@1) |
|---|---|---|
| Claude 4 Sonnet | SWE-Agent | 42.7% |
| Claude 4 Sonnet | CCA | 45.5% |
| Claude 4.5 Sonnet | SWE-Agent | 43.6% |
| Claude 4.5 Sonnet | Live-SWE-Agent | 45.8% |
| Claude 4.5 Sonnet | CCA | **52.7%** |
| Claude 4.5 Opus | Anthropic 私有 scaffold | 52.0% |
| Claude 4.5 Opus | CCA | **54.3%** |

同一个 Claude 4.5 Sonnet，从 SWE-Agent 换到 CCA，解决率从 43.6% 跳到 52.7%——**9.1 个百分点的提升完全来自 harness**，模型权重一个 bit 都没变。这个差距甚至大于同期很多模型代际升级带来的提升。

### 评测界已经开始正视这个问题

前面提到的《Stop Comparing LLM Agents Without Disclosing the Harness》（2026 年 2 月）进一步量化了这种混淆：在标准化的 SEAL scaffold 下，Claude Opus 4.5 在 SWE-bench Pro 上只能拿到 45.9%——显著低于 Anthropic 用自家私有 harness 报告的分数。结论是尖锐的：**不披露 harness 的 agent benchmark 分数，是不可比较的。**

### 工业界的公开背书

- Anthropic 工程博客 2026 年 3 月发表的 harness 设计文章记录了同一模型在 harness 迭代下的巨大产出差异：他们发现模型的自我评估存在上限，最终演进出「规划者 + 生成者 + 评估者」的三代理 harness 结构——模型没变，系统产出天差地别。其官方文档现在直接把 harness 设计作为独立主题来讨论（"A harness for every task"）。
- Claude Agent SDK 的官方定位就是「把驱动 Claude Code 的那套 harness 暴露给你编程」——Anthropic 事实上承认了：**Claude Code 的产品力不在模型，而在这套可以复用的 harness。**
- OpenAI Codex 团队、Firecrawl 等工程博客同期也得出了几乎相同的结论：讨论重心正从"用哪个模型"转向"怎么设计 harness"。

::: warning 一个诚实的反面
harness 不是万能杠杆。当模型能力跨代跃迁时，为旧模型精心调优的复杂 harness 经常变成累赘——Anthropic 自己在模型升级后就做过 harness 的简化。harness 会随模型能力共同演化，不存在一劳永逸的最优设计。这是本站反复强调的动态视角。
:::

## 六、权衡与取舍

理解 harness 的定义之后，紧接着的就是工程上的张力：

- **厚度 vs. 可迁移性**：harness 做得越厚（专用工具、深度定制的上下文管道），在当前模型上越强，但模型升级后需要重写的部分也越多。Claude Code 的解法是保持工具集"通用而原始"（读、写、grep、bash），把智能留给模型。
- **自动化 vs. 可控性**：给 agent 更大的自主权（无人值守、自动审批）换来吞吐，失去安全边界。这道光谱上没有一个"正确点"，只有与任务风险匹配的点。
- **结构 vs. 涌现**：预定义的 workflow（结构）保证可预期性，自由 loop（涌现）换取处理开放任务的能力。Anthropic《Building Effective Agents》给出的原则是：**先找能用的最简单方案，只在确有必要时才增加复杂度。** 这也是本站的默认立场。
- **评测污染**：任何声称"模型 X 比模型 Y 强"的 agentic 对比，如果没控制 harness 一致，结论都该打折扣。读论文和产品发布时请养成条件反射：harness 披露了吗？

## 七、从哪开始：本站学习路径

Harness 这个词确立了本站的基本立场——**研究 agent 就是研究模型之外的那套系统**。推荐按下面的顺序读：

1. **导读**（你在这里）：接着读 [模型 vs. Harness](/guide/model-vs-harness) 把责任边界彻底切清楚，再用 [Harness 的解剖](/guide/anatomy) 建立全局地图，[历史](/guide/history) 讲这套系统是怎么一步步长出来的。
2. **核心组件**：按 [Agent Loop](/components/agent-loop) → [上下文工程](/components/context-engineering) → [工具系统](/components/tools) → [记忆](/components/memory) 的顺序打地基，然后看进阶件：[规划](/components/planning)、[子代理](/components/subagents)、[权限](/components/permissions)、[Skills](/components/skills)、[可观测性](/components/observability)。
3. **案例拆解**：看真实产品的 harness 是怎么设计的——[Claude Code](/case-studies/claude-code)、[Cursor](/case-studies/cursor)、[SWE-agent](/case-studies/swe-agent)、[OpenHands](/case-studies/openhands)、[Aider](/case-studies/aider)、[Devin](/case-studies/devin)。
4. **动手实践**：[搭建自己的 harness](/practice/build-your-own)、[设计原则](/practice/design-principles)、[常见陷阱](/practice/pitfalls)。
5. 随时查阅：[术语表](/resources/glossary)、[核心论文](/papers/core-papers)。

## 参考资料

- [Claude Agent SDK 官方文档（Agent SDK overview）](https://docs.anthropic.com/fr/docs/claude-code/sdk) —— "the same tools, agent loop, and context management that power Claude Code"
- [Anthropic 工程博客：Claude Code SDK 更名为 Claude Agent SDK（2025-09-29）](https://www.augmentcode.com/tools/claude-code-vs-claude-agent-sdk) —— 更名公告中 "The agent harness that powers Claude Code" 的原始表述（转引）
- [Confucius Code Agent: Scalable Agent Scaffolding for Real-World Codebases (arXiv:2512.10398)](https://arxiv.org/html/2512.10398v4) —— SWE-bench Pro 上同一模型跨 scaffold 的对照实验数据
- [Stop Comparing LLM Agents Without Disclosing the Harness (arXiv:2605.23950)](https://arxiv.org/html/2605.23950) —— SEAL 标准 scaffold 下的分数混淆分析
- [Anthropic's Harness Design Philosophy — From Multi-Agent to Single-Agent（转述 2026-03 工程博客）](https://www.working-ref.com/en/reference/anthropic-harness-design-philosophy-evolution) —— 三代理架构与 harness 随模型简化的记录
- [What Is an Agent Harness? — Firecrawl Blog](https://www.firecrawl.dev/blog/what-is-an-agent-harness) —— 工业界对 harness 术语的普及性定义
- [Agent Harness 的解剖学（中文社区讨论）](https://blog.riba2534.cn/blog/2026/agent-harness-%E5%89%96%E6%9E%90/) —— Anthropic / OpenAI 对该术语的使用语境
