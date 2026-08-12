---
title: 技能与知识注入
description: Agent 获取领域知识的三种途径——静态注入（系统提示与规则文件）、动态检索（RAG）、能力包（Agent Skills），详解 Anthropic 的渐进式披露设计、规则优先级与冲突解决，以及何时该用哪种方式。
---

# 技能与知识注入

模型权重里的知识截止于训练那一天，而且它从来不知道你的项目：不知道你们的代码规范、不知道内部 SDK 的用法、不知道部署前必须先跑哪条命令。Harness 的一项重要职责，就是把这些**模型没有、但任务需要的知识**在运行时注入进去。

注入方式决定了知识的成本结构：是每条消息都付一次 token 税，还是按需付费、甚至零成本待命。这一页讲清楚三条主流途径——**静态注入、动态检索、能力包（skills）**——以及 Anthropic 在 2025 年 10 月推出的 Agent Skills 如何用「渐进式披露」把第三条路做成了开放标准。

## 为什么需要知识注入

一个天真的想法是：把所有相关知识都塞进系统提示。这条路会很快撞墙：

- **上下文预算有限**。塞得越多，留给对话历史和工具结果的空间越少，还会推高每轮调用的延迟和成本。详见[上下文工程](/components/context-engineering)。
- **注意力会被稀释**。无关知识与当前任务混在一起，模型对关键指令的遵循度会下降——长上下文不等于有效上下文。
- **知识有不同的生命周期**。代码规范半年不变，API 文档每周更新，某个故障的处理流程只在出事时才用得上。用同一种方式注入所有知识，必然要么浪费、要么过期。

所以工程上真正的问题是：**给每类知识找到成本与新鲜度都合适的注入通道**。

## 三种途径总览

| 途径 | 典型载体 | 注入时机 | 知识的「形状」 | 适合什么 |
| --- | --- | --- | --- | --- |
| 静态注入 | 系统提示、`CLAUDE.md`、`.cursor/rules/*.mdc` | 会话开始 / 每条消息 | 规则、约定、身份设定 | 少而稳定、每次都适用的约束 |
| 动态检索（RAG） | 向量库 + 检索器 + 拼接模板 | 按查询实时检索 | 大量、易变的文档事实 | 语料大到放不进上下文、需要新鲜度 |
| 能力包（skill） | `SKILL.md` + 脚本/资源目录 | 元信息常驻，正文触发时加载 | 操作流程、领域 know-how | 有步骤的程序性知识，平时不用但不能丢 |

三者的分水岭在于知识的形态：**陈述性约束**适合静态注入，**海量事实**适合检索，**程序性流程**适合封装成 skill。后文逐一展开。

## 途径一：静态注入

### 系统提示与规则文件

最直接的注入：把规则写进系统提示，或写成仓库里的规则文件，由 harness 在会话开始时读入上下文。Claude Code 读 `CLAUDE.md`，Cursor 读 `.cursor/rules/` 目录下的 `.mdc` 文件，社区还沉淀了跨工具的 `AGENTS.md` 约定。

`CLAUDE.md` 的语义很直白：文件内容在每次会话启动时被加载进上下文，相当于一份项目级的「入职手册」——构建命令、目录约定、测试纪律、禁止事项。它支持项目根目录与用户级等多个层级，就近覆盖。

Cursor 的规则系统则走得更远：每条规则带 frontmatter，声明自己**什么时候该被注入**，这本身已经是渐进式披露的雏形：

```mdc
---
description: "数据库迁移文件的编写规范"
globs: "migrations/**/*.sql"
alwaysApply: false
---

所有迁移必须可回滚：每个 up 迁移配一个 down 迁移。
禁止在迁移里做数据回填，回填走独立的 job。
```

| 规则模式 | 配置 | 行为 |
| --- | --- | --- |
| Always | `alwaysApply: true` | 每次对话都注入 |
| Auto Attached | 设 `globs` | 上下文中出现匹配文件时自动附加 |
| Agent Requested | 只设 `description` | 由模型判断相关性后自行取用 |
| Manual | 都不设 | 用户在对话中显式 `@` 引用 |

::: warning 静态注入的通胀陷阱
`alwaysApply: true` 和长长的 `CLAUDE.md` 是最常见的误用。每一条「每次都注入」的规则都在对每一轮对话收税，而且规则越多，单条规则被遵守的概率越低。经验法则：常驻规则控制在「一个新人第一天必须记住的事」这个量级，其余下沉到 glob 触发的规则或 skill。
:::

