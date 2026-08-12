---
title: 术语表
description: Agent Harness 领域核心术语表：智能体、挽具、上下文工程、工具、记忆、安全与评测等 50+ 术语的准确定义与辨析。
---

# 术语表

本表收录 Agent Harness 领域的核心术语，按主题分为七组：基础概念、循环与控制流、上下文、工具、记忆与知识、安全、评测。每条术语给出中文名、英文原名与定义；容易混淆的术语对单独做了辨析。

::: tip 使用建议
术语不必按顺序读。建议先读「基础概念」建立词汇骨架，然后在阅读其他章节遇到生词时回来查阅。加粗的站内链接指向该术语的深入讨论页。
:::

## 基础概念

**智能体（agent）**
在环境中感知状态、做出决策并执行动作以达成目标的系统。在 LLM 语境下，特指由大模型驱动、能自主进行多步推理与工具调用的程序——模型负责"想"，harness 负责"让它想得有用"。学术界对 agent 的定义更宽（任何感知-行动系统），工程语境下通常默认指 LLM agent。

**挽具 / 骨架（harness）**
围绕 LLM 的完整支撑系统：决定模型每一步看到什么上下文、能调用什么工具、如何规划、记住什么、何时停止或求助。同一个模型套上不同的 harness，能力表现可以天差地别。详见 [什么是 Harness](/guide/what-is-harness)。

**脚手架（scaffold）**
与 harness 基本同义，学术文献（尤其是评测论文）中更常用，指包裹模型的提示模板、工具定义与循环逻辑。工业界产品语境多说 harness，学术语境多说 scaffold；阅读论文时见到 scaffold 直接对应 harness 即可。

**智能体化（agentic）**
形容词，描述系统具有"自主多步行动"的性质，如 agentic coding（智能体编程）、agentic workflow。这个词没有精确的技术边界，更多是程度刻画：系统的决策链越长、人工干预越少，就越 agentic。

**工作流（workflow）**
控制流在编码阶段就固定的系统：步骤顺序、分支条件都由开发者写死，LLM 只填充其中的局部环节。与 agent 的分界在于"谁决定下一步"——workflow 由代码决定，agent 由模型在运行时决定。详见下文「易混淆辨析」。

**多智能体（multi-agent）**
由多个（通常是异构的）智能体协作完成任务的架构。常见形态是一个主智能体派生子智能体并行工作，或多个角色化智能体互相辩论、审查。收益是上下文隔离与并行度，代价是协调开销与错误传播。参见 [子智能体](/components/subagents)。

**计算机操作（computer use）**
让模型像人一样操作图形界面的能力范式：看屏幕截图、移动光标、点击、键入，而不是调用结构化 API。Anthropic 于 2024 年 10 月随升级版 Claude 3.5 Sonnet 首次以公测形式开放该能力。它是"万能但低效"的兜底接口，与专用工具形成互补。

**能力悬空（capability overhang）**
模型其实已经具备某种能力，但当前的 harness（提示、工具、循环设计）没有把该能力激发出来，导致实测表现低于模型的真实上限。换更好的 harness 而不换模型就能涨分，是 overhang 存在的直接证据——这也是本站研究 harness 的根本动机。

**轨迹（trajectory）**
智能体完成一次任务的完整行为序列：每一步的思考、动作、观测结果按时间排列。trajectory 既是调试的基本对象，也是评测（trajectory eval）和训练（模仿学习、强化学习）的基本数据单元。

**自主性（autonomy）**
智能体在无人干预下连续行动的步数与风险等级的综合度量。自主性不是越高越好：高自主性放大了错误累积与安全事故的半径，工程上需要与权限控制、人在回路机制配套设计。

## 循环与控制流

**智能体循环（agent loop）**
智能体的运行时主循环：组装上下文 → 调用模型 → 解析输出 → 执行工具 → 把结果写回上下文，如此往复直到任务完成或触发停止条件。它是 harness 的心脏，几乎所有组件都挂在这个循环上。参见 [Agent 循环](/components/agent-loop)。

