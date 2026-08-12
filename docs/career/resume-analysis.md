---
title: 能力对标：简历该突出什么
dataAsOf: 2026-08
description: 从 44 份真实在招 JD 反推 Agent 工程岗的能力模型：七项核心能力的 JD 证据、简历好差写法对比、面试考点，三类候选人画像的对标分析与补课路径，附逐条自查清单。
---

# 能力对标：简历该突出什么

这一页回答一个具体问题：**简历上的哪些经历，会让 Agent 工程岗的面试官眼前一亮？**

方法很笨但可靠：把 44 份真实 JD 拆开，数词频、读原话，反推雇主到底在为什么能力付钱。结论先行——这些岗位要的不是"会用 LangChain 的人"，而是**能把 agent 从 demo 推进到生产、并能证明它真的变好了的人**。

::: info 数据口径与诚实声明
本页所有结论基于 2026-08-11 ~ 08-12 检索的 44 份真实在招 JD（国外 10 家公司 17 岗、国内 12 家公司 27 岗），完整清单见 [JD 全景](/career/jd-list)。44 份是快照不是全貌：样本明显偏向一线大厂与头部模型公司，且部分岗位只抓到职责片段。词频统计为人工核对的粗统计，所有引用均标注公司名与岗位名，未抓到原文的一律不引。请把本页当作"有依据的归纳"，而不是"行业公理"。
:::

## 七项核心能力

把 44 份 JD 的高频要求合并同类项，得到七项能力。前四项是工程侧岗位的硬通货，后三项按岗位方向拉开差距：

```text
                    Agent 工程岗能力模型（按 JD 词频排序）
  ┌────────────────────────────────────────────────────────┐
  │  ① Agent 运行时与工具系统   国内 15 岗提运行时/Harness   │
  │  ② 评测体系（evals）        国内 12 岗 / 国外 10 岗      │
  │  ③ 上下文工程与 RAG         国内 10+6 岗 / 国外 3+4 岗   │
  │  ④ 工程基本功（后端/分布式） 几乎所有 JD 的硬性要求栏     │
  │  ──────────── 以下按方向分化 ────────────               │
  │  ⑤ 模型理解与微调           国内 6+5 岗 / 国外 6 岗      │
  │  ⑥ 安全、权限与边界意识      沙盒 4 岗、权限/注入多点名   │
  │  ⑦ 产品 sense 与业务闭环    散落在职责描述的高频潜台词    │
  └────────────────────────────────────────────────────────┘
```

值得注意的一个信号：**评测与可观测合计出现的频率，超过了 RAG 和 MCP。** 市场已经在为"能证明 agent 可靠"的能力付溢价，而不是为"会接 API"付溢价。这与本手册反复强调的判断一致：[Harness 决定 agent 的能力上限](/guide/what-is-harness)，而评测是 harness 迭代的方向盘。

### ① Agent 运行时与工具系统实战

**JD 证据。** 美团「Agent Harness 工程师」要求"参与 System Prompt、Tools、Skills、上下文管理、Agent Loop、任务状态及异常恢复等核心能力建设"；字节「Agent Harness工程师-AI数据与安全」要"解决线上 Agent 循环执行、任务中断、调用异常等问题"；月之暗面「Agentic Growth Engineer」的表述最有区分度——"能围绕 Agent 构建高质量的 scaffolding：context 如何组织、工具如何抽象、**循环如何终止、失败如何恢复**、效果如何评估"。国外对照：Cursor「Software Engineer, Agent Harness」直接列出 "agent loop, tools, prompts, execution environment"。

**简历上怎么写。**

- ❌ 差写法："熟悉 LangChain/LangGraph，开发过多智能体系统。"——框架名罗列，没有一句能被追问。
- ✅ 好写法（STAR）："客服工单 agent 上线后频繁在工具报错时陷入重试循环（S）；我负责运行时稳定性改造（T）；为 agent loop 增加最大步数熔断、工具错误分类回灌与断点续跑（A）；循环失控率从每周 17 起降到 0，P95 任务时长下降 31%（R）。"

注意好写法的重心不在"用了什么框架"，而在**处理过什么失败模式**——这正是 JD 里"任务中断、调用异常"对应的现实。

