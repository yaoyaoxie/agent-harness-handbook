---
title: JD 知识点拆解：大厂到底在考什么
dataAsOf: 2026-08
description: 基于 44 个国内外真实在招 Agent/LLM 工程岗 JD 的词频统计，拆解高频知识点与国内外的考察差异，并把每个知识点逐一映射回本手册的对应章节，给出「掌握到什么程度算够」的标尺。
---

# JD 知识点拆解：大厂到底在考什么

上一页 [JD 清单](/career/jd-list) 解决的是「有哪些岗位在招」，这一页回答一个更硬的问题：**这些 JD 凑在一起，拼出的能力画像到底是什么？**

方法很简单：我们对国外 10 家公司 17 个岗位、国内 12 家公司 27 个岗位（调研窗口 2026 年 8 月 11–12 日，均为真实在招岗位，来源与链接见 [JD 清单](/career/jd-list)）的 JD 原文做了逐条人工关键词核对，统计「包含该关键词的 JD 数」。这不是舆情分析，是把招聘市场的真实需求摊在桌面上，再逐个映射回本手册的章节——你可以直接把它当成一份有出处的学习优先级清单。

::: info 怎么读这份统计
词频统计的是「多少份 JD 提到了这个词」，不是「这个技能有多重要」。低频不等于不重要（比如 RLHF 只出现在少数岗位，但那些岗位完全不写别的），高频词才是真正的「入场券」——几乎所有团队都在考。
:::

## 词频排行：国内 vs 国外

先给一张总览图，看清两边各自的高频区：

```text
国外（17 个 JD）                国内（27 个 JD）
─────────────────────           ─────────────────────
agents/agentic 工作流  11 ▓▓▓   Agent 运行时/Harness   15 ▓▓▓
evals/评估框架         10 ▓▓▓   工具调用/工具编排      13 ▓▓▓
fine-tuning/post-train  6 ▓▓    评测/eval/benchmark   12 ▓▓▓
safety/alignment        5 ▓▓    上下文工程/长上下文    10 ▓▓▓
RAG/retrieval           4 ▓▓    多智能体/Multi-Agent    9 ▓▓
orchestration/多agent   4 ▓▓    可观测/Trace            7 ▓▓
observability           4 ▓▓    prompt 工程             6 ▓▓
prompt engineering      4 ▓▓    SFT/后训练              6 ▓▓
context engineering     3 ▓▓    AI Coding 工具熟练度    6 ▓▓
tool use                3 ▓▓    RAG                     6 ▓▓
```

**两边共同的 Top 区**是清晰的：评测（evals）、上下文工程、工具调用。这三个词在任何一边都属于「不写进简历就过不了筛」的级别。

**差异也很刺眼：**

- 国外 **evals（10/17）是绝对的第一梯队工程要求**，且写法极有指向性——Cognition 的 Post-Training 岗要求 "Build evals that actually capture what matters... making sure the numbers mean something"；OpenAI FDE 岗把 "eval-driven feedback that changes product and model roadmaps" 写进成功标准。同时 **safety/alignment（5/17）高频出现**，Anthropic 两个 Applied AI 岗都把 "safe and beneficial" 作为底色，Meta 把 Responsible AI 列为加分项。
- 国内的高频区更偏「让 Agent 跑起来、跑稳」：**工具调用/编排（13/27）、评测体系（12/27）、上下文工程（10/27）、可观测（7/27）**。字节的 Agent Harness 工程师岗要求「落地自动化 EVAL 流水线、版本回归、A/B 实验能力」外加「执行轨迹追踪、结构化日志采集、链路回放」——评测和可观测在国内是作为**平台工程**来招人的，而不只是研究素养。

一句话总结：**国外在考「你怎么证明它是对的、怎么保证它不作恶」，国内在考「你怎么把它搭起来、调起来、盯住它」。** 两边都考的东西，就是本手册的主体。

## 高频知识点逐个拆解

下面把每个高频知识点按「JD 里怎么要求 → 手册对应章节 → 掌握到什么程度算够」三段式展开。

### 上下文工程（Context Engineering）

**JD 里怎么要求的：** Anthropic 伦敦 Applied AI 岗把 "prompting、context engineering、agent architectures、evaluation frameworks" 并列为 production LLM 经验的硬性清单；Microsoft 医疗 FDE 岗要求 "production LLM systems, including context engineering, retrieval, tool use, orchestration, and evaluation"；字节巨量星图岗直接写「通过 Planner、AutoPrompt、上下文工程等技术构建灵活的自规划 Agent」；美团智能体工程师岗写的是「上下文治理」——注意这个措辞，治理意味着它是个持续工程而不是一次性 prompt。

**对应章节：** [上下文工程](/components/context-engineering)。

