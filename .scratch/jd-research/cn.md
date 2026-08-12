# 国内大厂 Agent/LLM 应用工程方向在招 JD 调研

- 检索日期：2026-08-11（任务指定调研日；实际抓取时间为 2026-08-11 晚间至 2026-08-12 凌晨，CST）
- 调研人：Agent Harness 手册 · 求职模块前期调研
- 覆盖公司：字节跳动、腾讯、阿里巴巴、百度、美团、月之暗面（Moonshot AI）、小红书、蚂蚁集团、DeepSeek、MiniMax、快手、智谱（智谱仅作渠道说明，未抓到可核验 JD）
- 岗位类型聚焦：AI Agent 工程师、大模型应用工程师、Agent 平台/框架工程师、LLM Infra、Agent Harness/评测 Infra 等

## 来源类型与可信度说明

- **官方（全文）**：从公司官方招聘站直接抓取的完整 JD 全文（jobs.bytedance.com、careers.tencent.com 官方 API、job.xiaohongshu.com 官方 API、app.mokahr.com 月之暗面官方招聘页、campus-talent.alibaba.com、talent.baidu.com、talent.deepseek.com）。可信度高。
- **官方（标题级）**：官方招聘站可确认岗位名称/地点/部门，但 JD 正文因 JS 渲染或接口限制未能抓到全文。不补写任何职责描述。
- **聚合站/搜索快照**：牛企直聘（jobs.niuqizp.com，声明转载腾讯官网）、BOSS直聘/猎聘/职友集快照、百度搜索结果摘要。可信度中—低，已逐条标注；内容仅保留快照中确实出现的文字。

---

## 字节跳动 — 大模型应用后端工程师（Agent方向）-巨量星图（上海）

- JD 链接：https://jobs.bytedance.com/experienced/position/7536149766817138951/detail
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：大模型应用工程师（后端）
- 核心职责摘要：
  1. 负责大语言模型在星图场景的工程化落地，搭建脚本/视频创作、智能对话、Agent 等应用的技术框架与工具；
  2. 了解 SFT/RLHF 等大模型优化技术，与算法同学一起构建工程链路来优化内容生成（内容可植入判断、脚本生成、素材创意感知等）；
  3. 基于多模态大模型，设计并构建支持大量级数据的高可用系统，实现文本、短视频、直播切片的理解与推荐；
  4. 探索并搭建内容营销 Agent 系统，通过 Planner、AutoPrompt、上下文工程等技术构建灵活的自规划 Agent；
  5. 跟进大模型领域前沿技术，将其转化为可落地的工程方案。
- 硬性要求：熟练的 Python/Go 编程能力；熟悉服务端基础技术（Ray、数据库、消息队列、ES 等）；有 AI 应用项目经历，熟悉 LLM 应用架构、PE 工程、上下文工程和数据评测，对 Agent、RAG、ReAct 等技术有认知和实践。学历未在 JD 中明示（社招）。
- AI 知识点关键词：RAG、ReAct、prompt 工程（PE/AutoPrompt）、上下文工程、SFT、RLHF、数据评测、多模态、Agent 规划（Planner）
- 薪资范围：未披露

## 字节跳动 — Agent Harness工程师-AI数据与安全（北京）

- JD 链接：https://jobs.bytedance.com/experienced/position/7651517511770818869/detail
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：Agent Harness/平台工程师
- 核心职责摘要：
  1. 针对数据合成场景完成 Harness 架构设计与开发优化，迭代智能体规划、工具编排、RAG 增强、长上下文管理、任务调度核心链路，解决线上 Agent 循环执行、任务中断、调用异常等问题，"搭建稳定可复用的工业级智能体运行基座"；
  2. 搭建 Agent 量化评估与质量管控体系，落地自动化 EVAL 流水线、版本回归、A/B 实验能力；
  3. 搭建 Agent 全链路可观测体系：执行轨迹追踪、结构化日志采集、性能监控、异常告警、可视化调试、链路回放；
  4. 跟进 Agent 前沿技术，沉淀通用组件与落地规范，支撑多智能体协作、故障自愈等高级能力。
- 硬性要求：本科及以上学历，计算机/人工智能等相关专业，2-5 年后端/AI 工程化研发经验，具备 0-1 工业级 AI Agent 项目完整落地经验；精通 Python 生产级开发，熟悉 Go/Java 任意一门；熟练掌握 LangChain、LangGraph 等主流 Agent 框架，精通提示工程、上下文优化、工具编排、RAG 工程化；熟悉 CI/CD、自动化测试、Docker。
- AI 知识点关键词：Agent Harness、Agent 框架（LangChain/LangGraph）、RAG、prompt 工程、长上下文、评测（EVAL/A/B）、可观测、多智能体、工具编排
- 薪资范围：未披露

## 字节跳动 — Agent技术研发工程师-火山方舟大模型平台（北京）

- JD 链接：https://jobs.bytedance.com/experienced/position/7486005250659338504/detail
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：Agent 平台/框架工程师
- 核心职责摘要：
  1. 负责火山引擎-方舟平台的 Agent 核心系统研发，"建设面向复杂任务的通用 Agent 基础设施能力"；
  2. 设计并实现高可靠、可扩展的 Agent 运行时与执行引擎，提升 Agent 的执行效率、安全性和稳定性；
  3. 推进 Agent 平台能力产品化，提升开发者使用 Agent 技术的效率；
  4. 探索 Agent 方向的创新方法与技术动态，"提出更先进的 Agent 范式"。