**ReAct**
"推理 + 行动"（Reasoning + Acting）的交错模式，由 Yao 等人于 2022 年 10 月提出（ICLR 2023 发表）。模型每步先产出一段思考（thought），再给出一个动作（action），观测（observation）结果回到上下文后继续思考。ReAct 证明了思考轨迹能显著减少幻觉并提升可解释性，是当代 agent loop 的事实范式。

**规划-执行（plan-and-execute）**
把"先想后做"显式化的架构：规划器（planner）先产出完整的多步计划，执行器（executor）逐步执行，必要时重新规划（replan）。与 ReAct 的"边想边做"相对——前者全局一致性好但对环境变化迟钝，后者灵活但容易短视。参见 [规划](/components/planning)。

**编排器（orchestrator）**
多智能体系统中负责任务分解、分发与结果汇总的中心节点。它自己通常不干活，只做路由与综合：判断该把子任务派给谁、何时收拢结果、冲突如何裁决。Claude Code 的主 agent 派发 subagent 就是典型的 orchestrator-worker 结构。

**子智能体（subagent）**
由主智能体派生、拥有独立上下文窗口的执行单元。核心价值是上下文隔离：子智能体可以把几十次探索的脏上下文压缩成一段结论返回，主上下文保持干净。参见 [子智能体](/components/subagents)。

**待办清单（todo list）**
让智能体把任务拆成可勾选条目并显式维护的工具。看似琐碎，实际作用显著：它把规划外化到上下文里，防止长任务中模型"忘记自己还要做什么"，也给用户一个观察进度的窗口。Claude Code 的 TodoWrite 工具即属此类。

**反思（reflection）**
让模型对自己的中间产出进行批判性检查并修正的机制。典型做法是生成 → 自评 → 改写的小循环，或用独立的"批评者"提示。反思能用推理时间换质量，但也会增加 token 开销与循环失控的风险（模型陷入无限自我怀疑）。

**人在回路（human-in-the-loop, HITL）**
在关键节点把决策权交还给人的机制：执行危险操作前请求批准、置信度低时主动求助、定期让人审查计划。它是自主性与安全性之间的调节阀，harness 设计的核心议题之一是"在哪些节点设卡"。参见 [权限与安全](/components/permissions)。

**停止条件（stopping condition）**
判定 agent loop 何时退出的规则集合：任务完成信号、步数/token 预算耗尽、连续无进展、错误率超阈值等。没有良好停止条件的 agent 要么过早放弃，要么无限空转烧钱，是最容易被忽视的循环设计点。

## 上下文

**上下文工程（context engineering）**
围绕"模型每一步应该看到什么"的系统性设计：选哪些信息进上下文、以什么顺序和格式组织、何时裁剪与压缩。该词在 2025 年前后随长任务 agent 的兴起在社区流行，被视为比"提示工程"更准确的框架——后者只管写好一段话，前者要管理整个信息流。参见 [上下文工程](/components/context-engineering)。

**上下文窗口（context window）**
模型单次调用能处理的 token 上限。它是稀缺资源而非免费空间：塞得越满，注意力越稀释、成本越高、关键信息越容易被淹没。harness 的大量设计（压缩、子智能体、按需加载）本质上都是在对抗窗口的有限性。

**系统提示词（system prompt）**
harness 注入每轮请求头部、定义智能体身份与行为规范的固定文本：角色设定、可用工具说明、行为红线、输出格式约定。它是 harness 对模型最直接的"立法"手段，也是提示注入攻击的首要目标。

**压缩（compaction）**
上下文接近窗口上限时，把历史对话总结成摘要、替换原始内容的机制。压缩是"有损记忆"：摘要丢掉细节，可能埋下后续决策的隐患，因此何时触发、保留哪些原文（如最近的工具结果）是关键工程决策。Claude Code 的自动压缩即是一例。

**提示缓存（prompt caching）**
API 层面对前缀 token 的计算结果做缓存的机制：只要请求前缀不变，重复的 system prompt、工具定义、长文档就无需重新计费全量计算。它直接影响 harness 设计——把稳定内容放在前缀、易变内容放在后缀，是成本优化的基本姿势。

