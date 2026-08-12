---
title: 框架与平台怎么选
description: 做 agent 该选哪个底座？本文把「自己写循环、代码框架、平台」摆成一条光谱，横评 LangGraph、CrewAI、AutoGen、OpenAI Agents SDK、Claude Agent SDK、Dify、扣子的抽象层级、控制权与锁入风险，并按场景给出决策树。
---

# 框架与平台怎么选

读完前面的章节，你已经知道 harness 由哪些组件构成、各有什么设计取舍。接下来是最实际的问题：**轮到自己动手做 agent 时，底座选哪个？**

先给本站的立场：选底座不是选「哪个框架最强」，而是选**harness 的哪几层你要自己写、哪几层外包出去**。外包得越多，起步越快，但调试时撞到的黑盒也越厚——你在[可观测性](/components/observability)里读到的一切痛点，在平台上都会以「看不到内部循环」的形式还回来。

## 一条三层光谱

截至 2026 年中，市面上的底座可以排进一条光谱：

```text
        你对循环的控制权 ─────────────────────────────► 高
        从零到能跑的速度 ◄───────────────────────────── 快

 ┌───────────────┐  ┌─────────────────────────┐  ┌──────────────────┐
 │  自己写 loop   │  │       代码框架           │  │       平台        │
 │               │  │                         │  │                  │
 │  裸 while 循环 │  │ LangGraph / CrewAI /    │  │ Dify（可自托管）  │
 │  + 模型 API    │  │ Microsoft Agent         │  │ 扣子（托管 SaaS） │
 │               │  │ Framework /             │  │                  │
 │  上下文、工具、│  │ OpenAI Agents SDK /     │  │ 整套 harness 现成，│
 │  停止条件全手写│  │ Claude Agent SDK        │  │ 你只编排与配置    │
 │               │  │                         │  │                  │
 │  例子：本站     │  │ 给你原语和骨架，         │  │ 例子：客服机器人、│
 │  最小 loop     │  │ 循环结构自己搭           │  │ 营销内容流水线    │
 └───────────────┘  └─────────────────────────┘  └──────────────────┘
```

三个判断先放在这里，后面展开：

- **没有「最好的」，只有「光谱位置与你的需求匹配的」。** 评测框架优劣的文章大多在比功能清单，但功能清单会过期，光谱位置不会。
- **左端不是「原始」，是「透明」。** 自己写 loop 意味着每一次上下文组装、每一次工具执行都在你的代码里，这在深度定制场景是决定性优势。
- **右端不是「低级」，是「租来的 harness」。** 平台把架构决策变成了配置项——快是真的快，天花板也是真的存在。

## 七个选手的现状速览

以下是截至 2026 年中核实过的事实，重点讲**定位与控制权**，不深讲机制——LangGraph、Dify、扣子在本站有专文，请移步案例章。

### LangGraph：图形态的受控循环

LangChain 团队出品，MIT 协议开源，2025 年 10 月随 LangChain 一起发布 v1.0 并承诺 2.0 前不做破坏性变更。核心主张：agent 的控制流应该被**显式建模成状态图**——节点、边、持久化、断点全由开发者声明。它是框架派里控制权给得最足的一个，也是本站的立场里「该用框架时」的默认答案。机制拆解见[案例：LangGraph](/case-studies/langgraph)。

### CrewAI：角色扮演式多智能体

独立公司 CrewAI 出品（2024 年 10 月获 1800 万美元融资），MIT 协议开源。抽象是「Crew（一队有角色的 agent）+ Flow（事件驱动的工作流）」：你给每个 agent 写人设和任务描述，让它们像一个小团队一样协作。上手是代码框架里最快的之一，但角色协作的浪漫叙事掩盖了一个事实——**多 agent 之间的对话式协调在生产上很难调试**。它有商业版 CrewAI Enterprise 提供管控平面。

### AutoGen → Microsoft Agent Framework：已换代，新项目勿入

这是选型时最容易踩的坑，值得单独说。AutoGen 是微软研究院 2023 年末开源的多智能体对话框架，曾经是多 agent 研究的默认选项。但截至 2026 年中：**AutoGen 已进入维护模式**——2025 年 10 月微软宣布将它与 Semantic Kernel 合并为 Microsoft Agent Framework（MAF），后者于 2026 年 4 月发布 1.0 GA（.NET 与 Python 双平台），继承了 AutoGen 的对话式多智能体抽象和 Semantic Kernel 的企业级能力（会话状态、中间件、遥测），并新增图工作流。

::: warning 选型提醒
不要基于「AutoGen 很火」的旧印象启动新项目。存量 AutoGen 代码可以继续维护，新项目应直接评估 Microsoft Agent Framework（MIT 协议）或其他底座。这也是「框架现状必须随查随新」的最好例证——一年前的对比文章今天可能整体失效。
:::

### OpenAI Agents SDK：极简原语 + OpenAI 生态位