- 硬性要求：熟练掌握 Python/Golang/Rust/Java 至少一门，熟练使用 AI Coding 工具；理解大模型与 Agent 技术原理，熟悉工具调用、上下文管理、长程执行、Self-involve 等关键机制；熟悉云原生、分布式系统、任务调度、可观测性、资源隔离、网络访问控制。学历未明示（社招）。
- AI 知识点关键词：Agent Runtime/执行引擎、工具调用、上下文管理、可观测、AI Coding 工具
- 薪资范围：未披露

## 字节跳动 — AI Agent研发工程师-开发者服务（地点未确认，快照显示为社招岗）

- JD 链接：https://jobs.bytedance.com/experienced/position/7428873140916554010/detail （规范链接；抓取自移动页 https://jobs.bytedance.com/experienced/m/position/detail/7428873140916554010 的搜索摘要）
- 检索日期：2026-08-11 ｜ 来源：官方链接 + 搜索引擎快照（仅要求片段）｜ 岗位类型：AI Agent 工程师
- 可确认信息：要求"本科及以上学历，计算机及相关专业；熟悉至少一门编程语言（Java/Objective-C/C/C++/Python/Go/JS 等）；熟悉 AI Agent 相关技术，了解工具开发"。职责全文未抓到，不补写。
- AI 知识点关键词：Agent 工具开发（仅片段可确认）
- 薪资范围：未披露

## 腾讯 — 混元AI Agent Harness Engineer（北京/深圳）

- JD 链接：https://careers.tencent.com/jobdesc.html?postId=2052685072754196480
- 检索日期：2026-08-11 ｜ 来源：官方（全文，careers.tencent.com 官方接口；TEG，两年以上经验，更新于 2026-08-06）｜ 岗位类型：Agent Harness 工程师
- 核心职责摘要：
  1. 参与设计并实现 Agent 执行全链路的 tracing & observability 系统；
  2. 参与构建 Agent 质量评估体系：自动化 eval pipeline、A/B testing、regression detection；
  3. 开发 Agent debugging 工具；
  4. 参与核心支撑平台（标注、SBS 评测、数据管道）的架构设计与开发；
  5. 与 AI 研究团队协作，"将大模型与 Agent 协同进化的研究成果工程化落地"；
  6. 探索并实践 AI Agent 的日常工作流。
- 硬性要求：使用 Cursor / Claude Code / Codex 等进行重度编程，对 agentic coding 的能力边界和 failure mode 有切身体感；全栈工程能力和系统设计功底；熟悉 AI/Agent 技术栈，了解 LLM、Agent framework、prompt engineering；代码质量要求严格。学历未明示。
- AI 知识点关键词：Agent Harness、评测（eval/A/B/regression）、可观测（tracing）、prompt 工程、Agent 框架、AI Coding（Cursor/Claude Code/Codex）
- 薪资范围：未披露

## 腾讯 — Agent Infra高级研发工程师（深圳）

- JD 链接：https://careers.tencent.com/jobdesc.html?postId=2086743606953160704
- 检索日期：2026-08-11 ｜ 来源：官方（全文，TEG，两年以上经验，更新于 2026-08-10）｜ 岗位类型：Agent Infra/平台工程师
- 核心职责摘要：
  1. 负责大模型 Agent 评估、强化学习和数据制造所需的大规模沙盒平台建设；
  2. 负责面向模型训练/研究场景下 Agent 框架的研发与维护，支持强化学习、数据生成、自动化评估和实验复现；
  3. 解决高并发任务执行场景下全链路的性能、稳定性问题；
  4. 支持各类评估 bench 及运行环境接入。
- 硬性要求：精通 Python；熟悉大模型与 Agent 相关应用技术，理解模型调用、工具调用、上下文管理、任务执行、日志 Trace 和结果评估等核心链路；熟悉 Go、Linux、Docker、Kubernetes、容器网络、镜像构建、集群调度中的多项；了解大模型训练流程和基本原理。学历未明示。
- AI 知识点关键词：沙盒、强化学习（RL）、评测（bench）、Agent 框架、工具调用、上下文管理、可观测（Trace）
- 薪资范围：未披露

## 腾讯 — 元宝-Agent架构工程师（深圳）

- JD 链接：https://careers.tencent.com/jobdesc.html?postId=2016726999816626176
- 检索日期：2026-08-11 ｜ 来源：官方（全文，CSIG，两年以上经验，更新于 2026-07-29）｜ 岗位类型：AI 应用架构师（Agent 方向）
- 核心职责摘要：
  1. 负责元宝在线产品的 Agent 系统整体架构设计与演进，包括 Agent Runtime、Tool/Memory/Context 抽象、多 Agent 协作模式、Human-in-the-loop 等；
  2. 结合产品功能、模型能力边界与架构约束，实现 Agent 产品的整体架构方案设计；
  3. 持续探索、研究并引入新的框架和 Agent 技术范式。
