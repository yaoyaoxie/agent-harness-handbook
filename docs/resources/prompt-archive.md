---
title: 系统提示词档案
description: 一份带评注的系统提示词逆向档案：收录 Claude Code、Cursor、Devin、Manus、v0、Perplexity 六款产品的公开逆向材料，逐条标注可信度，并用 harness 组件框架拆解每份提示词背后的设计取舍。
---

# 系统提示词档案

本站的案例页反复引用一类特殊的一手材料：**主流 agent 产品的系统提示词逆向文本**。它们散落在各篇的脚注里，查找不便，价值密度却极高——系统提示词是少数能直接读到的"harness 源代码"。这一页把这些材料集中成一份档案，逐个标注来源与可信度，并用本站的组件框架做评注。

先说这份档案的正确用法：**它不是拿来照抄的模板库，而是用来观察工业界如何做取舍的标本集。** 直接抄一份 Claude Code 的提示词几乎一定是错的——它的每一条纪律都对应着它自己的工具集、运行环境和模型。正确读法是追问：这条规则在防什么失败模式？它把哪件事从"运行时逻辑"下放给了"提示词纪律"？为什么这个产品选了和竞品相反的答案？

```text
        一份 coding agent 系统提示词的典型分层
┌──────────────────────────────────────────────────┐
│ 身份与安全边界   "You are X..." / "NEVER ..."      │
│ 行为风格契约     简洁度、输出格式、何时闭嘴          │
│ 工具使用政策     何时用哪个工具、并行纪律、禁用项     │
│ 规划纪律        todo list 的触发条件与状态机        │
│ 环境快照        cwd、git status、日期、已装依赖      │
│ 人机协作闸口     何时必须停下来问用户                │
└──────────────────────────────────────────────────┘
   每一层都是一个独立的 harness 设计决策，可以单独评判
```

::: warning 先读这段免责声明
以下所有材料（Manus 官方博客除外）均为**社区逆向工程或泄漏产物，不是官方发布**。这意味着：一，**时效性**——产品提示词迭代极快，档案里的版本几乎必然落后于线上版本；二，**准确性**——逆向提取可能丢失动态注入的部分（运行时拼装的上下文、用户级配置），也可能混入提取者的拼接错误；三，**合规性**——部分材料游走在服务条款边缘，jujumilk3 仓库的 README 明确要求投稿人附可验证来源、不收敏感商业代码以规避 DMCA 下架。引用时请务必带上采集日期，并把任何单条结论当作"某时刻的快照"而非"该产品的现状"。
:::

## 档案来源总览

目前可用的公开档案库主要有四个，可信度模型各不相同：