### 静态注入的适用判据

- 内容少（几百 token 量级）、变化慢、几乎总是相关 → 直接静态注入。
- 与特定文件/目录强相关 → 用 glob 触发的规则，而不是全局常驻。
- 超过一屏的操作流程、只在特定任务用得上 → 不该静态注入，往下看 skill。

## 途径二：动态检索（RAG）

当知识量大到不可能常驻上下文——几万页内部文档、整个工单历史、持续更新的 API 参考——就只能检索增强生成（retrieval-augmented generation, RAG）：按当前任务把语料切成块、做索引，运行时检索最相关的若干片段拼进上下文。

对 agent 而言，RAG 通常不表现为一次性检索，而是包装成工具（如 `search_docs(query)`），由 agent 在循环中多轮调用——这就是所谓 agentic RAG。检索质量的决定因素不在「用哪个向量库」，而在三件事：

1. **切分粒度**是否对齐知识的自然边界（一个函数、一节文档，而不是定长截断）；
2. **召回与重排**是否经得起评估集检验；
3. **拼接进上下文时**是否保留了来源与结构，方便模型引用和存疑。

::: info RAG 与规则文件的本质区别
规则文件注入的是**指令**（"你应该怎么做"），模型应当服从；RAG 注入的是**证据**（"资料是这样说的"），模型需要评估其相关性与时效性。把两者混在一个通道里，是检索噪声变成行为噪声的常见原因。
:::

RAG 的展开讨论见[上下文工程](/components/context-engineering)与[记忆](/components/memory)；这里只需要记住它的定位：**回答"是什么"的事实型知识，量大、易变、可检索**。

## 途径三：能力包（Agent Skills）

### 从 MCP 到 Skills

2025 年 10 月，Anthropic 发布 Agent Skills，随后将其作为开放标准公开（规范见 agentskills.io），官方示例仓库 `anthropics/skills` 同时开源，内置 docx、xlsx、pptx、pdf 等文档处理技能。这一格式随后被 Claude Code 之外的多个主流编码工具采纳，包括 Cursor 与 GitHub Copilot / VS Code。

如果说 MCP 解决的是「agent 能调用什么**工具**」，Skills 解决的是「agent 知道**怎么做**」：把一个领域的工作流程、检查清单、配套脚本和模板打包成一个可移植的文件夹。一个 skill 的最小形态只是一个带 frontmatter 的 Markdown 文件；完整形态是一个目录：

```
pdf-processing/
├── SKILL.md          # 必需：frontmatter（元信息）+ 正文（操作指令）
├── scripts/          # 可选：可执行脚本，agent 直接运行而非逐行阅读
│   └── extract_tables.py
├── references/       # 可选：按需加载进上下文的参考文档
│   └── FORMAT_SPEC.md
└── assets/           # 可选：模板等直接使用的资源，不进入上下文
    └── report_template.docx
```

### 核心设计：渐进式披露（progressive disclosure）

Skills 最精妙的设计是加载策略——不是所有内容一次性进上下文，而是分三层，成本逐级递增、按需深入：

```
┌─────────────────────────────────────────────────────────┐
│ 第 1 层：元信息（始终常驻）                                │
│   SKILL.md 的 YAML frontmatter：name + description      │
│   每个 skill 约几十~上百 token，启动时全量进入系统提示      │
│   用途：让模型知道"有这个技能、什么时候该用"               │
├─────────────────────────────────────────────────────────┤
│ 第 2 层：正文指令（触发时加载）                             │
│   SKILL.md 的 Markdown 正文：工作流程、检查清单、约束       │
│   模型判断任务与 description 匹配时才读入，通常数千 token   │
├─────────────────────────────────────────────────────────┤
│ 第 3 层：捆绑资源（按需引用）                               │
│   references/ 里的文档：模型需要细节时自行 Read 对应文件    │
│   scripts/ 里的脚本：模型像调命令一样执行，                │
│     代码本身不进上下文，只有输出进                         │
│   assets/ 里的模板：作为文件被复制/填写，不进上下文         │
└─────────────────────────────────────────────────────────┘
```

这三层恰好对应三种知识成本：元信息是**目录索引**，便宜到可以全量常驻；正文是**操作手册**，用到才翻开；资源是**资料室**，脚本甚至根本不必被「读」——执行 `python scripts/extract_tables.py` 比让模型把脚本内容读进上下文再心算执行，既省 token 又可靠。