- 硬性要求：本科及以上，计算机/自动化/AI 等相关背景；熟练至少一门主流语言（Python/TypeScript/Go 等），能熟练使用主流 AI coding 工具；了解 LLM 与 Agent 基本技术原理和常见范式。
- AI 知识点关键词：Agent Runtime、记忆（Memory）、上下文（Context）、多智能体、Human-in-the-loop、工具抽象、AI Coding
- 薪资范围：未披露

## 腾讯 — 企业微信-AI Agent 引擎核心开发工程师（成都）

- JD 链接：https://careers.tencent.com/jobdesc.html?postId=2039169824982204416
- 检索日期：2026-08-11 ｜ 来源：官方（全文，WXG，五年以上经验，更新于 2026-07-30）｜ 岗位类型：Agent 引擎/框架工程师（端侧）
- 核心职责摘要：
  1. 负责企业微信客户端自研 AI Agent 系统的架构设计与核心研发，"构建高可用、可扩展的端侧 Agent 运行框架"；
  2. 负责 Agent 调度引擎、工具调用链路、上下文管理、多轮对话状态机等核心模块；
  3. 探索端侧大模型推理加速、端云协同等技术方案；
  4. 跟进 Agent 模式优化、computer use、browser use 等技术进展，持续迭代 Agent 架构能力；
  5. 与产品、算法、后台团队协作，"定义 Agent 能力边界与交互协议"。
- 硬性要求：计算机相关专业本科及以上，5 年以上客户端或系统架构开发经验；熟练掌握 C++、Java、Kotlin、TS/JS 中至少一种；了解主流大模型架构原理，具备 AI Agent、RAG、Function Calling 等方向实践经验；有端侧模型推理部署与成熟 Agent 研发经验者优先。
- AI 知识点关键词：Agent 运行框架/调度引擎、Function Calling/工具调用、上下文管理、RAG、computer use/browser use、端侧推理
- 薪资范围：未披露

## 腾讯 — 混元Agent评测Infra工程师（北京/上海/深圳）

- JD 链接：https://careers.tencent.com/jobdesc.html?postId=2082754347585941504 （官方岗位页；职责全文经牛企直聘镜像页 https://jobs.niuqizp.com/job-vyr5NtMtL.html 核对，该镜像声明转载自腾讯官网）
- 检索日期：2026-08-11 ｜ 来源：官方（标题/元信息）+ 聚合站镜像（职责全文）｜ 岗位类型：评测 Infra 工程师（TEG，更新于 2026-07-31）
- 核心职责摘要：
  1. 构建评测运行底座：统筹沙盒环境、依赖管理、网络访问、并发调度，保障大规模评测稳定、可复现、高效运行；
  2. 保障评测质量与可观测性："从 Harness 与打分逻辑出发，确保平台化改造后评测结果的准确可信"，建立诊断与问题归因能力；
  3. 衔接算法与工程：深入理解各 Benchmark 所考察的模型能力维度。
- 硬性要求：计算机相关专业本科及以上，3 年及以上后端/平台/Infra 研发经验；精通至少一门主流后端语言（Python/Go/Java 等）；熟悉容器化与沙盒隔离、分布式系统、任务调度与并发控制。
- AI 知识点关键词：评测（Benchmark）、Harness、沙盒、可观测
- 薪资范围：未披露

## 阿里巴巴 — AI应用/Agent方向工程师（2027届实习，淘天集团等多个 BU 共用此 JD）

- JD 链接：https://campus-talent.alibaba.com/campus/position/199903220038
- 检索日期：2026-08-11 ｜ 来源：官方（全文，阿里巴巴校园招聘）｜ 岗位类型：大模型应用/Agent 工程师（实习）
- 核心职责摘要：
  1. "聚焦核心业务场景，利用 Agent 等前沿技术推动 AI 落地"，覆盖需求归因、架构设计、知识与环境构建、核心能力实现、系统迭代、性能优化全流程；
  2. 参与 Agent 系统核心模块规划：记忆管理、推理策略与工具编排；
  3. 搭建 AI 与业务系统的交互环境：API 接入、RAG 知识库构建、记忆方案设计，"持续优化召回质量与上下文注入策略"；
  4. 实现意图识别、任务拆解与反思纠错闭环；"构建 Agent 观测体系，实现全链路追踪与多维归因分析"；
  5. 建立自动化评测与回测机制。
- 硬性要求（2027 届实习，毕业时间 2026-11 至 2027-10）：计算机/软件工程/人工智能等相关专业优先；Cursor、Claude Code 等 AI 编程工具重度玩家，"具备极强的 Prompt 编写与调优能力"；熟悉主流大模型应用范式（Context Engineering、Prompt Engineering、Agent、工具/函数调用等）及主流 Agent 框架（如 LangChain 等）；具备大模型幻觉、Prompt 注入等风险的工程化应对思路；加分项含 MCP、Skill、多智能体编排、vLLM/KV cache、SFT/RL 经验。
- AI 知识点关键词：记忆、工具编排/函数调用、RAG、上下文工程（Context Engineering）、prompt 工程、Agent 框架（LangChain）、MCP、多智能体、评测与回测、可观测、AI Coding、SFT/RL（加分）
- 薪资范围：未披露（实习）

## 阿里巴巴（通义实验室） — 大模型Post-training算法工程师-通义千问（地点未确认）

