---
title: 论文地图
description: Agent Harness 相关研究的学术地图：按主题分组的代表论文、范式迁移时间轴，帮助判断一篇新论文落在哪个坐标上。
---

# 论文地图

Agent Harness（智能体骨架）不是一篇论文发明的概念，而是几十篇论文在三年间一点点拼出来的系统图景：ReAct 给出了「推理—行动」交织的主循环，Toolformer 证明了工具能力可以被训练进模型，SWE-bench 把评测拉进真实软件工程，SWE-agent 则第一次把「接口设计」本身写成了论文题目。这一页把这些工作按主题整理成一张地图，帮你判断一篇新论文落在哪个坐标上、该先读哪些。

::: tip 怎么用这张地图
如果你只有两小时，直接去[阅读路径](/papers/paths)选一条。每篇论文都标了 arXiv 编号，年份与作者机构均已在发表页核实。同一主题下按时间排序，方便看出思路的演化。
:::

## 范式迁移时间轴

```text
2021          2022                2023                              2024
 │             │                   │                                 │
 HumanEval     CoT ─────────────►  ReAct 确立 Agent Loop 范式          │
 (Codex)       SayCan             Toolformer / Gorilla / ToolLLM      │
               Inner Monologue    Generative Agents / MemGPT          │
               STaR               Voyager / Reflexion / Self-Refine   │
                                  WebArena / AgentBench / GAIA ──────►│
                                  SWE-bench ─────────────────────────►│
                                                                    OSWorld
                                                                    SWE-agent (ACI)
                                                                    CodeAct
                                                                    AutoCodeRover / Agentless
                                                                    OpenHands
```

三个明显的阶段迁移：

1. **2022 年：从「生成答案」到「交错决策」。** CoT 让模型在回答前先推理；ReAct 把推理和外部行动交织起来，Agent Loop 的雏形由此确立。
2. **2023 年：harness 各组件被逐个发明。** 工具（Toolformer、Gorilla）、记忆（Generative Agents、MemGPT）、技能库与自我反思（Voyager、Reflexion）、真实环境评测（WebArena、SWE-bench）几乎在同一年涌现——harness 的解剖图在这一年基本画完。
3. **2024 年：系统设计与评测纪律成为主角。** SWE-agent 提出「智能体—计算机接口（ACI）」的概念，Agentless 用「无智能体」的流水线反向拷问 agent 的必要性，OSWorld 把评测推进到真实操作系统。研究重心从「让模型更会想」转向「把模型围得更好」——这正是 harness 研究的内核。

## 推理与行动范式

