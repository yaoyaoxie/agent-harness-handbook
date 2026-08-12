---
title: 案例：Aider
description: Aider 是最适合研究 harness 细节的开源 CLI 结对编程 agent——它的编辑格式（edit format）取舍、tree-sitter repo map、lint/test 反馈环和 git 深度集成，每一项都有可核查的 benchmark 数据支撑。
---

# 案例：Aider

[Aider](https://aider.chat) 是 Paul Gauthier 于 2023 年创建的开源 CLI 结对编程（pair programming）agent。它没有 GUI、没有子代理编排、没有复杂的规划模块——它的全部「智能」几乎只由四样东西构成：**编辑格式（edit format）**、**repo map**、**lint/test 反馈环**和 **git 集成**。

这正是 aider 在 harness 研究中的独特价值：它足够简单，简单到每个设计决策的效果都能被隔离出来测量。而 aider 作者也确实这么做了——官方维护的 [LLM leaderboard](https://aider.chat/docs/leaderboards/) 和一系列 benchmark 博客文章，可能是公开资料里关于「harness 细节如何影响成功率」最扎实的实验记录。

::: info 为什么先读这篇
在 [模型与 Harness](/guide/model-vs-harness) 中我们论证了「同一模型，不同 harness，能力天差地别」。Aider 是这个论点的最佳证据：它常年用同一批模型做实验，仅仅改变**让模型用什么格式输出编辑**，成功率就能相差 3 倍。
:::

## 整体结构：一个围绕「编辑」的循环

```
┌──────────────────────────────────────────────────────────┐
│  aider（Python CLI，运行在你的本地 git 仓库中）             │
│                                                          │
│   系统提示词（含 edit format 规范）                         │
│        +                                                 │
│   repo map（tree-sitter 提取的代码库符号地图，默认 ≤1k token）│
│        +                                                 │
│   用户 /add 进会话的文件全文                                │
│        +                                                 │
│   对话历史 / lint / test 的错误输出                         │
│        │                                                 │
│        ▼                                                 │
│   LLM ──── 按 edit format 输出编辑 ────► 解析 & 弹性应用     │
│        ▲                                    │            │
│        │                                    ▼            │
│        │                              写入文件            │
│        │                                    │            │
│        │                     ┌──────────────┼───────────┐│
│        │                     ▼              ▼           ▼│
│        │                  auto-lint     auto-test    git │
│        │                  （有错则把错误  （同理）    自动 │
│        └────────反馈────────┘                     commit │
└──────────────────────────────────────────────────────────┘
```

注意这个图里**没有**的部分：没有任务分解器，没有多代理，没有长期记忆。Aider 把全部赌注押在一件事上——让模型「把代码改对」这个核心动作的成功率最大化。下面我们逐个拆开看。

## 胜负手：编辑格式（edit format）

### 问题定义

LLM 在对话里「写代码」和它写的代码「被可靠地落盘成正确文件」之间，隔着一个解析层。这个解析层的输入格式就是编辑格式——它是 harness 与模型之间的**输出协议**。协议设计得不好，模型再聪明也白搭：编辑无法应用、应用到错误位置、或者模型为了迁就格式写出更差的代码。

Aider 维护着一个格式家族，按模型能力分派（可用 `--edit-format` 强制指定）：

| 格式 | 内容 | 适用场景 |
|---|---|---|
| `whole` | 返回**整个文件**的更新版 | 弱模型；小文件；最可靠但最贵最慢 |
| `diff` | `<<<<<<< SEARCH` / `=======` / `>>>>>>> REPLACE` 搜索替换块 | 当前主流强模型的默认格式 |
| `diff-fenced` | 同 diff，但文件路径放进代码围栏内部 | Gemini 系列（它们经常不遵守 diff 的围栏约定） |
| `udiff` | 修改简化版的 unified diff | 历史上为治 GPT-4 Turbo 的「懒惰编码」而生 |
| `editor-diff` / `editor-whole` | diff/whole 的精简提示词版 | architect 模式下给「编辑模型」用 |

`diff` 格式的样子（语法刻意模仿 git 合并冲突标记，因为模型在训练数据里见过无数次）：

````
mathweb/flask/app.py
```
<<<<<<< SEARCH
from flask import Flask
=======
import math
from flask import Flask
>>>>>>> REPLACE
```
````

### 实验一：纯文本打败 function calling（2023-07）

Aider 最早的 benchmark 基于 Exercism 的 133 道 Python 练习题：模型读题、改实现文件、跑单测，测「端到端把编辑正确落盘并通过测试」的比例。

2023 年 7 月的结果中有一个反直觉发现：当时 OpenAI 刚推出 function calling API，作者预期它能提升结构化输出的可靠性，于是实现了 `whole-func` 和 `diff-func` 两种基于 function call 的格式。结果——**function call 格式在所有模型上都比纯文本格式差**。GPT-3.5 甚至会幻觉出不存在的函数调用：返回 `"name": "python"` 并把整个 Python 文件塞进 `arguments` 字段。

作者的解释值得记住（它后来成为 aider 的方法论）：

> 想象你在 Slack 上请一个同事改代码，他是愿意直接贴一段 markdown 代码块，还是手敲一段正确转义的、语法合法的 JSON 数据结构？

输出格式每复杂一分，模型就要从「思考代码」里分出一分注意力去「思考格式」，并且格式错误的概率也随之上升。**降低格式的认知开销，模型的编码质量和对格式的遵从度会同时变好。**

### 实验二：udiff 把 GPT-4 Turbo 的得分从 20% 拉到 61%（2023-12）

GPT-4 Turbo 发布后，用户普遍抱怨它「懒惰」——让它改大文件，它输出 `# ... 原有代码保持不变 ...` 这样的注释糊弄过去。Aider 作者专门构造了一个「懒惰 benchmark」：从 9 个流行开源 Python 项目中用 AST 扫描出 89 个重构任务（把类方法提取为顶层函数），文件大到足以诱发懒惰行为。

在 `gpt-4-1106-preview` 上的结果：

| 配置 | 得分 |
|---|---|
| SEARCH/REPLACE 块格式（基线） | **20%** |
| udiff（简化 unified diff）格式 | **61%** |
| 基线 + 「用户是盲人、没有手、会给你 2000 美元小费」情感诉求提示 | 比基线更差 |
| udiff + 同样的情感诉求提示 | 同样变差 |

同一模型，只换输出格式，成功率提升约 3 倍。而网上流传的「装可怜、许诺小费」提示词偏方，在受控测量下是**负优化**——这是「harness 决策要靠 benchmark 说话，不要靠民间传说」的教科书案例。

为什么 unified diff 有效？作者总结的四条原则：

- **FAMILIAR（熟悉）**：unified diff 是 `git diff` 的默认输出，模型在训练语料里见过海量样本。
- **SIMPLE（简单）**：aider 明确告诉模型**不要写行号**（`@@ ... @@` 代替 `@@ -2,4 +3,5 @@`），因为实验反复证明 LLM 不擅长处理行号。每个 hunk 退化成一次搜索替换。
- **HIGH LEVEL（高层）**：系统提示鼓励模型输出「整个函数的两个连贯版本」，而不是逐行的外科手术式最小编辑。去掉这条提示，编辑错误率上升 30–50%。
- **FLEXIBLE（弹性）**：模型输出的 diff 经常不完美（漏注释、忘加 `+` 前缀、整体少缩进）。Aider 的应用器（apply 逻辑）有一整套渐进宽松的容错策略：归一化 hunk、相对缩进匹配、把大 hunk 拆成小 hunk 逐个尝试等。**禁用弹性应用后，编辑错误率上升 9 倍。**

::: tip 输出协议的两端都要工程化
注意最后一点：好的编辑格式不只是「提示词里规定格式」，还包括**消费端一个宽容的解析/应用器**。模型输出永远会有瑕疵，harness 的职责是把 95 分的输出当成 100 分用，而不是因为一个小瑕疵就丢弃整次工作（或花钱让模型重试）。
:::

### 今天的榜单：格式与模型的匹配仍在继续

Aider 官方 leaderboard 持续用 polyglot benchmark（多语言版 Exercism 风格练习）测量新模型。每个条目除了通过率，还公开**「使用正确编辑格式的比例」**这一列——也就是说，「模型是否遵守输出协议」被当作独立于「代码是否正确」的一等指标长期监控。截至本页写作时抓取的榜单快照（含 GPT-5、Gemini 2.5 Pro 等 2025 年模型）：GPT-5 (high) 以 88.0% 居首，使用 `diff` 格式，格式遵从率 91.6%；Gemini 2.5 Pro 使用 `diff-fenced`；而一些较弱的开放模型仍用 `whole` 格式。

榜单本身也在讲故事：强模型收敛到 `diff` 家族，弱模型退回 `whole`——**编辑格式是随模型能力分档的 harness 参数，没有银弹**。

## Repo map：用 tree-sitter 压缩整个代码库

### 问题：上下文窗口装不下整个仓库

让模型在大型仓库里改代码，需要三类信息：改哪里、相关代码长什么样、怎么改。整库塞进上下文不现实，手动 `/add` 文件又太费人。Aider 的答案是 repo map——一张**整个 git 仓库的符号级地图**，随每次请求发给模型。

### 机制

1. **提取**：用 [tree-sitter](https://tree-sitter.github.io)（IDE 和 LSP 服务器广泛使用的增量解析器）把每个源文件解析成 AST，找出所有符号**定义**（类、函数、方法及其完整签名）和**引用**位置。Aider 最初用 ctags 做这个，2023 年 10 月切换到 tree-sitter，拿到了更丰富的签名信息和开箱即用的多语言支持（通过 `py-tree-sitter-languages` 包）。

2. **排序**：把仓库建成一张图——源文件是节点，依赖/引用关系是边——在图上跑图排序算法（graph ranking），找出「被引用最多」即最重要的符号。

3. **裁剪**：在 token 预算内（`--map-tokens`，默认 1024 token）装下排名最高的符号定义。预算会根据会话状态动态调整：当用户还没 `/add` 任何文件时，aider 会显著放大 repo map，尽量让模型先理解整个仓库。

地图长这样（aider 自己仓库的节选）：

```
aider/coders/base_coder.py:
⋮...
│class Coder:
│    abs_fnames = None
⋮...
│    @classmethod
│    def create(
│        self,
│        main_model,
│        edit_format,
│        io,
⋮...
│    def run(self, with_message=None):
⋮...
```

### 为什么这是天才设计

它精准命中了「模型需要什么」和「模型不需要什么」的边界：

- 模型**不需要**看到 `BarLog` 子系统的全部实现，它只需要看到签名，就知道怎么调用。
- 模型**需要**知道仓库里存在哪些抽象，这样它写新代码时会复用而不是重造。
- 当地图不够用时，模型可以**以地图为索引**，主动要求查看具体文件——aider 会把这些文件加进会话。Repo map 因此同时是「压缩上下文」和「检索入口」。

这是[上下文工程](/components/context-engineering)的经典范式：**不检索文档块，而是检索结构**。向量嵌入把代码当散文切，tree-sitter 把代码当代码切——对「调用关系」这类问题，后者的信息密度高出一个数量级。

::: details 对比：repo map vs. RAG
很多 coding agent 用向量数据库做代码检索（embed → 最近邻）。Repo map 的思路不同：它利用的是代码的**静态结构**（定义/引用图），而非语义相似度。代价是它回答不了「哪里处理了用户登录」这类语义问题；收益是零幻觉（签名逐字来自源码）、零基础设施（不需要 embedding 模型和向量库）、且结果确定可复现。两者可以互补——但 aider 证明了纯结构方案已经能走很远。
:::

## Lint / Test 反馈环

Aider 在每次 AI 编辑后自动执行两道检查，把错误输出反馈给模型自我修复：

- **自动 lint**：内置主流语言的 linter（也可用 `--lint-cmd` 或按语言配置），默认对所有被编辑的文件执行（`--no-auto-lint` 可关）。约定很朴素：linter 把错误打到 stdout/stderr、返回非零退出码。
- **测试**：`/test` 手动跑，`--test-cmd` + `--auto-test` 让每次编辑后自动跑。测试失败时 aider 自动尝试修复。

这个「编辑 → 验证 → 把验证结果喂回模型」的循环，正是 aider 早期 benchmark 的内置环节——Exercism benchmark 里每个任务都有第二次机会：第一次提交后若单测失败，把错误输出（截取前 50 行）发回模型修复。榜单的柱状图里「第一次尝试」与「最终结果」之间的差距，就是反馈环的净收益。

::: warning 反馈环的两个工程细节
- **截断**：错误输出只发前 50 行，防止撑爆上下文。反馈信息也要做上下文预算。
- **别把 formatter 当 linter 用**：很多格式化工具「改了文件就返回非零」，aider 会误以为有 lint 错误而让模型去「修」。官方建议把这类工具包一层 shell 脚本（跑两遍，第二遍的退出码才是真实状态）。外部工具的接口契约（退出码语义）也是 harness 契约的一部分。
:::

## Git 深度集成：把版本控制变成 agent 的「撤销系统」

Aider 假设你工作在 git 仓库里（不是的话它会主动提议 `git init`），然后把 git 用到了三个层次：

1. **自动 commit**：每次 AI 编辑落盘后立刻提交，提交信息由弱模型（`--weak-model`）根据 diff 和对话历史生成，默认遵循 Conventional Commits 规范。
2. **脏文件保护**：编辑一个已有未提交改动的文件前，aider 先把你的改动单独提交——保证「你的编辑」和「AI 的编辑」在 git 历史里泾渭分明，AI 改坏了永远可以无损回退。
3. **会话内操作**：`/undo` 撤销上次 AI 修改、`/diff` 查看上轮以来所有改动、`/commit`、`/git` 执行原生命令。

此外还有归因机制：aider 创作的 commit 会在 author/committer 名字后追加 `(aider)`（可配置为 `aider: ` 前缀或 `Co-authored-by` trailer）。

从 harness 视角看，这组设计的本质是把 **agent 的探索性行为建立在一个可靠的回滚基座上**。Agent 必然犯错；harness 的职责不是消灭错误，而是让错误廉价、可见、可逆。Git 是现成的、经过三十年验证的「文件系统时间机器」，aider 没有重造它，只是纪律性地每步都落一个 checkpoint。

## 权衡与取舍

Aider 的极简不是免费的，它的边界同样清晰：

- **人始终在回路里选文件**。Repo map 解决「理解」，但「改哪里」主要靠用户 `/add`。作者在 repo map 文章里明确把「自动找出所有需要修改的文件」列为未完成的未来工作。这是把规划权留给人的取舍——少了自主性，换来了可预测性。
- **单文件/少文件任务最强，跨仓库大改造吃力**。没有子代理并行，没有任务分解，一次会话就是一条线性的编辑流。
- **`whole` 格式的成本悬崖**。弱模型只能用整文件重写，大文件的延迟和 token 成本会让体验崩塌——harness 的能力上限被它能用得起的最强格式锁死。
- **benchmark 的适用范围**。Aider 的 benchmark 以中小规模练习和重构任务为主，「在 Exercism 上 88%」不等于「在你的 50 万行 monorepo 上同样出色」。它的价值在于**相对比较**（同 benchmark 下格式 A vs 格式 B），而非绝对预测。

## 从 Aider 学到的

1. **输出格式是 harness 的第一战场**。同一个 GPT-4 Turbo，SEARCH/REPLACE 拿 20 分，udiff 拿 61 分。你在提示词、检索、规划上做的大量优化，可能被一个糟糕的输出协议全部抵消。设计输出格式时问自己：模型在训练数据里见过它多少次？它需要模型算行号吗？解析失败时代价是什么？
2. **消费端要宽容**。Aider 的弹性 diff 应用器把编辑错误率降低 9 倍——不要假设模型会严格守约，harness 要在解析层吸收抖动。
3. **用代码的结构做上下文，而不是用代码的文本做上下文**。Tree-sitter + 图排序的 repo map 证明：约 1k token 的符号地图，可以替代几万 token 的全文塞入。
4. **每个决策都要能测量**。Aider 作者的博客几乎每篇都是一次受控实验：基线、消融（禁用弹性解析、去掉高层 diff 提示）、量化结论。「情感诉求提示词更差」这种结论，只有 benchmark 能给。
5. **用基础设施的存量，而不是发明新的**。Git 做回滚，linter 退出码做验证契约，tree-sitter 做结构提取——aider 的每一层都站在成熟工具的肩膀上。

## 延伸阅读

- [核心组件：上下文工程](/components/context-engineering)——repo map 是「压缩」与「检索」两章的具体实现
- [核心组件：工具](/components/tools)——编辑格式本质上是「模型输出 → 文件系统」这条工具链的协议设计
- [核心组件：可观测性](/components/observability)——aider 的 benchmark 文化如何落地为 harness 的评估体系
- [案例：Claude Code](/case-studies/claude-code)——另一种哲学：工具调用 + 权限门控 + 子代理
- [案例：SWE-agent](/case-studies/swe-agent)——同样极简，但赌注押在 ACI（Agent-Computer Interface）上
- [实践：设计原则](/practice/design-principles)——把本文的五条经验放进更一般的设计框架

## 参考资料

- [Aider LLM Leaderboards](https://aider.chat/docs/leaderboards/)——各模型通过率与编辑格式遵从率（本页快照含 GPT-5 88.0%、Gemini 2.5 Pro 等）
- [Edit formats - aider docs](https://aider.chat/docs/more/edit-formats.html)——whole/diff/diff-fenced/udiff/editor 格式定义
- [Benchmarking GPT-3.5 and GPT-4 on code editing (2023-07-02)](https://aider.chat/2023/07/02/benchmarks.html)——Exercism 133 题 benchmark；function calling 输给纯文本
- [Aider's new unified diff editing format (2023-12-21)](https://aider.chat/2023/12/21/unified-diffs.html)——懒惰 benchmark：20%→61%；消融数据（30–50%、9X）
- [Building a better repository map with tree-sitter (2023-10-22)](https://aider.chat/2023/10/22/repomap.html)——repo map 的 tree-sitter 提取与图排序机制
- [Repository map - aider docs](https://aider.chat/docs/repomap.html)——`--map-tokens` 默认 1024、动态调整
- [Linting and testing - aider docs](https://aider.chat/docs/usage/lint-test.html)——auto-lint/test 与退出码契约
- [Git integration - aider docs](https://aider.chat/docs/git.html)——自动 commit、脏文件保护、`(aider)` 归因
