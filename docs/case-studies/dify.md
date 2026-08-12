---
title: 案例：Dify
dataAsOf: 2026-08
description: 拆解 Dify 的 harness 设计——把 agent 循环、RAG 管线、工具插件与模型适配层做成「可自托管的中间件」，以及它在 LangGraph（代码框架）与扣子（托管 SaaS）之间的谱系位置。
---

# 案例：Dify

> 2023 年 4 月开源的 LLM 应用开发平台，创始人张路宇（前腾讯 CODING 产品经理），名字取「**D**o **I**t **F**or **Y**ou」。GitHub 星标超过 15 万，是目前星标数最高的开源 LLM 应用平台之一。它代表 harness 的第三种形态：既不是代码框架，也不是托管 SaaS，而是**一套可以搬进你自己机房的、带图形界面的 agent 中间件**。

## 它是什么：模型与应用之间的中间件

先用本站的语言给 Dify 定位。在 [什么是 Agent Harness](/guide/what-is-harness) 里，我们把 harness 定义为「模型之外、让模型变成能干活的智能体的全部软件系统」。大多数案例——Claude Code、SWE-agent、LangGraph——都是**开发者写代码造出来的** harness。Dify 的问题意识不同：它假设大多数要落地 LLM 的团队**不想、也不该自己从零写这套系统**。

Dify 官方的自我定位是「开源 LLM 应用开发平台」，把 harness 的全部组件做成了开箱即用的产品：

- **Agent 循环与编排**：可视化画布上的 Workflow 和 Agent 两种模式（下文详拆）；
- **上下文工程**：Prompt IDE、变量注入、会话历史管理，全部界面化；
- **工具系统**：内置 50+ 工具（Google Search、DALL·E、WolframAlpha 等），加上插件市场；
- **RAG 管线**：从文档摄入（PDF、PPT 等格式的文本抽取）到检索的内置流水线；
- **可观测性（LLMOps）**：应用日志、标注、基于生产数据的持续改进；
- **模型适配层**：对接数十家推理供应商的数百个模型，含任何 OpenAI API 兼容的端点；
- **Backend-as-a-Service**：以上一切都有对应 API，应用发布后就是一个可调用的后端服务。

换句话说，Dify 是把 [Harness 的解剖](/guide/anatomy) 里那张组件图**整个产品化**了。你用 Dify，本质上是在租用（或自托管）一套别人写好的 harness，把自己的工作压缩到「编排流程、写 prompt、接数据」这三件事上。

::: info 一句话定位
如果说 LangGraph 给你的是**造 harness 的原语**（State/Node/Edge），Dify 给你的是**造好的 harness 本身**——连同数据库、队列、管理后台、权限体系一起，docker compose 一把拉起。
:::

## 两种编排模式：Workflow 与 Agent

Dify 画布上并存着两种编排范式，这个二分不是偶然的产品决策，它几乎逐字对应 Anthropic《Building effective agents》里的著名区分——**workflow（LLM 沿预定义路径被编排）与 agent（LLM 动态指挥自己的流程）**。

```text
Dify 画布上的两种编排范式：

  Workflow（Chatflow）                Agent / Agent 节点
 ┌─────────┐                        ┌──────────────┐
 │ 开始     │                        │   LLM        │
 │   ↓      │                        │   ↓     ↑    │
 │ 知识检索  │      节点按人画的       │ 思考 → 工具调用 │   循环方向
 │   ↓      │      拓扑依次执行，     │   ↓     ↑    │   由模型在
 │ LLM 生成 │      模型只在节点内     │ 观察 → 再思考  │   运行时决定
 │   ↓      │      干活，不决定路由   │              │
 │ 条件分支  │ → 人预置的分叉         │  Function Calling │
 │   ↓      │                        │  或 ReAct 策略   │
 │ 结束     │                        └──────────────┘
 └─────────┘
  拓扑由人画死，可控可审计              循环拓扑由模型即兴，灵活
```