**掌握到什么程度算够：** 能讲清楚系统提示、工具输出、检索结果、历史消息各自的注入与裁剪策略；能给出一个长任务里上下文膨胀的真实故障案例（漂移、丢失指令、成本爆炸）并说明你的解法（压缩、子代理卸载、外化状态）。只会写 system prompt 不算会上下文工程——JD 里的 "context management"、"上下文治理" 指的都是动态管理。

### 工具调用 / Function Calling / MCP

**JD 里怎么要求的：** 这是国内词频第二高的能力（13/27）。腾讯企微 Agent 引擎岗要求「AI Agent、RAG、Function Calling 等方向实践经验」；小红书 Harness 岗把 "Tool Calling、MCP、Agent Runtime" 列为深入方向；字节火山方舟岗要求理解「工具调用、上下文管理、长程执行」等关键机制。国外侧，Microsoft 医疗 FDE 的架构原话是 "frontier models, context engineering, retrieval, tool use, orchestration... and deterministic services"；Anthropic 企业技术岗点名 MCP。

**对应章节：** [工具系统](/components/tools)，MCP 与插件生态部分；延伸看 [Skills](/components/skills)。

**掌握到什么程度算够：** 能手写一个工具的 schema 并讲清描述文字对模型选择行为的影响；知道工具错误的回灌格式怎么设计模型才读得懂；理解 MCP 解决的问题（协议标准化）和它不解决的问题（权限、可靠性）。美团 Tabbit 岗把 "System Prompt、Tools、Skills、上下文管理、Agent Loop" 并列为核心能力——这几样就是 harness 的主体，见 [Harness 的解剖](/guide/anatomy)。

### 评测与可观测（Evals / Observability）

**JD 里怎么要求的：** 这是全部 44 个 JD 里密度最高的一组要求。腾讯混元 Agent Harness Engineer 岗前三条职责全是它：「Agent 执行全链路的 tracing & observability 系统」「自动化 eval pipeline、A/B testing、regression detection」「Agent debugging 工具」；腾讯混元评测 Infra 岗更直白——「从 Harness 与打分逻辑出发，确保平台化改造后评测结果的准确可信」。国外侧，Amazon WorkSpaces 高级应用科学家岗要求 "Build evaluation frameworks to quantify agent performance, reliability, and user impact"；Notion 初级 AI 岗的三条团队方向里有一条就是 "Evaluation & quality (evals)"。

**对应章节：** [可观测性](/components/observability)；评测驱动的设计思想贯穿 [动手搭建 Harness](/practice/build-your-own)。

**掌握到什么程度算够：** 能设计一个最小 eval：任务集、轨迹采集、打分逻辑（规则/LLM-as-judge/人工）、回归门禁；能说清「离线 eval」与「线上观测」的分工；拿到一条失败轨迹，能用 trace 定位是模型问题、上下文问题还是工具问题。字节 Harness 岗要求的「链路回放、异常告警、可视化调试」就是这一章的产品化形态。

### Agent Loop / 运行时 / Harness 本体

**JD 里怎么要求的：** 国内有 15 个 JD 提到运行时/执行引擎/Harness/Agent Loop，其中 10 个直接出现 "Harness" 原词——字节、腾讯混元、美团（Tabbit）、小红书、DeepSeek 都设有以此命名的岗位。小红书 harness 系统岗要求「主导 Agent Loop 架构设计」；Moonshot 增长工程师岗的要求写得最具体：「能围绕 Agent 构建高质量的 scaffolding：context 如何组织、工具如何抽象、循环如何终止、失败如何恢复、效果如何评估」。国外侧，Cursor 的 Agent Harness 工程师岗（与本手册同名）职责就是推进 "agent loop, tools, prompts, execution environment"。

**对应章节：** [Agent 循环](/components/agent-loop)；总纲见 [什么是 Agent Harness](/guide/what-is-harness)。

**掌握到什么程度算够：** 能在一个下午写出一个最小 agent loop 并逐层加上停止条件、错误恢复、步数兜底；能讲清「循环如何终止、失败如何恢复」这两个 Moonshot 点名的问题——这恰恰是 [常见陷阱](/practice/pitfalls) 里最高发的两类事故。

### 规划与任务分解（Planning）

**JD 里怎么要求的：** 百度智能体算法工程师岗把「自主规划、复杂推理、动态决策」和「多步任务规划」写进核心算法研发；美团智能体工程师岗写「长程规划、自我纠错」；字节巨量星图岗点名 Planner；阿里实习岗要求实现「意图识别、任务拆解与反思纠错闭环」。

**对应章节：** [规划与任务分解](/components/planning)。

