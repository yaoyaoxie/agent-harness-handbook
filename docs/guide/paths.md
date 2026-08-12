---
title: 学习路径：三条路线
description: 本站 40 余页内容不是要你通读的图书馆，而是可以按需组合的路线图：为三个月内要面试的人准备求职冲刺线，为想打牢底子的人准备六周系统转兵线，为在职建造者准备「问题 → 页面」的案头速查索引。
---

# 学习路径：三条路线

这个站点有 40 多页内容。如果你从第一页顺着读下去，大概率会在组件章的第三篇开始走神——不是内容不好，而是**通读不是在职工程师学习一门工程学科的正确姿势**。你需要的不是图书馆，是路线图。

本站内容其实只有四种性质：**建立概念的**（导读）、**解释机制的**（组件）、**提供证据的**（案例与论文）、**改变你行为的**（实践与求职）。不同处境的人，应该以完全不同的顺序和深度消费它们。这一页给出三条已经排好的路线，你对号入座即可。

```text
                    你的处境是什么？
                          │
          ┌───────────────┼───────────────────┐
          ▼               ▼                   ▼
   1-3 个月内面试    时间充裕，想转行      已经在做 agent
          │               │                   │
   ┌────────────┐  ┌───────────────┐   ┌─────────────┐
   │ ① 求职冲刺线 │  │ ② 系统转兵线   │   │ ③ 案头速查线  │
   │   约 2 周   │  │   约 6 周     │   │  不通读，随用  │
   ├────────────┤  ├───────────────┤   ├─────────────┤
   │ career 主线 │  │ 导读→组件→案例 │   │ 遇到问题      │
   │ +高频组件   │  │ →实践→论文     │   │ →查索引表     │
   │ +动手 demo  │  │ 每周有检验标准 │   │ →回到工作     │
   ├────────────┤  ├───────────────┤   ├─────────────┤
   │产出：改好的  │  │产出：能讲清    │   │产出：当下的   │
   │简历+10 道题 │  │整套系统+作品集 │   │问题被解决     │
   └────────────┘  └───────────────┘   └─────────────┘
```

::: info 三条路线不是互斥的
很多人的真实轨迹是：先按速查线用了本站几个月，决定转型后走一遍系统线，临面试前再跑一遍冲刺线的后半段。路线是导航，不是铁轨。
:::

## 路线一：求职冲刺线（约 2 周）

**适用人群**：1–3 个月内有 agent 工程岗面试，已是在职工程师（后端/全栈/算法均可），没有整块时间，只有晚上和周末。

**核心思路**：面试考察的本质是两件事——你能否把 agent 系统讲清楚，以及你的简历和表达能否通过筛选。所以这条线**以终为始，从 JD 和面试题倒推学习内容**，不求全面，只求高频考点全部覆盖、每个考点都能说出"为什么"。

### 主线：career 模块四篇

| 顺序 | 页面 | 你要拿走的东西 |
| --- | --- | --- |
| 1 | [JD 清单：国内外大厂在招岗位](/career/jd-list) | 目标岗位到底要求什么，把其中反复出现的技能词抄下来 |
| 2 | [能力地图](/career/knowledge-map) | 把 JD 里的技能词映射到本站页面，生成你个人的补课清单 |
| 3 | [简历分析](/career/resume-analysis) | 按里面的标准重写你的项目经历，突出 harness 相关决策 |
| 4 | [面试题解析](/career/interview-questions) | 最后用它自测，而非第一天就看 |

### 配菜：最高频被考的组件 + 一个动手 demo

从 JD 和面试题的分布看，以下四篇组件文覆盖了绝大多数"harness 侧"考点，按这个顺序读：

1. [上下文工程](/components/context-engineering)——几乎每场 agent 面试必考，压缩、截断、注入的取舍要能脱口而出；
2. [工具系统](/components/tools)——工具描述怎么写、返回结果怎么处理，是区分"调过 API"和"做过 agent"的分水岭；
3. [可观测性](/components/observability)——"线上 agent 行为异常你怎么排查"是资深岗的区分题；
4. [子 Agent](/components/subagents)——多 agent 架构什么时候该用、什么时候是过度设计，面试官等着你说"看情况"并给出判断标准。

如果只能再加一篇，加 [Agent 循环](/components/agent-loop)——它是所有问题的地基。