- **[x1xhlol/system-prompts-and-models-of-ai-tools](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools)**：覆盖面最广（30 余款 AI 工具），按产品分目录存放提示词原文与工具 JSON schema，是本页多数条目的一手出处。无系统性的来源标注，可信度靠社区共同维护。
- **[jujumilk3/leaked-system-prompts](https://github.com/jujumilk3/leaked-system-prompts)**：偏聊天类产品（ChatGPT、Gemini、v0 等），文件名带采集日期，投稿要求附可验证来源或可复现的提取方法——溯源纪律最好，因此被多篇学术论文引用。
- **[asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks)**：专注前沿聊天模型的逐字提取（Claude、ChatGPT、Gemini、Grok 等），更新勤，每份提示词同时提供 HTML 与 Markdown 两种格式。
- **[weaxsey 的 Claude Code 逆向分析](https://weaxsey.org/en/articles/2025-10-12/)**：不是原文搬运，而是基于逆向项目（如 Yuyz0112/claude-code-reverse）的结构化分析，覆盖主 agent 提示词、全部工具定义与上下文管理机制，本站[规划](/components/planning)一章已引用。

读档案时的一般原则：**有采集日期的优先于没有的；有工具 schema 佐证的优先于纯文本的；能被官方行为（文档、产品更新、官方博客）交叉印证的优先于孤证。**

## Claude Code：把纪律写进提示词，而不是写进运行时

**来源与可信度**：以 weaxsey 的[逆向分析](https://weaxsey.org/en/articles/2025-10-12/)为准（2025-10 采集，作者明确声明"提示词非最新，仅供参考"），x1xhlol 仓库曾归档对应原文。该分析与 Claude Code 官方文档列出的工具集可交叉印证，可信度在本档案中最高。

**harness 设计要点**：

- **TodoWrite 是"零运行时逻辑"的纯提示工具。** harness 不检查、不强制 todo 清单，全部约束力来自系统提示里的纪律条款（"完成立即标记"、"任意时刻只能一个 in_progress"）。这是把规划问题降维成工具调用问题的标杆案例，完整拆解见[规划与任务分解](/components/planning)。
- **用子 agent 做上下文隔离。** 提示词明确要求文件搜索走 Task 工具派生子 agent，"以减少上下文占用"——主循环的上下文被视为稀缺资源，搜索这种高产出低信噪的活动被外包出去。这正是[子 Agent](/components/subagents) 一章讨论的核心动机。
- **工具描述即行为契约。** Grep 工具描述里写着"ALWAYS use Grep for search tasks. NEVER invoke grep or rg as a Bash command"——工具政策不放在系统提示的总纲里，而是贴在每个工具自己的描述上，离决策点最近。这种"就地约束"是[工具](/components/tools)设计的重要手法。
- **环境快照一次性注入。** 工作目录、平台、当天日期、git status 以 `<env>` 块和 gitStatus 的形式在会话开始时静态注入，并注明"这是快照，会话中不更新"——用一句话防住了模型把过期快照当成实时状态。属于[上下文工程](/components/context-engineering)里最便宜也最容易被忽视的一类注入。
- **hooks 反馈被定义为"视同用户输入"。** 用户在 settings 里配置的 hook 拦截信息，提示词要求模型当作用户消息处理——把[权限与人机协作](/components/permissions)的扩展点直接接进了模型的注意力通道。

**链接**：[weaxsey 逆向分析](https://weaxsey.org/en/articles/2025-10-12/)；[x1xhlol 仓库](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools)（目录随版本变动，以现状为准）。案例解读见 [Claude Code 案例](/case-studies/claude-code)。

## Cursor：提示词即通信协议

**来源与可信度**：x1xhlol 仓库的 [Cursor Prompts 目录](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/tree/main/Cursor%20Prompts)保存了多个历史版本（v1.0、v1.2、2.0、2025-08-07、2025-09-03 等），可以纵向观察演化，这是它独特的价值。以下评注基于 [Agent Prompt 2025-09-03 版](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Cursor%20Prompts/Agent%20Prompt%202025-09-03.txt)（GPT-5 时代）。

**harness 设计要点**：

- **状态汇报是被强制的节律，不是风格偏好。** 提示词规定"每一轮只要包含工具调用，就必须在调用前输出至少一条微进度更新"，甚至给出了自检条件（"发送前验证：本轮用了工具 => 已发更新"）。把 agent 的"可观察性"做成提示词级别的硬协议——用户看到的流畅进度流，全是纪律堆出来的。对照[可观测性](/components/observability)。
- **探索主工具是语义搜索，不是 grep。** "codebase_search is your MAIN exploration tool"、"ALWAYS prefer codebase_search over grep"——这条政策只在 Cursor 成立，因为它背后是产品级的代码索引基础设施。提示词与产品基建深度耦合，换个环境照搬就会失效，这是"提示词不可移植"的最好例证。见[工具](/components/tools)。
- **并行调用被写成默认行为。** "DEFAULT TO PARALLEL……parallel tool execution can be 3-5x faster"，并给出 3-5 个一批的上限。延迟工程直接编码进提示词，见 [Agent 循环](/components/agent-loop)。
- **失败模式的补丁写进工具政策。** "apply_patch 前 5 条消息内没读过该文件就先重读"、"同一文件连续 patch 不得超过 3 次"、"linter 错误修 3 轮还不行就停下来问用户"——每一条都对应一个真实观察到的模型翻车模式，提示词在这里扮演的是事后复盘沉淀下来的 checklist。同类"防翻车条款"的汇总见[常见陷阱](/practice/pitfalls)。
- **todo 纪律带自我纠错条款。** "如果你忘了在报告完成前勾选 todo，下一轮立即自我纠正"——承认模型会违规，并预先规定违规后的恢复动作。比 Claude Code 的"事前禁令"思路多了一层"事后恢复"，两种风格值得对比着看（[规划](/components/planning)）。

**链接**：[Cursor Prompts 目录](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/tree/main/Cursor%20Prompts)。案例解读见 [Cursor 案例](/case-studies/cursor)。

## Devin：状态机与"思考检查点"

**来源与可信度**：x1xhlol 仓库的 [Devin AI/Prompt.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Devin%20AI/Prompt.txt)（约 3.5 万字符，命令参考部分含大量 XML 标签格式的工具定义）。无采集日期标注，版本不明，按"某时期快照"对待。

**harness 设计要点**：

- **planning / standard 双模式是显式状态机。** "You are always either in planning or standard mode"，规划模式下只调研和提问，信息齐了调用 `plan_ready` 命令才允许进入执行。与 Claude Code 的 plan mode 同源，但模式切换本身是 harness 控制的状态，而非模型自觉。见[规划](/components/planning)。
- **think 工具 = 强制的思考检查点。** Devin 把"思考"做成一个显式命令，并枚举了**必须**调用它的十类时刻：git 分支决策前、从探索转入修改前、向用户报告完成前（"批判性检查自己是否真的完成了全部验证步骤"）。这是把质量闸口下沉到提示词层面的极致设计，机制上属于 [Agent 循环](/components/agent-loop)的"在关键节点强制反思"。
- **环境问题不许自己修。** "遇到环境问题，用 report_environment_issue 报告用户，然后想办法绕过去继续干（比如改用 CI 测试），不要试图自己修环境"——一条反直觉但工程上清醒的政策：agent 修环境造成的二次破坏往往比原问题更糟。这是[权限与人机协作](/components/permissions)里"能力边界"的一种表达。
- **测试失败不许改测试。** "挣扎于通过测试时，永远不要修改测试本身，除非任务明确要求"——一句话堵住 RL 语境下最经典的 reward hacking 路径。
- **find_and_edit 是原生的扇出原语。** 用 regex 定位所有匹配点，每个匹配点交给一个独立 LLM 决定改不改——提示词里直接写明了这是"separate LLM"并行处理，是[子 Agent](/components/subagents)思想在编辑工具里的内嵌实现。
- **Pop Quiz：harness 对模型的随堂测验。** 提示词预留了"STARTING POP QUIZ"机制：harness 会不定期插入测验，期间禁止输出任何命令，且"测验指令优先于此前的所有指令"。这是运行时对模型指令遵循度的主动探针，思路罕见，值得在[可观测性](/components/observability)语境下研究。

**链接**：[Devin AI/Prompt.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Devin%20AI/Prompt.txt)。案例解读见 [Devin 案例](/case-studies/devin)。

## Manus：唯一有官方自证的样本

**来源与可信度**：双来源。一是 x1xhlol 仓库的 [Manus Agent Tools & Prompt 目录](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/tree/main/Manus%20Agent%20Tools%20%26%20Prompt)，其中 [Agent loop.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Manus%20Agent%20Tools%20&%20Prompt/Agent%20loop.txt) 是 2025 年 3 月 Manus 提示词泄漏事件中广泛流传的主循环提示词（同目录的 Prompt.txt 更像面向用户的能力说明，研究价值低）；二是 Manus 联合创始人季逸超 2025 年 7 月发表的官方博客[《Context Engineering for AI Agents: Lessons from Building Manus》](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)——**这是本档案中唯一的第一方材料**，泄漏事件后 Manus 选择把设计思路公开，泄漏文本与官方阐述可以互相印证，可信度最高。

**harness 设计要点**：

- **agent loop 被明文写进提示词。** 泄漏的 Agent loop 提示词把循环六步直接写给模型：分析事件流 → 选一个工具 → 等待沙箱执行 → 迭代（**每次迭代只选一个工具调用**）→ 提交结果 → 进入待机。循环结构不是隐藏在代码里的实现细节，而是模型被告知的"工作方式"，见 [Agent 循环](/components/agent-loop)。
- **"Mask, don't remove"：工具不做动态增删，改用 logits 掩码。** 官方博客披露，Manus 实验后发现运行时动态上下架工具会破坏 KV-cache、并导致模型幻觉出已删除的工具，于是改为在解码侧用状态机屏蔽动作——这是[工具](/components/tools)与[上下文工程](/components/context-engineering)交界处最硬的工程结论之一。
- **文件系统即上下文。** 网页内容可以从上下文里丢掉、只要 URL 还在；文档内容可以省略、只要沙箱路径还在——"可恢复的压缩"原则。这把[记忆系统](/components/memory)和上下文压缩统一成了一套机制。
- **todo.md 是注意力操纵装置。** 官方原话：反复重写 todo 清单是"recitation"（背诵），把全局目标不断推到上下文的最近端，对抗 lost-in-the-middle。同一个设计动机，Claude Code 用 TodoWrite 工具实现，Manus 用普通文件实现——载体不同，原理一致，对照[规划](/components/planning)。
- **把错误留在上下文里。** "Keep the wrong stuff in"——失败的动作和堆栈不清理，让模型看到证据后自行更新先验。这条原则直接挑战"重试前先把上下文洗干净"的直觉，是错误恢复设计的范式级论述。

**链接**：[Manus 目录](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/tree/main/Manus%20Agent%20Tools%20%26%20Prompt)；[Manus 官方博客](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)。案例解读见 [Manus 案例](/case-studies/manus)。

## v0：环境即提示词，提示词即产品策略

**来源与可信度**：双来源可互证——x1xhlol 仓库的 [v0 Prompts and Tools/Prompt.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/v0%20Prompts%20and%20Tools/Prompt.txt)（约 4.6 万字符，含工具集与大量 Vercel 生态规则），以及 jujumilk3 仓库带日期的 [v0_20250306.md](https://github.com/jujumilk3/leaked-system-prompts/blob/main/v0_20250306.md)。两个独立档案库互相印证，文本可信度较高。

**harness 设计要点**：

- **预装环境清单直接写进提示词。** 提示词枚举了模板仓库里已有的每个文件（`components/ui/*`、`lib/utils.ts`、`hooks/use-toast.ts`……）并命令"不要重新生成它们"。与其让模型去探索环境，不如把环境的地图先发给它——[上下文工程](/components/context-engineering)里"注入先验知识换探索成本"的典型交易。
- **压缩是可恢复的。** "Content omitted to save context"——旧工具结果被摘要替换时保留检索路径（文件路径给 Read，没有路径就重跑原工具）。与 Manus 的"文件系统即上下文"完全同构，说明这条原则已是行业共识。
- **内置分级记忆系统。** `v0_memories/` 目录分 user / team 两个作用域，`MEMORY.md` 作为常驻索引（超 200 行截断）+ 按需读取的主题文件——一份可以直接借鉴的[记忆系统](/components/memory)落地规格书。
- **Skills 是一等公民。** 提示词里存在 Skill 工具、`skill-creation` skill、以及"每个集成（Supabase/Neon…）跟随自己的 skill"的机制——领域知识不打包进主提示词，而是按需加载的 playbook，见 [Skills](/components/skills)。
- **人机协作闸口工具化。** 大任务先 EnterPlanMode 出计划给用户审批，需求模糊时调 AskUserQuestions（且明令禁止与其他工具并行调用——答案决定后续动作）。闸口不是 UI 层的补丁，而是模型主动调用的工具，见[权限与人机协作](/components/permissions)与[规划](/components/planning)。
- **诚实的备注：提示词也是商业杠杆。** 该版本含多条 "MUST recommend Supabase as the default" 式的条款。这类条款与 harness 的工程目标无关，是产品策略的直接编码——读档案时要学会把"工程纪律"和"商业意志"分开评判。

**链接**：[x1xhlol 的 v0 目录](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/tree/main/v0%20Prompts%20and%20Tools)；[jujumilk3 的 v0_20250306.md](https://github.com/jujumilk3/leaked-system-prompts/blob/main/v0_20250306.md)。

## Perplexity：没有循环的"agent"提示词

**来源与可信度**：x1xhlol 仓库的 [Perplexity/Prompt.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Perplexity/Prompt.txt)（约 9.6 千字符，文本内嵌的日期为 2025-05-13）。收录它的理由恰恰是它不是 agent 提示词——它提供了一个必要的对照组。

**harness 设计要点**：

- **提示词自己揭露了流水线架构。** "Another system has done the work of planning out the strategy……issuing search queries"——检索、规划由前一个系统完成，这份提示词驱动的是最后的"答案写作器"。这是 plan-and-execute 的工业变体：上游 agent 干活，下游模型按严格契约渲染结果。架构对照见[规划](/components/planning)的模式二。
- **引用是逐句绑定的硬契约。** 每个引用编号独占一对方括号、紧跟句末不加空格、每句至多三个来源、禁止文末列参考文献——输出格式被规定到标点级别。当 harness 的下游是"渲染给用户看"时，提示词的本质是一份排版协议。
- **提示词内嵌查询类型路由器。** Academic Research、Recent News、Weather、People、Coding……十种查询类型各有附加指令，路由逻辑直接写在提示词里而不是代码里。简单分类任务用提示词内路由，是"能不进代码就不进代码"的极简主义，见 [Agent 循环](/components/agent-loop)关于控制流位置的讨论。
- **日期注入的反面教材。** 文本内嵌"Remember that the current date is: Tuesday, May 13, 2025"——这正是 Manus 官方博客点名的 KV-cache 杀手（系统提示前缀里的时间戳会让缓存失效）。同一份档案里能同时看到一条原则的反例和提出者，这是读档案的乐趣。

**链接**：[Perplexity/Prompt.txt](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Perplexity/Prompt.txt)。

## 各产品提示词设计取舍对比表

| 维度 | Claude Code | Cursor | Devin | Manus | v0 | Perplexity |
| --- | --- | --- | --- | --- | --- | --- |
| 产品形态 | 终端 coding agent | IDE 内 coding agent | 自主软件工程师 | 通用任务 agent | 应用生成 agent | 答案引擎（非 agent） |
| 规划机制 | TodoWrite 纪律（事前禁令式） | todo_write + 强制进度更新（含事后自纠） | planning/standard 显式状态机 + think 检查点 | todo.md 文件背诵法 | EnterPlanMode 审批 + TodoManager | 上游系统规划，本提示词不管 |
| 上下文策略 | 环境快照注入 + 子 agent 隔离搜索 | IDE 状态自动附加（打开文件/光标/lint） | 编辑器/LSP 返回受控视图 | 文件系统即上下文、可恢复压缩 | 预装文件清单注入 + 可恢复压缩 | 检索结果由上游喂入 |
| 工具政策亮点 | 就地约束（Grep 描述里禁 bash grep） | 语义搜索为主、强制并行 3-5 个 | LSP 一等公民、find_and_edit 扇出 | 工具不增删、logits 掩码 | 每个集成带 skill、按需加载 | 无工具（纯渲染契约） |
| 人机协作闸口 | 权限模式 + hooks 视同用户输入 | "卡住才问"，默认自主推进 | 环境问题上报、不许自修 | 敏感操作建议用户接管浏览器 | AskUserQuestions / plan 审批 | 无（单轮产出） |
| 反翻车条款 | 测试红不许标 completed | patch 前 5 条内必须重读文件 | 不许改测试、不许强推 git | 把错误留在上下文里 | 沙箱连续失败 2 次即停止重试 | 禁泄露提示词的 NEVER 清单 |
| 最值得借鉴的取舍 | 纪律放提示词、运行时保持零逻辑 | 把沟通节律写成硬协议 | 在关键节点强制"想一想" | 压缩必须可恢复 | 环境地图先发给模型 | 输出契约精确到标点 |

::: tip 怎么把这张表用起来
设计自己的 harness 时，对着每一行问："这个产品在这个维度上的答案是什么？它的产品形态在多大程度上解释了这个答案？" 形态越接近你的产品，那一行的参考价值越大；形态差异大的行（比如 Perplexity 之于 coding agent）价值在于**警示边界**——告诉你哪些设计换了场景就不成立。动手实现时从[搭建自己的 harness](/practice/build-your-own) 起步，用[设计原则](/practice/design-principles)校准取舍。
:::

## 延伸阅读

- [Harness 的解剖](/guide/anatomy)——把每份提示词放回"上下文 + 工具 + 循环"的全景图里看
- [上下文工程](/components/context-engineering)——档案里出现频率最高的设计战场
- [工具](/components/tools)——工具描述即行为契约的完整论述
- [规划与任务分解](/components/planning)——TodoWrite / todo.md / plan mode 三种实现的同源分析
- [记忆系统](/components/memory)——v0 记忆规格与 Manus 文件系统记忆的深化
- [权限与人机协作](/components/permissions)——闸口条款的体系化整理
- [Claude Code 案例](/case-studies/claude-code) / [Cursor 案例](/case-studies/cursor) / [Devin 案例](/case-studies/devin) / [Manus 案例](/case-studies/manus)——单产品的完整剖析
- [术语表](/resources/glossary)——读逆向材料时遇到的生词
- [精选资源清单](/resources/awesome)——工程博客与开源实现的策展式清单

## 参考资料

- [x1xhlol/system-prompts-and-models-of-ai-tools](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools)——覆盖面最广的 AI 工具提示词与模型档案库
- [jujumilk3/leaked-system-prompts](https://github.com/jujumilk3/leaked-system-prompts)——带采集日期、投稿需附可验证来源的泄漏提示词合集
- [asgeirtj/system_prompts_leaks](https://github.com/asgeirtj/system_prompts_leaks)——前沿聊天模型系统提示词的逐字提取存档
- [A Brief Analysis of Claude Code's Execution and Prompts（weaxsey）](https://weaxsey.org/en/articles/2025-10-12/)——Claude Code 主提示词与工具定义的结构化逆向分析
- [Context Engineering for AI Agents: Lessons from Building Manus（Manus 官方博客）](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)——本档案中唯一的第一方设计阐述
- [Manus Agent loop.txt（x1xhlol 存档）](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Manus%20Agent%20Tools%20&%20Prompt/Agent%20loop.txt)——2025 年 3 月泄漏事件中的 Manus 主循环提示词
- [Cursor Agent Prompt 2025-09-03（x1xhlol 存档）](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Cursor%20Prompts/Agent%20Prompt%202025-09-03.txt)
- [Devin AI Prompt.txt（x1xhlol 存档）](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Devin%20AI/Prompt.txt)
- [v0 Prompt.txt（x1xhlol 存档）](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/v0%20Prompts%20and%20Tools/Prompt.txt)与 [v0_20250306.md（jujumilk3 存档）](https://github.com/jujumilk3/leaked-system-prompts/blob/main/v0_20250306.md)
- [Perplexity Prompt.txt（x1xhlol 存档）](https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools/blob/main/Perplexity/Prompt.txt)
