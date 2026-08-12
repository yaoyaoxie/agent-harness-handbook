---
title: Devin 案例
description: 剖析"全自主软件工程师"Devin 的 harness：shell/浏览器/编辑器/规划器组合的长时程架构、2024 年发布时的演示与打假争议、Cognition 工程博客中关于 context engineering 与模型选型的一手经验，以及"自主性 vs 可控性"这条产品化光谱上最激进的一次押注。
---

# Devin 案例

2024 年 3 月 12 日，Cognition 发布 Devin，用的标题不是"又一个 AI 编程助手"，而是"第一位 AI 软件工程师"（the first AI software engineer）。这个叙事选择本身就是一次 harness 立场的宣示：Devin 不把自己定位成"辅助人写代码的工具"，而是"接收任务、独立完成、交付成果的同事"——人和它的关系是派活与验收，不是结对与补全。

在所有 coding agent 案例里，Devin 是把**自主性推到最极端**的那个。它也因此成了最好的研究样本：它的演示为何 viral、为何被打假，它的团队后来在工程博客里公开了哪些 harness 经验，它的产品形态如何在"全自主"和"可控制"之间找平衡——这三件事合起来，恰好标定了长时程 agent 设计的边界。

## 时间线速览

- **2024 年 3 月**：发布博客与系列演示视频（[Introducing Devin](https://cognition.ai/blog/introducing-devin)），宣称在 SWE-bench 上以无辅助方式端到端解决 13.86% 的 issue，远超此前 1.96% 的最佳成绩；附带"Devin 在 Upwork 上接了真实自由职业订单"的演示。公司同时披露 2100 万美元 A 轮融资（Founders Fund 领投）。
- **2024 年 4 月**：YouTube 频道 Internet of Bugs 发布逐帧打假视频，演示争议爆发（详见下文）。
- **2024 年 12 月 10 日**：Devin 正式 GA（[官方公告](https://www.cognition.ai/blog/devin-generally-available)）：500 美元/月起、含 250 个 ACU（Agent Compute Unit）、不限席位，入口覆盖 Slack、IDE 插件与 API。
- **2025 年 4 月**：Devin 2.0 发布，推出 20 美元起步的按量付费档（[TechCrunch 报道](https://techcrunch.com/2025/04/03/devin-the-viral-coding-ai-agent-gets-a-new-pay-as-you-go-plan/)），从"昂贵的实验品"转向大众化定价。
- **2025 年 7 月**：在 OpenAI 收购 Windsurf 告吹、Google 挖走其 CEO 与研究负责人之后，Cognition 出手收购 Windsurf 剩余实体（[TechCrunch 报道](https://techcrunch.com/2025/07/14/cognition-maker-of-the-ai-coding-agent-devin-acquires-windsurf/)），并在此后延续 SWE 系列自有模型线（如 [SWE-1.5](https://cognition.ai/blog/swe-1-5)）。
- **2025–2026 年**：Cognition 工程博客进入高产期，公开的 harness 经验（下文的 context engineering 与模型路由）成为行业一手资料。

## Harness 架构：给 agent 一整台电脑

Devin 发布博客中对系统本身的描述只有几句话，但每一句都是 harness 决策：

> "We've equipped Devin with common developer tools including the shell, code editor, and browser within a sandboxed compute environment—everything a human would need to do their work."

拆开看，这套架构的本质是：**不给模型一个对话框，而是给它一台电脑**。四个关键组件：

- **Shell**：装依赖、跑测试、执行任意命令——环境交互的万能接口；
- **代码编辑器**：结构化地读写代码，而不是在聊天里吐 diff；
- **浏览器**：读文档、查资料、验证自己部署的页面——把"学习不熟悉的技术"变成运行时能力而非训练时记忆；
- **规划器（Planner）**：发布博客称之为"long-term reasoning and planning"，支撑"需要数千个决策的复杂工程任务"，并能在每一步"召回相关上下文、随时间学习、修正错误"。

```text
┌─────────────── Devin 云端沙箱（每个任务一台隔离 VM）───────────────┐
│                                                                  │
│   ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐     │
│   │  Shell  │  │ 代码编辑器 │  │  浏览器   │  │    Planner    │     │
│   │ 装依赖/  │  │ 读写代码  │  │ 读文档/   │  │ 长时程规划/    │     │
│   │ 跑测试   │  │          │  │ 验证页面  │  │ 进度与上下文   │     │
│   └────┬────┘  └────┬─────┘  └────┬─────┘  └───────┬───────┘     │
│        └────────────┴──────┬──────┴────────────────┘             │
│                            ▼                                     │
│                     ┌────────────┐                               │
│                     │    LLM     │  ← 模型只是这台"电脑"的操作员    │
│                     └────────────┘                               │
└───────────────────────────────┬──────────────────────────────────┘
                                │ 交付物：PR / 部署结果 / 报告
        入口：Slack / Web / IDE / API ──► 用户角色：派活 + 验收
```

这个设计与 [OpenHands](/case-studies/openhands) 的架构几乎同构——并不奇怪，OpenHands 的前身 OpenDevin 就是社区对 Devin 的开源复刻。两者的共识是：**长时程软件任务的工具集必须覆盖人类工程师的完整工作面**，只在聊天框里生成代码的 agent 走不远。区别在于 OpenHands 把这套架构做成了可自托管、可审计的开源平台，而 Devin 把沙箱、调度、入口全部闭源产品化。

与 [Claude Code](/case-studies/claude-code) 的对比更能说明 Devin 的取向：Claude Code 住在你的本地终端里，同步、在场、随时可打断，是"结对"模型；Devin 住在云端 VM 里，异步、远程、以 PR 交付，是"外包同事"模型。同样的 shell+editor+browser 组合，因为**部署位置和人机接口不同**，长成了两种完全不同的产品。

## 2024：演示、viral 与打假

Devin 的发布是 agent 史上传播最成功的产品首秀之一，也是教训最深刻的一次。

### 演示讲了什么故事

发布博客给了七组演示：读博客学会用 ControlNet 生成带隐藏信息的图片、从零构建并部署生命游戏网站到 Netlify、在开源代码库里自主定位并修复 bug、只给一个 GitHub 仓库链接就完成 LLM 微调环境搭建、解决 SWE-bench 中 sympy 的真实 issue——以及最有爆炸力的一条：**"我们甚至让 Devin 在 Upwork 上接了真实的工作，它也完成了"**。

### 打假：逐帧分析揭出的三个问题

2024 年 4 月，有三十余年经验的工程师 Carl Brown 在其 YouTube 频道 Internet of Bugs 发布视频 [《Debunking Devin: "First AI Software Engineer" Upwork lie exposed!》](https://www.youtube.com/watch?v=tNmgmwEtoWE)，对 Upwork 演示做了约半小时的逐帧复核，发现：

1. **任务被调包。** 原始 Upwork 订单要的是"写出如何让这个模型跑起来的部署说明"，而演示中 Devin 只拿到了订单描述的第一句话，实际完成的是一个不同的、更讨喜的编程任务。
2. **修的是自己造的 bug。** 演示中最精彩的"发现并修复代码库错误"桥段，被修复的文件在原仓库里根本不存在——那是 Devin 自己在过程中创建的文件。它展示的 debug 能力，有一部分是在给自己擦屁股。
3. **效率叙事不成立。** 视频核算后指出，人类工程师完成同样工作所需时间远短于 Devin 的实际耗时。

这段分析随后在 Hacker News 和 Reddit 上被广泛传播（如 [TLDR 的摘要](https://tldr.tech/dev/2024-04-15)），Cognition 未做实质性的逐点反驳。

### 基准数字的脚注

SWE-bench 的 13.86% 同样需要读脚注：发布博客自己注明，评测是在**随机抽取的 25% 子集**上进行的，且 Devin 是 unassisted 而对比系统是 assisted（被告知要改哪些文件）。数字本身未必造假，但"远超此前最佳 7 倍"的传播版本丢掉了全部限定条件。

::: warning 这场争议对 harness 研究者的真正价值
打假的杀伤力不来自"Devin 很弱"，而来自**外部观察者无法核查 harness 内部发生了什么**。闭源 harness + 精选演示 + 带脚注的基准数字，这个组合在当时是行业常态。两年后再看，评测社区已经用"不披露 harness 就别比较分数"的共识回应了这个问题（见[模型 vs Harness](/guide/model-vs-harness)）。Devin 争议是这个共识形成过程中最有名的一块铺路石。
:::

## Cognition 工程博客：harness 一手资料

Devin 团队真正对行业产生持久影响的，不是演示视频，而是 2025 年之后陆续公开的工程博客。这些文章罕见地把一家头部 agent 公司的 harness 设计决策写了出来。

### "Don't Build Multi-Agents"：context engineering 的两条原则

2025 年 6 月 12 日，Cognition 的 Walden Yan 发表 [Don't Build Multi-Agents](https://cognition.ai/blog/dont-build-multi-agents)——时间点值得玩味：Anthropic 那篇著名的多智能体研究系统博客发表于 6 月 13 日，两家头部 agent 公司几乎同时公开了相反立场。

文章开宗明义：长时程 agent 的可靠性问题，本质是 **context engineering** 问题——"这实际上是构建 AI agent 的工程师的第一要务"。由此提出两条原则：

**原则一：共享上下文，且共享完整的 agent 轨迹，而不是单条消息。** 经典的"主 agent 拆任务 → 子 agent 并行执行 → 汇总"架构之所以脆弱，是因为子任务描述在传递中必然丢失原始上下文。文章用了一个著名例子：让系统克隆 Flappy Bird，子 agent 1 理解的"游戏背景"做成了超级马里奥风格，子 agent 2 做的鸟完全不像游戏素材——每个环节都"合理"，拼起来全是误解。

**原则二：动作携带隐式决策，冲突的决策带来糟糕的结果。** 即使把完整任务复制给每个子 agent，它们各自的动作仍然基于互不知晓的假设：子 agent 1 和子 agent 2 做的鸟和背景视觉风格完全不搭，因为彼此看不见对方在做什么。

文章的结论相当激进：**默认排除一切违反这两条原则的架构**，首选方案是单线程线性 agent（上下文天然连续）；任务大到撑爆上下文窗口时，用专门训练的压缩模型把历史蒸馏成关键决策与事件，而不是把任务切给多个上下文互不相通的 agent。

::: info 这条原则在站内框架中的位置
Yan 说的"共享完整轨迹而非单条消息"，正是[子 Agent](/components/subagents) 设计中"返回什么给主 agent"这一核心决策的极端立场版本；而他对压缩模型的强调，属于[上下文工程](/components/context-engineering)里压缩策略的工程化路线。这篇文章的价值在于：它不是学术推演，而是 Devin 这种长时程产品踩过坑之后的总结。
:::

值得强调的是标题的误导性：Cognition 反对的不是"多个执行体"，而是**上下文被切碎的多 agent 架构**。证据是他们一年后自己就发布了一个"双 agent"系统——

### Devin Fusion：模型选型与多模型 harness

2026 年 6 月 29 日的 [Devin Fusion](https://cognition.com/blog/devin-fusion) 是 harness 工程文献里关于**模型路由（model routing）**最坦诚的一篇。问题设定很务实：不能所有任务都用最贵的模型，但现有的模型路由方案"在基准上好看，写出的代码你不会合并"。

Fusion 的解法是两个技术：

**Sidekick（副驾）模式。** 跑两个并行 agent：主 agent 用前沿模型，sidekick 用便宜模型，两者都是带完整工具集的独立 agent，各自维护**持久、可缓存的上下文**。关键交互纪律是：主 agent 应尽量少动手，只做真正重要的决策——定计划、解释歧义、终审把关——默认委派与监控。文章特意对比了"让一个模型用工具去咨询另一个模型"的方案（Cognition 自己试过的 "Smart Friend" 和 Anthropic 的 "Advisor" 工具）：那种做法每次咨询都会破坏 KV cache，代价昂贵；sidekick 模式下两个上下文各自连续缓存，这是它便宜的结构性原因。

**会话中动态切换（dynamic mid-session routing）。** 不在任务开始时一选定终身，而是用轻量分类器在执行过程中判断何时升级/降级模型。工程上最漂亮的一笔是：**模型切换安排在上下文压缩（compaction）时进行**——压缩本来就会触发 cache miss，切换模型等于"免费"。

结果：在其 FrontierCode 基准上，Fusion 以约低 35%（后续数据至 60%）的成本维持前沿级表现；内部试用中 88% 的合并 PR 由自动路由器全程驱动。

```text
┌──────────────────── Devin Fusion 的双 agent 结构 ─────────────────┐
│                                                                  │
│   ┌──────────────┐         委派/监控/回收        ┌──────────────┐ │
│   │  主 Agent     │ ───────────────────────────► │   Sidekick   │ │
│   │ (前沿模型)    │ ◄─────────────────────────── │  (便宜模型)   │ │
│   │ 计划/歧义/终审 │          结果与状态           │  具体执行     │ │
│   └──────┬───────┘                               └──────┬───────┘ │
│          │  各自的持久上下文，独立缓存                     │        │
│          ▼                                              ▼        │
│     上下文压缩点 ──────► 趁机切换模型（cache miss 本来就要发生）     │
└──────────────────────────────────────────────────────────────────┘
```

把 Fusion 和"Don't Build Multi-Agents"放在一起读，才能读出 Cognition 的真实立场：**可以多 agent，但上下文必须连续、决策权必须集中**。Sidekick 恰恰遵守了那两条原则——主 agent 保留全部关键决策与完整视野，sidekick 是被严格委派的执行臂。这不是打脸，是把原则贯彻到了模型选型层面。

## 自主性 vs 可控性：Devin 的产品化取舍

把所有案例放进同一条光谱，Devin 的位置一目了然：

| 产品 | 运行位置 | 人的角色 | 自主性 | 可控性机制 |
| --- | --- | --- | --- | --- |
| Devin | 云端沙箱，异步 | 派活 + Review PR | 最高：数小时无人值守 | 沙箱隔离、PR 评审闸口、Slack 对话纠偏 |
| Claude Code | 本地终端，同步 | 在场结对、随时打断 | 高：自主循环但人在回路 | 权限审批、plan mode、逐工具确认 |
| OpenHands | 可自托管沙箱 | 可配置 | 高（路线与 Devin 同构） | 开源可审计、策略自定义 |
| Cursor | IDE 内 | 驾驶员 | 中低：建议/编辑为主 | 每处 diff 人工确认 |

Devin 的取舍可以概括为三句话：

**1. 用"交付物闸口"替代"过程审批"。** Claude Code 让你在每一步动作前按 y/n；Devin 让你在最后 Review 一个 PR。前者把控制权分布在过程中，后者把控制权压缩到交付点。代价很明显：中途走偏的成本全部沉没，所以 Devin 必须比任何同类产品都更依赖规划器、进度汇报和 Slack 里的中途纠偏——发布博客中"实时报告进度、接受反馈"的承诺不是功能点缀，是这个架构的必需品。

**2. 用沙箱隔离换行动自由。** 给 agent 一整台电脑意味着它能装任何依赖、访问任何网站、跑任何脚本——这在本地终端是不可接受的风险，在一次性云端 VM 里是可控的实验。[权限与人机协作](/components/permissions) 讨论的核心 trade-off，Devin 的答案是"把爆炸半径物理隔离掉，然后在隔离区内尽量放权"。

**3. 自主性叙事的通胀与还债。** 2024 年的演示争议、GA 之后第三方评测中不高的任务完成率（[The Register 2025 年初的报道](https://www.theregister.com/software/2025/01/23/first-ai-software-engineer-is-bad-at-its-job/549014)标题就是"第一位 AI 软件工程师不擅长它的工作"），都是"把自主性卖点拉满"之后要还的债。有意思的是 Cognition 后来的转向：工程博客越来越强调内部可核查的工程指标（合并 PR 比例、单任务成本），而不是 viral 演示——这本身就是从争议中学到的教训。

::: tip 从 Devin 能带走的三条经验
1. 长时程 agent 的工具集要覆盖人类的完整工作面（shell + editor + browser），缺一面就会在对应任务上系统性失败；
2. "多 agent 还是单 agent"是假问题，"上下文是否连续、决策权是否集中"才是真问题；
3. 自主性越高的产品，越要把可核查性（轨迹、交付物、内部指标）当成核心功能来建——否则第一次打假就足以摧毁叙事。
:::

## 延伸阅读

- [子 Agent](/components/subagents)——"Don't Build Multi-Agents" 两原则的完整设计空间
- [上下文工程](/components/context-engineering)——压缩、轨迹共享与 cache 友好的上下文管理
- [权限与人机协作](/components/permissions)——过程审批与交付物闸口两种控制模式
- [规划与任务分解](/components/planning)——Devin 的 Planner 在长时程任务中的角色
- [OpenHands 案例](/case-studies/openhands)——同一架构路线的开源对照实验
- [Claude Code 案例](/case-studies/claude-code)——"在场结对"模型的另一端
- [模型 vs Harness](/guide/model-vs-harness)——为什么 harness 不披露，分数就不可比较
- [什么是 Agent Harness](/guide/what-is-harness)——本文全部讨论的概念地基

## 参考资料

- [Cognition: Introducing Devin（2024-03-12 发布博客）](https://cognition.ai/blog/introducing-devin)
- [Internet of Bugs: Debunking Devin: "First AI Software Engineer" Upwork lie exposed!（2024-04 打假视频）](https://www.youtube.com/watch?v=tNmgmwEtoWE)
- [TLDR Dev 2024-04-15：打假视频的摘要与传播](https://tldr.tech/dev/2024-04-15)
- [Cognition: Devin is now generally available（2024-12-10 GA 公告）](https://www.cognition.ai/blog/devin-generally-available)
- [Devin 官方文档：2024 年 Release Notes（GA 定价与 ACU 细则）](https://docs.devin.ai/release-notes/2024)
- [TechCrunch: Devin 推出按量付费新档位（2025-04-03）](https://techcrunch.com/2025/04/03/devin-the-viral-coding-ai-agent-gets-a-new-pay-as-you-go-plan/)
- [TechCrunch: Cognition 收购 Windsurf（2025-07-14）](https://techcrunch.com/2025/07/14/cognition-maker-of-the-ai-coding-agent-devin-acquires-windsurf/)
- [Cognition: Introducing SWE-1.5（自有模型线）](https://cognition.ai/blog/swe-1-5)
- [Walden Yan / Cognition: Don't Build Multi-Agents（2025-06-12）](https://cognition.ai/blog/dont-build-multi-agents)
- [Anthropic: How we built our multi-agent research system（2025-06-13，对立立场）](https://www.anthropic.com/engineering/built-multi-agent-research-system)
- [Cognition: Devin Fusion——多模型 harness 与模型路由（2026-06-29）](https://cognition.com/blog/devin-fusion)
- [The Register: "First AI software engineer" is bad at its job（2025-01-23）](https://www.theregister.com/software/2025/01/23/first-ai-software-engineer-is-bad-at-its-job/549014)