一个真实的 `SKILL.md` 长这样（frontmatter 各字段的要求来自 Anthropic 官方编写指南）：

```markdown
---
name: pdf-processing
description: 从 PDF 中提取文本与表格、拆分合并文档。当用户需要处理 PDF 文件、
  提取表格数据或填写 PDF 表单时使用。
---

# PDF 处理

## 快速开始
提取文本：运行 `python scripts/extract_text.py <input.pdf>`。

## 表格提取
需要保留表格结构时，改用 `scripts/extract_tables.py`，
输出为 CSV。复杂的版式规则见 references/FORMAT_SPEC.md。

## 禁止事项
- 不要逐页截图再用视觉识别，除非 PDF 是扫描件。
```

关键字段：

- `name`：kebab-case，须与目录名一致；
- `description`：模型的触发依据，必须同时写清**做什么**和**什么时候用**（上限 1024 字符，且不能含 XML 标签）——它不是文档，而是一个模糊匹配的触发器；
- Claude Code 还支持 `allowed-tools` 等字段，限定该 skill 激活时可用的工具范围，与[权限系统](/components/permissions)联动。

::: tip description 写不好，skill 等于不存在
模型是否激活一个 skill，几乎完全取决于 description 与用户请求的语义匹配。「帮助处理文档」这种写法永远不会被触发；「当用户要求从 PDF 提取表格、合并/拆分 PDF、填写 PDF 表单时使用」才会。写 skill 时先写 description、用真实任务验证触发率，再写正文。
:::

### Skill 与相邻概念的分工

- **vs 工具/MCP**：工具是能力接口（"能做什么"），skill 是程序性知识（"该怎么做"）。skill 经常编排若干工具完成一个流程。
- **vs 规则文件**：规则是每次都生效的约束，skill 是按任务激活的手册。同一个团队的 deploy 流程，写成规则每次收税，写成 skill 零成本待命。
- **vs [子代理](/components/subagents)**：skill 是把知识交给当前 agent；subagent 是把任务连上下文一起外包。skill 可以作为 subagent 的能力来源，两者正交。

## 优先级与冲突解决

知识来源多了，冲突是必然的：用户消息说"直接改生产配置"，`CLAUDE.md` 说"禁止直接改生产"，skill 里写着部署流程。工程上通行的优先级序（从高到低）大致是：

1. **系统提示**（harness 内置，定义身份与安全底线，用户不可覆盖）；
2. **权限策略**（确定性拦截，不经过模型判断，见[权限与人机协作](/components/permissions)）；
3. **用户当轮指令**（对任务目标的定义权最高，但不能击穿 1、2）；
4. **项目级规则**（`CLAUDE.md`、`.cursor/rules` 中更靠近当前目录的优先于全局的）；
5. **用户级全局规则**；
6. **skill 正文**（程序性建议，与高层规则冲突时应让位）；
7. **检索到的文档**（证据性内容，优先级最低，且需注明来源与时效）。

两条实操建议：

- **冲突要显式，不要覆盖**。在规则文件里写明「X 与 Y 冲突时以 X 为准」，比指望模型自己猜可靠得多。
- **安全相关的约束不要只写在自然语言里**。规则文件靠模型遵守，模型是会犯错的；真正的硬约束应该落在权限层（工具白名单、路径拦截），自然语言规则只做引导。

## 决策指南：规则、RAG 还是 Skill

写之前先问三个问题：这条知识**多久变一次**？**多大概率与当前任务相关**？它是**约束、事实还是流程**？

| 场景 | 选择 | 理由 |
| --- | --- | --- |
| "提交信息用 Conventional Commits" | 规则文件（常驻） | 短、稳定、每次相关 |
| "改 `api/` 下代码必须同步更新 OpenAPI 文档" | 规则文件（glob 触发） | 只在碰特定文件时相关 |
| "我们的故障处理手册有三百页" | RAG | 量大、按需取片段即可 |
| "内部 SDK 的接口文档每天重新生成" | RAG / 工具化查询 | 新鲜度优先于结构 |
| "发版要跑检查清单：打 tag、更新 changelog、灰度 5%" | Skill | 程序性流程，平时零成本，用到必须完整 |
| "把这个 8 步的数据清洗流程固化下来给全组用" | Skill（含 scripts/） | 可移植、可版本化、脚本确定性执行 |
| "公司安全红线：不许把密钥写进代码" | 权限层硬拦截 + 规则文件提醒 | 光靠自然语言约束不够 |