**上下文腐化（context rot / context pollution）**
随着循环推进，无关、过时、自相矛盾的信息在上下文中堆积，导致模型注意力被噪声稀释、表现逐渐退化的现象。对策包括定期清理、子智能体隔离脏上下文、只回传结论而非过程。

**中间迷失（lost in the middle）**
模型对长上下文开头和结尾的信息利用较好、对中间部分利用显著较差的现象。工程启示：关键指令和最新状态要放在两端，重要内容埋在中段约等于没放。

**渐进式披露（progressive disclosure）**
不一次性加载全部信息，而是先给元信息（名称+简述）、需要时再展开细节的分层加载策略。Anthropic 的 Agent Skills 即以此为核心原则：启动时只加载各技能的 name 与 description，模型判断相关后才读入完整内容。

**少样本示例（few-shot examples）**
在上下文中放入若干输入-输出示例来规范模型行为的技术。对 agent 而言，示例不仅教格式，也教"决策风格"（遇到报错怎么办、何时该搜索），但示例也占用宝贵的窗口空间，需要精选。

## 工具

**工具使用（tool use）**
模型通过结构化输出请求外部能力（搜索、执行命令、读写文件等）的机制。模型只产出"调用意图"，真正的执行由 harness 完成并把结果回填——工具是模型触达真实世界的唯一通道。参见 [工具设计](/components/tools)。

**函数调用（function calling）**
tool use 在 API 层面的具体实现形态：开发者在请求中声明函数的 JSON Schema（名称、描述、参数），模型以结构化 JSON 返回调用请求。各家模型 API 的 schema 大同小异，但细节差异足以让跨模型 harness 维护多套适配代码——这正是 MCP 要解决的问题。

**工具描述（tool description / tool schema）**
写给模型看的工具"说明书"：名称、功能描述、参数定义、使用时机与禁忌。大量实验表明，同一份底层能力，工具描述写得好坏可以直接改变 agent 的成功率——工具描述是提示工程的一部分，不是文档附属品。

**模型上下文协议（Model Context Protocol, MCP）**
Anthropic 于 2024 年 11 月发布的开放协议，用统一的 JSON-RPC 接口标准化"应用 ↔ 工具/数据源"的连接。它把 N 个 agent × M 个工具的定制集成问题，变成 N+M 个标准化接入；OpenAI、Google、微软随后相继宣布支持。MCP server 暴露三类原语：resources（数据）、tools（动作）、prompts（模板）。

**智能体-计算机接口（agent-computer interface, ACI）**
SWE-agent 论文（2024 年 5 月）提出的概念：就像人类工程师需要 IDE，LLM 智能体也需要为其认知特点专门设计的软件操作界面——面向 agent 优化的命令、反馈格式与编辑原语。论文证明 ACI 的优劣显著影响 agent 表现，这是"harness 比模型更能决定系统能力"的纲领性论证。参见 [SWE-agent 案例](/case-studies/swe-agent)。

**技能（skills）**
Anthropic 于 2025 年提出的能力封装格式：一个含 `SKILL.md` 的目录，用 YAML frontmatter 声明 name 与 description，正文与附属文件按需渐进加载。技能把"领域 know-how"变成可分发的资产，让通用 agent 按需专业化；2025 年 12 月该格式被发布为开放标准。参见 [技能系统](/components/skills)。

**钩子（hooks）**
harness 在循环关键节点（工具调用前后、上下文组装时、会话开始结束）暴露的用户自定义回调。钩子让使用者不改 harness 源码就能注入确定性逻辑：格式化代码、拦截危险命令、记录审计日志，是"可编程的兜底"。

**工具结果（tool result / observation）**
工具执行后回填给模型的内容。它的设计常被忽视但极其重要：返回 5000 行原始日志还是 3 行结论，直接决定上下文预算的消耗速度与模型的判断质量。

## 记忆与知识

**记忆（memory）**
让智能体跨越单次会话保留信息的机制总称。狭义指 harness 主动写入/读取的持久化存储；广义也包括会话内上下文本身（工作记忆）。记忆系统要回答三个问题：记什么、怎么组织、何时检索。参见 [记忆系统](/components/memory)。