**面试可能怎么考。** "你的 agent 在第 30 步卡住了，怎么定位是模型问题还是 harness 问题？""工具报错应该怎么回灌给模型，直接把 stack trace 塞进去吗？"——考点落在 [Agent 循环](/components/agent-loop)与[工具系统](/components/tools)的真实设计决策上。

### ② 评测体系搭建

**JD 证据。** 字节同一岗位要求"落地自动化 EVAL 流水线、版本回归、A/B 实验能力"；腾讯「混元AI Agent Harness Engineer」要求"自动化 eval pipeline、A/B testing、regression detection"；蚂蚁「AReaL工程师-智能体」、MiniMax「自动化测试Agent开发工程师」、百度「智能体算法工程师」（"建立效果、效率、资源成本一体化量化指标"）都围绕评测设岗。国外同样密集：Cognition「Research Engineer, Post-Training」写得最透——"Build evals that actually capture what matters... making sure the numbers mean something"；Amazon「Senior Applied Scientist, Agentic WorkSpaces AI」要求 "Build evaluation frameworks to quantify agent performance, reliability, and user impact in real-world, unstructured environments"。

**简历上怎么写。**

- ❌ 差写法："搭建了大模型评测体系，准确率达 95%。"——数字没有口径，反而扣分。
- ✅ 好写法："为文档问答 agent 从 0 搭建离线评测集（217 条真实 badcase 标注）与 LLM-as-judge 流水线，与人工标注一致率 89%；接入 CI 后每次 prompt/模型变更自动回归，上线后人工抽检工作量下降约 70%。"

**面试可能怎么考。** "LLM-as-judge 的偏差怎么处理？""评测集会不会被 prompt 调优'过拟合'？""线上 1% 的 badcase 怎么回流进评测集？"准备好讲清楚你的评测**数字为什么可信**。

### ③ 上下文工程与 RAG

**JD 证据。** "上下文工程/上下文管理"在国内 10 个岗位出现，几乎成标配表述：阿里实习岗要求"持续优化召回质量与上下文注入策略"，美团智能体工程师要"上下文治理"。国外 Anthropic「Applied AI Engineer」（London）在硬性要求里直接点名 "context engineering"；Microsoft「Forward Deployed AI Engineer, Health」要求生产经验覆盖 "context engineering, retrieval, tool use, orchestration, and evaluation"；Meta「AI Native」把 "context management" 与 RAG 并列。

**简历上怎么写。**

- ❌ 差写法："精通 RAG，熟悉向量数据库与 embedding。"——工具清单，没有 trade-off。
- ✅ 好写法："知识库 agent 长会话中检索噪声随轮次累积（S）；我负责上下文层重构（T）；把'每轮全量检索拼接'改为'会话状态 + 按需检索 + 工具输出摘要压缩'，并给上下文设预算与淘汰策略（A）；长会话任务完成率提升 22%，平均 token 成本降 40%（R）。"

**面试可能怎么考。** "上下文窗口快爆了，你先压缩什么、先丢什么？为什么？"——本质是考[上下文工程](/components/context-engineering)里"模型每一步该看到什么"的判断力，而不是背压缩算法名。

### ④ 工程基本功：后端与分布式

**JD 证据。** 这一项不写在 AI 要求栏，而是写进硬性要求栏。xAI「Backend Engineer」要求"分布式系统设计、实现与维护经验，service observability and reliability 最佳实践"（加分项才是 "Hands-on experience with LLM APIs, embeddings, or RAG patterns"）；月之暗面「资深Agent研发工程师」要"精通 Go，熟悉微服务、RESTful API、gRPC、OpenTelemetry"加一串存储组件；小红书「Agent Harness 工程师」要"理解服务治理、任务调度、权限系统、可观测性、分布式系统"；腾讯「Agent Infra高级研发工程师」点名 Docker、Kubernetes、容器网络、集群调度。

**简历上怎么写。**

- ❌ 差写法：只写模型侧经历，工程经历一句不提——面试官会默认你扛不住生产环境。
- ✅ 好写法："agent 任务执行平台支撑日均 40 万次异步任务调度：基于 K8s 的任务隔离与弹性伸缩、全链路 OpenTelemetry trace、执行轨迹可回放；可用性 99.95%。"——把 agent 经历**写成**后端经历，这是最讨巧也最真实的写法。