这一组论文定义了 agent 的「心跳」：模型每一步在想什么、做什么、如何交替。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [Chain-of-Thought Prompting Elicits Reasoning in Large Language Models](https://arxiv.org/abs/2201.11903) | Google Research | 2022 | 用 few-shot 示例诱导模型生成中间推理步骤，确立「先想后答」的基座能力 |
| [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629) | Princeton / Google Brain | 2022 | 推理轨迹与外部行动交错生成，几乎是所有现代 agent loop 的模板 |
| [Tree of Thoughts: Deliberate Problem Solving with Large Language Models](https://arxiv.org/abs/2305.10601) | Princeton / Google DeepMind | 2023 | 把单链推理扩展成可搜索、可回溯的思维树，Game of 24 成功率从 4% 提到 74% |
| [Executable Code Actions Elicit Better LLM Agents](https://arxiv.org/abs/2402.01030)（CodeAct） | UIUC | 2024 | 用可执行 Python 代码作为统一动作空间替代 JSON 工具调用，成功率提升最高 20% |

::: info 独立判断
ReAct 的真正遗产不是那个 prompt 模板，而是「观察—思考—行动」的回合结构被固化为 harness 的主循环协议。CodeAct 则提醒我们：动作空间的表示形式（JSON 还是代码）本身就是 harness 设计决策，且影响显著。两篇都值得逐字读。
:::

## 工具学习

模型如何学会调用工具——是靠 prompt 编排，还是靠训练内化。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [Toolformer: Language Models Can Teach Themselves to Use Tools](https://arxiv.org/abs/2302.04761) | Meta AI | 2023 | 自监督方式让模型学会何时调 API、传什么参数，只需每个 API 少量示例 |
| [HuggingGPT: Solving AI Tasks with ChatGPT and its Friends in Hugging Face](https://arxiv.org/abs/2303.17580) | 浙江大学 / 微软亚洲研究院 | 2023 | LLM 作为控制器调度 Hugging Face 上的专家模型，语言作为通用接口 |
| [Gorilla: Large Language Model Connected with Massive APIs](https://arxiv.org/abs/2305.15334) | UC Berkeley | 2023 | 检索增强微调在 API 调用生成上超过 GPT-4，并缓解 API 幻觉 |
| [ToolLLM: Facilitating Large Language Models to Master 16000+ Real-world APIs](https://arxiv.org/abs/2307.16789) | 清华大学 / 面壁智能 | 2023 | ToolBench 数据集 + 深度优先搜索决策树，让开源模型掌握上万真实 API |

工具学习对 harness 的意义是双向的：harness 的工具描述写得越好，模型调得越准（见[工具系统](/components/tools)）；而模型被训练得越会调工具，harness 要做的编排就越少。

## 自我改进

不靠梯度更新，agent 如何在任务中变好。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [STaR: Bootstrapping Reasoning With Reasoning](https://arxiv.org/abs/2203.14465) | Stanford | 2022 | 用模型自己生成的、导向正确答案的推理链来微调自身，自举出推理能力 |
| [Reflexion: Language Agents with Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366) | Northeastern / MIT / Princeton | 2023 | 用语言化的反思替代权重更新，HumanEval pass@1 达 91%（论文报告值） |
| [Self-Refine: Iterative Refinement with Self-Feedback](https://arxiv.org/abs/2303.17651) | CMU / Allen Institute for AI | 2023 | 同一个 LLM 兼任生成者、反馈者与修改者，无需训练即可迭代改进输出 |
| [Voyager: An Open-Ended Embodied Agent with Large Language Models](https://arxiv.org/abs/2305.16291) | NVIDIA / Caltech / UT Austin | 2023 | Minecraft 中自动课程 + 可执行代码技能库 + 自我验证，实现终身学习 |

::: warning 读 Reflexion 时注意
Reflexion 报告的 HumanEval 91% 是在允许迭代尝试与测试反馈的条件下取得的，与单次生成的 80% 基线不是同一赛道的数字。这恰恰说明了 harness 的价值——但引用数据时要说清条件。
:::

## 记忆

agent 记住什么、怎么取回、如何压缩，决定了它能跑多长的任务。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [Generative Agents: Interactive Simulacra of Human Behavior](https://arxiv.org/abs/2304.03442) | Stanford / Google Research | 2023 | 观察—反思—计划的记忆流架构，让 25 个模拟镇民涌现出可信社会行为 |
| [MemGPT: Towards LLMs as Operating Systems](https://arxiv.org/abs/2310.08560) | UC Berkeley | 2023 | 借鉴操作系统的分层存储与「虚拟上下文管理」，用中断机制自主换页记忆 |

Voyager 的技能库也可以读成一种记忆——只不过存的不是事实而是「会做的事」。三条路线（检索式记忆流、OS 式换页、程序化技能库）在今天的生产 harness 里都有对应实现，详见[记忆系统](/components/memory)。

## 规划

把「下一步做什么」从模型身上分出来，是 agent 研究里最反复的争论。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [Do As I Can, Not As I Say: Grounding Language in Robotic Affordances](https://arxiv.org/abs/2204.01691)（SayCan） | Google Research | 2022 | 用技能的可供性（affordance）评分约束 LLM 的规划，让计划落在机器人真能做到的事上 |
| [Inner Monologue: Embodied Reasoning through Planning with Language Models](https://arxiv.org/abs/2207.05608) | Google Research | 2022 | 闭环语言反馈（成功检测、场景描述、人类输入）作为「内心独白」改进具身规划 |
| [On the Planning Abilities of Large Language Models](https://arxiv.org/abs/2302.06706) | Arizona State University | 2023 | 基于国际规划竞赛域的批判性评测：LLM 自主生成可执行计划的成功率仅约 3% |
| [LLM+P: Empowering Large Language Models with Optimal Planning Proficiency](https://arxiv.org/abs/2304.11477) | UT Austin | 2023 | LLM 把自然语言问题翻译成 PDDL，交给经典规划器求最优解再翻回来 |

这组论文合起来讲了一个完整的故事：LLM 直接规划很弱（Valmeekam 等），但把规划外包给符号系统（LLM+P）或用环境反馈闭环约束（SayCan、Inner Monologue）就大幅改善。这正是 harness「分工」思想的学术源头，对应站内的[规划机制](/components/planning)。

## 评测基准

没有基准就没有 harness 工程。以下基准定义了「agent 行不行」的度量衡。

| 基准 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [HumanEval（Evaluating Large Language Models Trained on Code）](https://arxiv.org/abs/2107.03374) | OpenAI | 2021 | 164 个手写编程题 + 执行式判定，代码生成评测的事实起点 |
| [WebArena: A Realistic Web Environment for Building Autonomous Agents](https://arxiv.org/abs/2307.13854) | CMU | 2023 | 自托管的真实功能网站环境，当时最强 GPT-4 agent 成功率仅 14.41%（人类 78.24%） |
| [AgentBench: Evaluating LLMs as Agents](https://arxiv.org/abs/2308.03688) | 清华大学 | 2023 | 8 类交互环境的多维评测，系统刻画了商用与开源模型的 agent 能力差距 |
| [SWE-bench: Can Language Models Resolve Real-World GitHub Issues?](https://arxiv.org/abs/2310.06770) | Princeton | 2023 | 2294 个真实 GitHub issue，把评测从「写函数」推进到「修真实的仓库」，成为行业金标准 |
| [GAIA: a benchmark for General AI Assistants](https://arxiv.org/abs/2311.12983) | Meta AI / Hugging Face 等 | 2023 | 对人类简单、对 AI 困难的 466 个真实世界问题，需要浏览、推理与工具组合 |
| [OSWorld: Benchmarking Multimodal Agents for Open-Ended Tasks in Real Computer Environments](https://arxiv.org/abs/2404.07972) | 香港大学 / CMU / Salesforce 等 | 2024 | 真实操作系统中的 369 个开放式任务，执行式评估，最佳模型成功率仅 12.24% |

::: tip 读基准论文的正确姿势
不要只看 leaderboard 数字，要看三件事：任务从哪来（真实性）、如何判定成功（执行式还是匹配式）、失败案例长什么样（决定 harness 该补什么）。SWE-bench 论文里「Claude 2 只解决 1.96%」的数字之所以重要，是因为它证明了当时的问题不在模型智商而在交互方式。
:::

## 软件工程 Agent

软件工程是 harness 思想落地最彻底的领域，也是本站的重心。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering](https://arxiv.org/abs/2405.15793) | Princeton | 2024 | 提出智能体—计算机接口（ACI）概念，证明接口设计本身显著影响 agent 表现 |
| [AutoCodeRover: Autonomous Program Improvement](https://arxiv.org/abs/2404.05427) | National University of Singapore | 2024 | 以程序结构（AST/类/方法）而非纯文件视图组织代码搜索，成本显著低于同期方案 |
| [Agentless: Demystifying LLM-based Software Engineering Agents](https://arxiv.org/abs/2407.01489) | UIUC | 2024 | 「定位—修复—验证」三段式无智能体流水线，以极低成本登上 SWE-bench Lite 前列 |
| [OpenHands: An Open Platform for AI Software Developers as Generalist Agents](https://arxiv.org/abs/2407.16741) | UIUC / CMU 等 | 2024 | 社区驱动的开放平台：代码执行沙箱、多 agent 协调、15 项基准集成评测 |

::: details 为什么 Agentless 是本站最重要的「反面教材」
Agentless 故意不用 agent loop——不让模型自由决定下一步，只用固定流水线——却击败了当时所有开源软件 agent。它的教训不是「agent 没用」，而是：在 harness 设计里，每一步自由度都要有理由。盲目堆自主性会付出可靠性、成本和可调试性的代价。这与站内[设计原则](/practice/design-principles)和[常见陷阱](/practice/pitfalls)互为印证。
:::

## 综述

想快速建立全景，两篇综述互补。

| 论文 | 机构 | 年份 | 一句话贡献 |
| --- | --- | --- | --- |
| [A Survey on Large Language Model based Autonomous Agents](https://arxiv.org/abs/2308.11432) | 中国人民大学 | 2023 | 提出统一的「构建—应用—评测」框架梳理 agent 研究，持续维护文献库 |
| [The Rise and Potential of Large Language Model Based Agents: A Survey](https://arxiv.org/abs/2309.07864) | 复旦大学 | 2023 | 「大脑—感知—行动」三分框架，兼论 agent 社会与哲学源流，篇幅较长 |

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness) — 论文里各组件在 harness 概念下的重新组织
- [Harness 解剖](/guide/anatomy) — 把这张论文地图映射成系统结构图
- [Agent 主循环](/components/agent-loop) — ReAct 范式的工程展开
- [上下文工程](/components/context-engineering) — 每篇论文的 prompt 与上下文策略细读
- [规划机制](/components/planning) — 规划组论文的当代回声
- [记忆系统](/components/memory) — 记忆组论文的当代回声
- [经典论文精读](/papers/core-papers) — 少数几篇的逐篇精读
- [前沿进展](/papers/frontier) — 2024 年之后的新工作
- [SWE-agent 案例](/case-studies/swe-agent) — ACI 思想的完整案例
- [OpenHands 案例](/case-studies/openhands) — 开放平台案例

## 参考资料

- [ReAct (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)
- [Chain-of-Thought (arXiv:2201.11903)](https://arxiv.org/abs/2201.11903)
- [Tree of Thoughts (arXiv:2305.10601)](https://arxiv.org/abs/2305.10601)
- [CodeAct (arXiv:2402.01030)](https://arxiv.org/abs/2402.01030)
- [Toolformer (arXiv:2302.04761)](https://arxiv.org/abs/2302.04761)
- [HuggingGPT (arXiv:2303.17580)](https://arxiv.org/abs/2303.17580)
- [Gorilla (arXiv:2305.15334)](https://arxiv.org/abs/2305.15334)
- [ToolLLM (arXiv:2307.16789)](https://arxiv.org/abs/2307.16789)
- [STaR (arXiv:2203.14465)](https://arxiv.org/abs/2203.14465)
- [Reflexion (arXiv:2303.11366)](https://arxiv.org/abs/2303.11366)
- [Self-Refine (arXiv:2303.17651)](https://arxiv.org/abs/2303.17651)
- [Voyager (arXiv:2305.16291)](https://arxiv.org/abs/2305.16291)
- [Generative Agents (arXiv:2304.03442)](https://arxiv.org/abs/2304.03442)
- [MemGPT (arXiv:2310.08560)](https://arxiv.org/abs/2310.08560)
- [SayCan (arXiv:2204.01691)](https://arxiv.org/abs/2204.01691)
- [Inner Monologue (arXiv:2207.05608)](https://arxiv.org/abs/2207.05608)
- [On the Planning Abilities of LLMs (arXiv:2302.06706)](https://arxiv.org/abs/2302.06706)
- [LLM+P (arXiv:2304.11477)](https://arxiv.org/abs/2304.11477)
- [HumanEval / Codex (arXiv:2107.03374)](https://arxiv.org/abs/2107.03374)
- [WebArena (arXiv:2307.13854)](https://arxiv.org/abs/2307.13854)
- [AgentBench (arXiv:2308.03688)](https://arxiv.org/abs/2308.03688)
- [SWE-bench (arXiv:2310.06770)](https://arxiv.org/abs/2310.06770)
- [GAIA (arXiv:2311.12983)](https://arxiv.org/abs/2311.12983)
- [OSWorld (arXiv:2404.07972)](https://arxiv.org/abs/2404.07972)
- [SWE-agent (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
- [AutoCodeRover (arXiv:2404.05427)](https://arxiv.org/abs/2404.05427)
- [Agentless (arXiv:2407.01489)](https://arxiv.org/abs/2407.01489)
- [OpenHands (arXiv:2407.16741)](https://arxiv.org/abs/2407.16741)
- [A Survey on LLM based Autonomous Agents (arXiv:2308.11432)](https://arxiv.org/abs/2308.11432)
- [The Rise and Potential of LLM Based Agents: A Survey (arXiv:2309.07864)](https://arxiv.org/abs/2309.07864)
