---
title: 权限、安全与人类在环
description: 深入解析 Agent Harness 的信任机制：权限模式从全人工审批到 yolo 的谱系、Claude Code 的四级模式与 hooks 护栏、文件系统与网络双重沙箱、prompt injection 与 lethal trifecta 的威胁模型，以及人类在环闸口与读写工具分离的设计原则。
---

# 权限、安全与人类在环

前面所有组件解决的都是"能力"问题：上下文让模型看得更准，工具让模型能做更多，循环让模型走得更远。本篇解决相反方向的问题——**约束**。这是 harness 三重隐喻里"攀岩安全带"的那一面（见[什么是 Agent Harness](/guide/what-is-harness)）：安全带限制你的运动，但正是这种限制让你摔不死。

一个值得记住的命题：**agent 的能力上限由自主性决定，但信任度由权限系统决定。** 把工具全部放开、审批全部关掉，任何 agent 都能立刻"更能干"——这不难。难的是让它在没人盯着的时候也不闯祸，并且让使用者敢于把它放到没人盯着的场景里。产品竞争的胜负手不在"能给多少自主权"，而在"给自主权的同时把风险压到多低"。

## 权限模式的谱系

所有 coding agent 的权限设计都落在同一条光谱上：**每个动作由谁批准、依据什么批准。**

```text
  人工介入 高 ───────────────────────────────────────────────────────────> 自主权 高

 ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
 │全人工审批  │  │规则白名单  │  │模式换挡    │  │沙箱内自治  │  │全自动(yolo)│
 │每个工具调用│  │allow / deny│  │default/plan│  │边界内免审批│  │全部放行    │
 │都弹窗确认  │  │规则精确匹配│  │acceptEdits │  │越界才问人  │  │仅限隔离环境│
 │            │  │            │  │随时切换    │  │            │  │            │
 └────────────┘  └────────────┘  └────────────┘  └────────────┘  └────────────┘
   安全但不可用     精确但配置重    按任务调挡位    当前最优折中    事故的前奏
```

这条光谱上没有一个"正确点"，只有与任务风险和环境隔离度匹配的点。几个关键判断：