光看不练的简历没有说服力。用周末跑通[动手搭建一个 Harness](/practice/build-your-own)：仓库里 `examples/` 目录下的 v1 最小循环只有几十行，v2 加工具、v3 加规划与记忆，逐层跑一遍、改一改，你就拥有了一个可以在面试时讲五分钟不带停的亲手项目。

### 两周节奏

**第一周（理解 + 简历）：**

- 周一到周三：JD 清单 → 能力地图，产出你的补课清单；
- 周四到周五：按上面顺序读四篇组件文，每篇读完合上书，用手机录音给自己讲一遍核心机制，讲不顺的地方回读；
- 周末：跑通 build-your-own 的 v1→v3；按简历分析页的标准改完简历初稿。

**第二周（表达 + 自测）：**

- 周一到周三：面试题解析，每道题先自己答再对照，把答不上来的标红回炉对应组件页；
- 周四到周五：找朋友或用语音自问自答做模拟，重点练"为什么"类问题（为什么压缩而不是加窗口？为什么子 agent 不是越多越好？）；
- 周末：定稿简历，把 demo 项目整理成能展示的仓库。

::: tip 两周后的验收标准
你手里应该有三样东西：**一份按 agent 岗标准重写过的简历、一个跑得通讲得清的 mini harness 仓库、10 道能讲出取舍和权衡的面试题答案**。少一样，说明对应环节偷工了。
:::

## 路线二：系统转兵线（约 6 周）

**适用人群**：时间相对充裕（每周能投入 8–10 小时），想在 1–2 个季度内完成转型，看重底子而不是速成。

**核心思路**：agent 工程的知识是有依赖图的——不理解 loop 就看不懂上下文工程，不理解组件就看不出案例的门道，没拆过案例就写不出自己的设计原则。这条线按依赖顺序排布，**每周附检验标准，达不到就不要进下一周**。

| 周 | 内容 | 检验标准 |
| --- | --- | --- |
| 第 1 周 | 导读四篇：[什么是 Harness](/guide/what-is-harness) → [模型 vs. Harness](/guide/model-vs-harness) → [历史](/guide/history) → [解剖](/guide/anatomy) | 能向一个没听过这个词的同事讲清"模型和 harness 各负责什么"，并举出一个实证例子 |
| 第 2 周 | 组件地基三篇：[Agent 循环](/components/agent-loop) → [上下文工程](/components/context-engineering) → [工具系统](/components/tools) | 能在白板上画出最小 agent loop，并说出上下文窗口满了之后的至少三种处理策略及其代价 |
| 第 3 周 | 组件进阶四篇：[规划](/components/planning) → [记忆](/components/memory) → [子 Agent](/components/subagents) → [模型路由](/components/model-routing) | 能说清三种规划模式的差异，以及"什么时候该拆子 agent、什么时候只是 todo list" |
| 第 4 周 | 组件收尾三篇 + 案例选读：[权限](/components/permissions)、[Skills](/components/skills)、[可观测性](/components/observability)；案例至少精读 [Claude Code](/case-studies/claude-code) 和 [SWE-agent](/case-studies/swe-agent)，再从 [Cursor](/case-studies/cursor)、[OpenHands](/case-studies/openhands)、[Aider](/case-studies/aider)、[Devin](/case-studies/devin) 中按兴趣选两篇 | 拿到任意一个 agent 产品，能拆解出它的 loop 结构、工具集、上下文策略，并指出一个你认为可疑的设计决策 |
| 第 5 周 | 实践五篇：[搭建自己的 Harness](/practice/build-your-own) → [Harness 教程](/practice/harness-tutorial) → [设计原则](/practice/design-principles) → [常见陷阱](/practice/pitfalls) → [评估实践](/practice/evals-in-practice)；目标是在本周内做出一个解决你真实工作痛点的小 agent | 你的 demo 能在别人的机器上跑起来，并且你能说出它在什么输入下会失败 |
| 第 6 周 | 论文选读 + 求职材料收尾：[核心论文](/papers/core-papers) 至少精读 ReAct 相关部分，[前沿论文](/papers/frontier) 选读；然后走 career 模块：[能力地图](/career/knowledge-map) → [简历分析](/career/resume-analysis) → [面试题](/career/interview-questions) | 能讲清 ReAct 到现代 todo list 的演化逻辑；简历和 10 道题答案达到路线一的验收标准 |

