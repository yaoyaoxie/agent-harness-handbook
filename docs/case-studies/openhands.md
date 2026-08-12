---
title: 案例：OpenHands
description: 深入剖析开源 agent 平台 OpenHands（原 OpenDevin）的 harness 架构：事件流、Docker 沙箱运行时、CodeAct 统一动作空间、microagent 与可插拔设计，以及它作为「harness 实验平台」的学术价值。
---

# 案例：OpenHands

如果 [SWE-agent](/case-studies/swe-agent) 展示了「精心打磨的 ACI（Agent-Computer Interface）」能有多大威力，那么 OpenHands 回答的是另一个问题：**能不能把 harness 本身做成一个通用的、可复现的实验平台**——让任何人都能在同一套基础设施上换 agent、换模型、换工具、跑基准评测？

OpenHands（前身为 OpenDevin）大概是目前对「harness 即研究对象」这件事贯彻得最彻底的项目。它不是某个 agent 的实现，而是一整套围绕 agent 的脚手架：事件流、沙箱运行时、技能库、多 agent 委派、评测框架。读懂它，约等于读懂了现代 coding agent harness 的完整清单。

## 项目速览

| 维度 | 内容 |
| --- | --- |
| 前身 | OpenDevin，2024 年 3 月作为 Devin 的开源复刻启动，2024 年 9 月更名为 OpenHands |
| 论文 | *OpenHands: An Open Platform for AI Software Developers as Generalist Agents*（arXiv:2407.16741，v1 2024-07-23） |
| 核心作者 | Xingyao Wang、Graham Neubig 等（UIUC / CMU / All Hands AI 等） |
| 理论基础 | CodeAct 论文：*Executable Code Actions Elicit Better LLM Agents*（arXiv:2402.01030，ICML 2024） |
| 许可证 | MIT（允许商用） |
| 社区规模 | 论文发表时 32K GitHub stars、188 位贡献者、2.1K+ 次贡献；此后持续增长 |
| 定位 | 通用 agent 开发平台：agent 抽象 + 事件流 + 沙箱运行时 + AgentHub + 评测框架 |

::: info 项目演进提示
OpenHands 迭代很快。本文剖析的是其经典架构（对应 2407.16741 论文与 0.x 时代的代码结构）。2025 年 11 月项目发布 V1 并推出独立的 OpenHands Software Agent SDK，仓库组织也从 `All-Hands-AI/OpenHands` 迁移到 `OpenHands/OpenHands`，产品形态进一步扩展为可托管第三方 agent（Claude Code、Codex 等）的 Agent Canvas。架构思想一脉相承，但具体类名和目录请以你所读版本的代码为准。
:::

## 为什么值得研究 OpenHands

多数 coding agent 产品（Claude Code、Cursor、Aider）把 harness 藏在产品内部，你能看到的是行为和结果，看不到完整机制。OpenHands 反其道而行：

- **机制全部摊开**。事件流、状态、动作、观测、运行时，每个概念都有明确的代码实体，且写进了论文。
- **变量可控**。agent 实现、LLM、沙箱镜像、技能库、benchmark 都是可替换的插槽，天然适合做消融实验。
- **有学术背书**。两篇论文（平台论文 + CodeAct 论文）把设计决策的动机写清楚了，不用逆向工程去猜。

用[导读](/guide/anatomy)里的话说：OpenHands 是把 harness 的每个组件都做成了「一等公民」的项目。它自己的定位也很直白——一个 community-driven platform，而不是一个 agent。

## 总体架构：三大件

平台论文把 OpenHands 归纳为三个主组件：**Agent 抽象**（社区可贡献不同实现的 agent，汇入 AgentHub）、**事件流**（event stream，记录动作与观测的历史）、**运行时**（runtime，把动作执行为观测）。