- JD 链接：https://careers-tongyi.alibaba.com/off-campus/position-detail?lang=zh&positionId=7000031509
- 检索日期：2026-08-11 ｜ 来源：官方（标题级，通义实验室官方招聘站；页面 JS 渲染，正文未抓到）｜ 岗位类型：大模型算法（后训练）
- 可确认信息：岗位名称、招聘方（通义实验室/通义千问团队）、社招（off-campus）通道。职责与要求未抓到，不补写。
- AI 知识点关键词：后训练（Post-training/SFT 方向，标题级）
- 薪资范围：未披露

## 百度 — 智能体算法工程师（北京，校招，职位编号 J101017）

- JD 链接：https://talent.baidu.com/jobs/list （百度官方招聘列表页，可搜职位编号 J101017；发布于 2026-07-21，校招技术类）
- 检索日期：2026-08-11 ｜ 来源：官方（职责全文抓自官方列表页渲染）｜ 岗位类型：Agent 算法工程师
- 核心职责摘要：
  1. "负责大模型智能体（Agent）系统全链路设计与开发，搭建具备自主规划、复杂推理、动态决策能力的智能体架构"；
  2. 主导智能体核心算法研发：意图理解、多步任务规划、工具调用、长短期记忆管理、多智能体协同等核心模块；
  3. 搭建多维度智能体评估体系，"建立效果、效率、资源成本一体化量化指标"；
  4. 推进基于智能体驱动的业务创新，从技术验证到产品落地闭环。
- 硬性要求：校招岗（学历要求未在抓取的职责片段中显示；同列表同类技术岗一般要求本科及以上在校学生）。
- AI 知识点关键词：Agent 规划、工具调用、记忆管理、多智能体协同、评测体系
- 薪资范围：未披露

## 百度 — 大模型算法工程师（北京，校招，职位编号 J100728）

- JD 链接：https://talent.baidu.com/jobs/list （百度官方招聘列表页，可搜职位编号 J100728；发布于 2026-07-21，校招技术类）
- 检索日期：2026-08-11 ｜ 来源：官方（职责全文抓自官方列表页渲染）｜ 岗位类型：大模型算法工程师
- 核心职责摘要：
  1. 从事大语言模型（LLM）的预训练、后训练（SFT/RLHF）及应用落地算法研究；
  2. 探索大模型在推理、代码生成、多轮对话、知识问答等核心能力的提升方法；
  3. "结合强化学习、检索增强（RAG）、思维链（CoT）等前沿技术，推动模型能力边界突破"；
  4. 设计数据策略与评估体系，驱动模型质量持续迭代。
- 硬性要求：校招技术岗（具体学历条款未抓到）。
- AI 知识点关键词：SFT、RLHF、RAG、CoT、强化学习、评估体系
- 薪资范围：未披露

## 百度 — Search/Agent大模型算法工程师（北京，社招）

- JD 链接：https://m.bosszhipin.com/job_detail/840810689cf1bb9e0nB62N68ElRT.html
- 检索日期：2026-08-11 ｜ 来源：聚合站（BOSS直聘，搜索引擎快照）｜ 可信度：中（仅确认标题、地点、学历）｜ 岗位类型：大模型算法（搜索/Agent）
- 可确认信息：北京，要求硕士学历、经验不限；福利含五险一金、补充医疗保险等。职责全文未抓到，不补写。
- AI 知识点关键词：无可确认片段（标题含 Search/Agent 大模型）
- 薪资范围：快照中薪资字段为空

## 美团 — Agent Harness 工程师（北京，部门编号 GN06）

- JD 链接：https://zhaopin.meituan.com/web/position?keyword=Agent （美团官方招聘站搜索结果页，岗位"Agent Harness 工程师"，更新于 2026/08/06）
- 检索日期：2026-08-11 ｜ 来源：官方（职责片段抓自官方列表页渲染；详情页为 JS 路由未获取到独立链接）｜ 岗位类型：Agent Harness 工程师
- 核心职责摘要：
  1. "负责 Tabbit Agent Harness 的设计、开发与持续优化，提升复杂任务的完成效果、稳定性和用户体验"；
  2. "参与 System Prompt、Tools、Skills、上下文管理、Agent Loop、任务状态及异常恢复等核心能力建设"。
- 硬性要求：未抓到（社招）。
- AI 知识点关键词：Agent Harness、System Prompt、Tools/Skills、上下文管理、Agent Loop
- 薪资范围：未披露

## 美团 — AI Agent工程师（北京/上海，核心本地商业-基础研发平台）

- JD 链接：https://zhaopin.meituan.com/web/position?keyword=Agent （更新于 2026/07/23）
- 检索日期：2026-08-11 ｜ 来源：官方（职责片段抓自官方列表页渲染）｜ 岗位类型：Agent 平台/框架工程师
- 核心职责摘要：
  1. "开发框架 — CatPaw SDK/CLI 能力建设、Skill/Plugin 体系、开发者体验"；
  2. "平台集群 — 基于 OpenClaw 构建 CatClaw 集群，多智能体运行时、路由调度、会话管理、记忆系统"。
- 硬性要求：未抓到（社招）。
- AI 知识点关键词：Agent 框架（SDK/CLI）、Skill/Plugin、OpenClaw、多智能体运行时、记忆系统
- 薪资范围：未披露

## 美团 — 智能体（Agent）工程师（北京，核心本地商业-基础研发平台）