**掌握到什么程度算够：** 能对比纯反应式、Plan-and-Execute、交织模式三种范式的适用场景；能解释为什么 Claude Code 的 TodoWrite 没有任何运行时逻辑却有效（认知卸载）；知道「循环如何不漂移」靠的是外化计划工件而不是模型自觉。

### 记忆（Memory）

**JD 里怎么要求的：** 出现频次不高（国内 4/27）但都出现在架构类岗位：腾讯元宝 Agent 架构岗负责 "Tool/Memory/Context 抽象"；百度智能体岗要求「长短期记忆管理」；美团 CatPaw 平台岗含「记忆系统」；阿里实习岗把「记忆管理」列为核心模块之一。

**对应章节：** [记忆系统](/components/memory)。

**掌握到什么程度算够：** 能区分会话内工作记忆（todo list、上下文）与跨会话持久记忆（文件、向量库）的职责边界；知道记忆写入的准入控制（什么值得记）比检索算法更难。词频不高不等于可以不会——它是架构岗的区分度问题。

### 多智能体（Multi-Agent / Orchestration）

**JD 里怎么要求的：** 国内 9/27。Moonshot 的 multi-agent 产品工程师岗把这个方向写得最激进：「设计 Agent 与 Agent 之间协作的交互协议，把协作本身视作一种新型 harness」，要求理解 "A2A、MCP、ACP"，加分项含 "task decomposition、role assignment、conflict resolution"；小红书 Harness 岗要求建设「Multi-Agent 通信与协作机制、SuperAgent 路由编排」。国外侧 Microsoft、Cognition、Cursor、Meta 各有一处。

**对应章节：** [子 Agent](/components/subagents)。

**掌握到什么程度算够：** 能讲清什么时候该上多智能体（上下文隔离、并行、专业化分工）、什么时候是过度设计；知道子代理间通信的信息瓶颈问题。面试里能引用一个真实产品的取舍（比如 Claude Code 的 subagent 设计）会比空谈编排框架加分得多。

### 权限与安全（Permissions / Safety / Guardrails）

**JD 里怎么要求的：** 国外的表述偏价值层——Anthropic 的 "safe and beneficial"、Cognition Post-Training 岗的 "RLHF、RLAIF、constitutional approaches"、Meta 的 Responsible AI。国内的表述偏工程层：小红书 Harness 岗要求「建设 Agent 身份认证与权限治理能力，解决权限穿透、最小授权和安全边界问题」；小红书 harness 系统岗要求「设计云端 Agent 沙箱系统」；字节火山方舟岗列了「资源隔离、网络访问控制」。Moonshot 则两者兼有：知道什么设计（"guardrails、human-in-the-loop、delegation policy"）能让 bot 成为团队成员。

**对应章节：** [权限与人机协作](/components/permissions)。

**掌握到什么程度算够：** 工程侧能设计工具白名单、审批闸口、沙箱边界；观念侧能讲清「约束是 harness 的核心职责，不是副产品」。对齐理论（RLHF/constitutional AI）除非面模型侧岗位，否则知道其在解决什么问题即可。

## 手册覆盖较弱的知识点

诚实地说，有几类高频 JD 要求超出了本手册的主题边界。它们不是 harness 工程，而是**模型侧**或**推理基础设施侧**的能力：

| JD 要求 | 典型出处 | 为什么手册不覆盖 | 建议学习方向 |
| --- | --- | --- | --- |
| fine-tuning / post-training（SFT、蒸馏） | OpenAI RE（"distillation、supervised fine-tuning、policy optimization"）、Amazon WorkSpaces、字节巨量星图、蚂蚁后训练岗 | 属于模型权重侧，不是模型之外的系统 | Hugging Face SFT/PEFT 文档、各厂后训练技术博客 |
| RLHF / RL / agentic 训练 | Cognition Post-Training（"RLHF、RLAIF、preference modeling"）、腾讯 Agent Infra（RL 沙盒）、快手（"RL 端到端训练 agentic reasoning model"） | 训练方法学，面向研究/算法岗 | 直接读 InstructGPT、DPO、GRPO 等原始论文，见 [核心论文](/papers/core-papers) 的边界说明 |
| 推理优化（vLLM、KV cache、端侧推理） | 阿里实习岗加分项（"vLLM/KV cache"）、腾讯企微岗（端侧推理加速）、小红书 LLM Engineering 岗 | 属于 model serving 层 | vLLM 官方文档与源码、各推理框架 benchmark |
| 传统分布式/云原生工程 | xAI（Rust + 分布式系统 + observability）、腾讯 Agent Infra（K8s、容器网络） | 通用后端功底，不是 agent 特有 | 这部分没有捷径，是工程底盘 |

