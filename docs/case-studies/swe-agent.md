---
title: 案例：SWE-agent
description: 普林斯顿团队的 SWE-agent 是"harness 设计即研究"的典范：它提出 Agent-Computer Interface（ACI）概念，用为语言模型专门设计的命令与反馈格式，在 SWE-bench 上取得了远超非交互式基线的成绩。
---

# 案例：SWE-agent

SWE-agent 是普林斯顿大学 NLP 团队（John Yang、Carlos E. Jimenez、Alexander Wettig、Kilian Lieret、Shunyu Yao、Karthik Narasimhan、Ofir Press 等人）于 2024 年 5 月发布、被 NeurIPS 2024 接收的一篇论文及其配套开源系统。它的任务设定很朴素：给 agent 一个真实的 GitHub issue 和整个代码仓库，让它自动定位问题、修改代码、提交修复。

真正让它成为经典案例的，不是它"又做了一个编程 agent"，而是它把一件大家默认的事情变成了研究对象：**agent 与计算机之间的接口本身**。论文标题就点明了主旨——*Agent-Computer Interfaces Enable Automated Software Engineering*（智能体-计算机接口使自动化软件工程成为可能）。

在 harness 的视角下，SWE-agent 是最纯粹的"学术论文驱动 harness 设计"代表作：它几乎没有复杂的规划器、没有多 agent 编排，全部精力都花在了一件事上——**模型每一步看到什么、能用什么动作、失败后收到什么反馈**。这正是 harness 的核心命题。

## 背景：SWE-bench 与"非交互式"的天花板

理解 SWE-agent 之前，需要先理解它的评测基准 SWE-bench（同样出自普林斯顿团队，ICLR 2024 论文）。SWE-bench 从 12 个流行 Python 开源项目（django、scikit-learn、sympy 等）中挖掘真实 issue 及其对应的合并 PR，要求系统自动生成能通过相关测试的补丁。

在 SWE-agent 之前，主流做法是把 issue 描述和检索到的相关代码片段**一次性塞进 prompt**，让模型直接输出补丁——这是一种"非交互式"（non-interactive）的做法。它的问题显而易见：

- 真实仓库动辄数十万行，检索器给不全上下文；
- 模型无法验证自己的补丁，错了也不知道；
- 修 bug 本质上是**迭代**过程：定位 → 读代码 → 假设 → 修改 → 跑测试 → 修正，一次性生成违背了这个过程的本质。

SWE-agent 换了个思路：不给模型"一张试卷"，而是给它"一台电脑"，让它像人类工程师一样在仓库里工作。问题是——**人类工程师用的那台"电脑"（shell、编辑器、IDE），适合语言模型吗？** 论文的回答是：不适合，而这正是 ACI 概念的起点。

## 核心概念：ACI（Agent-Computer Interface）

ACI 是这篇论文最重要的概念贡献。它的类比对象是 HCI（Human-Computer Interface，人机交互）：

::: info 论文的核心论点
人类在复杂任务上受益于专门设计的软件（如 IDE）。语言模型是**一类新的"终端用户"**，有自己的能力与局限，同样值得专门为其设计的接口。正如 HCI 研究如何让人用好计算机，ACI 研究如何让 LM 用好计算机。
:::

这个类比的份量在于：它把"harness 该长成什么样"从一个工程调参问题，提升为一个可以系统研究的设计问题。为什么为人设计的界面不适合 LM？论文和实践层面可以列出这些具体差异：

| 维度 | 人类工程师 | 语言模型 |
| --- | --- | --- |
| 视觉处理 | 擅长扫视语法高亮、滚动的大文件 | 逐 token 读，长输出浪费预算且稀释注意力 |
| 记忆 | 能记住刚看过的文件结构、变量名 | 只有上下文窗口，需要重复呈现关键信息 |
| 错误恢复 | 看到堆栈报错能直觉定位 | 需要**格式化、可解析**的错误反馈才能可靠纠正 |
| 操作粒度 | 一次击键/一次鼠标操作 | 一次动作就是一次推理调用，**粒度太细成本爆炸** |
| 语法容错 | 手抖了编辑器会实时提示 | 一次格式错误的编辑可能让后续全部跑偏 |

举个例子：`vim` 对人极其高效，对 LM 却是灾难——模态状态不可见、编辑结果不回显、一个误操作就困住。反过来，一个对 LM 友好的"编辑器"应该是：**无状态的、每次操作都回显结果窗口、带行号、一次最多展示固定行数、提交前自动做语法检查**。这就是 SWE-agent 实际构建的东西。

## ACI 的具体设计

SWE-agent 的 ACI 由三部分组成：定制命令、反馈格式、防护栏（guardrails）。以下按论文与开源仓库的实现逐一拆解。

