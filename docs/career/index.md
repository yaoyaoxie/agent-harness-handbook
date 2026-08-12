---
title: 求职与 JD 分析
dataAsOf: 2026-08
description: 从 2026 年 8 月国内外 22 家公司 44 个真实在招岗位 JD 反推 Agent Harness 学习路径：岗位版图、技能需求全景、以及"Agent Harness 工程师"成为正式岗位名这一行业信号。
---

# 求职与 JD 分析

学一门技术最好的指南针是什么？不是教程目录，不是论文列表，而是**招聘市场正在为什么付钱**。

JD（Job Description，职位描述）是行业对知识需求最诚实的投票。一家公司写进 JD 的每一条要求，背后都是真金白银的预算、被卡住的项目进度、和"招不到这种人就做不成事"的真实痛点。技术博客可以说谎（营销），会议演讲可以超前（愿景），但招聘需求不行——它必须描述一个**此刻就缺人做**的具体工作。本手册前面讲过的每一个组件——[上下文工程](/components/context-engineering)、[工具系统](/components/tools)、[可观测性](/components/observability)——到底值不值得学、学到什么深度，招聘市场早就给出了答案。这个模块做的事，就是把这些答案系统地挖出来。

## 数据说明：这份调研是怎么做的

本模块所有结论基于 2026 年 8 月 11–12 日的一次集中检索，共收录 **44 个真实在招岗位**：

| 板块 | 公司数 | 岗位数 | 覆盖公司 |
| --- | --- | --- | --- |
| 国外 | 10 | 17 | Anthropic、OpenAI、Microsoft、Google DeepMind、Meta、Amazon AWS、xAI、Cognition、Cursor（Anysphere）、Notion |
| 国内 | 12 | 27 | 字节跳动、腾讯、阿里巴巴、百度、美团、月之暗面、小红书、蚂蚁集团、DeepSeek、MiniMax、快手、智谱（仅渠道说明） |

来源可信度分三级，阅读时请留意区分：

- **官方（全文）**：从公司官方招聘站直接抓取的完整 JD（Greenhouse、Ashby、amazon.jobs、jobs.bytedance.com、careers.tencent.com、job.xiaohongshu.com 等）。可信度高，所有引用以它为准。
- **官方（标题级）**：官方招聘站可确认岗位名称、地点、部门在招，但 JD 正文因 JS 渲染未能抓到。只记录标题信息，不补写职责。
- **聚合站/搜索快照**：BOSS直聘、猎聘、牛企直聘等第三方镜像或搜索引擎快照。可信度中到低，模块内凡引用必显式标注。

::: warning 时效性提醒
JD 是会下架的。这份调研是 2026 年 8 月中旬招聘市场的一张**快照**：Anthropic 一个知名的 FDE 岗位在检索期间就已疑似下架未能收录。请务必把本模块当作"某一时刻的行业需求剖面"来读，而不是永恒的职业指南。具体岗位链接的时效与完整 JD 原文，见 [JD 清单](/career/jd-list)。
:::

::: info 一条调研纪律
凡是只抓到标题、没抓到正文的岗位，宁可标注"未确认"也不虚构职责。这导致一些知名公司（如智谱）因找不到可核验的官方 JD 页面而只作渠道说明——数据缺口本身也是诚实的信息。
:::

## 岗位版图：国外在招什么人

国外 17 个岗位的 title 分布呈现清晰的三层：

```text
┌─────────────────────────── 国外 Agent/LLM 工程岗版图 ──────────────────────────┐
│                                                                                │
│  客户交付层（最热门）                                                            │
│    Applied AI Engineer / Forward Deployed Engineer (FDE)                       │
│    Anthropic×2 · OpenAI · Microsoft · Cognition×2 · Notion                     │
│    职责核心：把模型/产品部署进客户环境，沉淀 playbook 与可复用资产                    │
│                                                                                │
│  Harness 核心层（与本手册直接同名）                                                │
│    Software Engineer, Agent Harness / Agent Evaluation                         │
│    Cursor（Anysphere）——agent loop、tools、guardrails、model routing            │
│                                                                                │
│  研究与模型层                                                                    │
│    Research Engineer / Applied Scientist                                       │
│    OpenAI · DeepMind · Cognition Post-Training · Amazon×2                      │
│    职责核心：后训练、RLHF、agentic 数据与算法，普遍要求硕士/博士                     │
└────────────────────────────────────────────────────────────────────────────────┘
```