**短期记忆（short-term / working memory）**
当前会话上下文窗口内的信息。特点是即时可用但容量有限、会话结束即消失（除非显式持久化）。上下文工程管理的对象主要就是它。

**长期记忆（long-term memory）**
跨会话持久化的信息：用户偏好、项目事实、历史教训。实现上通常是文件、向量库或结构化存储，配合检索机制在需要时注入上下文。难点不在存，在于"该回忆什么"的判断。

**检索增强生成（retrieval-augmented generation, RAG）**
先用查询从外部知识库检索相关片段、再拼进上下文供模型使用的范式。对 agent 而言，RAG 从"一次问答的增强"演化为"循环中的按需回忆"：检索本身成为一个工具，模型自己决定查什么、何时查。

**项目记忆文件（CLAUDE.md / AGENTS.md）**
放在仓库根目录、被 harness 自动读入上下文的项目级说明文件：代码规范、构建命令、架构约定、禁忌事项。它是最朴素的长期记忆实现——把"每次都要重申的话"固化成文件，让团队知识随代码一起版本化。

**情景记忆（episodic memory）**
对"过去做过的事"的记录：历史轨迹、成功与失败的案例。区别于语义记忆（事实性知识），情景记忆让 agent 能从经验中学习——比如检索"上次遇到类似报错是怎么解决的"。

## 安全

**权限模式（permission mode）**
harness 对工具执行施加的分级授权策略：从"每步都问"到"完全放行"之间的多个档位，通常配合按工具、按路径、按命令的细粒度规则。权限模式把"信任"变成可调参数，让同一 agent 能适配从沙箱试玩到生产环境的不同场景。参见 [权限与安全](/components/permissions)。

**沙箱（sandbox）**
隔离智能体执行环境的技术：容器、虚拟机、受限文件系统、网络隔离等。沙箱的假设是"agent 一定会犯错或被攻击"，目标是把爆炸半径限制在隔离区内。对能执行任意代码的 coding agent 而言，沙箱是刚需而非选配。

**护栏（guardrail）**
对智能体输入输出的程序化检查与拦截：内容过滤、格式校验、动作白名单、速率限制。与权限模式的区别在于：权限管"能不能做"，护栏管"做得对不对"，通常以确定性的代码而非模型判断来实现。

**提示注入（prompt injection）**
攻击者把恶意指令藏进 agent 会读到的内容里（网页、文档、工具返回值），诱导模型违背原定任务执行攻击者意图。它是 agent 系统特有的头号安全威胁：模型无法天然区分"数据"与"指令"，防御需要权限、沙箱、内容标记多层组合。

**最小权限原则（least privilege）**
安全工程的经典原则在 agent 领域的直接应用：只授予完成任务所必需的最小工具集与最小作用范围。给一个修 bug 的 agent 开放数据库写权限，就是把一次普通失误变成事故。

**允许列表 / 拒绝列表（allowlist / denylist）**
权限规则的两种枚举方式。allowlist（默认拒绝、显式允许）安全但繁琐，denylist（默认允许、显式拒绝）方便但有遗漏风险。工程实践通常是分层组合：危险类别走 allowlist，低风险类别走 denylist。

**致命三连（lethal trifecta）**
agent 安全事故的经典条件组合：能接触不可信内容 + 能访问敏感数据 + 能对外通信（exfiltration 通道）。三者齐备时，一次提示注入就能完成"读取机密并外发"的完整攻击链，防线的目标就是打断其中至少一环。

## 评测

**评测（eval）**
用标准化任务集度量模型或 agent 系统能力的活动与产物。对 harness 而言，eval 的特殊性在于：它测的是"模型 + harness"的联合表现，换 harness 不换模型也会显著改变分数——harness 选择是评测中的隐藏变量。

**追踪（trace）**
对 agent 运行过程的结构化记录：每次模型调用的输入输出、工具调用、耗时与 token 消耗。trace 是观测与调试的原材料，与 trajectory 侧重"行为序列"不同，trace 更强调"可审计的系统事件流"。参见 [可观测性](/components/observability)。