### 定制命令：为 LM 重新设计"编辑器"

SWE-agent 没有让模型直接用裸 shell 操作文件（虽然 shell 也可用），而是提供了一组定制命令。代表性的有：

| 命令 | 作用 | 设计意图 |
| --- | --- | --- |
| `open <path> [line]` | 打开文件，显示以某行为中心的窗口 | 一次只给固定行数（默认约 100 行），附行号 |
| `goto <line>` | 跳到当前文件的指定行 | 把"翻文件"变成显式、可预测的动作 |
| `scroll_up` / `scroll_down` | 上下滚动一个窗口 | 粒度与上下文窗口匹配，而非与人的手指匹配 |
| `search_dir <term> [dir]` | 在目录中搜索关键词 | 返回压缩的文件名 + 行号列表，而非原始 grep 输出 |
| `search_file <term> [file]` | 在当前文件内搜索 | 同上，输出为"命中清单"而非上下文洪流 |
| `find_file <name> [dir]` | 按文件名查找 | 常见操作的专用捷径 |
| `create <path>` | 创建新文件并进入编辑 | 把多步 shell 操作合并为一个动作 |
| `edit <start>:<end>` + 替换文本 | 替换指定行区间的内容 | 基于行号的精确编辑，**提交前自动 lint** |

注意贯穿其中的两条设计原则：

1. **合并高频操作序列为单条命令**。人做"搜索→看结果→打开文件→跳到那一行"是四个小动作；对 LM 来说每一跳都是一次完整的推理回合。ACI 把这些序列压缩成一条语义明确的命令，既省 token 又减少出错环节。
2. **命令是无状态的、自描述的**。每条命令的输入输出都在当前回合内闭合，不依赖隐藏状态（对比 vim 的模式），模型不需要"记住界面现在处于什么模式"。

### 反馈格式：每次动作都回显"工作区状态"

ACI 的另一半是观测（observation）设计。SWE-agent 的每一回合，模型收到的不是裸终端输出，而是结构化回显。一次 `open` 的反馈大致长这样：

```text
[File: /repo/django/core/exceptions.py (120 lines total)]
  1: """
  2: Global Django exception and warning classes.
  3: """
  ...
 45: class FieldDoesNotExist(Exception):
 46:     """The requested model field does not exist"""
 47:     def __init__(self, model_field_name):
 48:         ...
 ...
(55 more lines above, 20 more lines below)
```

关键设计点：

- **固定窗口大小**：无论文件多大，每次只展示约 100 行，附带"上方/下方还有多少行"的元信息，模型对文件规模始终有感知；
- **行号始终在场**：为后续 `edit 45:52` 这类基于行号的编辑提供锚点；
- **长输出截断**：命令输出过长时保留首尾、截断中段，并明确告知截断量，避免一次 `pytest` 报错把上下文撑爆。

这与通用 shell 的哲学完全相反：shell 假设用户能自己处理输出，ACI 假设输出必须先为模型"裁剪"过。

### 防护栏：在动作生效前拦截错误

SWE-agent 最体现"为 LM 设计"精神的，是它内置的防护栏（guardrails）。典型的例子是 `edit` 命令的 **lint 检查**：模型提交的替换文本会先过一遍语法检查，如果不通过，编辑**不会生效**，而是返回一条解释性错误：

```text
Your proposed edit has introduced new syntax error(s).
Please read the error message carefully and then retry editing the file.

ERRORS:
- E999 IndentationError: unexpected indent (line 47)

This is how your edit would have looked if applied
-------------------------------------------------
[File: /repo/django/core/exceptions.py (120 lines total)]
 45: class FieldDoesNotExist(Exception):
 46:     """The requested model field does not exist"""
 47:         def __init__(self, model_field_name):
-------------------------------------------------
```

这个设计背后是论文明确总结的一条经验：**让错误发生在便宜的地方**。如果带语法错误的编辑直接落盘，模型往往在好几个回合之后跑测试时才发现，此时要回溯定位"哪一步写坏了"代价很高；在编辑提交前拦截，反馈回路缩短到一个回合。类似的还有：对格式非法的命令调用返回"用法提示 + 期望格式示例"，而不是静默失败。

### 整体循环

把这些组件拼起来，SWE-agent 的运行循环是一个典型的 ReAct 式 thought–action–observation 循环：

```text
┌─────────────────────────────────────────────────────────────┐
│                        任务输入                              │
│   GitHub issue 描述 + 仓库环境 + ACI 命令手册(system prompt) │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│   LM 推理回合                                               │
│   Thought: 我需要先定位报错中提到的 validate() 方法          │
│   Action:  search_dir "def validate" django/db/models        │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│   ACI 执行层（harness 本体）                                 │
│   · 解析动作 → 调用定制命令 / bash                          │
│   · 裁剪输出（窗口化、截断、行号）                           │
│   · 防护栏检查（lint、格式校验）                             │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│   Observation 回显给 LM → 下一回合……                        │
│   （直到模型输出 submit，提取 git diff 作为补丁）            │
└─────────────────────────────────────────────────────────────┘
```