一句话：**约束写进规则，事实交给检索，流程封成 skill，底线落到权限**。

## 好的 skill 长什么样

**反例**（摘自真实世界中常见的失败写法）：

```markdown
---
name: helper
description: 一个有用的助手技能，帮助用户完成各种任务。
---

# 助手
你可以用我来帮助处理文件。尽量做得好一点。
还有很多其他功能，根据需要自行探索。
```

问题一目了然：description 不含任何触发条件，模型永远不会激活它；正文是空洞的口号，没有可执行的步骤；没有脚本，每一步都要模型即兴发挥。

**正例**：

```markdown
---
name: changelog-release
description: 为本仓库生成发版 changelog 并打 git tag。当用户要求
  "发版"、"生成 changelog"、"准备 release" 时使用。
---

# 发版流程

1. 确认工作区干净：`git status` 无未提交改动，否则停下来询问用户。
2. 收集自上一个 tag 以来的提交：`scripts/commits_since_last_tag.sh`。
3. 按 Conventional Commits 分类（feat/fix/chore），写入 CHANGELOG.md
   顶部，格式参考 references/CHANGELOG_FORMAT.md。
4. 版本号规则：有 feat 升 minor，只有 fix 升 patch。
5. 打 tag 前向用户展示 changelog 草稿，得到确认后再执行 `git tag`。
```

好 skill 的共性：

- **description 即触发器**：写清做什么 + 什么时候用，包含用户会说的原话；
- **正文是可执行的流程**，编号步骤、有顺序、有失败分支（"否则停下来问"），不是散文；
- **确定性的事交给脚本**：能写 `scripts/` 的就不让模型手搓，模型只负责决策和串联；
- **细节下沉到 references/**：正文保持数千 token 以内，格式规范、完整清单放第 3 层按需加载；
- **有人类检查点**：不可逆操作（打 tag、发版、写生产）前显式暂停求确认——与[权限设计](/components/permissions)的思路一致。

## 权衡与取舍

- **Skill 不是免费的**。元信息虽小，几百个 skill 的 description 累加也会吃掉可观的上下文，并互相稀释触发精度。保持 skill 数量与任务域匹配，定期清理从不触发的 skill。
- **模型触发的本质是模糊的**。description 匹配是语义判断，可能漏触发（该用没用）或误触发（不该用用了）。关键流程不要只依赖自动触发，保留显式调用入口（如 `/skill-name`）。
- **静态注入胜在确定性**。规则文件每条消息都在，不存在"忘了触发"的问题——对必须每次都生效的约束，这是优点而不是浪费。
- **Skill 是一把双刃剑的安全面**。skill 里的脚本会以 agent 的权限执行，第三方 skill 相当于供应链依赖；接入外部 skill 前审一遍 `scripts/` 和正文里的指令注入风险。
- **别把 skill 写成第二份文档库**。如果"skill"正文只是大段参考资料而没有操作流程，那它应该进 RAG，而不是占着触发通道。

## 延伸阅读

- [上下文工程](/components/context-engineering)：token 预算的分配与上下文组装，知识注入的成本在这里结算
- [工具设计](/components/tools)：skill 编排的对象；MCP 与工具的接口设计
- [记忆系统](/components/memory)：跨会话知识的沉淀，与 RAG 的边界
- [权限与人机协作](/components/permissions)：规则无法兜底的硬约束如何实现
- [子代理](/components/subagents)：知识注入与任务外包的分工
- [案例：Claude Code](/case-studies/claude-code)：`CLAUDE.md` 与 skills 在一个成熟 harness 中的实际组合
- [实践：构建自己的 Harness](/practice/build-your-own)：从零实现一个极简 skill 加载器

## 参考资料

- [Equipping agents for the real world with Agent Skills — Anthropic Engineering](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)（2025-10-16，Agent Skills 发布文章）
- [Agent Skills 开放规范 — agentskills.io](https://agentskills.io)
- [anthropics/skills — 官方示例技能库（GitHub）](https://github.com/anthropics/skills)
- [Use Agent Skills in VS Code — Microsoft Docs](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Cursor Rules 官方文档 — docs.cursor.com](https://docs.cursor.com/context/rules)（Always / Auto Attached / Agent Requested / Manual 四种规则模式）
- [The complete guide to building Skills for Claude（Anthropic 官方指南整理版）](https://gist.github.com/include/2f2214a696846749233cccb4bae50065)（frontmatter 字段要求：name 须 kebab-case、description 上限 1024 字符且须含触发条件）