几个值得注意的信号：

- **FDE/Applied AI 成为最大招聘门类。** Anthropic、OpenAI、Microsoft、Cognition、Notion 都在招这类"驻扎客户现场"的工程师，职责惊人地一致：陪客户从 discovery 走到 deployment，然后把一线模式沉淀回产品。这类岗位的硬通货恰好是 harness 知识——Anthropic（Applied AI Engineer, London）的 JD 明确点名 prompting、context engineering、agent architectures、evaluation frameworks、deployment at scale。
- **薪资透明且带宽大。** 国外官方 JD 普遍披露薪资带：Anthropic Applied AI（旧金山/纽约/西雅图）$200,000–$320,000；Microsoft FDE（Health）IC5 档 $142,800–$274,800、IC6 档 NYC 可达 $331,200；Cognition Applied AI $180,000–$225,000；Notion 早期职业岗 $130,000–$150,000。即使是要求 PhD 的 Amazon Applied Scientist（Agentic AI），base 也在 $171,600–$222,200。
- **年限门槛集中在 3–6 年**，且接受多元背景（FDE / SWE / 技术 PM / 技术创始人均可，Anthropic JD 原文）。Cursor 的 Agent Harness 岗甚至没有列学历年限硬门槛，只要求"构建过复杂 agentic products 或基础设施"。

把披露了薪资的官方 JD 按岗位类型排开，带宽差异一目了然（均为年 base，未含 bonus/equity）：

| 岗位类型 | 代表岗位 | 薪资带 |
| --- | --- | --- |
| 客户交付（FDE/Applied AI） | Anthropic Applied AI（旧金山/纽约/西雅图） | $200,000–$320,000 |
| 客户交付（FDE/Applied AI） | Cognition Applied AI Engineer | $180,000–$225,000 |
| 客户交付（FDE/Applied AI） | Notion FDE（Tokyo） | 未公开 |
| 研究/模型（PhD 向） | Amazon Applied Scientist II（Agentic AI） | $171,600–$222,200 |
| 研究/模型（PhD 向） | Google DeepMind Research Engineer | $141,000–$202,000 |
| 早期职业（<2 年经验） | Notion Software Engineer, Early Career (AI) | $130,000–$150,000 |
| Harness 核心 | Cursor Software Engineer, Agent Harness | 未公开 |

两个读法：其一，**不做 PhD 也有高薪通道**——薪资最高的档位在客户交付层而非研究层，工程能力 + harness 知识的组合本身就是硬通货；其二，harness 核心层（Cursor）反而是唯一未公开薪资的，参照同司同地工程师岗位的带宽，议价空间大概率不低。

## 岗位版图：国内在招什么人

国内 27 个岗位的版图与国外有明显不同的形状：