**轨迹评估（trajectory eval / process eval）**
不只看最终答案对错，还评估中间过程质量的评测方式：工具选择是否合理、是否走了弯路、何时该停没停。长任务时代，仅看结果的 outcome eval 信息量少且易被运气污染，过程评估愈发重要。

**SWE-bench**
软件工程 agent 的事实标准基准，2023 年 10 月发布（ICLR 2024）：从 12 个流行 Python 仓库的真实 GitHub issue 与对应 PR 中构建出 2,294 个任务，要求系统修改代码库使测试通过。发布时最强的 Claude 2 仅解决 1.96% 的问题，如今头部系统已超过 70%，是观察 agent 能力演进的最佳标尺。参见 [论文解读](/papers/core-papers)。

**SWE-bench Verified**
OpenAI 于 2024 年 8 月联合 SWE-bench 团队推出的人工筛选子集，500 个任务经人工校验剔除了描述不清、测试不合理的样本，成为厂商报告成绩的主流口径。后续还出现了多语言（Multilingual）、多模态（Multimodal）等扩展版本。

**Terminal-Bench**
评测终端智能体的基准：任务在真实命令行环境中执行（编译、系统管理、调试、写脚本），以环境最终状态判定成功，而非比对文本输出。其 2.0 版本包含 89 个精心筛选的任务。它检验的是 agent "在真实机器上把事办成"的端到端能力。

**OSWorld**
评测计算机操作（computer use）能力的基准：让 agent 在真实操作系统环境中完成开放式桌面任务。Anthropic 发布 computer use 时，Claude 3.5 Sonnet 在 OSWorld 截图模式下得分 14.9%——数字本身提醒人们，通用 GUI 操作仍是 agent 的硬骨头。

**pass@k**
评测指标：采样 k 次，至少成功一次即算通过。SWE-agent 论文报告的即是 pass@1。读榜单时务必注意 k 值与采样温度——pass@1 反映单次实战能力，高 k 值的成绩更接近"能力上限"而非可用性。

## 易混淆辨析

::: info harness / scaffold / agent
三者是"整体与部分"的关系：**agent** 是干活的系统整体；**harness / scaffold** 是 agent 内部除模型之外的一切（循环、工具、上下文管理）。harness 与 scaffold 同义，仅语境不同。说"换一个更强的 agent"时，值得追问：换的是模型，还是 harness？
:::

::: info workflow / agent
判据只有一个：**下一步由谁决定**。控制流写死在代码里、LLM 只负责局部填充的是 workflow；由模型在运行时动态决定动作序列的是 agent。Anthropic 的建议是能用 workflow 解决就不要上 agent——workflow 可控、可测、便宜，agent 的自主性只在任务路径不可预知时才值回票价。
:::

::: info trajectory / trace
**trajectory** 是行为视角：agent 想了什么、做了什么、看到什么，面向任务语义。**trace** 是系统视角：每次 API 调用、工具执行、token 消耗的结构化事件，面向工程观测。前者用于分析"agent 聪不聪明"，后者用于分析"系统健不健康"。
:::

::: info memory / RAG / context
**context** 是模型此刻看到的全部内容；**memory** 是跨时间保留信息的机制；**RAG** 是从外部库取回信息的一种具体技术。三者关系：memory 决定"有什么可回忆的"，RAG 决定"怎么取回来"，context engineering 决定"取回来后怎么摆进窗口"。
:::

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness) —— 全站概念的起点
- [Harness 解剖](/guide/anatomy) —— 各术语在系统中的位置
- [核心论文](/papers/core-papers) —— ReAct、SWE-agent 等原始文献
- [实践避坑指南](/practice/pitfalls) —— 术语背后的工程教训

## 参考资料

- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)
- [SWE-bench: Can Language Models Resolve Real-World GitHub Issues? (arXiv:2310.06770)](https://arxiv.org/abs/2310.06770)
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
- [Anthropic: Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol)
- [Anthropic: Upgraded Claude 3.5 Sonnet, Claude 3.5 Haiku, and computer use](https://www.anthropic.com/news/3-5-models-and-computer-use)
- [Anthropic Engineering: Equipping agents for the real world with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
- [Terminal-Bench 官方网站与榜单](https://www.tbench.ai/)