这个对照和 [LangGraph 案例](/case-studies/langgraph) 里「受控循环 vs 自由循环」的张力是同构的，区别只在载体：LangGraph 用代码表达这张谱系，Dify 把它做成了画布上的两个按钮。实践中 Dify 用户的常见落点也是混合架构——外层 Workflow 管确定性流程，中间嵌入一个 Agent 节点处理不可预知的子任务，这正是「图负责可治理的部分，loop 负责不可预知的部分」的分层思路。

值得注意的一个演进细节：Dify 2023 年起步时的拳头功能是知识库问答（RAG 客服机器人），2024 年才把 Workflow 做成核心抽象，随后又在 Workflow 里加入 Agent 节点。这条演化路径本身就是一部微型的 harness 简史：从 DAG（检索→生成），到显式流程图，再到在流程图里给自由循环留一个受控的「笼子」。

## 内置 RAG：把最烫手的组件做成标配

Dify 起家的本领是 RAG，至今仍是它被采用的第一理由。它把 RAG 从「一个需要组装的架构」变成了「一个勾选出来的功能」：

- **摄入端**：内置 PDF、PPT 等常见格式的文本抽取，分段（chunking）、清洗、索引全在界面里配置；
- **检索端**：向量检索、全文检索、混合检索与重排序（rerank）可选，知识库作为一类节点直接拖进 Workflow；
- **运营端**：命中测试、分段内容的在线编辑、基于标注数据的持续调优——这是 LLMOps 视角下的 RAG，而不是一次性的脚本。

对照 [上下文工程](/components/context-engineering) 一章的视角：RAG 是「给模型装配上下文」的最大宗工程，也是自建 harness 时最容易烂尾的部分（抽取质量、分段策略、召回评估，每一项都是坑）。Dify 的判断是——**与其让一千个团队各写一遍平庸的 RAG，不如平台内置一套及格线以上的**。这个判断对 RAG 有效，对 harness 整体也成立，它就是 Dify 整个产品的存在理由。

## 插件系统与 MCP：工具层的两次进化

Dify 的工具层经历过一次重要的架构重构，理解它对理解「平台型 harness」的边界很关键。

**第一阶段（2025 年 2 月，v1.0）：插件化架构。** 模型供应商和工具从主仓库代码里被剥离，迁移为独立分发的**插件**，同时引入 Agent 策略（Agent Strategy）、扩展（Extension）等插件类型，配套官方市场（Marketplace）。动机在官方博客里讲得很清楚：主仓库不可能承接全世界模型和工具的适配代码，平台要活下来，必须让生态自己长。这是所有平台型 harness 的必经之路——适配层的工作量注定超过核心团队的开发生命。

**第二阶段（2025 年 7 月，v1.6）：内置双向 MCP。** 社区此前已靠第三方插件（如 MCP SSE 插件）曲线接入 MCP；v1.6 把它变成原生能力，而且是**双向**的：

- **消费 MCP**：任何 MCP server 的工具可以在 Workflow 里被调用——既可以放进 Agent 节点让模型动态选用（动态路径），也可以作为独立节点按固定位置编排（精确路径）；
- **暴露 MCP**：反过来，可以把 Dify 应用和 Workflow 发布成 MCP server，供 Claude Code 这类外部 agent 调用。

双向 MCP 的含义值得停下来想一下：Dify 不再只吞噬外部能力，它自己编排出来的流程也变成了别人 harness 里的[工具](/components/tools)。平台之间开始用同一个协议互插——这是「harness 中间件化」最明确的信号。

## 模型中立：把「换模型」做成日常操作

Dify 对接数十家供应商的数百个模型，并兼容任何 OpenAI API 格式的端点（包括 vLLM、Ollama 等本地推理）。模型在 Dify 里是一个**运行时可替换的配置项**：同一个应用，后台切一下供应商就换了引擎，Prompt IDE 还支持多模型并排对比输出。

这正好实证了本站反复强调的边界划分：**模型不在 harness 之内**（见 [模型 vs Harness](/guide/model-vs-harness)）。Dify 的商业模式恰恰建立在这条边界上——它不绑定任何模型厂商，反而靠「帮你随时换模型」活着。对企业来说，这层中立性还有合规含义：涉密数据可以切到本地部署的开源模型，流程和应用层一行不改。