```
┌─────────────────────────── OpenHands 宿主进程 ───────────────────────────┐
│                                                                          │
│   用户 / UI / CLI                                                        │
│        │  MessageAction / 反馈                                           │
│        ▼                                                                 │
│   ┌─────────────┐    step(state)     ┌──────────────┐                    │
│   │   Agent     │ ◄───────────────── │    State     │                    │
│   │ (CodeAct等) │                    │  ├ event stream (action+obs 历史) │
│   └──────┬──────┘                    │  ├ 累计 LLM 成本                  │
│          │ 返回 Action               │  └ 多 agent 委派元数据            │
│          ▼                           └──────────────┘                    │
│   ┌─────────────────── Event Stream ──────────────────┐                  │
│   │  Action → 派发给 Runtime → Observation 写回事件流 │                  │
│   └──────────────────────┬────────────────────────────┘                  │
└──────────────────────────┼───────────────────────────────────────────────┘
                           │ REST API（动作执行请求）
                           ▼
              ┌──── Docker 沙箱容器（每个任务会话一个）────┐
              │  Action Execution API Server             │
              │   ├─ bash shell（命令执行）              │
              │   ├─ Jupyter IPython server（跑 Python） │
              │   └─ Chromium + Playwright（浏览器）     │
              │  挂载：用户 workspace 目录               │
              └──────────────────────────────────────────┘
```

这个结构里最值得注意的是**职责切分**：agent 只负责「看状态、出动作」，它完全不知道动作是怎么被执行的；runtime 只负责「执行动作、回观测」，它完全不知道动作是谁、为什么发出的。两者通过事件流这个 append-only 的日志解耦。接下来逐块拆解。

## 事件流：一切皆为事件

事件流是 OpenHands 的心脏。它的定义（论文 §2.1）：**按时间顺序排列的动作（action）与观测（observation）集合**，既包括 agent 自己发出的动作，也包括用户的指令与反馈。

围绕事件流有几个关键设计：

**State = 事件流 + 辅助信息。** 除了历史事件，状态还携带累计 LLM 调用成本、多 agent 委派的跟踪元数据、执行参数等。这意味着 harness 层面的关切（花了多少钱、谁把子任务委派给了谁）和 agent 的「记忆」被显式建模在同一个数据结构里。

**动作与观测是成对的类型化对象。** 核心动作集合刻意保持小而通用：

| 动作 | 作用 |
| --- | --- |
| `CmdRunAction` | 在沙箱中执行任意 bash 命令 |
| `IPythonRunCellAction` | 在沙箱的 Jupyter 中执行 Python 代码 |
| `BrowserInteractiveAction` | 用 BrowserGym 的领域特定语言操作浏览器 |
| `AgentDelegateAction` | 把子任务委派给另一个 agent |
| `AgentFinishAction` / `MessageAction` | 结束任务 / 与人对话 |

对应的观测（observation）描述环境变化：命令输出、Python 执行结果、浏览器的 HTML/DOM/accessibility tree/截图、用户消息等。

**事件流即对话历史，也是审计日志。** 因为所有交互都落在同一条流上，「模型看到什么上下文」和「系统实际发生了什么」在 OpenHands 里是同一个东西的两个视图。这让调试、回放、评测都变得直接——评测框架正是消费这些轨迹来打分的。

::: tip harness 视角
事件流架构本质是**事件溯源（event sourcing）思想在 agent 系统中的应用**：不存「当前状态」，只存「事件序列」，状态由重放派生。代价是每步都要把历史序列化成 prompt——上下文工程的压力随之而来（长会话的压缩、截断由专门的 condenser 机制处理）。详见[上下文工程](/components/context-engineering)。
:::

## Agent 抽象：一个 step 函数

在这个事件流之上，实现一个新 agent 的接口被压缩到了极致——论文 Figure 3 给出的 `MinimalAgent` 骨架足以说明问题：

```python
class MinimalAgent:
    def reset(self) -> None:
        self.system_message = "You are a helpful assistant …"

    def step(self, state: State):
        # 1. 把事件流历史序列化成消息列表
        messages = [{"role": "system", "content": self.system_message}]
        for prev_action, obs in state.history:
            messages.append(get_action_message(prev_action))
            messages.append(get_observation_message(obs))

        # 2. 调 LLM，解析输出为动作
        response = self.llm.do_completion(messages)
        action = self.parse_response(response)

        # 3. 返回类型化动作，交给 runtime 执行
        if self.is_finish_command(action):
            return AgentFinishAction()
        elif self.is_bash_command(action):
            return CmdRunAction(command=action.command)
        elif self.is_python_code(action):
            return IPythonRunCellAction(code=action.code)
        elif self.is_browser_action(action):
            return BrowseInteractiveAction(code=action.code)
        else:
            return MessageAction(content=action.message)
```