::: warning 岗位分层是真实存在的
国内调研的粗结论值得记住：**模型侧岗位**（后训练/RL/agentic 数据，集中在腾讯混元、百度、蚂蚁、快手、DeepSeek）和**工程侧岗位**（Harness/Infra/应用，集中在字节、美团、小红书、腾讯各 BG）在招聘市场上已经明显分层。本手册服务的是后者。投错层级的简历，词频对得再齐也没用。
:::

## 国内外要求的结构性差异

词频之外，还有几个结构性差异值得单独说。

**学历与资历门槛。** 国外的研究/科学岗门槛极高——Amazon Applied Scientist 要求 PhD 或硕士 + 4 年，OpenAI RE 要求硕士或博士；但工程岗明显宽松，Cursor 的 Agent Harness 岗**没有列出任何学历年限硬门槛**，只看「构建过复杂 agentic products」的实绩。国内相反：工程岗普遍写明「本科及以上，计算机相关专业」，年限要求精确（字节 Harness 岗 2–5 年、腾讯企微岗 5 年以上、小红书 3–5 年），但硕士要求主要出现在算法岗。

**Title 体系。** 国外这两年长出一个新物种：**Forward Deployed Engineer / Applied AI Engineer**（OpenAI、Anthropic、Cognition、Notion、Microsoft 都在招）——嵌入客户侧、把模型能力交付成生产系统的工程师，薪资对标研究岗（Anthropic 伦敦岗 £225k–£240k，OpenAI FDE 第三方参考区间 $162k–$280k）。国内对应的形态是「Agent Harness/Infra 工程师」和「大模型应用工程师」，更偏平台侧而非客户侧。

**AI Coding 工具熟练度被写进了硬性要求。** 这是一个容易忽略但信号极强的变化：国内有 6 个岗位点名 Cursor / Claude Code / Codex——腾讯混元 Harness Engineer 岗要求「使用 Cursor / Claude Code / Codex 等进行重度编程，对 agentic coding 的能力边界和 failure mode 有切身体感」；阿里实习岗要求「Cursor、Claude Code 等 AI 编程工具重度玩家」；Moonshot 增长工程师岗写「Claude Code / Codex 这类 harness 是你的日常」。国外 Notion 初级岗同样要求跟进使用 Cursor、Claude Code。

::: tip 这意味着什么
大厂招 harness 工程师时，默认你**日常就在一套成熟的 harness 里工作**，并且对这套 harness 的失效模式有一手体感。这正是本手册的读法：不要只读概念，把 [Claude Code 案例](/case-studies/claude-code)、[Cursor 案例](/case-studies/cursor) 拆开看，再按 [动手搭建 Harness](/practice/build-your-own) 自己搓一个——Moonshot 的 JD 原话就是「可以快速自己手搓一套 Harness 来验证 Agent 协作与编排效率」。
:::

## 怎么用这张地图

把上面的拆解落成行动，顺序建议如下：

1. **先对齐词频最高的三块**：上下文工程、工具系统、评测与可观测。这三块在 44 个 JD 里几乎没有缺席，是本手册的 [上下文工程](/components/context-engineering)、[工具](/components/tools)、[可观测性](/components/observability) 三章，也是任何面试的第一轮考点。
2. **补 harness 本体的叙事能力**：能讲清 Agent Loop、规划、记忆如何咬合，对应 [Agent 循环](/components/agent-loop) → [规划](/components/planning) → [记忆](/components/memory)。这决定你聊的是「我用过 LangChain」还是「我设计过运行时」。
3. **按目标岗位层级选边**：工程侧（Harness/应用）把本手册读透即可；模型侧（后训练/RL）额外补上一节列出的外部方向。
4. **最后回到简历**：把 JD 高频词翻译成你项目里的证据，方法见 [简历对标分析](/career/resume-analysis)。

::: info 数据来源与时效
本页全部统计与引文来自 2026 年 8 月 11–12 日对国内外 44 个真实在招岗位的调研，逐条出处（公司、岗位、链接、可信度标注）见 [JD 清单](/career/jd-list)。招聘市场需求变化很快，这份地图的保质期以季度计——但「evals、上下文、工具」这三块从 2024 年至今只升不降，可以当作长期押注。
:::

## 延伸阅读

- [JD 清单](/career/jd-list)——本页全部数据的原始出处与岗位链接
- [求职导航](/career/)——本模块总览：从 JD 到简历的完整链路
- [简历对标分析](/career/resume-analysis)——把这些知识点翻译成简历语言
- [什么是 Agent Harness](/guide/what-is-harness)——为什么这些 JD 考的恰恰是「模型之外的系统」
- [Harness 的解剖](/guide/anatomy)——高频知识点的全景地图
- [设计原则](/practice/design-principles)——面试里「你怎么看 XX 设计」类问题的弹药库
- [术语表](/resources/glossary)——JD 里每个英文术语的精确定义