可以看到，模型侧没有任何特殊训练——全部"智能"都在 ACI 执行层与回显格式里。这正是 harness 的价值主张。

## 成绩与意义

SWE-agent 论文报告的核心成绩（使用 GPT-4 Turbo 作为底座）：

- **SWE-bench 完整测试集：pass@1 约 12.5%**（论文摘要口径 12.5%，仓库 README 口径 12.47%），是当时 SWE-bench 上的最佳成绩，且明显超过此前非交互式方法的最佳水平；
- **SWE-bench Lite：约 23%**（Lite 是完整集的 300 题子集，难度分布更友好）；
- **HumanEvalFix：87.7% pass@1**，同样是当时的最佳成绩。

这个数字今天看来不高，但它的意义不在绝对值：

1. **它证明了"交互式 agent 路线"在真实软件工程任务上可行**。此前 SWE-bench 上的主流是一次性检索+生成，SWE-agent 之后，排行榜几乎全部被"agent + 定制工具"的形态占据。
2. **它把接口设计变成了可消融（ablation）的实验变量**。论文系统分析了 ACI 各设计（窗口大小、错误反馈、lint 防护栏等）对行为与成功率的影响，为后续工作提供了"哪些设计真的重要"的经验证据。
3. **它留下了一个可复用的概念框架**。ACI 这个词已被后续大量工作沿用，成为讨论"agent 工具设计"的标准词汇。

::: warning 解读数字时的两个注意点
- 论文成绩基于 GPT-4 Turbo 与当时的 SWE-bench 完整集；此后排行榜经历了 SWE-bench Verified（OpenAI 人工筛选的 500 题子集）等演进，不同口径的数字不可直接横比。
- SWE-agent 的成绩是"harness + 模型"的联合结果。论文的意义恰恰是证明：**在同一模型下，ACI 设计不同，成绩可以差出量级**。
:::

## 后续工作：从 SWE-agent 出发的一条线

SWE-agent 不是一个孤立系统，它处在一个清晰的演化链条上，这条线本身就是"harness 研究"的编年史：

- **SWE-bench（2023.10，ICLR 2024）**：同一团队先造了评测基准，定义了"真实 issue → 真实补丁"的任务形态；
- **SWE-agent（2024.05，NeurIPS 2024）**：提出 ACI，确立交互式 agent 路线；
- **EnIGMA（2024.09 预印本）**：把 ACI 思想迁移到网络安全领域。团队发现 CTF（Capture The Flag）攻防挑战需要 gdb 调试器、远程服务连接这类**交互式程序**，而 SWE-agent 的 ACI 只支持"发一条命令、拿一份输出"的非交互模式。EnIGMA 引入交互式智能体工具（Interactive Agent Tools），让 agent 首次能与持续会话的程序交互，在 390 道 CTF 题目上达到 NYU CTF、Intercode-CTF、CyBench 三个基准的最佳水平；在 NYU CTF 完整基准上解出 13.5%（27/200），是此前最佳 agent 的三倍以上。EnIGMA 还顺带研究了一个 harness 层面的新现象——"soliloquizing"（自言自语）：模型不与环境交互，而是幻觉出一份观测结果继续推理；
- **SWE-agent 1.0 / mini-SWE-agent（2025）**：仓库持续迭代。按项目公告，2025 年 2 月 SWE-agent 1.0 搭配 Claude 3.7 达到 SWE-bench 完整集最佳；2025 年 7 月发布的 mini-SWE-agent 用约 100 行 Python 在 SWE-bench Verified 上达到 65%，项目方推荐其取代原版 SWE-agent——这本身是一个意味深长的信号：**当模型足够强，harness 可以极简**（关于这一点，见[模型与 Harness 之争](/guide/model-vs-harness)）。

## 范式价值：harness 设计即研究

SWE-agent 对 agent 研究方法论的最大贡献，是把 harness 从"不可见的胶水代码"变成了**一等研究对象**。它示范了一种范式：

1. **提出设计假说**：为人设计的界面不适合 LM（类比 HCI 提出 ACI）；
2. **给出设计原则**：命令要合并高频序列、无状态、自描述；反馈要窗口化、带行号、可解析；错误要在便宜处拦截；
3. **用受控实验验证**：消融每个设计维度，量化其对成功率的影响，并分析行为层面的变化（例如模型是否更高效地导航仓库）；
4. **沉淀为可复用资产**：ACI 概念、命令设计模式、防护栏思想被后续工作广泛继承。