2025 年 3 月发布，是实验性项目 Swarm 的生产继任者，MIT 协议，Python 与 TypeScript 双实现。设计哲学是激进的最小主义：核心原语只有 Agent、Handoff（把对话控制权移交给另一个 agent）、Guardrails、Sessions、Tracing 五样。

两个关于它的常见误解需要澄清：

- **它不是 OpenAI 模型的专属。** 默认走 OpenAI Responses API，但可以通过 LiteLLM 等适配层接 100 多家模型供应商——只是工程打磨集中在 OpenAI 路径上。
- **真正的锁入点在 Tracing。** 内置追踪默认把数据送到 OpenAI 平台，想用自己的观测栈需要另接 processor。代码是 MIT 的，数据管道不是。

### Claude Agent SDK：一套成品 harness 的暴露

原名 Claude Code SDK，2025 年 9 月更名为 Claude Agent SDK——更名本身就是定位宣言：这套东西的能力范围超出了写代码。它是**驱动 Claude Code 的那套 harness 的编程接口**：内置文件/终端/搜索工具、子代理派发、权限钩子、CLAUDE.md 记忆机制，全部来自一个日活巨大的真实产品。

::: info 它在光谱上的特殊位置
别的框架给你「搭 harness 的原语」，Claude Agent SDK 给你「一套已经调好的 harness」——你做的是往里填系统提示、工具和权限策略。这让它的起步速度快得不像代码框架，代价是双重绑定：绑 Claude 模型（按 token 计费），也绑 Anthropic 对「好 harness」的判断。它不是宽松开源框架，而是按 Anthropic 商业条款使用的 SDK。
:::

### Dify 与扣子：平台端的两个形态

- **Dify**：2023 年 4 月开源的 LLM 应用开发平台，GitHub 星标超过 15 万。协议是 Apache 2.0 加两条附加条件（保留前端版权标识；未获书面授权不得用于对外多租户 SaaS）——自托管内部使用基本无限制，拿去做生意要先看条款。定位是「模型与应用之间的中间件」，画布编排 + RAG + 插件 + LLMOps 全套产品化。详见[案例：Dify](/case-studies/dify)。
- **扣子（Coze）**：字节跳动出品的一站式智能体平台，国内版 2024 年 2 月发布，主形态是托管 SaaS（零代码编排 + 一键发布到豆包/飞书/微信）。2025 年 7 月 26 日，其零代码开发平台 Coze Studio 与评测工具 Coze Loop 以 Apache 2.0 开源（连同此前开源的 Eino 框架），自托管成为可能，但生态重心仍在托管侧。详见[案例：扣子](/case-studies/coze)。

## 按场景决策

把需求翻译成光谱位置，答案往往自己就出来了：

```text
Q1. 团队里有人写代码吗？
 ├─ 没有 ──────────────────────────────► 扣子（托管 SaaS）
 │                                        零代码、渠道发布现成
 └─ 有
    └─ Q2. 要自托管 / 数据不出内网吗？
       ├─ 要，且以知识库问答、固定流程为主 ─► Dify（自托管）
       │                                     注意多租户条款
       └─ 不强制，或流程高度定制
          └─ Q3. 任务形态？
             ├─ 原型验证，一周内要 demo ────► Claude Agent SDK
             │   （绑 Claude 无所谓时）       或 CrewAI
             ├─ 生产级 coding agent ────────► Claude Agent SDK，
             │                              或直接自写 loop
             │                              （框架在这里多半是负资产）
             ├─ 企业流程自动化（审批、状态、  ► LangGraph（首选）
             │  可审计、要跑几周的长任务）    或 MAF（.NET 栈）
             └─ 深度定制 / 研究新 harness ──► 自己写 loop
                                             （见下一节）
```

::: tip 一个反直觉的经验
「原型用框架、生产换自写」这条路径听起来省事，实际常常双倍成本：框架原型里养成的抽象习惯（图、角色、handoff）会渗透进你对问题的理解，重写时很难剥掉。更稳的做法是**原型就用最终形态的最简版本**——比如直接写一个 100 行的 loop 验证任务可行性，再决定要不要引入框架。
:::

## 横评对比表

截至 2026 年中的快照。协议与活跃度会变化，决策前请以官方仓库为准。

| 底座 | 维护方 / 协议 | 抽象层级 | 你对循环的控制 | 生态与集成 | 锁入风险 |
| --- | --- | --- | --- | --- | --- |
| **LangGraph** | LangChain / MIT | 状态图（显式控制流） | 高：循环拓扑由你画 | 最大：模型、工具、LangSmith 观测 | 低；迁出成本在图的思维方式 |
| **CrewAI** | CrewAI / MIT | 角色 + 任务 + Flow | 中：crew 内部协调是黑盒 | 大：插件、企业管控平面 | 低；但多 agent 范式本身迁移难 |
| **MAF**（AutoGen 后继） | 微软 / MIT | 对话式多 agent + 图工作流 | 中高 | Azure 深度集成；.NET 一等公民 | 中：Azure 生态引力 |
| **OpenAI Agents SDK** | OpenAI / MIT | 五原语（Agent/Handoff/…） | 中高：原语少、逃逸口多 | OpenAI 托管工具；可接他厂模型 | 中：Tracing 默认回 OpenAI |
| **Claude Agent SDK** | Anthropic / 商业条款 | 成品 harness | 低中：循环是 Claude Code 的 | Claude Code 全套工具、MCP、Skills | 高：模型与 harness 判断双绑 |
| **Dify** | Dify / Apache 2.0+附加条件 | 可视化编排 | 低：循环是平台内置的 | 数百模型、插件市场、RAG | 中低：可自托管，迁出要重写编排 |
| **扣子** | 字节跳动 / SaaS（Studio 开源 Apache 2.0） | 零代码画布 | 低 | 字节系渠道（豆包/飞书/微信） | 高：托管侧数据与渠道深绑 |