**面试可能怎么考。** 系统设计轮："设计一个支持十万并发的 agent 任务执行平台，状态存哪、怎么隔离、怎么观测？"参考[可观测性](/components/observability)里 Trace/回放的设计动机。

### ⑤ 模型理解与微调

**JD 证据。** 这是方向分化项。模型侧岗位把它当核心：OpenAI「Research Engineer, Applied AI Engineering」点名 "distillation、supervised fine-tuning、policy optimization"；快手「基础大模型算法工程师—Agent方向」要"SFT冷启动训练、RL端到端训练agentic reasoning model"；蚂蚁设「Agent后训练算法工程师」。工程侧岗位则多为"了解"级：字节巨量星图要"了解 SFT/RLHF 等大模型优化技术，与算法同学一起构建工程链路"，腾讯 Agent Infra 要"了解大模型训练流程和基本原理"。

**简历上怎么写。**

- ❌ 差写法（投工程岗时）：通篇 loss 曲线、奖励模型细节，看不到系统交付。
- ✅ 好写法："与算法团队协作完成客服 agent 的 SFT 数据工程：设计 3 万条工具调用轨迹的清洗与质检管线，badcase 从线上 trace 自动回流；微调后工具参数错误率下降 54%。我负责数据管线与评测，训练由算法同学执行。"——**讲清楚你在模型工程链路里的那一段**，比假装全栈更有说服力。

**面试可能怎么考。** "什么时候该微调，什么时候该改 prompt/harness？"——好答案要提到成本、迭代周期和数据门槛，而不是"微调效果更好"。

### ⑥ 安全、权限与边界意识

**JD 证据。** 出现频率不算最高，但出现在最高级的岗位上：小红书 Harness 工程师要"建设 Agent 身份认证与权限治理能力，**解决权限穿透、最小授权和安全边界问题**"；小红书另一岗要"设计云端 Agent 沙箱系统，保障 Agent 在生产环境中的安全可控运行"；阿里实习岗已要求"具备大模型幻觉、Prompt 注入等风险的工程化应对思路"；国外 Amazon WorkSpaces 强调 "ensuring efficiency, safety, and alignment with enterprise requirements"，Meta 把 "Responsible AI（safety、ethics、alignment、explainability）"列为加分。

**简历上怎么写。**

- ❌ 差写法："注重 AI 安全与对齐。"——空话。
- ✅ 好写法："为内部 agent 平台设计工具权限分层：只读工具默认放行、写操作需策略校验、高危操作走人审；拦截过一次真实 prompt 注入导致的越权数据查询，事后把该 badcase 固化为评测集回归项。"

**面试可能怎么考。** "agent 拿到一个用户不可信的输入，里面藏着'忽略之前的指令'，你的系统在哪几层能挡住？"对照[权限与人机协作](/components/permissions)的思路作答。

### ⑦ 产品 sense 与业务闭环

**JD 证据。** 这一条很少出现在要求栏，却密集出现在职责栏——是"来了要干什么"的潜台词。Cognition「Applied AI Engineer」要求"量化影响（productivity metrics、ROI stories）"；百度智能体算法工程师要"从技术验证到产品落地闭环"；美团智能体工程师要"推动Agent能力多场景规模化应用"；月之暗面 Agentic Growth Engineer 更是要"在 Agent 领域发掘能带来 10 倍增长的非共识机会"。

**简历上怎么写。** 不需要单列一栏——把业务结果缝进每条技术经历里："上线后客服一次解决率 +9pp"、"覆盖 6 个业务线"。技术人的产品 sense，就体现在**你记得自己做的东西改变了什么数字**。

**面试可能怎么考。** "你做过的 agent 里，哪个其实不该用 agent 做？"——这道题在考你对技术适用边界的诚实。

::: warning 高频词不等于得分点
看到这里你手里已经有了一份关键词清单：harness、evals、上下文工程、MCP、多智能体……**别把清单直接糊到简历上。** 腾讯混元的 JD 写得很直白：要"对 agentic coding 的能力边界和 failure mode 有切身体感"——体感二字，任何关键词都伪造不出来。面试官对每一个高频词都备了追问三连环（怎么做的、为什么这么做、出过什么事故），没有真实项目支撑的词，写上去就是把面试引向你的知识盲区。正确姿势：每个关键词背后挂一个你能讲十分钟的真实项目，挂不住的宁可不写。
:::

