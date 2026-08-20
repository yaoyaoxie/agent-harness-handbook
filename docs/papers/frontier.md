---
title: 前沿进展
dataAsOf: 2026-08
description: 梳理 2025–2026 年 Agent Harness 研究的七条前沿主线：长时程执行、上下文工程、记忆基础设施、多智能体协作、自我改进 agent、训练内生化与评测纪律，逐篇标注问题、方法与对 harness 设计的启示。
---

# 前沿进展

[经典论文](/papers/core-papers)讲的是 2022–2024 年：harness 的组件被逐个发明——循环、工具、记忆、规划、接口。2025 年之后，研究问题换了一个方向：**组件都在了，但它们能在几小时、几天的任务里可靠地协同工作吗？** 失败分析取代了能力演示，上下文从提示技巧升格为系统学科，harness 本身甚至成了被优化和被比较的对象。

本页按主题梳理七条主线，每条给出代表性工作（问题、方法一句话、与 harness 设计的关系）和本站的独立判断。所有 arXiv 编号与发布日期均已核实。

```text
2025.02  A-MEM ──────────────── 记忆结构化：笔记 + 链接 + 演化
2025.03  METR 长任务测量 ────── "能撑多久"取代"答得多对"成为度量衡
2025.03  MAST ───────────────── 多智能体失败模式分类学（冷水第一盆）
2025.04  SICA ───────────────── agent 开始改自己的代码
2025.05  多轮迷失 ───────────── 多轮对话平均掉分 39%
2025.05  DGM ────────────────── 开放式进化：SWE-bench 20% → 50%
2025.06  Anthropic 多智能体系统 ─ 工业界承认多 agent 的成本与边界
2025.07  Context Rot / Manus ── 上下文工程成为显学
2025.09  递减回报的错觉 ──────── 长程执行的失败在执行，不在推理
2025.10  ACE ────────────────── 上下文即 playbook，自我进化
2025.12  RLM / Confucius CCA ── 上下文即环境；scaffold 价值被量化
2026.05  Harness 披露檄文 ───── 不披露 harness 的分数不可比较
2026.08  Agent Lightning / LEGO-RL ── 训练住进了骨架（Harness-Native RL）
```

## 长时程 Agent：从"答得对"到"撑得久"

这一组工作共同把 agent 能力的度量衡从"单题成功率"换成了"时间跨度"，并解释了长任务为什么难。

**METR 的长任务测量**（*Measuring AI Ability to Complete Long Tasks*，arXiv:2503.14499，2025 年 3 月）。问题：模型的 agent 能力到底怎么度量？方法：不看分数，看"50% 任务完成时间跨度"——模型能以 50% 可靠性独立完成的人类任务时长。他们发现这个时长从 2019 年起**大约每 7 个月翻一倍**，2025 年初的前沿模型约在 1 小时量级。对 harness 的意义：这是一个 harness-sensitive 指标——同一模型在不同的上下文管理、错误恢复设计下，"能撑住的任务时长"完全不同，时间跨度是比单步准确率更诚实的 harness 试金石。

**《递减回报的错觉》**（*The Illusion of Diminishing Returns*，arXiv:2509.09677，2025 年 9 月）。问题：短任务基准上的提升趋缓，是否意味着 scaling 到头了？方法：把"执行任务"与"推理任务"分离——直接给模型提供解题所需的知识和计划，只测它执行长指令序列的能力。三个发现对 harness 设计至关重要：

- 单步准确率的微小提升会**复合**成可完成任务长度的指数级增长——短基准上的"边际收益递减"是测量错觉；
- 长程失败主要来自**执行错误**而非推理能力不足；
- 存在 **self-conditioning 效应**：上下文里出现自己前几轮的错误，会显著提高后续出错的概率，且单纯扩大模型规模不能消除它，但 thinking（长链推理）能显著缓解。

```text
单步可靠性的复合效应（为什么 1% 的进步很大）

   单步成功率 95%    × 连续 100 步 ≈ 0.6% 整体成功率
   单步成功率 99.9%  × 连续 1000 步 ≈ 36.8% 整体成功率

   → 长任务下，harness 的每一次错误拦截、每一次轨迹清理
     都在指数曲线上做功
```