- JD 链接：https://zhaopin.meituan.com/web/position?keyword=Agent （更新于 2026/08/02）
- 检索日期：2026-08-11 ｜ 来源：官方（职责片段抓自官方列表页渲染）｜ 岗位类型：Agent 工程师
- 核心职责摘要：
  1. "Agent系统架构：微信生态下生活服务Agent全链路系统设计与开发——Harness框架、上下文治理、工具编排、长程规划、自我纠错等"；
  2. "规模化落地：与产品协作，对接美团丰富的业务场景，推动Agent能力多场景规模化应用"。
- 硬性要求：未抓到（社招）。
- AI 知识点关键词：Harness 框架、上下文治理、工具编排、长程规划、自我纠错
- 薪资范围：未披露

## 美团 — 大模型Agent实习生（北京，核心本地商业-基础研发平台）

- JD 链接：https://zhaopin.meituan.com/web/position?keyword=Agent （日常实习，更新于 2026/07/09）
- 检索日期：2026-08-11 ｜ 来源：官方（职责片段抓自官方列表页渲染）｜ 岗位类型：Agent 工程师（实习）
- 核心职责摘要：
  1. "参与公司大模型Agent基础能力的建设规划和方案设计，包括RAG、MCP、Multi-Agent等"；
  2. "深入了解不同业务的需求和场景，抽象转化为通用能力并推动建设落地"。
- 硬性要求：未抓到（实习）。
- AI 知识点关键词：RAG、MCP、Multi-Agent
- 薪资范围：未披露

## 月之暗面（Moonshot AI） — 资深Agent研发工程师（北京/上海）

- JD 链接：https://app.mokahr.com/social-recruitment/moonshot/148506 （月之暗面官方社招页，发布于 2026-08-10）
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：AI Agent 工程师
- 核心职责摘要：
  1. "设计与开发 Agent 相关主线产品的关键特性，包括内核框架、业务逻辑、效果调优"；
  2. "建设稳定可靠的 Agent 工程基座，让复杂任务的执行过程可控、可查、可复现"；
  3. 围绕 Agent 内核、任务执行、工具生态与工程基础设施打造一体化产品体系；
  4. 关注业务数据与指标，围绕模型效果与用户体验持续打磨；
  5. 引入 AI 改善研发工作流和工程质量，建设先进的 CI/CD 和 DevOps 工具。
- 硬性要求：深入理解 Agent 产品形态、核心能力与落地路径；"熟悉 Agent 主流技术栈（如 Skills、MCP、Sandbox 等），有真实 Agent 系统的开发经验"；精通 Go，熟悉微服务、RESTful API、gRPC、OpenTelemetry；理解 PostgreSQL/MySQL/Redis/Elasticsearch/S3/HBase 等存储组件；熟悉 Linux、Docker、Kubernetes、CI/CD。学历未明示。
- AI 知识点关键词：Agent 内核/工程基座、MCP、Skills、Sandbox、工具生态、效果调优
- 薪资范围：未披露

## 月之暗面（Moonshot AI） — Agent产品工程师（multi-agent 方向）（地点未标注，社招）

- JD 链接：https://app.mokahr.com/social-recruitment/moonshot/148506 （发布于 2026-07-20）
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：Agent 产品工程师（多智能体）
- 核心职责摘要：
  1. "设计 Agent 与 Agent 之间协作的交互协议，把协作本身视作一种新型 harness，最大化模型能力的释放"；
  2. 定义 Agent 与人之间协作的产品形态，构建面向未来组织的协作界面与工作流，"持续 scaling Agent 的协作带宽"；
  3. "优化每一个 token 的使用效率，让推理算力最大化转化为任务完成率与智能密度"（背景：Kimi 已发布 Agent Swarm，探索 Agents Scaling）。
- 硬性要求：热爱 Coding，"可以快速自己手搓一套 Harness 来验证 Agent 协作与编排效率"；"理解 A2A、MCP、ACP 等协作基础设施"；知道什么设计（guardrails、human-in-the-loop、delegation policy）能让 bot 成为团队成员；加分：multi-agent workflow/agent swarm 原型、task decomposition、role assignment、conflict resolution，熟悉 Claude Code、Codex、OpenClaw 的实际能力边界。
- AI 知识点关键词：多智能体（agent swarm）、harness、A2A、MCP、ACP、human-in-the-loop、guardrails
- 薪资范围：未披露

## 月之暗面（Moonshot AI） — Agentic Growth Engineer（北京）

- JD 链接：https://app.mokahr.com/social-recruitment/moonshot/148506 （发布于 2026-07-27）
- 检索日期：2026-08-11 ｜ 来源：官方（全文）｜ 岗位类型：Agent 工程师（增长方向）
- 核心职责摘要：
  1. 用户增长核心链路：从投放系统到用户触达、行为数据链路到效果归因，"让 AI 在每一个决策点上增强甚至替代人的判断"；
  2. 增长产品实验田：主导小而快的实验，"在 Agent 领域发掘能带来 10 倍增长的非共识机会"；
  3. "Agentic Growth Infra - scaffolding 设计、evaluation harness、工具链，以及可复用的工程模式与 Infra；助力每位同事使用、构建自己的 Agent 团队"。