## 三类候选人画像对标

同一套能力模型，落在不同背景的人身上，长短板完全不同：

| 画像 | 优势项 | 差距项 | 补课路径 |
| --- | --- | --- | --- |
| 后端转 Agent 工程 | ④ 工程基本功天然扎实；生产环境体感（可用性、并发、故障）正是 ① 的底层 | ② 评测方法论空白；③ 上下文工程；对"模型会怎么犯错"缺体感 | 手搓一个最小 harness（见[动手搭建](/practice/build-your-own)）→ 给它配评测集和 trace → 读 [Claude Code](/case-studies/claude-code)、[SWE-agent](/case-studies/swe-agent) 的架构取舍 |
| 算法 / ML 背景 | ⑤ 模型理解直接对口模型侧岗位；② 的实验设计思维可迁移到 evals | ④ 生产工程；① 的运行时细节（循环终止、失败恢复、并发调度） | 把一个 agent 项目真正推上线（哪怕是内部工具），亲手处理一次线上事故；补 [Agent 循环](/components/agent-loop)与[可观测性](/components/observability)的工程实现 |
| 应届 / 初级 | AI Coding 工具原生一代：阿里实习岗要"Cursor、Claude Code 等 AI 编程工具重度玩家"，Notion Early Career 岗明确要求跟进使用同类工具；没有旧范式包袱 | ④ 几乎无生产经验；系统设计薄弱；项目多为玩具规模 | 用公开 benchmark（如 SWE-bench 子集）做可复现的项目；给玩具项目补上 eval 与 trace，让它"看起来被认真评测过"；争取 Agent 方向实习（44 份 JD 里有明确的实习/初级岗） |

三条路径殊途同归：**都得有一个"从 demo 到生产（或接近生产）"的完整故事**。JD 市场里纯 prompt 调参的岗位正在消失，而"Harness 工程师"已经成为字节、腾讯混元、美团、小红书、DeepSeek 的正式岗位名——市场用钱投票的方向，就是你的补课方向。

## 投递前自查清单

对照 JD 最高频的要求逐条自评。每条都要能立刻说出一个对应的真实项目，说不出来就是差距项：

- [ ] 我做过 agent loop 的稳定性设计（循环终止、失败恢复、步数熔断），讲得出具体事故
- [ ] 我设计过工具系统：工具划分粒度、错误回灌格式、描述怎么写模型才用得对
- [ ] 我搭过评测集与自动化回归，能辩护"这个数字为什么可信"
- [ ] 我做过上下文管理：压缩、注入、检索质量优化，知道各自的代价
- [ ] 我有生产级后端交付记录（并发、可用性、存储、CI/CD），且能和 agent 场景结合
- [ ] 我处理过或可详细推演：prompt 注入、越权工具调用、敏感数据泄漏的防护
- [ ] 我重度使用至少一款 AI Coding 工具，说得出它的 failure mode
- [ ] 我能讲清"微调 vs. prompt vs. harness 改造"的选型逻辑
- [ ] 我的每条经历都带业务结果数字，而不是技术名词堆砌
- [ ] 我对 MCP、Skills、多智能体协作中的至少一项有上手经验而非仅读过文章（阿里、月之暗面、小红书均点名）

::: tip 清单的正确用法
10 条里能扎实勾上 5-6 条就可以投——44 份 JD 里没有一份要求全部命中。把勾不上的条目当作下一轮学习清单，比当作焦虑清单有用得多。本手册的[知识地图](/career/knowledge-map)按这些能力项组织了对应的章节与论文。
:::

## 延伸阅读

- [求职模块首页](/career/)——岗位市场全景与本模块导航
- [JD 全景](/career/jd-list)——44 份 JD 的原始清单与出处，本页结论的数据基础
- [知识地图](/career/knowledge-map)——按能力项组织的学习路径
- [什么是 Agent Harness](/guide/what-is-harness)——为什么市场愿意为 harness 能力设岗
- [Harness 的解剖](/guide/anatomy)——七项能力中①②③对应的组件全景
- [动手搭建一个 Harness](/practice/build-your-own)——把本页任何一条"差距项"变成"项目经历"的最短路径
- [常见陷阱](/practice/pitfalls)——面试追问"出过什么事故"时的素材库