## 部署形态：云服务、社区版与企业版

Dify 自己也是「谱系中间态」的践行者——同一套代码，三种交付：

- **Dify Cloud**：官方托管版，零安装，有免费 Sandbox 套餐，适合尝鲜和原型验证。功能与自部署版基本一致。
- **社区版（Community Edition）**：自托管的开源版本，也是大多数人说的「Dify」。`docker compose up -d` 一把拉起，最低配置只要 2 核 CPU、4GB 内存；要上海量生产，社区贡献了 Helm Chart（Kubernetes）、Terraform（Azure/GCP）、AWS CDK 等整套部署方案。
- **企业版**：在社区版之上叠加企业级特性（如更强的安全与管理能力），商业授权——这正是 License 附加条款的变现出口。

这个三档结构和 GitLab、Mattermost 那一代开源商业化的打法一脉相承：**用开源版占领开发者和私有化场景，用托管版吃怕运维的团队，用企业版收割合规与规模需求**。对 harness 研究的启发在于：当 harness 本身成为商品，「开源内核 + 托管增值」可能是它比模型更可持续的商业模式——模型会贬值，而运维、合规和生态粘性的贬值速度慢得多。

## 平台谱系：LangGraph / Dify / 扣子

把案例章的三个「平台类」放在一起，构成一条清晰的谱系——同样的问题（如何不重写 harness 就落地 agent），三种交付形态：

| 维度 | LangGraph（代码框架） | Dify（自托管中间件） | 扣子 Coze（托管 SaaS） |
|---|---|---|---|
| 交付物 | Python/TS 库 | Docker 部署的完整系统 | 云端账号 |
| 使用者 | 工程师写代码 | 工程师 + 业务人员拖画布 | 业务人员为主 |
| 控制流表达 | 代码里的图 | 画布上的 Workflow/Agent | 画布上的工作流 |
| 数据与运行位置 | 你的进程 | 你的机房 / VPC | 厂商的云 |
| 可定制上限 | 无上限（就是代码） | 插件 + API，核心不可改 | 平台边界内 |
| 运维负担 | 自己扛 | 自己扛（PostgreSQL/Redis/向量库等一栈组件） | 零 |
| 锁定风险 | 低（Apache 2.0 代码库） | 中（License 附加条款，见下） | 高（数据与流程都在别人手里） |
| 典型买家 | 有强工程团队的 AI 公司 | 要自托管的企业/政企 | 求快的团队与个人 |

三点之间没有优劣，只有**控制权和运维负担沿谱系的此消彼长**。Dify 卡在中间：比 LangGraph 省掉「自己造系统」的工作量，比扣子保住「数据和运行在自己地盘」的底线。

## 企业自托管场景：为什么偏偏是 Dify

Dify 在政企、金融、制造业的渗透率明显高于它的技术新颖度所能解释的水平。原因不在功能清单，在几个很实际的结构因素：

1. **数据不出域是硬约束。** 私有化部署的合规要求直接排除托管 SaaS，自建框架又太贵——「可自托管的成品中间件」恰好填进这个夹缝。Docker Compose 最低 2 核 4G 就能跑，社区还贡献了 Helm Chart、Terraform、AWS CDK 等一整套生产部署方案。
2. **业务人员要参与。** 企业的 prompt 和流程知识在业务专家手里，不在工程师手里。画布让业务方能直接改流程，工程师退到「接系统、写插件」的位置——协作结构本身就值钱。
3. **API 优先，可嵌入存量系统。** 每个应用发布即 REST API，Dify 扮演的是「AI 能力中台」：门户、审批系统、客服系统调它的接口，它不抢占前端。
4. **国产模型友好。** 对国产模型供应商和本地推理端点的一线支持，叠加中文社区与文档，让它在国产化环境里几乎没有同形态对手。

::: warning License 注意点：不是纯 Apache 2.0
Dify 采用的是「Dify Open Source License」——**基于 Apache 2.0，但附加两条关键限制**（GitHub 也因此将其标记为 NOASSERTION，非 OSI 标准协议）：