::: info self-conditioning 对上下文工程的直接推论
如果"上下文里留有模型自己的错误"本身就有毒，那么 harness 在压缩、重写、总结轨迹时就不该忠实地保留失败尝试的全过程——[上下文工程](/components/context-engineering)中的轨迹清理（如折叠冗余错误输出、用结构化摘要替换原始报错）获得了来自测量研究的理论支持。
:::

**Vending-Bench**（arXiv:2502.15840，2025 年 2 月）则从反面刻画了长时程的失效形态：让模型长期经营一台虚拟自动售货机，测的是**长期连贯性**。即使最强的模型也会在长时间运行后陷入"妄想螺旋"——坚持某个错误信念（比如以为货没送到）并围绕它做出一连串越来越荒唐的决策。Anthropic 后来真的让 Claude 经营了一台实体售货机（[Project Vend](https://www.anthropic.com/research/project-vend-1)，2025 年 6 月），观察到了同类的长程失稳。对 harness 的意义很直白：**长任务需要外置的校验与状态回写机制**，指望模型在几百轮之后仍然"自己想明白"是不可靠的。

把三篇合起来，长时程研究给 harness 设计开出的处方是一致的：[agent 循环](/components/agent-loop)里要有停止与预算控制，上下文里要持续清理"有毒"的错误轨迹，关键状态要外化到模型无法篡改的地方，长任务的风险操作要过[权限闸口](/components/permissions)。没有一条是靠"等更强的模型"解决的。

## 上下文工程成为一门学科

2025 年最重要的概念变化，是 "context engineering" 从少数人的口头禅变成了行业术语。两篇工业界长文定义了它：Manus 团队的[《Context Engineering for AI Agents: Lessons from Building Manus》](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)（2025 年 7 月）和 Anthropic 的[《Effective Context Engineering for AI Agents》](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)（2025 年 9 月）。前者贡献了今天被广泛引用的工程手段：保持 KV-cache 前缀稳定、用 todo.md 的反复重写把目标"背诵"进近期注意力（recitation）、把文件系统当作无限大的外部上下文；后者系统化了"最小充分上下文"的原则。详见[上下文工程](/components/context-engineering)。

学术界同期提供了两条关键证据。

**Context Rot**（Chroma Research 技术报告，2025 年 7 月，[research.trychroma.com/context-rot](https://research.trychroma.com/context-rot)）。问题：上下文窗口越来越大，性能真的跟着涨吗？方法：对 18 个主流模型做受控测量，改变输入长度而控制任务难度。结论：**随着输入 token 增加，模型性能单调下降**，即使任务本身不变难——"100 万 token 窗口"的宣传数字与"有效上下文"之间存在系统性差距。对 harness 的意义：往上下文里多塞东西不是免费的，策展（curation）是 harness 不可推卸的职责。

**《LLMs Get Lost in Multi-Turn Conversation》**（arXiv:2505.06120，Microsoft Research / Salesforce，2025 年 5 月）。问题：模型在多轮对话里的表现和单轮一样好吗？方法：20 万次以上的模拟对话，对比单轮全信息与多轮逐步披露。结论：所有受测模型在多轮设定下**平均掉分 39%**，且分解显示主要是**可靠性崩塌**（方差变大）而非能力下降——模型在早期轮次草率假设、过早锁定答案，之后拒不回头。对 harness 的意义：长会话 agent 必须把中间结论显式固化（文件、清单、计划工件），因为模型的"隐性记忆"在多轮里是系统性不可靠的——这正是[规划](/components/planning)中"外化状态"主张的测量学证据。

**Recursive Language Models**（arXiv:2512.24601，MIT CSAIL，2025 年 12 月）给出了一个激进的解法。问题：超长输入注定压垮上下文窗口。方法：**不把长 prompt 喂给 transformer**，而是把它放进一个 REPL 环境作为变量，让模型写代码探查、切片，并对自己发起递归子调用。论文报告 RLM 能处理超出窗口两个数量级的输入，在四个长上下文任务上以可比成本显著优于压缩基线和常见 coding scaffold。对 harness 的意义：这是把[子代理](/components/subagents)思想推进到极致的形态——**上下文管理即环境设计**，长输入从"要消化的内容"变成了"要探索的环境"。

## 记忆：从记忆流到记忆基础设施

2023 年的记忆论文（[Generative Agents、MemGPT](/papers/core-papers)）发明了机制；2025 年的记忆论文把机制做成了**带治理、可检索、可演化**的子系统。三篇代表三条路线：

| 系统 | 核心机制一句话 | 记忆如何组织 | 对 harness 的意义 |
| --- | --- | --- | --- |
| A-MEM（[arXiv:2502.12110](https://arxiv.org/abs/2502.12110)） | 借鉴 Zettelkasten 卡片盒：每条记忆生成结构化笔记（关键词、标签、上下文描述），并自动建立语义链接、让旧记忆随新经验演化 | 动态演化的笔记网络 | 记忆条目之间要有**关系**，检索时才能带出上下文 |
| Mem0（[arXiv:2504.19413](https://arxiv.org/abs/2504.19413)） | 从对话中抽取、更新、删除候选事实，以向量检索为主的生产级记忆层 | 扁平事实库 + 图扩展（Mem0ᵍ） | 论文报告在 LOCOMO 基准上以**更低的延迟和 token 成本**优于全上下文方案——记忆不是功能，是成本结构 |
| MemOS（[arXiv:2505.22101](https://arxiv.org/abs/2505.22101)） | 把记忆当作操作系统管理的资源：MemCube 统一封装参数式、激活式、明文式三类记忆，带元数据与治理属性（生命周期、权限、审计） | 记忆立方体 + 调度框架 | 记忆需要**治理**：过期、权限、来源追溯都是 harness 职责 |

::: tip 一条共同主线
三篇论文的分歧在组织形式，共识在另一点：**记忆的写入端需要判据**——什么值得存、何时该更新或删除。这与 [Toolformer 的"有用才保留"过滤器](/papers/core-papers)一脉相承：没有写入判据的记忆库，越检索越误导。实现细节见[记忆系统](/components/memory)。
:::

## 多智能体：热潮与冷水

2025 年的多智能体研究有一个罕见的特点：最有影响力的两篇文献，一篇是工业界的"经验谈"，一篇是学术界的"失败学"。

**Anthropic 的多智能体研究系统**（[How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)，2025 年 6 月）。这是 Claude Research 功能的工程复盘：orchestrator-worker 结构，主 agent 分解任务、派生子 agent 并行检索，再汇总。博客最有价值的部分是诚实的边界声明：据其披露，agent 的 token 消耗约为普通对话的 4 倍，多智能体系统约为 15 倍——**多 agent 只在任务价值高、可并行分解、子任务间信息需求不重叠时才划算**。

**MAST：多智能体失败模式分类学**（*Why Do Multi-Agent LLM Systems Fail?*，arXiv:2503.13657，2025 年 3 月）。问题：多智能体系统到底为什么失败？方法：对 7 个主流多智能体框架、200 余条带标注轨迹做失败归因，提炼出 **14 种失败模式、3 大类别**（规范与系统设计缺陷、agent 间对齐失效、任务验证与终止问题）。一个贯穿性发现是**验证环节的薄弱**——结果没人检查就传递下去，错误沿链路放大。

把两篇放在一起读，本站的判断是：**多 agent 架构目前更像一种昂贵的并行化手段，而非智能的乘法器。** 它能买到的是吞吐（并行检索、并行探索），买不到的是可靠性（协调与验证成本反而上升）。工程默认值仍然是"单 agent + 好 harness + 受限的子任务委派"，这正是 Claude Code 的 [subagent](/components/subagents) 设计所走的路线——子代理用于隔离上下文和并行探索，不用于模拟"团队"。

## 自我改进：harness 成为优化对象

2023 年的 Reflexion 让 agent 用反思改进行为；2025 年的 self-improving agent 则直接改进 **agent 自身的代码与上下文**——harness 从"人写的固定结构"变成了"被优化的变量"。

**SICA**（*A Self-Improving Coding Agent*，arXiv:2504.15228，2025 年 4 月）。问题：agent 能不能不靠人改提示词和工具，自己改进自己？方法：取消"元 agent 改目标 agent"的分层，让 agent 直接编辑自己的代码库，并用编辑历史形成改进记忆。它是最早的完整闭环演示之一。

**Darwin Gödel Machine**（arXiv:2505.22954，2025 年 5 月，Sakana AI 等）。问题：自我改进能不能不是局部修补，而是开放式演化？方法：维护一个 agent 档案库，每次从库中采样一个版本、让基础模型产出有趣的变体、用 coding benchmark 实证验证后入库——达尔文式开放探索。结果引人注目：**SWE-bench 从 20.0% 提升到 50.0%，Polyglot 从 14.2% 到 30.7%**，且自动演化出的改进恰恰是 harness 层面的——更好的代码编辑工具、长上下文窗口管理、同行评审机制。值得注意的是 DGM 全程在沙箱与人工监督下运行。

**ACE**（*Agentic Context Engineering*，arXiv:2510.04618，Stanford / SambaNova 等，2025 年 10 月）则指明了另一条不动代码的路线。问题：不改权重、不改架构，能不能让系统通过进化**上下文本身**来自我改进？方法：把系统提示当作不断演化的 playbook，由 generator–reflector–curator 三个角色持续增删条目，刻意对抗简洁偏置（brevity bias）和上下文坍缩（context collapse）。论文报告在 AppWorld agent 任务和金融分析任务上，相对强基线平均提升约 10.6% 和 8.6%——**不碰权重，全靠上下文迭代**。

::: warning 自我改进的验证闭环必须外置
这三篇工作的共同前提，与 [Reflexion](/papers/core-papers) 的教训一致：改进是否成立，由**外部 benchmark / 环境信号**裁决，不由模型自我感觉裁决。DGM 用 SWE-bench 入库，ACE 用任务反馈蒸馏条目。没有可靠验证器的"自我改进"，只是在给幻觉做加法——这是[常见陷阱](/practice/pitfalls)里反复出现的形态。想建立全景可读自进化 agent 综述（[arXiv:2507.21046](https://arxiv.org/abs/2507.21046)，2025 年 7 月）。
:::

对 harness 工程的推论是深远的：**harness 的代码、提示词、工具描述都是可被自动搜索优化的对象**——手写 harness 的先验优势正在消失，但"评估改进是否真实"的设施（可靠的本地 benchmark、轨迹审计）变成了新的护城河，见[可观测性](/components/observability)。

## 训练住进了骨架：Harness-Native RL

2026 年 8 月中旬，arXiv 上密集出现一簇论文，把 harness 从「推理时的外壳」变成「训练时的环境」——模型不再只是被 harness 围着跑，而是在 harness 里被训练。三天内至少三篇：

**Agent Lightning v1.0**（*Towards Harnessed Agentic RL*，arXiv:2608.17528，2026 年 8 月 18 日）。问题：给 agent 做 RL 通常要求把 agent 代码围着训练框架改写，harness 一换就得重来。方法：解耦架构——用一个 LLM 端点代理把**任意** agent 接进 RL 训练回路，agent 代码不用动。论文称其初代方案已被 verl Uni-Agent、AReaL 2.0、slime、Polar 等训练框架采用。

**LEGO-RL**（*Harness-Native Reinforcement Learning for Coding Agents*，arXiv:2608.17393，同日）。问题：coding agent 的 RL 越来越依赖长时间运行的真实 harness，但 harness 的原生执行环境与策略梯度训练天然错位——环境崩溃和 reward hacking 会污染结果信号，训推不一致又让 rollout 失真。方法：把训练直接做成 harness-native 的，在真实 harness 里对齐训练与推理。

**ClawGym II**（arXiv:2608.16798，8 月 17 日）走了第三条路：不改 harness、不看内部状态，把整套骨架当**黑盒环境**做 RL，专攻长时程任务上"穿过复杂 harness 训练难以扩展"的问题。

::: info 独立判断
5 月的[披露檄文](https://arxiv.org/abs/2605.23950)证明了「同一模型换 harness 分数不同」，8 月这一簇论文是顺理成章的下一步：**既然 harness 决定表现，那就让模型在最真实的 harness 里学习**。对从业者的含义很直接——你写的 harness 不再只是部署资产，它开始参与决定模型能学成什么样；harness 的稳定性（崩溃率、信号干净程度）从工程指标变成了训练指标。
:::

同一周还有三篇值得扫一眼：**Demystifying Agent Skills**（arXiv:2608.14036，8 月 14 日）用受控实验回答「skills 什么时候有用、为什么有用、在哪失效」，正好给本站 [Skills](/components/skills) 一页提供实证对照；**AgentRewind**（arXiv:2608.14380，8 月 14 日）处理长时程执行的可恢复性——早期错误会同时污染上下文和环境状态，靠后续动作往往救不回来，需要可回滚的执行；**HarnessRisk**（arXiv:2608.17597，8 月 18 日）则是第一个按 harness 职责（工具、扩展、持久状态、权限、外部动作）组织的全生命周期安全基准，把[权限与安全](/components/permissions)从最佳实践推向了可测量。

## 评测：从分数到纪律

2025 年后的评测研究有两条平行线：更难的新基准，和对"分数本身可信度"的系统性拷问。

**新基准补上了老基准的盲区：**

| 基准 | 年份 | 测什么 | 关键发现 / 特点 |
| --- | --- | --- | --- |
| [τ²-bench](https://arxiv.org/abs/2506.07982)（arXiv:2506.07982） | 2025 | **双重控制**：用户和 agent 都能操作共享环境（客服场景） | agent 在用户也会行动时表现显著退化；多次试跑的通过率一致性（pass^k）很低 |
| [BrowseComp](https://arxiv.org/abs/2504.12516)（arXiv:2504.12516） | 2025 | 需要持久多跳浏览才能找到的答案，1266 道难题 | 普通模型几乎全军覆没，催生了 deep research 类 agent 的军备竞赛 |
| [Terminal-Bench](https://github.com/laude-institute/terminal-bench) | 2025 | 真实终端环境中的任务（编译、配置、运维） | 把评测推进到 coding agent 的主战场——命令行 |

**评测纪律成为独立议题。** Princeton 的 [HAL（Holistic Agent Leaderboard）](https://github.com/princeton-pli/hal-harness)（2025 年）把评测基础设施化：用统一 harness 跑多个基准、公开完整轨迹、披露成本，让任何人审计"这个分数是怎么跑出来的"。[Confucius Code Agent](/guide/what-is-harness)（arXiv:2512.10398，2025 年 12 月）用同模型跨 scaffold 的对照实验量化了 harness 的贡献；2026 年 5 月的《[Stop Comparing LLM Agents Without Disclosing the Harness](https://arxiv.org/abs/2605.23950)》（arXiv:2605.23950）把话说绝：在标准化 scaffold 下重测后，**不披露 harness 的 agent 分数不可比较**。

::: info 本站的阅读建议
读 2025 年后的任何 agent 论文或榜单，先做三次检查：harness 披露了吗？报告的是单次还是 pass^k？失败案例分析了吗？三个里缺两个，数字就只能当广告看。这条纪律同样适用于你自己搭 harness 时的自测，见[设计原则](/practice/design-principles)。
:::

## 七条主线合起来看

- **长时程**告诉我们瓶颈在执行可靠性与错误复合，不在单步聪明；
- **上下文工程**与**记忆**回答"信息怎么进、怎么留"；
- **多智能体**的冷水提醒我们：并行化收益必须跑赢协调成本；
- **自我改进**把 harness 变成优化对象，同时抬高了验证设施的地位；
- **训练内生化**更进一步：harness 从部署外壳变成训练环境，骨架的工程质量开始直接塑造模型能力；
- **评测纪律**则给以上全部主张提供了判据。

一个贯穿性的观察：2022–2024 年的论文问"模型能做什么"，2025–2026 年的论文问"**系统在多长时间尺度上、以什么成本、可被验证地做什么**"。研究重心从能力秀变成了工程问责——这本身就是 harness 视角的胜利。

## 延伸阅读

- [经典论文精读](/papers/core-papers)——本页所有工作的前身：ReAct、Reflexion、MemGPT、SWE-agent
- [论文地图](/papers/map)——按主题组织的完整学术地图
- [什么是 Agent Harness](/guide/what-is-harness)——Confucius CCA 与 harness 披露檄文的详细解读
- [上下文工程](/components/context-engineering)——Context Rot、recitation、压缩的工程化展开
- [记忆系统](/components/memory)——A-MEM / Mem0 / MemOS 思想的产品形态
- [子代理](/components/subagents)——多 agent 热潮下的工程默认值
- [规划](/components/planning)——外化状态对抗多轮迷失的机制分析
- [Skills](/components/skills)——自我改进 agent 的技能沉淀在产品中的对应物
- [可观测性](/components/observability)——自我改进时代的验证与审计基础设施
- [常见陷阱](/practice/pitfalls)——前沿论文反复印证的工程教训

## 参考资料

- [Measuring AI Ability to Complete Long Tasks (arXiv:2503.14499)](https://arxiv.org/abs/2503.14499)
- [The Illusion of Diminishing Returns: Measuring Long Horizon Execution in LLMs (arXiv:2509.09677)](https://arxiv.org/abs/2509.09677)
- [Vending-Bench: A Benchmark for Long-Term Coherence of Autonomous Agents (arXiv:2502.15840)](https://arxiv.org/abs/2502.15840)
- [Anthropic: Project Vend（Claude 经营实体售货机）](https://www.anthropic.com/research/project-vend-1)
- [Manus 博客：Context Engineering for AI Agents: Lessons from Building Manus](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [Anthropic 工程博客：Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Chroma Research 技术报告：Context Rot](https://research.trychroma.com/context-rot)
- [LLMs Get Lost in Multi-Turn Conversation (arXiv:2505.06120)](https://arxiv.org/abs/2505.06120)
- [Recursive Language Models (arXiv:2512.24601)](https://arxiv.org/abs/2512.24601)
- [A-MEM: Agentic Memory for LLM Agents (arXiv:2502.12110)](https://arxiv.org/abs/2502.12110)
- [Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory (arXiv:2504.19413)](https://arxiv.org/abs/2504.19413)
- [MemOS: An Operating System for Memory-Augmented Generation (arXiv:2505.22101)](https://arxiv.org/abs/2505.22101)
- [Anthropic 工程博客：How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [Why Do Multi-Agent LLM Systems Fail? (MAST, arXiv:2503.13657)](https://arxiv.org/abs/2503.13657)
- [A Self-Improving Coding Agent (SICA, arXiv:2504.15228)](https://arxiv.org/abs/2504.15228)
- [Darwin Gödel Machine (arXiv:2505.22954)](https://arxiv.org/abs/2505.22954)
- [Agentic Context Engineering (ACE, arXiv:2510.04618)](https://arxiv.org/abs/2510.04618)
- [A Survey of Self-Evolving Agents (arXiv:2507.21046)](https://arxiv.org/abs/2507.21046)
- [τ²-bench: Evaluating Conversational Agents in a Dual-Control Environment (arXiv:2506.07982)](https://arxiv.org/abs/2506.07982)
- [BrowseComp: A Simple Yet Challenging Benchmark for Browsing Agents (arXiv:2504.12516)](https://arxiv.org/abs/2504.12516)
- [Terminal-Bench（Laude Institute）](https://github.com/laude-institute/terminal-bench)
- [HAL: Holistic Agent Leaderboard（Princeton）](https://github.com/princeton-pli/hal-harness)
- [Confucius Code Agent (arXiv:2512.10398)](https://arxiv.org/abs/2512.10398)
- [Stop Comparing LLM Agents Without Disclosing the Harness (arXiv:2605.23950)](https://arxiv.org/abs/2605.23950)
- [Agent Lightning v1.0: Towards Harnessed Agentic RL (arXiv:2608.17528)](https://arxiv.org/abs/2608.17528)
- [LEGO-RL: Harness-Native Reinforcement Learning for Coding Agents (arXiv:2608.17393)](https://arxiv.org/abs/2608.17393)
- [ClawGym II: Exploring Black-Box RL on Agent Harness (arXiv:2608.16798)](https://arxiv.org/abs/2608.16798)
- [Demystifying Agent Skills: Why They Work—Until They Don't (arXiv:2608.14036)](https://arxiv.org/abs/2608.14036)
- [AgentRewind: Recoverable Execution for Long-Horizon LLM Agents (arXiv:2608.14380)](https://arxiv.org/abs/2608.14380)
- [HarnessRisk: A Lifecycle-Oriented Benchmark for Agent Harness Safety (arXiv:2608.17597)](https://arxiv.org/abs/2608.17597)