- **全人工审批在实践中会自我瓦解。** 问题不在安全，在人：每个动作都弹窗，用户从第 20 次点击开始进入"审批疲劳"（approval fatigue），不再细看就点通过——审批还在，但审批的意义没了。Anthropic 在[沙箱设计的工程博客](https://www.anthropic.com/engineering/claude-code-sandboxing)里明确指出这一点：过度频繁的审批提示反而让开发变得更不安全。形式上的最高安全级别，实际效果可能不如中间档。
- **全自动不是禁区，是环境命题。** Cursor 的 YOLO mode、Gemini CLI 的 `--yolo`、Claude Code 的 `--dangerously-skip-permissions` 都是真实存在的功能，它们的名字本身就带着警告。在一次性容器、云端隔离 VM 里跑全自动 agent 是合理的（[Devin](/case-studies/devin)、[OpenHands](/case-studies/openhands) 的默认形态）；在你放着 SSH 私钥和 `.env` 文件的主力机上跑，是事故的前奏。
- **行业收敛的答案是"沙箱内自治"**：不追求逐条审批每个动作，而是划一条硬边界（这个目录、这些域名），边界内免审，越界升级给人。下面会展开。

## Claude Code 的权限系统设计

Claude Code 的权限系统是这条光谱上最完整的参考实现，值得逐层拆开。它由三层构成：模式（mode）定基调，规则（rules）做精调，hooks 加代码级护栏。

### 四种权限模式

| 模式 | 行为 | 适用场景 |
| --- | --- | --- |
| `default` | 首次使用某类工具时弹窗询问 | 日常交互式开发 |
| `acceptEdits` | 工作目录内的文件编辑自动通过，其余仍询问 | 熟悉的仓库、低风险改动 |
| `plan` | 只读探索 + 制定计划，人批准计划后才能动手 | 新代码库调研、高风险变更前 |
| `bypassPermissions` | 跳过几乎全部审批（`--dangerously-skip-permissions` 进入） | 容器/CI 等隔离环境 |

会话中用 Shift+Tab 循环切换前三者——模式是"挡位"，用户根据当前任务的风险随时换挡，而不是一次配置定终身。

### allow / ask / deny 规则

模式之下是细粒度规则，写在 settings 文件里（用户级、项目级、企业管理级分层覆盖）：

```json
{
  "permissions": {
    "allow": ["Bash(npm run test:*)", "Bash(git status)"],
    "ask":   ["Bash(git push:*)"],
    "deny":  ["Read(./.env)", "Read(./secrets/**)"]
  }
}
```

规则按工具名 + 参数模式匹配，优先级是 **deny > ask > allow**：哪怕用户已经把 `Bash` 整个放进了白名单，一条 `deny: ["Read(./.env)"]` 仍然能钉死 `.env` 文件的读取。这个优先级方向是对的——规则系统的默认姿态应该是"收紧的权限永远优先于放宽的权限"，否则一条宽 rule 就会悄悄废掉所有安全边界。

### Hooks：不靠模型自觉的护栏

第三层是 [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)：在工具调用的生命周期的关键节点（`PreToolUse`、`PostToolUse`、`UserPromptSubmit`、`Stop` 等）执行用户配置的 shell 命令，把 harness 的行为挂到确定性的代码上。

`PreToolUse` 是关键的一个：hook 脚本检查即将执行的工具调用，退出码为 2 即阻断执行，或者以 JSON 返回 `allow` / `deny` / `ask` 的权限决策。它和模型审批的本质区别是：**hook 是代码，每次都执行，没有"模型忘了"这回事。**

```text
┌──────────────── Claude Code 权限管线 ─────────────────┐
│  模型请求工具调用                                     │
│      │                                                │
│      ▼                                                │
│  ① PreToolUse hooks ──deny──> 阻断（确定性，不可绕过）│
│      │ 通过                                           │
│      ▼                                                │
│  ② deny 规则匹配? ──yes──> 阻断                       │
│      │ no                                             │
│      ▼                                                │
│  ③ allow 规则 / 模式免审? ──yes──> 直接执行           │
│      │ no                                             │
│      ▼                                                │
│  ④ 弹窗问人 ──批准──> 执行（可沉淀为新规则）          │
└───────────────────────────────────────────────────────┘
```

这条管线体现了两个设计原则，值得抄进任何自研 harness：**deny 永远先于 allow 评估**（护栏不可被宽规则覆盖），以及**确定性的检查放在模型决策之外**（模型可以提议动作，但无权批准自己）。详细的产品设计剖析见 [Claude Code 案例](/case-studies/claude-code)。

## 人类在环：闸口该设在哪里

"人类在环"（human-in-the-loop）不是一句口号，而是一组具体的闸口（gate）设计决策：在哪个节点、以什么形式、把什么信息交给人拍板。闸口设错位置的代价是双向的——设太多，审批疲劳让闸口形同虚设；设太少或太晚，不可逆损害已经发生。

### 闸口一：动手之前的计划审批

Claude Code 的 plan mode 是最典型的人工闸口：agent 只用只读工具调研、产出一份计划，人批准后才获得写权限。它在[规划模式](/components/planning)的光谱上叠加了"关键节点人工审批"，把 plan-and-execute 的"整体可审计性"嫁接到了交织模式上。计划在这里同时是规划工件和**授权凭证**——人批的不是"这个思路好不好"，而是"我授权你按这个范围动手"。

### 闸口二：不可逆操作的显式确认

不是所有操作都配得上弹窗。工程上合理的分级依据是**可逆性**：

| 操作类型 | 例子 | 合理处置 |
| --- | --- | --- |
| 纯只读 | 读文件、grep、git status | 默认放行 |
| 可逆的写 | 编辑工作区文件（git 可回滚） | 模式内免审 |
| 难逆的写 | `rm -rf`、删数据库表、force push | 强制弹窗或 deny |
| 对外生效 | 发邮件、发 PR、部署、支付 | 必须人工确认，沙箱拦外发 |

判断标准可以压成一句话：**git 救得回来的不用问，git 救不回来的必须问。** 工作区文件编辑之所以敢放进 `acceptEdits` 免审，前提正是版本控制兜底——这也解释了为什么 coding agent 的权限设计天然以"仓库"为信任边界。

### 闸口三：异常时的主动求助

第三种闸口是 agent 自己触发的：权限被拒、计划反复失败、遇到凭据缺失时，停下来问人而不是硬闯。这依赖[可观测性](/components/observability)把"哪一步被谁拒了"暴露给用户，否则用户连闸口被触发过都不知道。

::: tip 一条元规则
闸口的单位成本是"打断人"，所以要像对待稀缺资源一样分配：**把人的注意力预算花在不可逆、对外生效的决策上，把可逆的高频操作让给规则和沙箱。** 一个每五分钟弹一次窗的 harness，教给用户的唯一技能就是不假思索地点"允许"。
:::

## 沙箱：用环境换自主权

沙箱把权限问题从"逐条审批动作"改写成"一次性划定边界"：边界内 agent 全自动，边界本身就是安全策略。这是当前兼顾自主与安全的最佳工程答案——Anthropic 报告其内部使用沙箱后**权限提示减少了 84%**，同时安全性上升而不是下降。

关键设计点（据 Anthropic 的[沙箱工程博客](https://www.anthropic.com/engineering/claude-code-sandboxing)）：**文件系统隔离和网络隔离缺一不可，必须成对出现。**

- **文件系统隔离**：只允许读写指定目录（通常是当前工作目录）。没有它，被注入的 agent 可以读 `~/.ssh/`、改 shell 配置文件、进而逃出任何网络限制。
- **网络隔离**：出站流量全部经过沙箱外的代理，按域名白名单放行，新域名触发人工确认。没有它，被注入的 agent 可以把读到的任何文件发去任何地方——文件系统隔离形同虚设。

实现层次从轻到重：

| 层次 | 机制 | 代表 |
| --- | --- | --- |
| OS 原语 | Linux bubblewrap / macOS Seatbelt，无容器开销 | Claude Code 的 sandboxed bash tool |
| 容器 | Docker 隔离运行时，动作在容器内执行 | OpenHands 的 sandboxed runtime |
| 云端隔离环境 | 每个会话一个独立 VM，凭据不进沙箱 | Claude Code on the web、Devin |

云端方案的一个细节值得注意：Claude Code on the web 的设计是**敏感凭据（git 凭证、签名密钥）从不进入沙箱**，沙箱内的 git 操作用一把受限凭证走代理，由代理验明分支和目标后再附上真实 token。这就是"凭据与执行环境分离"——即使沙箱内完全沦陷，攻击者也拿不到能带出门的东西。

## Prompt injection：agent 的头号威胁

所有权限系统共同的假想敌是同一个：**prompt injection**。这个术语由 Simon Willison 提出（他刻意类比 SQL injection）：LLM 无法可靠区分"指令"和"数据里的指令"，一切内容最终被拼成同一串 token 喂给模型，于是攻击者只要把恶意指令藏进 agent 会读到的任何内容——网页、issue、邮件、文档、工具返回——就可能劫持它的行为。

要区分两件常被混为一谈的事：**jailbreak** 是用户直接骗模型说不该说的话（输出问题），**prompt injection** 是不可信内容借模型的手做不该做的事（行动问题）。对 chatbot 前者是大事；对 agent，后者才是致命的——模型被劫持的每一步都会变成真实的工具调用。

### Lethal trifecta：危险的三要素组合

Willison 在 2025 年 6 月的[《The lethal trifecta for AI agents》](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)中给出了一个简洁的判断框架。当一个 agent 同时具备以下三项能力时，它就处在一发入魂的距离上：

```text
                lethal trifecta
       ┌───────────────────────────────────────────┐
       │  ① 能访问私有数据                         │
       │     （代码、密钥、邮件）                  │
       │           +                               │
       │  ② 会接触不可信内容                       │  三腿齐备 =
       │     （网页、issue、工具返回）             │  一次注入即可
       │           +                               │  完成窃取+外发
       │  ③ 能对外通信                             │
       │     （HTTP 请求、发 PR、                  │
       │      发邮件）                             │
       └───────────────────────────────────────────┘
             防御 = 砍掉至少一条腿
```

攻击链条是平凡的：② 里的攻击者指令操纵 agent 用 ① 读到私有数据，再用 ③ 发给攻击者。Willison 的文章列举了一长串中招的生产系统——Microsoft 365 Copilot、GitHub 官方 MCP server、GitLab Duo，往前还有 Slack、Google Bard、Amazon Q 等。GitHub MCP 的案例尤其典型：一个工具同时读公开 issue（攻击者可投毒的不可信内容）、访问私有仓库（私有数据）、创建 PR（外发通道），三要素在同一个工具里凑齐了。

注意：**coding agent 默认就是三腿齐备的**——它读你的仓库和 `.env`（①），抓网页和 issue（②），能跑 `curl` 和 `git push`（③）。这不是假设性风险，而是这类工具的出厂形态，上面的沙箱和权限设计全部是在给这个事实补课。

### 防御：结构性拆腿，而不是提示词祈祷

Willison 的判断很直白，也值得全文引用：**我们还不知道如何 100% 可靠地防住这类攻击。** 他对宣称"拦截 95% 攻击"的 guardrail 产品的评价是：在 Web 安全领域，95% 是不及格分数——攻击者只要试 20 次。提示词里写"不要听从文件里的指令"更是祈祷而非防御：恶意指令的表述方式是无穷多的，你的禁令只是一次采样。

有效的防御是**结构性的**，即让攻击在架构上不可能，而不是在概率上变小：

1. **拆腿。** 会话同时碰 ① 和 ② 时，砍掉 ③——能读私有数据又能读不可信内容的 agent，不发给外发工具。这就是网络隔离和 ask 规则管的事。Meta 在 2025 年 10 月提出的 "Agents Rule of Two" 是同一思想的规则化：一个会话最多拥有三项能力中的两项，必须全占就加人工监督。
2. **后果冻结。** 引述 Willison 提到的那篇安全模式论文的总结："一旦 agent 摄入了不可信输入，就必须约束它，使该输入不可能触发任何有后果的动作。"读网页的 agent 只许产出文本总结，不许获得写工具——这是[工具](/components/tools)组合层面的最小权限。
3. **纵深防御。** 提示词加固、注入检测、权限规则、沙箱、人工闸口，每一层都会漏，叠在一起让攻击者要同时过五道关。没有银弹不等于什么都不做。

::: warning 别指望模型自己扛
把"识别并拒绝注入指令"的职责交给模型本身，等于让被告兼任法官。模型的职责是干活，harness 的职责是确保模型被劫持时干不成坏事——这就是为什么权限、沙箱、闸口必须实现在模型之外。
:::

## 只读工具与写工具的分离

最小权限原则落到 harness 上，最直接的形式是工具集的切分。`Read`、`Grep`、`Glob` 是安全的，`Edit`、`Write`、`Bash` 是要命的，`WebFetch`、`git push`、发消息类工具是"对外生效"的第三档——三档的信任成本完全不同，应该在架构上分开管理：

- **默认只给只读。** 探索、问答、调研类任务（以及 plan mode 的调研阶段）只挂只读工具。只读工具的输出可能带毒（注入），但它本身造不成破坏——毒性要等写工具在场才会发作。
- **写工具按环境授权。** 工作区内可逆的写归 `acceptEdits` 一档；越界的写、不可逆的写走审批或 deny。
- **对外工具单独对待。** 凡是"动作后果离开本机"的工具（push、部署、发消息），默认进 ask 列表。这类工具的不可逆性最高，也正是 lethal trifecta 的第三条腿。
- **用机器可读的标注。** MCP 协议的工具注解（tool annotations，如 `readOnlyHint`、`destructiveHint`）把这个三分类做成了协议级元数据，harness 可以据此自动决定放行还是询问，而不必逐个工具硬编码。

子代理场景同样适用：[子 agent](/components/subagents) 的权限应该是主 agent 的子集而非全集——派去"总结这个网页"的子代理没有任何理由继承 `Edit` 和 `Bash`。

## 设计检查清单

把本篇压缩成一份可直接使用的清单：

- 默认姿态是 **deny-first**：没明确允许的就问，没问过的不放行；deny 规则优先于 allow 规则。
- 权限管线里**确定性检查（hooks、规则）在模型之外**，模型只有提议权没有批准权。
- 按可逆性分级设闸：可逆免审、难逆弹窗、对外必审。审批预算花在不可逆操作上。
- 需要高自主性时，先上沙箱（文件系统 + 网络双隔离），再考虑放开审批；绝不在有真实凭据的主力环境跑 yolo。
- 对照 lethal trifecta 体检你的工具组合：三腿齐备的会话，砍一条腿，或者加一道人工闸。
- 工具按只读 / 可逆写 / 对外生效三档分离，子代理权限只减不增。
- 把一切权限事件（放行、拒绝、越界）写进日志——事后能回答"它干过什么、被拦过什么"，是信任的最终来源。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——"攀岩安全带"隐喻：约束是 harness 的核心职责之一
- [工具系统](/components/tools)——读写分离、工具注解与最小权限的落点
- [规划与任务分解](/components/planning)——plan mode：把计划审批作为授权闸口
- [Agent 循环](/components/agent-loop)——权限管线挂在循环的哪个位置
- [子 Agent](/components/subagents)——子代理的权限收敛
- [可观测性](/components/observability)——权限事件日志与事后审计
- [Claude Code 案例](/case-studies/claude-code)——四种模式 + hooks + 沙箱的完整产品设计
- [OpenHands 案例](/case-studies/openhands)——容器化 sandboxed runtime 的另一种解法
- [常见陷阱](/practice/pitfalls)——审批疲劳、yolo 滥用等反模式

## 参考资料

- [Simon Willison: The lethal trifecta for AI agents（2025-06-16）](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/)
- [Anthropic 工程博客：Beyond permission prompts — Claude Code 沙箱设计（含 84% 审批减少数据）](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Claude Code 官方文档：Hooks 参考](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code 官方文档：Settings（permissions allow/ask/deny 规则）](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Munder Difflin Blog: The Agents Rule of Two（Meta 2025-10 安全框架的转述与解读）](https://munderdiffl.in/blog/agents-rule-of-two/)