对比同期的很多 agent 论文（重点是提示词技巧或规划算法），SWE-agent 的独特之处在于它研究的是**模型与环境之间的接触面**。这个接触面恰恰是每个自建 agent 的工程师每天都要面对、却很少被系统化讨论的问题。

## 给工程师的可迁移启示：为你自己的 agent 设计 ACI

即使你做的不是编程 agent，SWE-agent 的方法论几乎可以逐条照搬。下面是一份可直接使用的 ACI 设计清单：

**命令（工具）设计**

- 观察你的 agent 的高频动作序列，把稳定出现的 3~5 步序列合并成一个复合工具（`search_dir` 之于 `grep + open + goto`）；
- 工具要无状态：每次调用的结果自包含，不要让模型"记住界面处于什么模式"；
- 工具参数宁少勿多，每个参数都要有明确的格式示例——格式错误的调用是 agent 失败的第一大来源。

**反馈（观测）设计**

- 为输出设定固定预算：窗口化、首尾保留中间截断、永远报告截断量；
- 给输出加锚点：行号、ID、路径，让后续动作能精确引用；
- 错误信息写给模型看，不是写给人看：说明错在哪、期望的格式是什么、给一个正确示例。

**防护栏**

- 列出"一旦生效就很难挽回/很难发现"的动作类别（写文件、改数据库、发请求），在这些动作前加廉价校验（语法检查、schema 校验、dry-run）；
- 校验失败时不要静默丢弃，要返回结构化的纠正性反馈——反馈回路每缩短一个回合，成功率就上一截。

**实验方法**

- 把每个设计决策当作可消融的变量：固定模型与任务集，只改一个 ACI 维度，看成功率与回合数的变化；
- 除了成功率，还看行为指标：平均每任务回合数、无效动作比例、重复动作比例——这些往往先于成功率暴露接口问题。

::: tip 一句话版本
把 LM 当成你的"用户"：为它的感知方式（token、上下文窗口）设计界面，为它的失败模式（格式错误、幻觉、忘事）设计防护栏，然后用消融实验验证每一个设计。
:::

## 权衡与取舍

ACI 路线也不是免费的午餐，工程上要清醒地认识几个代价：

- **定制接口 vs. 通用能力**：定制命令越多，agent 越依赖你的接口文档，迁移到新领域（如 EnIGMA 面对的 CTF）时需要重新设计；裸 bash 虽难用但通用。mini-SWE-agent 的 100 行方案走了另一个极端——只给 bash，把一切留给模型。
- **防护栏 vs. 自主性**：拦截式防护栏防止了低级错误，也可能拦掉"非常规但正确"的操作。论文的取舍是：对**可恢复性低、错误发现晚**的动作加防护栏，其余放开。
- **窗口大小**：观测窗口太小，模型要花更多回合翻文件；太大，成本上升且注意力被稀释。论文中的约 100 行是实验调出来的甜点，你的任务需要自己的甜点。
- **接口即先验**：你设计的命令集合，本质上是你对"这个任务该怎么解"的先验编码。先验准，agent 事半功倍；先验偏，agent 被你锁死在错误的工作流里。ACI 设计得越精巧，越要警惕这一点。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——ACI 在 harness 整体版图中的位置
- [Harness 解剖](/guide/anatomy)——把 SWE-agent 的组件映射到通用解剖框架
- [核心组件：工具系统](/components/tools)——工具设计的通用原则
- [核心组件：上下文工程](/components/context-engineering)——观测裁剪、窗口化属于上下文工程的范畴
- [核心组件：可观测性](/components/observability)——EnIGMA 发现的 soliloquizing 这类行为问题如何被监测
- [案例：OpenHands](/case-studies/openhands)——另一条 SWE-bench 系 harness 路线
- [实践：构建你自己的 Agent](/practice/build-your-own)——把 ACI 清单落到代码
- [论文导读：核心论文](/papers/core-papers)——SWE-agent 论文的阅读路径

## 参考资料

- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering（arXiv:2405.15793）](https://arxiv.org/abs/2405.15793)
- [SWE-agent GitHub 仓库（SWE-agent/SWE-agent）](https://github.com/SWE-agent/SWE-agent)
- [EnIGMA: Enhanced Interactive Generative Model Agent for CTF Challenges（arXiv:2409.16165）](https://arxiv.org/abs/2409.16165)
- [SWE-bench: Can Language Models Resolve Real-World GitHub Issues?（ICLR 2024）](https://arxiv.org/abs/2310.06770)
- [mini-SWE-agent 项目（SWE-agent 团队公告，2025.07）](https://github.com/SWE-agent/SWE-agent)
