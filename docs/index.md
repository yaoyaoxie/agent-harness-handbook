---
layout: home

hero:
  name: "Agent Harness 手册"
  text: "模型之外，让智能体真正干活的那套系统"
  tagline: 系统拆解 AI 智能体骨架的设计与实现 —— 智能体循环 · 上下文工程 · 工具系统 · 记忆 · 子代理 · 安全边界
  image:
    src: /logo.svg
    alt: Agent Harness 手册
  actions:
    - theme: brand
      text: 什么是 Agent Harness？
      link: /guide/what-is-harness
    - theme: alt
      text: 选一条学习路径
      link: /guide/paths
    - theme: alt
      text: 动手构建
      link: /practice/build-your-own

features:
  - icon: 🧭
    title: 导读
    details: 概念定义、演进简史、模型与骨架的关系、总体架构——先建立全局认知地图。
    link: /guide/what-is-harness
  - icon: ⚙️
    title: 核心组件
    details: 智能体循环、上下文工程、工具系统、规划、记忆、子代理编排、权限安全、技能注入、评测可观测性。
    link: /components/agent-loop
  - icon: 🔍
    title: 经典案例
    details: Claude Code、Cursor、SWE-agent、OpenHands、Aider、Devin、LangGraph，以及扣子、Manus、Dify 等国内产品的 Harness 设计深度剖析。
    link: /case-studies/claude-code
  - icon: 📄
    title: 论文精读
    details: 从 ReAct 到 SWE-agent 的论文脉络，追踪 Agent Harness 研究的前沿进展。
    link: /papers/
  - icon: 🛠️
    title: 实践指南
    details: 从零构建一个最小 Harness、搭一套 Agent 评测、提炼设计原则、避开常见陷阱与反模式。
    link: /practice/build-your-own
  - icon: 💼
    title: 求职与 JD 分析
    details: 国内外大厂 Agent/LLM 岗位真实 JD 清单、知识点拆解、简历能力对标与面试题库。
    link: /career/
  - icon: 📚
    title: 资源
    details: 术语表与精选资源清单——框架、工具链与必读博客文章。
    link: /resources/glossary
---

## 从哪开始？

不想迷路的话，直接选一条路线——[学习路径页](/guide/paths)把全站 40+ 篇内容排成了三条明确的路线：

- **求职冲刺（约 2 周）**：1–3 个月内要面试的人，直奔 JD 对标、简历改写与面试题库
- **系统转行（约 6 周）**：时间充裕想打牢底子，从导读到实践分周推进，每周有检验标准
- **案头速查**：在职建造者不通读，按「问题 → 页面」索引即查即走

学完想验证成果？[三个能写进简历的作品集项目](/practice/portfolio-projects)，每个都标注了覆盖哪些大厂 JD 的高频要求。

## 什么是 Harness？

如果把大语言模型比作引擎，**Harness（骨架 / 挽具）就是把引擎变成一辆车所需要的一切**：传动、转向、仪表盘、刹车。

在 AI 智能体领域，Harness 指围绕模型的完整系统——它决定模型在每一步**看到什么上下文**、**能调用什么工具**、**如何规划任务**、**记住什么**、**何时停下来向人类求助**。

同一个模型，配上不同的 Harness，表现出的智能体能力可以天差地别。这就是本站存在的意义。