- **"Agent Harness"直接成为正式岗位名。** 字节跳动（Agent Harness工程师-AI数据与安全）、腾讯（混元AI Agent Harness Engineer）、美团（Agent Harness 工程师，负责 Tabbit Agent Harness）、小红书（Agent Harness 工程师）、DeepSeek（Agent Harness 团队，官方人才页在招）——五家公司用这个精确的 title 在招人，这是 2026 年国内招聘市场最醒目的变化。
- **职责收敛度极高。** 字节（Agent Harness工程师）的 JD 要求迭代"智能体规划、工具编排、RAG 增强、长上下文管理、任务调度核心链路"，搭建量化评估体系与全链路可观测体系；腾讯混元的 Harness Engineer 岗同样聚焦 tracing & observability、自动化 eval pipeline、A/B testing、Agent debugging 工具。运行时、评测、可观测、沙盒，几乎是每个 harness 岗的标配四件套。
- **硬性要求典型形态**：本科及以上、计算机相关专业，2–5 年（字节 Harness 岗）或 3–5 年（小红书 Harness 岗）后端/AI 工程化经验；精通 Python，熟悉 Go/Java；点名 LangChain/LangGraph 等 Agent 框架。
- **薪资披露习惯与国外相反：普遍不披露。** 国内官方 JD 几乎都不写薪资，仅有的数据点来自聚合站快照（可信度中低）：蚂蚁集团 AReaL 工程师-智能体 35-65K·15薪（猎聘快照），MiniMax 自动化测试Agent开发工程师 30-50K（职友集快照）。谈判前的薪资调研需要另寻渠道。

::: tip 一个被写进硬性要求的新信号
国内外同时出现：**AI Coding 工具熟练度成为硬性要求**。腾讯混元要求"使用 Cursor / Claude Code / Codex 等进行重度编程，对 agentic coding 的能力边界和 failure mode 有切身体感"；阿里 2027 届实习岗要求"Cursor、Claude Code 等 AI 编程工具重度玩家"；Notion 早期职业岗也要求跟进并使用 AI 开发工具。会用 harness 的人，才有资格造 harness。
:::

把两个市场并排对比，差异集中在四个维度：

| 维度 | 国外 | 国内 |
| --- | --- | --- |
| 岗位命名 | Applied AI Engineer / FDE 为主流，"Agent Harness" 仅 Cursor 一家明确使用 | "Agent Harness 工程师"成为多家大厂正式岗位名（字节、腾讯、美团、小红书、DeepSeek） |
| 薪资披露 | 官方 JD 普遍披露带宽（$130K–$330K 年 base） | 官方 JD 几乎不披露，仅聚合站快照有零星数据（30–65K 月 base） |
| 学历年限 | 年限 3–6 年为主，研究岗要 PhD，工程岗接受多元背景；Cursor 无硬门槛 | 普遍要求本科及以上 + 2–5 年经验；实习/校招通道明确（阿里 2027 届、百度校招、美团日常实习） |
| 能力侧重 | 客户交付、evals、production deployment、跨团队协作 | 运行时/执行引擎、评测体系、可观测、沙盒——更偏平台与基建 |

一个合理的解读：国外的 harness 需求被**打包进**了 FDE/Applied AI 这类交付型岗位里（"把 agent 部署进客户环境"本身就是 harness 工程），而国内直接把 harness **当成一个独立工种**来招。路径不同，要的核心能力是同一份清单——这正是本手册的组件章节覆盖的东西。

## 重要发现：「Agent Harness」在国内外同时成为岗位 title

这是本次调研最重要的发现，值得单独一节。

「Agent Harness」不再只是工程博客里的术语，它已经同时出现在国内外一线公司的**官方招聘站岗位名**里：

| 公司 | 岗位名 | 来源 |
| --- | --- | --- |
| Cursor（Anysphere） | Software Engineer, Agent Harness | 官方 careers 页 |
| 腾讯 | 混元AI Agent Harness Engineer | 官方（全文） |
| 字节跳动 | Agent Harness工程师-AI数据与安全 | 官方（全文） |
| 美团 | Agent Harness 工程师（Tabbit） | 官方（列表页片段） |
| 小红书 | Agent Harness 工程师 | 官方（全文） |
| DeepSeek | Agent Harness 团队 | 官方（标题级） |

而且不止于 title。腾讯混元评测 Infra 岗的职责里写着"从 Harness 与打分逻辑出发，确保平台化改造后评测结果的准确可信"；月之暗面的 multi-agent 产品工程师岗要求"可以快速自己手搓一套 Harness 来验证 Agent 协作与编排效率"，并把协作协议本身称作"一种新型 harness"。词频统计显示，国内 27 个岗位中有 10 个明确出现 "Harness" 原词。