- 硬性要求："Claude Code / Codex 这类 harness 是你的日常"，对其有效性/失效模式有自己的判断；"能围绕 Agent 构建高质量的 scaffolding：context 如何组织、工具如何抽象、循环如何终止、失败如何恢复、效果如何评估"；扎实系统功底（并发、内存、网络、存储）。学历未明示。
- AI 知识点关键词：harness/scaffolding、evaluation harness、上下文组织、工具抽象、Agent Loop（循环终止/失败恢复）、AI Coding
- 薪资范围：未披露

## 小红书 — Agent Harness 工程师（北京/上海/杭州）

- JD 链接：https://job.xiaohongshu.com/social/position/20778 （小红书官方招聘站；职位 ID 20778，3-5 年经验）
- 检索日期：2026-08-11 ｜ 来源：官方（全文，官方接口）｜ 岗位类型：Agent Harness/Infra 工程师
- 核心职责摘要：
  1. "建设企业级 Agent Harness / Agent Runtime，支撑会话管理、任务执行、工具调用和状态持久化"；
  2. 建设 Agent Serverless 基础设施，实现按需启动、弹性伸缩和生命周期管理；
  3. "建设 Agent 可观测体系，覆盖 Trace/Log/Metric/Event 全链路，支持调试回放和故障诊断"；
  4. 建设 Agent 身份认证与权限治理能力，解决权限穿透、最小授权和安全边界问题；
  5. 建设 Multi-Agent 通信与协作机制，负责任务分发、消息传递和 SuperAgent 路由编排；
  6. "参与 OpenClaw/Claude Code/Hermes/LangGraph/MCP 等开源 Agent 框架研究与改造，参与沉淀小红书自研 Agent Infra 技术体系"。
- 硬性要求：本科及以上，计算机相关专业优先；熟悉 TypeScript/Python/Go/Java/Rust 任一后端语言；理解服务治理、任务调度、权限系统、可观测性、分布式系统；"对 LLM Agent、Tool Calling、MCP、Agent Runtime、Coding Agent、Multi-Agent 等方向有深入兴趣或实践经验"。
- AI 知识点关键词：Agent Harness/Runtime、工具调用（Tool Calling）、MCP、多智能体、可观测、Agent 框架（LangGraph/OpenClaw/Claude Code/Hermes）、Serverless、权限治理
- 薪资范围：未披露

## 小红书 — AI Agent 工程师（harness系统）（北京/上海）

- JD 链接：https://job.xiaohongshu.com/social/position/21108 （职位 ID 21108，后端开发）
- 检索日期：2026-08-11 ｜ 来源：官方（全文，官方接口）｜ 岗位类型：Agent 工程师（社区技术团队）
- 核心职责摘要：
  1. 负责面向社区技术团队的 Agentic 工程交付系统设计、工程化平台建设、评估治理体系搭建，"推动业务研发智能化从'单点工具'向'自主协同系统'演进"；
  2. "主导 Agent Loop 架构设计，构建高效的模型能力调度、Multi-Agent 协作与自我迭代机制（如自学习、自探索）"；
  3. 构建 Agent 全生命自我迭代平台，覆盖运行时编排、可观测、评测与反馈闭环；
  4. 推动技术栈标准化，沉淀通用框架、工具接入规范与可复用组件；
  5. "设计云端 Agent 沙箱系统，保障 Agent 在生产环境中的安全可控运行"。
- 硬性要求：要求字段在官方接口中为空（未公示），仅确认地点北京/上海、后端开发类别。
- AI 知识点关键词：Agent Loop、Multi-Agent、运行时编排、可观测、评测、Agent 沙箱
- 薪资范围：未披露

## 小红书 — AI Agent & LLM Engineering（上海/北京/杭州）

- JD 链接：https://job.xiaohongshu.com/social/position/19138 （职位 ID 19138，后端开发）
- 检索日期：2026-08-11 ｜ 来源：官方（全文，官方接口）｜ 岗位类型：LLM 应用工程师
- 核心职责摘要：
  1. 负责创新业务在泛体验、泛效率方向的大模型工程化能力建设；
  2. "主导面向研发全链路（前端/端侧/后端）的 AI 编码智能体（Agent）建设"：UI 生成、代码转换、组件创建、逻辑编排、PRD 拆解、任务分解、自动化评审/PR 辅助、质量保障；
  3. 跟进 LLM/Agent/端智能前沿技术，应用于 AI 辅助开发（Dev/Code/Review/Test/Release）、端侧推理与多端协同、创新孵化 MVP；
  4. "构建与优化大模型应用的工程化体系（LLMOps），打造高效工具链与平台能力"；
  5. 以 IDE 插件/在线服务/内部平台等形式产品化交付。
- 硬性要求：要求字段在官方接口中为空（未公示）。
- AI 知识点关键词：AI Coding Agent、LLMOps、任务分解、端侧推理、IDE 插件
- 薪资范围：未披露

## 蚂蚁集团 — AReaL工程师-智能体（杭州）

