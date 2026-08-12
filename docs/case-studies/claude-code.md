---
title: Claude Code 案例
description: 深度剖析 Claude Code 的 harness 设计：极简 Unix 风格工具集、TodoWrite 与 plan mode 的规划机制、CLAUDE.md 记忆文件、子代理、hooks、MCP 与权限模式，以及它为什么选择终端而非 IDE——本站组件框架在一个真实产品里的完整组合。
---

# Claude Code 案例：一个"最小厚度"的 Harness

前面 [Harness 的解剖](/guide/anatomy) 把 agent 系统拆成了组件：循环、上下文、工具、规划、记忆、子代理、权限。现在看一个把这些组件全部装进去、且每个组件都做到了"能跑的最简形态"的真实产品——Claude Code。

选它作为本站的总案例，理由有三。第一，它是少见的**模型与 harness 同厂垂直整合**的产品：Anthropic 同时训练模型和构建包裹模型的系统，并且公开承认产品力的重心在后者——Claude Agent SDK 的官方定位就是「驱动 Claude Code 的同一套 tools、agent loop 与 context management」（见[什么是 Agent Harness](/guide/what-is-harness)）。第二，它的设计哲学极端克制，创造者 Boris Cherny 在 [Latent Space 的访谈](https://www.latent.space/p/claude-code)里说得很直白：「Claude Code 与其说是一个产品，不如说是一个 Unix 工具（Unix utility）」，团队的产品原则是 "do the simple thing first"。第三，它的内部结构有大量公开材料可查：官方文档、工程博客，以及对其系统提示词和工具定义的[逆向分析](https://weaxsey.org/en/articles/2025-10-12/)，让我们能在证据而非猜测上讨论它的 harness。

本文的论点：**Claude Code 的强不在于任何单个精巧机制，而在于它把每个组件都削减到"刚好够用"的程度，然后把省下的复杂度全部让渡给模型。** 这是理解现代 agent harness 设计最重要的一课。

## 总体结构：一张图看 Claude Code 的 Harness

```text
┌────────────────────── Claude Code (Harness) ──────────────────────┐
│                                                                   │
│  用户输入 ──> system prompt + CLAUDE.md 记忆 + todo list + 历史     │
│                          │                                        │
│                          ▼                                        │
│                 ┌─────────────────┐     Task 工具      ┌────────┐ │
│                 │    Agent Loop   │ ────────────────> │ 子代理  │ │
│                 │ 思考→行动→观察   │ <──── 汇总结果 ─── │(独立上下文)│
│                 └────────┬────────┘                   └────────┘ │
│                          │                                        │
│        ┌─────────────────┼─────────────────┐                      │
│        ▼                 ▼                 ▼                      │
│   Bash/Read/Edit     Glob/Grep        TodoWrite                   │
│   Write/WebFetch     (检索类工具)      ExitPlanMode/Task            │
│        │                                                          │
│  ──────┴──── 权限模式 + hooks（横切：每次工具调用前后把关）───────── │
│                          │                                        │
│                    终端里的真实环境（文件系统/shell/git）            │
└───────────────────────────────────────────────────────────────────┘
```

对照[解剖图](/guide/anatomy)逐项核对：循环、上下文、工具、规划、记忆、子代理、权限——一个不缺，而且每一个都有明确的实现物可以拆解。下面逐个来。

## 工具集：Unix 工具就是最好的 agent 工具

Claude Code 内置工具只有十几个，而且几乎全部是对 Unix 哲学的一次复刻（工具清单与定义可见[逆向分析](https://weaxsey.org/en/articles/2025-10-12/)，官方[设置文档](https://docs.anthropic.com/en/docs/claude-code/settings)的权限规则一节也列出了工具名）：

| 工具 | 对应 Unix 心智模型 | 职责 |
| --- | --- | --- |
| `Bash` | shell 本身 | 执行任意命令：构建、测试、git、包管理 |
| `Read` / `Write` / `Edit` | `cat` / 重定向 / `sed` | 文件读写与精确替换 |
| `Glob` / `Grep` | `find` / `grep` | 按文件名与内容检索代码库 |
| `TodoWrite` | 无（纯上下文工具） | 维护任务清单，见下节 |
| `Task` | `xargs` 式的扇出 | 派生子代理 |
| `WebFetch` / `WebSearch` | `curl` / 搜索引擎 | 获取外部信息 |

注意这个清单**没有**的东西：没有 `read_function_definition`、没有 `find_symbol_by_name`、没有语义索引、没有 LSP 风格的结构化代码工具。一个 2023 年风格的"AI IDE"会为代码理解造一堆专用工具；Claude Code 给模型的就是 `grep`。为什么这样反而是对的？

**第一，模型的预训练语料里全是 Unix。** 二十年来全世界程序员在 Stack Overflow、GitHub、文档里演示的排查和修改流程，绝大多数以 grep/bash/git 的形式存在。用这些工具，模型是在自己的"母语"里工作；每造一个新奇工具，都是在要求模型学一门只有你家产品说的方言。

**第二，通用工具的失败模式比专用工具温和。** 专用工具把"怎么用"编码进了接口，模型只要走错一个字段就死；`grep` 没有字段可走错，查不到就换个 pattern 再查——重试成本极低，这恰好匹配 [agent loop](/components/agent-loop) 的试错节奏。

**第三，组合性。** Unix 工具的价值不在单个工具，而在管道式的组合。Bash 一个工具就把整个生态（`gh`、`aws`、`npm`、测试框架、linter）变成了 agent 的能力集，harness 作者一行适配代码都不用写。官方[最佳实践](https://www.anthropic.com/engineering/claude-code-best-practices)甚至明确建议用户"让 Claude 用 `gh` 这类 CLI 工具与外部服务交互"。

Anthropic 自己的工具设计方法论（[《Writing tools for agents》](https://www.anthropic.com/engineering/writing-tools-for-agents)）把这套思路总结为几条原则：不要逐个包装 API、要为高价值工作流造少数"想得清楚"的工具、工具返回值要高信噪比、工具描述要像写 prompt 一样精心打磨。Claude Code 的内置工具集就是这些原则应用于"编码"这个领域的产物——工具数量刻意压低，边界清晰，返回纯文本。更多讨论见[工具系统](/components/tools)。

::: info 一个常被误解的点
"极简工具集"不等于"harness 偷懒"。恰恰相反：正因为工具是原始的，模型使用的正确性、输出的截断、超长结果的上下文管理，全都压给了 harness 和提示词去处理。逆向分析显示 Claude Code 的系统提示里有大量关于"先读再改"、"Edit 必须精确匹配"、"Bash 优先用专门工具代替"的纪律条款。工具越通用，提示词工程越重——复杂度没有消失，只是从接口层转移到了上下文层。
:::

## 规划：TodoWrite 与 plan mode 的双层结构

Claude Code 的规划机制是[规划与任务分解](/components/planning)一文的主要分析对象，这里只勾勒它在产品里的形态。

**TodoWrite 是交织式规划的标杆实现**：一份三态（pending / in_progress / completed）任务清单驻留在上下文里，模型被要求频繁维护——完成立即标记、同时只能有一个 in_progress、受阻就新增任务而不是硬标完成。它没有任何运行时逻辑，生效机制纯粹是认知卸载（cognitive offloading）：清单始终可见，对抗长任务中的目标漂移。

**plan mode 则是叠加在循环上的人机闸口**：`Shift+Tab` 或 `claude --permission-mode plan` 进入只读模式，模型只能调研不能改动，最后通过 `ExitPlanMode` 工具把计划提交给用户审批，批准后才进入执行。官方最佳实践给出的标准工作流是四段式：**探索 → 计划 → 实现 → 提交**。

::: tip 两个机制为什么都要
TodoWrite 解决的是"模型自己别忘事"（会话内的状态外化），plan mode 解决的是"动手前先给人看"（不可逆操作前的审批点）。前者面向模型的认知局限，后者面向人的信任校准。只保留一个的系统——比如只有 plan mode 的 Cursor 早期规划功能，或只有 todo list 的开源复刻——都只盖住了一半问题。
:::

## 记忆：CLAUDE.md 的极简主义

记忆系统通常被设计成复杂的样子：向量库、检索管道、摘要压缩、遗忘曲线。Claude Code 的答案是：**一个 Markdown 文件，每次会话启动时读进上下文，仅此而已。** Boris Cherny 的原话：团队研究过各种记忆架构和外部产品，最后"ship the simplest thing——一个文件，里面有点东西，会被自动读进上下文"（[Latent Space 访谈](https://www.latent.space/p/claude-code)）。

但这个"最简形态"里有几个深思熟虑的层次（见官方[记忆文档](https://docs.anthropic.com/en/docs/claude-code/memory)）：

- **分层作用域**：组织级（managed policy）→ 用户级（`~/.claude/CLAUDE.md`）→ 项目级（`./CLAUDE.md`，入版本库与团队共享）→ 本地级（`CLAUDE.local.md`，gitignore）。从工作目录逐级向上查找、拼接注入，越靠近当前位置的指令越后出现。
- **惰性加载**：子目录里的 CLAUDE.md 不在启动时加载，只在模型实际读到那个目录的文件时才进入上下文——这是朴素的[上下文工程](/components/context-engineering)：不为用不到的指令付 token。
- **`@path` 导入语法**：可以把 README、package.json 或其他文档链入，最大递归四层。
- **明确的自我认知**：官方文档反复强调 CLAUDE.md 是**上下文而非强制配置**——它作为 user message 注入、模型"尽量遵守"，但没有保证。想要强制，请用 hooks（下节）。

这套机制的工程启示在于**它把"记忆"重新定义成了"约定"**：CLAUDE.md 不进 git 之外的任何存储、不需要索引、人类可以直接编辑审查、随代码库一起演化。它还催生了跨产品的惯例（AGENTS.md 等同类文件），官方文档甚至专门教你怎么用 `@AGENTS.md` 导入让多个 agent 工具共享一份指令。与更重的记忆架构的对比，见[记忆系统](/components/memory)。

## 子代理：上下文隔离是唯一目的

Claude Code 的 `Task` 工具可以把一个子任务派发给子代理：子代理在**独立的上下文窗口**里运行，做完后只把结论汇总回主会话。用户还可以在 `.claude/agents/` 下用带 frontmatter 的 Markdown 文件定义自定义子代理——指定它的系统提示、可用工具子集、甚至用什么模型（官方[子代理文档](https://docs.anthropic.com/en/docs/claude-code/sub-agents)）。

这里最重要的设计判断是**子代理的第一价值不是"角色扮演"，而是上下文预算管理**。官方最佳实践说得明白：调研一个代码库要读大量文件，这些文件内容会吃掉主会话的上下文；让子代理去读，主会话只收到一页结论。这与"专家人格"叙事（"派一个安全审计师"）相比是更朴素也更真实的动机。多代理协作的完整讨论见[子代理](/components/subagents)。

## Hooks：把"建议"升级成"保证"

CLAUDE.md 是劝说的，hooks 是强制的。这是 Claude Code 里一对被官方刻意对举的机制。

Hooks 是用户在 settings 里配置的 shell 命令，挂在 agent 生命周期事件上执行：`PreToolUse`（工具调用前，可以拦截）、`PostToolUse`（工具调用后）、`UserPromptSubmit`、`Stop`、`SessionStart` 等（完整事件模型见[官方 hooks 文档](https://docs.anthropic.com/en/docs/claude-code/hooks)）。关键语义：`PreToolUse` hook 以退出码 2 退出即可**阻止**这次工具调用，并把 stderr 反馈给模型。

官方最佳实践里的分工表述非常精确：「CLAUDE.md 的指令是建议性的（advisory），hooks 是确定性的（deterministic）——用于那些必须每次发生、零例外的事情。」每次编辑后必跑 eslint？写 hook。禁止写入 migrations 目录？写 hook。别指望模型记得。

从 harness 视角看，hooks 的意义在于**给用户开了一个不依赖模型配合的可编程接口**：模型是随机的，hook 是确定的，两者叠加才把 agent 的行为包进了一个可强制的边界内。这也暴露了一个诚实的架构事实——纯靠提示词约束模型行为，在严肃工程场景里是不够的。

## 权限模式：一条自治光谱

每次有副作用的工具调用（写文件、跑 bash、调 MCP）默认都会弹给用户审批——安全，但点第十次之后审批就形同虚设。Claude Code 把这个问题做成了一条显式的光谱（细节见官方[设置文档](https://docs.anthropic.com/en/docs/claude-code/settings)与最佳实践博客）：

| 模式 | 行为 | 适用场景 |
| --- | --- | --- |
| `default` | 首次使用每类动作都要批准，可逐条加白名单 | 日常交互式使用 |
| `acceptEdits` | 文件编辑自动放行，bash 等仍审批 | 信任编辑、警惕命令 |
| `plan` | 只读，禁止一切改动 | 调研与计划审批 |
| `auto` | 另一个分类器模型审查每条命令，只拦高风险的 | 方向可信、不想逐条点 |
| `bypassPermissions` | 全部放行（即 `--dangerously-skip-permissions`） | 沙箱/容器内的无人值守批处理 |

两个值得注意的设计：其一，**白名单可以细到命令前缀**（如只允许 `npm run lint` 不允许任意 bash），颗粒度直接决定了这套系统在生产环境能不能用；其二，`auto` 模式用"另一个模型当审查员"而不是规则引擎，承认了危险性的判断本身需要语义理解。此外还支持 OS 级沙箱来物理限制文件和网络访问。这道光谱上没有"正确点"，只有与任务风险匹配的点——完整的框架讨论见[权限与人机协作](/components/permissions)。

## MCP：工具系统的开放边界

内置工具再通用也盖不住全部世界，Claude Code 的开放接口是 MCP（Model Context Protocol，Anthropic 2024 年 11 月[开源的协议](https://www.anthropic.com/news/model-context-protocol)，规范见 [modelcontextprotocol.io](https://modelcontextprotocol.io/)）：`claude mcp add` 一行接入一个 MCP server，Notion、Figma、数据库、内部服务的工具就进入了模型的工具列表。

值得留意的是 Anthropic 在[工具设计博客](https://www.anthropic.com/engineering/writing-tools-for-agents)里给出的警告：MCP 让"几百个工具"成为可能，但工具不是越多越好——逐个包装 API 端点是最常见的反模式，工具应按工作流合并（`schedule_event` 而非 `list_users` + `list_events` + `create_event`）。换言之，MCP 解决的是"接得上"的问题，接得好不好仍然是 harness 工程问题。相关的权衡在[工具系统](/components/tools)展开。

## 为什么是终端，不是 IDE

这是 Claude Code 最反直觉、也最被事后证明正确的选择。在 2024–2025 年，主流判断是 AI 编码产品应该长在 IDE 里（[Cursor](/case-studies/cursor) 路线的胜利似乎证明了这一点）。Claude Code 偏偏做了个 CLI。

Boris Cherny 在 Latent Space 访谈里给了两层原因。**历史层**：它起初只是他一个人熟悉 API 的终端小实验，"do the simple thing first"的文化让它保持了最简形态；**战略层**则更有意思——他们预判模型会快速变强，与其为今天的模型精雕细琢一个厚 UI/脚手架，不如保持 bare bones、给用户 raw access to the model，把筹码押在模型进步上。他还提到一个三层心智模型：能力能训练进模型就进模型，不行的进 scaffolding（Claude Code 本身），再不行的留给用户组合（tmux 开多窗口跑并行会话、GitHub Action 里跑 `claude -p`）——harness 只占中间那一层，且刻意做薄。

终端形态带来了几个 IDE 给不了的属性：

- **可组合性**：`cat error.log | claude`、`claude -p` 进 CI、shell 循环批量迁移文件——它遵守 Unix 的文本 I/O 契约，天然能嵌进任何已有工作流。
- **环境通用性**：SSH、容器、远程服务器、无 GUI 的 CI runner，凡是能跑 shell 的地方就能跑它。
- **与 IDE 不互斥**：它不是 Cursor 的替代品而是正交品——很多用户两边同时用。

::: warning 诚实的代价
终端形态的成本是真实的：diff 审查体验差、对非 CLI 重度用户门槛高、长输出可读性差。Anthropic 后来也推出了 IDE 扩展和桌面/web 形态作为补充。这个案例的教训不是"终端永远正确"，而是**界面选择应该服从 harness 的核心假设**——Claude Code 的假设是"agent 自主工作、人做审批和监督"，终端恰好匹配；Cursor 的假设是"人写代码、AI 辅助"，所以它在 IDE 里。
:::

## 设计哲学总结：简单是押注模型进步的姿势

把 Claude Code 的组件选择连起来看，能看到一条一以贯之的线索：

- 记忆 = 一个 Markdown 文件，而不是向量数据库；
- 上下文压缩（compact）= "让 Claude 总结一下前面的消息"，而不是精巧的选择性截断算法（Boris 的原话是试过多种方案后"we just did the simplest thing"）；
- 工具 = grep 和 bash，而不是语义代码索引；
- 规划 = 一份三态清单，而不是 plan-and-execute 的双模型架构；
- 强制力 = shell 脚本 hooks，而不是规则引擎。

这不是简陋，而是一种**可淘汰性（disposability）设计**：每个机制都简单到当模型变强时可以随手丢弃或简化。反面是那些为弥补弱模型缺陷而建的厚脚手架——模型一升级，它们从资产变成负债（这个动态视角在[模型 vs. Harness](/guide/model-vs-harness)里详细讨论）。Anthropic 在[《Building effective agents》](https://www.anthropic.com/research/building-effective-agents)里给的原则是同一句话：找能用的最简单方案，只在确有必要时增加复杂度。

当然，"简单"成立有一个隐藏前提：**你的模型足够强**。grep 能替代语义检索，是因为前沿模型真的会熟练使用 grep；CLAUDE.md 能被遵守，是因为模型的指令遵循能力过关。这套设计哲学可以抄，但抄之前要先回答：你的模型接得住吗？这正是 harness 工程必须与模型能力共同演化的原因，也是[设计原则](/practice/design-principles)反复强调的匹配问题。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——Claude Agent SDK 为何被称作"驱动 Claude Code 的 harness"
- [Harness 的解剖](/guide/anatomy)——本文逐项对照的组件框架
- [规划与任务分解](/components/planning)——TodoWrite 与 plan mode 的机制深挖
- [工具系统](/components/tools)——"少而通用"工具设计的完整论证
- [记忆系统](/components/memory)——CLAUDE.md 与更重记忆架构的对比
- [子代理](/components/subagents)——上下文隔离与多代理协作
- [权限与人机协作](/components/permissions)——自治光谱的通用框架
- [Skills](/components/skills)——`.claude/skills/` 的按需加载机制
- [Cursor 案例](/case-studies/cursor)——IDE 路线的对照样本
- [设计原则](/practice/design-principles)——从本案提炼的可迁移原则

## 参考资料

- [Claude Code 官方文档：Memory（CLAUDE.md 与 auto memory）](https://docs.anthropic.com/en/docs/claude-code/memory)
- [Claude Code 官方文档：Subagents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Code 官方文档：Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code 官方文档：Settings（权限规则与工具名）](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Anthropic 工程博客：Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Anthropic 工程博客：Writing Tools for Agents](https://www.anthropic.com/engineering/writing-tools-for-agents)
- [Latent Space 播客：Claude Code: Anthropic's Agent in Your Terminal（Boris Cherny & Cat Wu 访谈）](https://www.latent.space/p/claude-code)
- [A Brief Analysis of Claude Code's Execution and Prompts（提示词与工具定义逆向分析）](https://weaxsey.org/en/articles/2025-10-12/)
- [Anthropic：Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol)
- [Model Context Protocol 规范](https://modelcontextprotocol.io/)
- [Anthropic：Building Effective Agents](https://www.anthropic.com/research/building-effective-agents)