::: warning 关于第 5 周的硬性要求
六周里唯一不可压缩的是动手周。读完四篇组件文时你会产生一种"我已经懂了"的错觉——这种错觉会在你第一次让模型自己调用 shell 工具时碎掉。没有亲手被 agent 的失控行为教育过，转型是不算完成的。
:::

时间实在紧张的话，第 4 周的案例和第 6 周的论文可以各砍一半，但**导读、组件、动手这三段不要砍**——它们是这条线的承重墙。

## 路线三：案头速查线（在职建造者）

**适用人群**：已经在做 agent 相关开发，问题是以"今天卡住了"为单位出现的，没有通读的需求和耐心。

这条线的用法是：**遇到问题时从下表查入口页，读完解决问题就走，不要顺藤摸瓜。** 摸瓜留给周末。

| 你遇到的问题 | 去看 |
| --- | --- |
| 工具返回太长，上下文很快就爆了 | [上下文工程](/components/context-engineering)（压缩与截断策略） |
| 模型总是忘记最初的目标、越跑越偏 | [规划与任务分解](/components/planning)（Todo list 机制） |
| 不知道该给 agent 配哪些工具、工具描述怎么写 | [工具系统](/components/tools) |
| 想让模型记住用户偏好/跨会话信息 | [记忆系统](/components/memory) |
| 一个 agent 干不完，想拆多个但怕过度设计 | [子 Agent](/components/subagents) |
| agent 要执行危险操作，审批流程怎么设计 | [权限与人机协作](/components/permissions) |
| 线上行为诡异，不知道怎么排查和记录轨迹 | [可观测性](/components/observability) |
| 简单任务不想烧大模型的钱 | [模型路由](/components/model-routing) |
| 想把团队的领域知识喂给 agent | [Skills](/components/skills) |
| 不知道该用 LangGraph 还是自己写 loop | [框架对比](/practice/framework-comparison) |
| 要自己从零搭一个 | [动手搭建一个 Harness](/practice/build-your-own) |
| agent 效果时好时坏，想建评估体系 | [评估实践](/practice/evals-in-practice) |
| CLAUDE.md / 系统提示词不知道怎么写 | [编写 CLAUDE.md](/practice/writing-claude-md) |
| 想看看成熟产品怎么解决同类问题 | 案例章：[Claude Code](/case-studies/claude-code)、[Cursor](/case-studies/cursor)、[Devin](/case-studies/devin)、[LangGraph](/case-studies/langgraph)、[Coze](/case-studies/coze)、[Manus](/case-studies/manus)、[Dify](/case-studies/dify) 等十篇 |
| 面试或被面试，需要考察框架 | [面试题解析](/career/interview-questions) |
| 术语卡壳 | [术语表](/resources/glossary) |
| 找外部工具、prompt 样例 | [资源导航](/resources/awesome)、[Prompt 档案](/resources/prompt-archive) |

::: tip 把这一页加书签
速查线的价值在于复用率。建议把本页（而不是任何一篇组件文）设为书签——它是全站的交换机。
:::

## 两点说明

**路径不是死规定。** 三条线的周数和顺序都是按典型背景估的：后端工程师可以跳过部分工具章节，算法出身的可以快进模型路由，产品经理转岗则应该在导读和案例上花双倍时间。判断标准永远是你能否通过每周的检验，而不是日历翻到了第几页。

**注意内容的时效。** Agent 工程是本站见过的所有工程学科里半衰期最短的一个——求职数据、案例拆解、论文清单都会过期。career 模块和案例章的部分页面在 frontmatter 里标注了 `dataAsOf`（数据截止月份），页面顶部也会显示；引用其中的具体岗位、分数、产品行为之前，先看一眼那个日期，超过一个季度的数据请当作"趋势参考"而非"当前事实"，并以官方来源复核。概念性的内容（什么是 harness、组件怎么工作）衰减慢得多，可以放心长期依赖。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——三条路线的共同起点
- [Harness 的解剖](/guide/anatomy)——全站内容地图，与本文互为索引
- [求职与 JD 分析](/career/)——路线一主线的模块入口
- [核心论文](/papers/core-papers)——路线二第六周的原始文献
- [设计原则](/practice/design-principles)——读完任何一条线后都值得回来对照的一页