- JD 链接（搜索快照来源）：百度搜索结果页 https://www.baidu.com/s?wd=%E8%9A%82%E8%9A%81%E9%9B%86%E5%9B%A2%20%E5%A4%A7%E6%A8%A1%E5%9E%8B%20Agent%20%E5%B7%A5%E7%A8%8B%E5%B8%88%20%E6%8B%9B%E8%81%98 （快照内容来自猎聘，显示发布于 2026-06-11）；蚂蚁官方招聘站为 https://talent.antgroup.com/off-campus-position （岗位列表需登录/JS 交互，未能抓到该岗官方详情页）
- 检索日期：2026-08-11 ｜ 来源：聚合站快照（猎聘经百度索引）｜ 可信度：中低，仅有快照片段
- 可确认信息：岗位名"蚂蚁集团-AReaL工程师-智能体"，杭州-西湖区，3-5 年，统招本科，招 1 人；快照片段："AReaL团队寻找Agent工程师，负责快速搭建各种Agent产品/研究demo，并进行相关评测，数据…"（片段截断）。
- AI 知识点关键词：Agent 评测（片段可确认）；AReaL 为蚂蚁开源强化学习框架（此为背景知识，非 JD 原文）
- 薪资范围：35-65k·15薪（快照显示）

## 蚂蚁集团 — Agent后训练算法工程师（杭州）

- JD 链接（搜索快照来源）：同上百度的蚂蚁检索结果页（快照来自 BOSS 直聘，显示 2026-07-23）
- 检索日期：2026-08-11 ｜ 来源：聚合站快照（BOSS直聘经百度索引）｜ 可信度：中低，仅标题+要求摘要
- 可确认信息：岗位名"蚂蚁集团Agent后训练算法工程师"，杭州，1-3 年，本科。职责全文未抓到，不补写。
- AI 知识点关键词：Agent 后训练（标题级）
- 薪资范围：快照中薪资字段为空

## DeepSeek（深度求索） — Agent方向在招岗位（官方人才页，标题级，北京/杭州）

- JD 链接：https://talent.deepseek.com/ （DeepSeek 官方招聘页"在招职位"）
- 检索日期：2026-08-11 ｜ 来源：官方（标题级；页面仅列出岗位名称/类别/城市，无 JD 正文，不补写）
- 可确认在招岗位（与 Agent/应用工程相关）：
  1. **Agent Harness 团队**（全栈开发/算法，北京市/杭州市）；
  2. **Agent Infra 研发工程师**（全栈开发/算法，北京市/杭州市）；
  3. **服务端开发工程师（线上核心服务/Agent 后端/数据仓库）**（全栈开发/算法，北京市/杭州市）；
  4. 相关岗位还有：Code Agent 数据工程师（模型数据策略，北京）、通用 Agent 数据产品经理（办公/生活/搜索）。
- AI 知识点关键词：Agent Harness（标题级）
- 薪资范围：未披露

## MiniMax — 自动化测试Agent开发工程师（上海）

- JD 链接（搜索快照来源）：百度搜索结果页 https://www.baidu.com/s?wd=MiniMax%20Agent%20%E5%B7%A5%E7%A8%8B%E5%B8%88%20%E6%8B%9B%E8%81%98%20%E4%B8%8A%E6%B5%B7 （快照来自职友集/BOSS 类聚合站，显示 2026-06-03）；MiniMax 官方校招门户为 https://vrfi1sk8a0.jobs.feishu.cn/ （可打开，但岗位列表需 JS 交互，未能抓到条目）
- 检索日期：2026-08-11 ｜ 来源：聚合站快照｜ 可信度：中低，仅有快照片段
- 可确认信息：上海-徐汇区，本科以上，经验不限（快照标注"不限经验"）；职责片段："1、负责智能Agent相关的质量保障工作，参与垂类场景benchmark构建；2、探索赋能测试场景的Agent设计和建设，创新性解决实际痛点问题；…"（片段截断）。
- AI 知识点关键词：Agent 评测/benchmark
- 薪资范围：30000-50000（快照显示，即 30-50K）

## 快手 — 基础大模型算法工程师—Agent方向（地点未确认）

- JD 链接（搜索快照来源）：百度搜索结果页 https://www.baidu.com/s?wd=%E5%BF%AB%E6%89%8B%20%E5%A4%A7%E6%A8%A1%E5%9E%8B%20Agent%20%E5%B7%A5%E7%A8%8B%E5%B8%88%20%E6%8B%9B%E8%81%98%202026 （快照显示 2026-06-23，发布方为猎头公司"武汉市逍源信息科技"代发）；快手官方招聘站 https://zhaopin.kuaishou.cn/ 为 JS 应用，未能抓到官方详情
- 检索日期：2026-08-11 ｜ 来源：聚合站快照（猎头代发）｜ 可信度：低—中，仅作参考
- 可确认信息（快照片段）："一、基础大模型算法工程师—Agent方向 职位描述 1、基于快手自研基础大模型，构建Agent系统，并打造Deep Research等原生大模型应用；2、参与包括但不限于agentic数据集构造、SFT冷启动训练、RL端到端训练agentic reasoning model、prompt优…"（片段截断）。
- AI 知识点关键词：Deep Research、agentic 数据集、SFT、RL（agentic reasoning）、prompt 优化
- 薪资范围：未披露

## 智谱（Z.AI） — 渠道说明（未抓到可核验 JD，不列岗位）