读这张表的正确姿势：先按「锁入风险」和「循环控制」两列划掉不能接受的，再在剩下的里比生态——而不是反过来。

## 什么时候该抛开框架，自己写 loop

最后落到本站反复强调的判断上。以下信号出现得越多，框架就越可能是负资产：

- **你要做的恰恰是 harness 研究或深度定制。** 比如你想验证一种新的[上下文工程](/components/context-engineering)策略、一种新的[子代理](/components/subagents)派发协议——框架的抽象层会把你隔在你想研究的东西外面。
- **任务是 coding agent 这类「循环本身就是产品」的形态。** [Claude Code](/case-studies/claude-code)、[SWE-agent](/case-studies/swe-agent)、[OpenHands](/case-studies/openhands) 三个案例的共同点是：它们的竞争力全在循环、工具和上下文管道里，没有任何一个能用现成框架搭出来。
- **框架的黑盒开始吃掉你的调试时间。** 当你发现自己在逆向「这个 handoff 为什么没触发」「这个节点状态为什么被覆盖」时，框架省下的时间已经还回去了。
- **模型在快速迭代。** 为旧模型精心调优的框架配置可能在新模型上变成累赘，而自写的薄 loop 跟模型升级的成本最低。

而且，自己写 loop 的门槛被严重高估了——[什么是 Agent Harness](/guide/what-is-harness)里的最小循环只有几十行，七个职责清清楚楚。[动手搭建一个 Harness](/practice/build-your-own) 带你从零写出它，[Harness 教程](/practice/harness-tutorial) 再逐层加上工程设施。写完之后你回头看框架，会有一个新的身份：你不再是框架的「用户」，而是能读懂它每一层设计意图的「同行」。这大概是自写 loop 最确定的回报——**哪怕最终选了框架，知道框架在替你做什么的人，永远比不知道的人用得好。**

## 延伸阅读

- [动手搭建一个 Harness](/practice/build-your-own)——从零实现最小 agent loop
- [Harness 教程](/practice/harness-tutorial)——在最小 loop 上逐层叠加工程设施
- [案例：LangGraph](/case-studies/langgraph)——图形态受控循环的机制拆解
- [案例：Dify](/case-studies/dify)——可自托管 agent 中间件的产品化拆解
- [案例：扣子](/case-studies/coze)——平台型 harness 的能力边界
- [Agent 循环](/components/agent-loop)——所有框架最终都要回答的那个循环
- [可观测性](/components/observability)——评估底座时最容易忽略、生产中最重要的维度
- [设计原则](/practice/design-principles)——选型之外的通用 harness 设计取舍
- [常见陷阱](/practice/pitfalls)——包括「框架依赖」在内的实战教训

## 参考资料

- [LangGraph 仓库（langchain-ai/langgraph）](https://github.com/langchain-ai/langgraph)
- [LangChain 官方博客：LangChain 与 LangGraph 1.0 发布说明](https://www.langchain.com/blog/langchain-langchain-1-0-alpha-releases)
- [CrewAI 仓库（crewAIInc/crewAI）](https://github.com/crewaiinc/crewai)
- [Microsoft Agent Framework 仓库（microsoft/agent-framework，AutoGen 与 Semantic Kernel 的合并后继）](https://github.com/microsoft/agent-framework)
- [AutoGen 仓库（microsoft/autogen，已进入维护模式）](https://github.com/microsoft/autogen)
- [OpenAI Agents SDK 官方文档（含非 OpenAI 模型接入说明）](https://openai.github.io/openai-agents-python/)
- [Claude Agent SDK 官方文档](https://docs.claude.com/en/api/agent-sdk/overview)
- [Dify 仓库（langgenius/dify，Apache 2.0 + 附加条件）](https://github.com/langgenius/dify)
- [Coze Studio 仓库（coze-dev/coze-studio，Apache 2.0）](https://github.com/coze-dev/coze-studio)
- [InfoQ：扣子官宣开源的决策披露（2025-07）](https://www.infoq.cn/article/a4ikxoqf5tfq24izedcl)
- [Anthropic：Building Effective Agents（workflow 与 agent 的经典区分）](https://www.anthropic.com/research/building-effective-agents)