这对本手册的读者是一个直接的印证：**你正在学的这套东西——agent loop、上下文工程、工具系统、评测、可观测——正是招聘市场上被明码标价、且供给稀缺的能力组合。** 手册里[什么是 Agent Harness](/guide/what-is-harness) 提出的"harness 决定 agent 能力上限"，在招聘市场上有一个对应的版本：harness 工程能力决定工程师的市场价格。

## 附带发现：模型侧与工程侧已经分层

44 份 JD 还暴露了招聘市场的一次清晰分层——**模型侧岗位与工程侧岗位已经分成两条职业轨道**：

- **模型侧**：后训练、RL、agentic 数据与评测 benchmark。国内集中在腾讯混元（Agent Infra 的沙盒/RL 平台）、百度（SFT/RLHF）、蚂蚁（Agent 后训练）、快手（RL 端到端训练 agentic reasoning model）、DeepSeek；国外集中在 OpenAI Research Engineer、Cognition Post-Training、Amazon Applied Scientist。普遍要求硕士/博士、论文或大规模训练经验。
- **工程侧**：Harness/Infra/应用落地。国内集中在字节、美团、小红书、腾讯 CSIG/WXG；国外集中在 Anthropic、Microsoft、Cognition、Notion 的交付与平台岗。要的是扎实工程功底 + harness 知识，学历门槛友好得多。

这条分层对读者的实际意义是：**harness 是那条不靠 PhD 也能走通的轨道。** 国内工程侧岗位的典型门槛是本科 + 2–5 年经验，国外 Cursor 甚至不设学历年限硬门槛——决定竞争力的是"构建过复杂 agentic products 或基础设施"这类可验证的工程证据。这也是为什么本模块的[简历分析](/career/resume-analysis)会把"可展示的项目证据"作为核对的重点。

## 本模块怎么读

三篇文章分别回答三个问题，按顺序读或按需取用均可：

| 文章 | 回答的问题 | 适合谁 |
| --- | --- | --- |
| [JD 清单](/career/jd-list) | **都有谁在招、招什么、给多少？** 44 个岗位的完整清单：公司、岗位、职责、硬性要求、薪资、来源链接与可信度标注 | 正在找工作、想直接投简历的人 |
| [技能图谱](/career/knowledge-map) | **这些岗位到底要求什么能力？** 把 44 份 JD 的词频与要求聚合成一张 harness 知识点需求地图，与手册组件章节一一对应 | 想规划学习路径、查缺补漏的人 |
| [简历分析](/career/resume-analysis) | **我的简历离这些岗位有多远？** 以真实 JD 要求为标尺，逐条核对简历的匹配度与缺口，给出修改方向 | 准备投递前做最后打磨的人 |

一个推荐的用法：先在[技能图谱](/career/knowledge-map)里看清楚需求全景，回到手册的[核心组件](/guide/anatomy)章节补齐知识，用[动手搭建一个 Harness](/practice/build-your-own)产出可写进简历的项目证据，最后对照 [JD 清单](/career/jd-list)选目标、用[简历分析](/career/resume-analysis)做校准。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——招聘市场上这个 title 指的那套东西的精确定义
- [Harness 的解剖](/guide/anatomy)——JD 里高频出现的运行时、工具、上下文、评测各自对应哪个组件
- [可观测性](/components/observability)——国内外 harness 岗职责重合度最高的方向之一
- [Claude Code 案例](/case-studies/claude-code) 与 [Cursor 案例](/case-studies/cursor)——两家正在招 harness 工程师的公司，其产品 harness 的完整拆解
- [动手搭建一个 Harness](/practice/build-your-own)——把 JD 要求变成简历上的项目证据
- [常见陷阱](/practice/pitfalls)——面试中被追问 harness 设计时最容易暴露的盲区
- [术语表](/resources/glossary)——JD 里的 FDE、evals、agentic 等术语速查