- 官方主站 https://zhipuai.cn/ 及其 sitemap（/zh、/zh/autoglm、/zh/about、/zh/news、/zh/contact）中均无招聘页；jobs.feishu.cn、app.mokahr.com 上未找到智谱租户（多个候选 slug 均返回"页面不存在"）；zhipuai.italent.cn 存在但为北森 HR 登录端。
- 搜索快照线索（可信度低，仅供参考）：2026-03 的新闻快照称"智谱近日在 GLM 团队的一份最新招聘中，开放 Data Infra、AI Coding、Agent、GLM 基座研（发）…"等方向岗位；另有搜索结果片段显示智谱官方招聘页含"校园招聘/社会招聘/智谱福利"板块，但对应 URL 未能确认。
- 结论：智谱确认有 Agent/AI Coding 方向招聘动作，但本次未能定位到可核验的官方 JD 页面，不收录具体岗位，避免虚构。

---

## 知识点词频粗统计

统计口径：仅统计上文所收录内容中明确出现的关键词（含官方全文与快照片段；标注"标题级"的岗位只在标题确切含该词时计入）。共 27 个岗位条目（智谱说明条不计）。

| 关键词 | 出现岗位数 | 出现在哪些 JD（节选） |
| --- | --- | --- |
| Agent 运行时/Harness/执行引擎/Agent Loop（含 "Harness" 原词） | 15 | 字节×3、腾讯×3（Harness Engineer/元宝/企微引擎/评测Infra）、美团×3、Moonshot×3、小红书×2、DeepSeek×1 |
| 其中 "Harness" 原词明确出现 | 10 | 字节 Harness 工程师、腾讯混元 Harness Engineer、腾讯混元评测 Infra、美团 Tabbit Harness、美团智能体工程师、Moonshot multi-agent、Moonshot Growth、小红书×2、DeepSeek Harness 团队 |
| 工具调用 / function calling / 工具编排 | 13 | 字节×3、腾讯×3、阿里、百度智能体、美团×2、Moonshot×2、小红书 Harness |
| 评测 / eval / benchmark / 评估体系 | 12 | 字节×2、腾讯×3（Harness/Infra/评测Infra）、阿里、百度×2、Moonshot Growth、小红书 harness系统、蚂蚁 AReaL、MiniMax |
| 上下文工程 / 上下文管理 / 长上下文 | 10 | 字节×3、腾讯×3、阿里、美团×2、Moonshot Growth |
| 多智能体 / Multi-Agent / agent swarm | 9 | 字节 Harness、腾讯元宝、阿里、百度智能体、美团×2、Moonshot multi-agent、小红书×2 |
| 可观测 / Trace / observability | 7 | 字节×2、腾讯×3、阿里、小红书×2 |
| prompt 工程 / System Prompt / 提示工程 | 6 | 字节×2、腾讯 Harness、阿里、美团 Tabbit、快手 |
| SFT / 微调 / 后训练（Post-training） | 6 | 字节巨量星图、阿里（加分+通义标题）、百度大模型、蚂蚁后训练（标题）、快手 |
| AI Coding 工具（Cursor/Claude Code/Codex 等） | 6 | 字节火山方舟、腾讯×2（Harness/元宝）、阿里、Moonshot Growth、小红书（Claude Code 研究改造、AI 编码智能体） |
| RAG | 6 | 字节×2、腾讯企微、阿里、百度大模型、美团实习生 |
| RL / RLHF / 强化学习 | 5 | 字节巨量星图（RLHF）、腾讯 Agent Infra、阿里（加分）、百度大模型（RLHF+RL）、快手 |
| MCP | 5 | 阿里、美团实习生、Moonshot×2、小红书 Harness |
| 沙盒 / Sandbox | 4 | 腾讯×2（Infra/评测Infra）、Moonshot 资深Agent、小红书 harness系统 |
| 记忆 / Memory | 4 | 腾讯元宝、阿里、百度智能体、美团 CatPaw |
| Human-in-the-loop | 2 | 腾讯元宝、Moonshot multi-agent |
| 端侧推理 / computer use / browser use | 2 | 腾讯企微、小红书 LLM Engineering（端侧） |
| ReAct | 1 | 字节巨量星图 |
| CoT / 思维链 | 1 | 百度大模型 |
| A2A / ACP | 1 | Moonshot multi-agent |
| Deep Research | 1 | 快手 |
| LLMOps | 1 | 小红书 LLM Engineering |

### 粗结论

1. **"Harness" 已成为国内大厂正式岗位名**：字节、腾讯混元、美团（Tabbit）、小红书、DeepSeek 均设有以 "Agent Harness" 命名的岗位，核心职责高度重合——运行时/执行引擎、评测体系（eval pipeline/A/B/regression）、可观测（trace/回放）、沙盒。
2. **评测与可观测是出现频率最高的工程能力**（12 与 7 个岗位），超过 RAG（6）与 MCP（5）；上下文工程/上下文管理（10）几乎成为标配表述。
3. **工具调用/工具编排（13）与多智能体（9）** 是职责描述中最常见的两类能力要求；记忆管理（4）多出现在架构类岗位。
4. **AI Coding 工具熟练度被写进硬性要求**（6 个岗位点名 Cursor/Claude Code/Codex），腾讯混元与 Moonshot 甚至要求对 agentic coding 的 failure mode 有切身体感。
5. 模型侧岗位（后训练/RL/agentic 数据）与工程侧岗位（Harness/Infra/应用）在招聘市场上已明显分层：前者集中在腾讯混元、百度、蚂蚁、快手、Moonshot（RL Infra）、DeepSeek；后者集中在字节、美团、小红书、腾讯 PCG/CSIG/WXG。