1. **多租户限制**：未经书面授权，不得用 Dify 源码对外运营多租户环境（Dify 语境下一个 workspace 即一个租户）。换句话说：企业内部自用、给自己的应用做后端，没问题；想拿它做面向多个客户的 SaaS 服务，必须购买商业授权。
2. **前端标识保留**：使用 Dify 前端时不得移除或修改其 LOGO 与版权信息。

对典型企业自托管场景这两条基本无感，但对「基于 Dify 二次开发对外卖服务」的团队，这是签合同前必须读的第一份文件。
:::

## 适合与不适合

**Dify 发光的地方：** 知识库问答/客服（RAG 是出厂标配）；企业内部流程自动化（审批、分流、报告生成——步骤确定的 Workflow 场景）；需要业务人员直接参与编排的团队；有私有化合规要求的政企；想快速验证多个想法、把 Dify 当 AI 原型工场的团队。

**Dify 硌脚的地方：** 开放探索型 coding agent 这类任务——画布不是为「模型全权即兴」设计的，Claude Code 式的自由 loop 在 Dify 里反而施展不开；对 harness 行为有极致定制需求的团队——平台的核心循环不可改，改起来比用 [LangGraph](/case-studies/langgraph) 自己写还痛；极简嵌入场景——为一个单行 LLM 调用拉起 PostgreSQL + Redis + 向量数据库的全套依赖，是拿航母送快递。

::: tip 一个判断口诀
选型时问自己：**我的瓶颈是「写不出 harness」还是「买不起运维」？** 写不出 → Dify（或扣子）；买不起 → LangGraph 这类库，循环自己养；都写得出也养得起 → 回到 [从零构建一个最小 Harness](/practice/build-your-own)，那可能才是最合身的答案。
:::

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——Dify 产品化的对象：模型之外的那整套系统
- [Harness 的解剖](/guide/anatomy)——对照 Dify 的功能清单，逐个组件看它如何落地
- [案例：LangGraph](/case-studies/langgraph)——谱系左端：用代码造 harness 的框架派
- [案例：扣子（Coze）](/case-studies/coze)——谱系右端：把 harness 整个托管掉的 SaaS 派
- [工具系统](/components/tools)——插件与双向 MCP 背后的通用问题：工具如何被建模和接入
- [上下文工程](/components/context-engineering)——内置 RAG 管线对应的底层主题
- [可观测性](/components/observability)——LLMOps 在通用 harness 设计中的位置
- [Harness 设计原则](/practice/design-principles)——把「何时用平台、何时自建」放进更大的原则体系

## 参考资料

- [langgenius/dify（GitHub 仓库）](https://github.com/langgenius/dify)——核心功能清单、自部署指南、License 说明，本文多处引述
- [Dify 官方文档：Introduction](https://docs.dify.ai/en/introduction)——平台定位、Dify Cloud 与自托管社区版的分野、名字由来
- [Dify v1.0.0: Building a Vibrant Plugin Ecosystem（官方博客，2025 年 2 月）](https://dify.ai/blog/dify-v1-0-building-a-vibrant-plugin-ecosystem)——插件化架构：模型与工具迁移为插件、Agent Strategy、Marketplace
- [Dify Plugin System: Design and Implementation（官方博客，2025 年 3 月）](https://dify.ai/blog/dify-plugin-system-design-and-implementation)——插件系统的设计动机与实现
- [Dify v1.6.0: Built-in Two-Way MCP Support（官方博客，2025 年 7 月）](https://dify.ai/blog/v1-6-0-built-in-two-way-mcp-support)——原生双向 MCP：消费 MCP 工具与把应用暴露为 MCP server
- [Dify Open Source License（仓库 LICENSE 文件）](https://github.com/langgenius/dify/blob/main/LICENSE)——Apache 2.0 附加条款原文：多租户限制与前端标识保留
- [Building effective agents（Anthropic，2024 年 12 月）](https://www.anthropic.com/engineering/building-effective-agents)——workflow 与 agent 的二分法，Dify 双编排模式的理论对应物