这就是[agent 循环](/components/agent-loop)在 OpenHands 里的形态：`step(state) -> action`，循环本身由平台驱动。抽象的价值在于——研究者只需要关心「给定历史，下一步做什么」，执行细节、沙箱安全、成本统计、UI 渲染全部由 harness 兜底。这是它能成为实验平台的前提：换 agent 的成本约等于写一个几十行的类。

## CodeAct：代码作为统一动作空间

OpenHands 默认的通用 agent CodeActAgent 基于同团队更早的 CodeAct 论文（arXiv:2402.01030，ICML 2024）。这篇论文要回答的问题是：**agent 的动作应该用什么格式表达？**

当时的两种主流做法都有明显缺陷：

| 动作格式 | 问题 |
| --- | --- |
| 预定义 JSON function calling | 动作空间受限于预先声明的工具清单；一个动作只能调一个工具，无法组合 |
| 自由文本动作 | 解析脆弱，格式漂移，难以可靠执行 |

CodeAct 的方案：让 LLM 直接输出**可执行的 Python 代码**作为动作，接一个解释器执行，观察结果后再继续。代码天然携带循环、条件、变量、库导入和函数组合能力——一个代码块可以完成 JSON 格式需要十几轮往返的事。而且解释器的报错信息本身就是确定性的、高质量的环境反馈，agent 可以据此自我修正。

论文在 API-Bank 和一个新构建的工具使用基准上测试了 17 个 LLM，CodeAct 相比 JSON/文本格式的成功率**最高提升约 20%**。

OpenHands 把这一思想落到了工程上：

- 核心动作 `IPythonRunCellAction` 和 `CmdRunAction` 就是 CodeAct 的实例化——动作空间 ≈ 「一个 Linux 机器上能跑的任何代码」。
- 它同时**兼容传统 function calling**：想加一个新「工具」，不用改动作 schema，写个 Python 函数放进沙箱的 IPython 环境即可（见下一节的 AgentSkills）。
- 更激进的推论是：agent 可以**自己造工具**——当现成 API 不存在时，现场写一个 Python 函数顶上。

::: warning 统一动作空间的代价
「一切皆可代码」把灵活性推到了极致，也把安全性问题推到了极致：模型写的每一行代码都会被真实执行。这正是为什么 OpenHands 必须搭配一个强隔离的沙箱运行时——CodeAct 和 Docker 沙箱在这个平台里是互为前提的设计，不是两个独立特性。
:::

## 运行时沙箱：把危险关进容器

CodeAct 让 agent 能执行任意代码，runtime 的职责就是让这件事安全且可复现。OpenHands 的运行时设计（论文 §2.2）要点：

**一会话一容器。** 每个任务会话启动一个隔离的 Docker 容器，事件流里的所有动作都在容器内执行。用户的工作目录以可配置方式挂载进去，agent 的破坏半径被限制在容器内。

**容器内的动作执行 API。** 沙箱里跑着一个 REST API server（OpenHands Action Execution API），宿主进程把事件流中的动作发给它，它维护三样东西并返回观测：

1. 一个与容器 OS 相连的 **bash shell**；
2. 一个 **Jupyter IPython server**，处理交互式 Python 执行；
3. 一个基于 Playwright 的 **Chromium 浏览器**，动作原语来自 BrowserGym（导航、点击、输入、滚动），观测则包括 HTML、DOM、accessibility tree、截图、打开的标签页等。

**任意镜像支持。** 运行时有一个 build 机制：拿来任意用户提供的 Docker 镜像，往里注入动作执行 API，就变成了一个可用沙箱。这意味着评测不同项目（不同语言、依赖、OS 环境）时不需要改 harness，只换镜像——对跑 SWE-bench 这类需要逐仓库复现环境的基准至关重要。

::: details 为什么浏览器也要进沙箱？
OpenHands 的野心不是「代码补全工具」而是「通用数字工作者」：人类开发者工作时会查文档、看 issue、浏览网页。内置浏览器让同一套 agent 抽象可以覆盖 WebArena 这类网页任务——论文里 CodeActAgent 不做任何 prompt 修改就能同时跑软件工程、网页浏览和杂项助理三类基准，靠的就是这个动作空间设计。
:::

## AgentSkills：工具不用 schema 定义，用 pip 装

[SWE-agent 的论文](/case-studies/swe-agent)证明了精心设计的工具（ACI）对性能影响巨大，但工具的创建、维护、分发是沉重的工程负担。OpenHands 的 AgentSkills 库给出了一个很轻的答案（论文 §2.3）：

- **技能就是一个 Python 包。** 写个 Python 函数就是写了个工具，自动 import 进沙箱的 IPython 环境，agent 通过 `IPythonRunCellAction` 直接调用。不需要注册 schema，不需要改 agent 代码。
- **收录标准克制。** 官方明确了两条准入规则：LLM 自己直接写代码搞不定的（比如按行号编辑文件的 `edit_file`），或者需要调用外部模型的（比如 `parse_image` 调视觉模型、`parse_pdf` 解析 PDF）。「LLM 本来就会用 pandas 读 CSV」这种就不需要包一层。
- **像正经软件一样维护。** 技能库配套单元测试，避免「agent 背锅、工具背刺」。

这条路线和[工具组件](/components/tools)里讨论的「工具即代码」一脉相承：当动作空间本身是代码时，「给 agent 加工具」退化成了「给环境装依赖」，工程复杂度大幅下降。

## microagent：两个容易混淆的概念

OpenHands 语境下「micro」出现在两个层面，读文档时容易混淆，值得分开说清：

**1. Micro agent（论文中的特化 agent）。** 复用通用 agent（如 CodeActAgent）的绝大部分实现，只替换 prompt 和少量配置，面向特定任务特化。设计目标是降低社区贡献门槛——你不必懂整个 harness，分享一个调好的 prompt 就能发布一个「新 agent」。

**2. Microagents（仓库里的知识片段机制）。** 这是更常被用户接触的机制：在仓库根目录建 `.openhands/microagents/` 目录，放 Markdown 文件，内容为给 agent 的项目特定指引。官方文档定义了两类：

| 类型 | 触发方式 | frontmatter | 典型用途 |
| --- | --- | --- | --- |
| General | 每次会话自动注入 | 非必需 | `repo.md`：仓库结构、构建命令、代码规范 |
| Keyword-Triggered | 用户消息中出现指定关键词才注入 | 必需（`triggers` 字段） | 涉及特定框架/服务时才加载的专项知识 |

```
some-repository/
└── .openhands/
    └── microagents/
        ├── repo.md            # 通用仓库指引（常驻）
        ├── trigger_this.md    # 关键词触发
        └── trigger_that.md    # 关键词触发
```

::: tip harness 视角
microagents 本质是**条件化的上下文注入**：把「什么时候该给模型看什么知识」从一次性的大 system prompt 变成按需加载的模块化知识库。文档也明确提醒——加载的 microagent 会占用上下文窗口，所以关键词触发不是锦上添花，而是控制 prompt 体积的必要手段。这与 Claude Code 的 [skills](/components/skills)、CLAUDE.md 分层加载是同一个思想的不同实现。
:::

## 多 agent 委派与可插拔设计

**委派是一个动作，不是一个框架。** OpenHands 的多 agent 协作通过 `AgentDelegateAction` 实现：一个 agent 把子任务打包委派给另一个 agent，比如通用的 CodeActAgent 把复杂网页操作委派给专职的 BrowsingAgent。委派关系记录在 State 的元数据里。这个设计刻意简单——没有黑板系统、没有角色编排引擎，就是「动作空间里多一个动作」。详见[多智能体](/components/subagents)的比较讨论。

**Agent 可插拔：AgentHub。** 平台上汇集了 10 余种社区贡献的 agent 实现：默认的 CodeActAgent、面向网页的 BrowsingAgent、基于可优化图的 GPTSwarm agent、各种 micro agent……它们共享同一套事件流和运行时，因此可以公平对比。

**LLM 可插拔：LiteLLM。** 模型接入走 LiteLLM 这一层统一网关，换模型就是换配置里的 model string（如 `openai/gpt-4o`、`claude-*`、openrouter 或本地 vLLM/Ollama 端点），并内建了 429 限流重试等实用逻辑。模型与 harness 彻底解耦——这正是本站[模型 vs harness](/guide/model-vs-harness)论点的活样本。

**评测可插拔。** 平台集成了 15 个基准（SWE-bench、WebArena、GAIA、GPQA、HumanEvalFix、ML-Bench、BIRD、AgentBench、MINT 等），覆盖软件工程、网页浏览、杂项助理三类。论文报告的代表性数字：CodeActAgent v1.8 配 claude-3.5-sonnet 在 SWE-bench Lite 上达 26.0%（单实例平均成本约 $1.10），同一 agent 不改 prompt 在 WebArena 达 14.5–15.3%，GPQA diamond 子集约 52%。

::: info 一个值得注意的研究发现
论文在 AgentBench 上观察到一个现象：换用较弱的模型（gpt-3.5-turbo）时，OpenHands 的通用 agent 反而**不如**原始基准里的专用 baseline。作者的解读是：通用 agent 对基座模型的指令遵循能力存在一个门槛，低于门槛时精心特化的专用 harness 更稳。这是「harness 与模型能力匹配」的定量证据。
:::

## 权衡与批评性观察

OpenHands 是优秀的研究平台，但它的设计选择都有对应代价，做工程选型时要看清：

- **事件流的全量序列化成本。** 每步都把完整历史发给模型，长任务的 token 消耗和延迟都会膨胀，必须依赖 condenser 做压缩——而压缩策略本身就是新的研究变量。对生产系统而言，append-only 的事件溯源未必是上下文管理的最佳答案。
- **通用动作空间 vs 专用 ACI 的张力。** 「bash + Python + 浏览器」三件套覆盖面广，但在具体任务上往往打不过为任务精调的工具集（论文中 SWE-agent 在 HumanEvalFix 上的 1-shot 成绩更高即为佐证）。通用性和单点性能之间的取舍不会因为平台化而消失。
- **沙箱的重量级。** 一会话一 Docker 容器换来强隔离和可复现，代价是启动开销、镜像体积、运维复杂度（Docker-in-Docker、资源配额）。本地轻量使用场景下这是明显的过重设计。
- **「平台」的复杂度税。** 事件流、runtime、技能库、委派、评测每一块都是独立子系统，完整理解的门槛不低。想快速给自家产品加个 agent 的团队，直接抄 OpenHands 的全套架构通常得不偿失——应该抄的是它的**分层思想**。
- **演进中的不稳定。** 从 OpenDevin 到 OpenHands 再到 V1 SDK / Agent Canvas，项目的 API 和目录结构变动频繁，基于它做二次开发需要跟紧版本。

一句话总结：OpenHands 证明了 harness 可以被系统地平台化、可复现地研究，但它自己不是「最轻」或「最强」的 agent——它是让「最轻」和「最强」可以被度量出来的那套仪器。

## 延伸阅读

- [案例：SWE-agent](/case-studies/swe-agent) —— ACI 思想的对照样本：小而精的专用 harness
- [案例：Devin](/case-studies/devin) —— OpenDevin 当年对标的商业产品
- [案例：Aider](/case-studies/aider) —— 另一个把「编辑工具」打磨到极致的开源路线
- [Agent 循环](/components/agent-loop) —— `step(state) -> action` 的通用形态
- [上下文工程](/components/context-engineering) —— 事件流如何变成 prompt，以及压缩问题
- [工具](/components/tools) —— CodeAct 与 function calling 的动作空间之争
- [权限与人机协同](/components/permissions) —— 沙箱之外，「何时停下来问人」的设计
- [核心论文](/papers/core-papers) —— CodeAct 与平台论文的更多背景
- [动手实现一个最小 harness](/practice/build-your-own) —— 把本文的分层思想落到几百行代码

## 参考资料

- [OpenHands: An Open Platform for AI Software Developers as Generalist Agents（arXiv:2407.16741）](https://arxiv.org/abs/2407.16741)
- [Executable Code Actions Elicit Better LLM Agents（arXiv:2402.01030，ICML 2024）](https://arxiv.org/abs/2402.01030)
- [OpenHands GitHub 仓库](https://github.com/OpenHands/OpenHands)
- [OpenHands 官方文档：Microagents 概览](https://docs.openhands.dev/openhands/usage/microagents/microagents-overview)
- [OpenHands 官方文档：LLM 配置（LiteLLM）](https://docs.openhands.dev/openhands/usage/llms)
- [OpenHands 官方文档：架构总览](https://docs.openhands.dev/openhands/usage/architecture/backend)
