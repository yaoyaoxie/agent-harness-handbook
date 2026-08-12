---
title: 工具系统与 MCP
description: 工具是模型与环境之间的界面，也是 harness 设计中最被低估的部分：本文拆解什么该做成工具、schema 与返回结果如何塑造模型行为、工具数量的选择困难、MCP 协议的价值与局限、computer use 类通用工具的取舍，以及 TodoWrite 式纯提示工具的特殊形态。
---

# 工具系统与 MCP

工具（tool）回答的问题是：**模型如何触碰上下文之外的世界？**

模型本身只做一件事——输入 token、输出 token。它能读文件、跑测试、查数据库、发消息，全是因为 harness 把一段结构化的"动作请求"翻译成真实的函数调用，再把结果翻译成文本塞回上下文。换句话说，**工具是模型与环境之间的界面**，而界面设计有一条被无数产品验证过的经验法则：界面质量决定使用者的表现上限。

这条法则在 agent 语境下同样成立，只是"使用者"从人换成了模型。SWE-agent 的论文（arXiv:2405.15793，NeurIPS 2024）把这个观点明确化为一个概念——**Agent-Computer Interface（ACI）**：正如好的 UI 决定人能多好地操作软件，给模型用的命令和反馈格式也决定它能多好地操作计算机。SWE-agent 团队发现，仅仅把编辑命令从"自由文本 patch"改成"指定行号范围的 replace"，再配合紧凑的错误反馈，SWE-bench 成绩就能显著提升——模型没变，prompt 没变，变的只是工具界面。

本文的立场由此而来：**工具设计是 harness 设计中最被低估的部分**。大家热衷于讨论用哪个模型、什么 agent 框架，却很少认真回答：这几个工具的名字、参数、返回文本，正在怎样塑造模型的每一步行为。Anthropic 在工程博客[《Writing effective tools for agents》](https://www.anthropic.com/engineering/writing-tools-for-agents)里给出了一个精准的定义，可以作为本文的出发点：

> 工具是一种新型软件——它不是确定性系统之间的契约，而是**确定性系统与非确定性 agent 之间的契约**。给 `getWeather("NYC")` 写 API 时，调用方是另一个程序；而 agent 可能调用它、可能凭记忆直接回答、也可能先反问用户"你在哪个城市"。

理解这个契约的特殊性，是理解一切工具设计决策的前提。

## 什么该做成工具：API 能做的事，不必都包成工具

最常见的错误是**把现有 API 的端点逐个包装成工具**：有一个 `list_contacts` 接口，就包一个 `list_contacts` 工具；有 `get_user`、`list_transactions`、`list_notes` 三个接口，就包三个工具。这在传统软件集成里是天经地义的，在 agent 场景里却是反模式——因为 agent 的"内存"是昂贵且有限的上下文窗口，不是廉价的堆。

Anthropic 在同一篇博客里给出了几个对比案例：

- 不要 `list_contacts`（返回全部联系人，让模型逐条翻），要 `search_contacts`（返回相关的那几个）；
- 不要 `list_users` + `list_events` + `create_event`（模型自己串联三步），要 `schedule_event`（一个工具内部完成查空档和创建）；
- 不要 `get_customer_by_id` + `list_transactions` + `list_notes`，要 `get_customer_context`（一次性返回该客户的完整相关上下文）。

规律很清晰：**按工作流（workflow）设计工具，而不是按 API 端点设计工具**。每合并一次，就少一轮中间结果进出上下文，少一次模型在步骤之间"抄写"数据出错的机会。

但这不意味着工具越粗越好。另一个方向的错误是把工具做成"万能瑞士刀"：一个 `execute_action` 工具接受一个自由文本的 `instruction` 参数——这把接口设计的责任全推回给了模型，等于没有工具。判断该做成什么的经验法则：

- **高频、多步、确定性的流程**合并成单个工具（如 `schedule_event`）；
- **需要模型当场判断的分支**保留为独立工具，别预先替它做决定；
- **模型用 shell + 代码就能组合出来的事**不必专门做工具——Claude Code 只给 `Read`/`Write`/`Grep`/`Bash` 这类"通用原语"，剩下的组合留给模型，这是刻意的克制（见 [Claude Code 案例](/case-studies/claude-code)）；
- **纯知识性、无环境副作用的能力**优先写成 [Skills](/components/skills)（说明书）而不是工具（运行时），避免工具列表膨胀。

## Schema 设计：写给模型看的接口文档

工具的 schema——名字、描述、参数定义——是模型选择和使用工具的唯一依据。它不进数据库、不进编译器，它**直接进 prompt**。所以 schema 设计本质是 [上下文工程](/components/context-engineering)：你写的每一个词都在塑造模型的行为分布。

### 命名即路由

工具名是模型路由决策的第一信号。当 agent 同时挂着几十个 MCP server、上百个工具时，重叠或含糊的名字会直接制造误调用。Anthropic 的实测建议是**命名空间（namespacing）**：按服务前缀分组（`asana_search` vs `jira_search`）、按资源分层（`asana_projects_search` vs `asana_users_search`），让名字本身就携带"什么时候该用我"的信息。他们甚至发现前缀式还是后缀式命名对工具调用准确率有"非平凡的影响"，且不同模型结论不同——这意味着命名方案值得被纳入你的评测，而不是拍脑袋。

### 描述是 prompt engineering，不是文档

工具描述不是写给人看的参考文档，而是写给模型看的行为指令。Anthropic 博客里有一个教科书级的案例：他们的 web search 工具上线后，发现 Claude 总是给 `query` 参数画蛇添足地加上 `2025`（大概是训练数据里留下的"最新信息要带年份"的偏差），污染搜索结果。修复方式不是改代码、不是微调模型，而是**改了一句工具描述**，把模型引回正路。

由此得到几条可操作的写法：

- 描述里写清**什么时候用、什么时候不用**，而不只是"这是什么"；
- 对容易填错的参数给出正例和反例（`query` 该长什么样、不该长什么样）；
- 复杂的、领域性的使用纪律放 system prompt 比塞进工具描述更有效（Anthropic 在 think tool 的 τ-bench 实验里验证了这一点，见后文）；
- 参数用 schema 约束（enum、必填、格式说明）把"能犯的错"在结构层先砍掉一半——模型不需要被说服，只需要没有歧义。

### 标识符要对人（模型）友好

一个容易被忽视的细节：模型处理自然语言标识符远比处理无意义字符串可靠。Anthropic 发现，把工具返回里的任意 UUID 解析成有语义的名称（哪怕是 0 开始的序号），就能显著降低检索任务里的幻觉——模型在引用 `uuid: 7f3a...` 时很容易抄错一个字符，而引用 `alice-smith` 几乎不会。类似地，返回字段优先给 `name`、`file_type` 这种下游决策直接可用的信息，少给 `mime_type`、`256px_image_url` 这类只有程序才关心的低层字段。

## 返回结果设计：工具说的话，也是 prompt

工具的返回值和报错会以 `tool` 角色的消息进入上下文，成为模型下一步推理的输入。所以**返回结果设计的受众不是开发者，是模型**。

### 错误信息是给模型看的提示

传统 API 的错误面向调用方程序员：`{"error": 400, "code": "INVALID_PARAM"}`。这种错误对模型几乎零信息量——它只会换一个参数值再试，或者干脆放弃。好的工具错误应该像一位同事在指导模型：

```text
差的错误：  Error: invalid parameter
好的错误：  Error: `path` 必须是仓库内的相对路径（例如 "src/main.ts"），
            收到的是绝对路径 "/home/user/proj/src/main.ts"。
            提示：可以先用 ListFiles 工具查看目录结构。
```

后者同时完成了三件事：指出错在哪、给出正确格式、推荐下一步动作。模型绝大多数"卡死"时刻，都是因为工具只告诉它"你错了"，没告诉它"怎么对"。

### Token 预算与截断

工具返回是上下文膨胀的头号来源之一。一次 `grep` 返回五千行匹配、一次 API 调用返回整个 JSON 文档，都可能把关键指令挤出模型的有效注意力范围（这正是[上下文工程](/components/context-engineering)要对抗的"context rot"）。工程上的标准做法：

- **默认限制**：Claude Code 对工具返回默认截断在 25,000 token 以内（Anthropic 博客披露的数值）；
- **截断要带指引**：不能悄悄砍掉。好的截断消息形如"Results truncated at 100 items. Use filters or pagination to narrow results."——把"结果被截了"这个事实和"下一步该怎么办"一起告诉模型，引导它做多次小而准的查询而不是一次大而全的；
- **提供分页/过滤/范围参数**：让模型能自己控制返回量，必要时暴露 `response_format: concise | detailed` 这类开关。

### 一个工具调用的完整解剖

把以上原则放在一起，一次工具调用在 harness 里的完整生命周期长这样：

```text
┌──────────────── 一次工具调用的解剖 ────────────────┐
│                                                    │
│  ① schema 进 system prompt                         │
│     (名字/描述/参数 —— 模型的选择依据)               │
│              │                                     │
│              ▼                                     │
│  ② 模型输出结构化调用 {name, args}                   │
│              │                                     │
│              ▼                                     │
│  ③ harness 校验 + 权限闸门 —— 见 /components/permissions │
│              │                                     │
│              ▼                                     │
│  ④ 真实执行（文件/网络/数据库）                      │
│              │                                     │
│              ▼                                     │
│  ⑤ 结果回灌上下文 —— 高信号字段、错误指引、截断       │
│              │                                     │
│              ▼                                     │
│  ⑥ 模型基于观察继续 agent loop 的下一轮                 │
└────────────────────────────────────────────────────┘
```

注意 ① 和 ⑤ 都是"文本进上下文"——工具的两端本质上都是 prompt 设计，只有 ④ 是传统软件工程。这就是为什么工具设计同时需要后端思维和 prompt 思维。

## 工具数量与选择困难

工具不是越多越好，这里有两层独立的开销。

**第一层是静态开销：schema 本身吃 token。** 每挂一个工具，它的定义就常驻 system prompt。接几十个 MCP server、几百个工具时，模型还没读到用户的请求，就要先处理几十万 token 的工具定义（Anthropic 在[《Code execution with MCP》](https://www.anthropic.com/engineering/code-execution-with-mcp)中给出的量级描述）——响应变慢、成本变高、还挤占任务本身的上下文。

**第二层是行为开销：选择准确率随候选增多而下降。** 模型是在一堆候选里做分类决策，候选越多、彼此越像，选错、填错参数、该调用时不调用的概率就越高。Anthropic 的表述很直接：太多工具或功能重叠的工具会"分散 agent 的注意力，使其偏离高效策略"。Cloudflare 在[《Code Mode》](https://blog.cloudflare.com/code-mode/)一文里给过一个更扎心的解释：工具调用的特殊 token 格式只来自少量人造训练数据，而代码来自数百万真实开源项目——**让模型写代码调 API，比让它直接调工具，更接近它训练分布里的强项**。

对应的解法已经形成了一套组合拳：

| 解法 | 机制 | 代表 |
| --- | --- | --- |
| 合并工具 | 按工作流收敛，减少候选总数 | `get_customer_context` 替代三个查询工具 |
| 命名空间 | 前缀分组，降低误选 | `asana_search` / `jira_search` |
| 按需加载 | 先给 `search_tools` 检索工具，用到哪个再加载哪个的完整定义 | Anthropic "progressive disclosure" |
| 代码执行 | 把工具转成代码 API，模型写代码调用、在执行环境里过滤数据 | Anthropic / Cloudflare Code Mode |

最后一条路的效果数字很惊人：Anthropic 把"从 Google Drive 取会议记录写入 Salesforce"这类多工具工作流改写成代码执行后，token 消耗从 150,000 降到 2,000（-98.7%）——因为中间结果不再两次穿过模型上下文，循环、条件、重试也全在执行环境里完成。代价是要一个安全的沙箱执行环境，这是新的基础设施负担，详见的权衡在 [权限与人机协作](/components/permissions)。

::: tip 一条元规则
工具数量的正确单位不是"个"，而是**"模型为选对工具付出的决策成本"**。10 个职责清晰、名字正交的工具，好过 50 个边界模糊的工具；而 500 个工具的正确打开方式，往往不是全塞进上下文，而是加一层检索或代码执行。
:::

## MCP：工具系统的标准化层

理解了工具设计的各种讲究之后，再看 MCP（Model Context Protocol）就会清楚它解决了什么、没解决什么。

### 它是什么

MCP 是 Anthropic 于 2024 年 11 月 25 日[开源发布的协议](https://www.anthropic.com/news/model-context-protocol)，目标是给"AI 应用连接外部工具与数据"定一个统一标准。架构是经典的 host/client/server：harness（host）里的 client 与各个 MCP server 建立会话，server 通过 JSON-RPC 2.0 暴露三类原语——**tools**（可调用函数）、**resources**（可读取的数据）、**prompts**（可复用的指令模板）。传输可以是本地 stdio，也可以是远程 HTTP。

```text
┌────────────── Host（你的 harness）──────────────┐
│                                                 │
│   Agent Loop                                    │
│      │                                          │
│      ▼                                          │
│   ┌─────────┐  JSON-RPC   ┌───────────────┐
│   │ Client  │ ══════════> │ MCP Server A  │ ──> 本地文件系统
│   │         │  (stdio)    │ (tools/资源)   │
│   │         │ ══════════> │ MCP Server B  │ ──> GitHub API
│   │         │  (HTTP)     │               │
│   └─────────┘ ══════════> │ MCP Server C  │ ──> 数据库
│                           └───────────────┘     │
└─────────────────────────────────────────────────┘
        一套协议，N 个 server，即插即用
```

它解决的是经典的 **M×N 集成问题**：M 个 agent 应用 × N 个外部系统，没有协议就是 M×N 个定制连接器；有了协议，每边各实现一次，复杂度降到 M+N。社区常拿它类比 USB-C 或 LSP（Language Server Protocol 给所有编辑器统一了接语言后端的界面，MCP 给所有 agent 统一了接工具的界面）——这个类比基本准确。

采纳速度也确实惊人：2025 年 3 月 OpenAI 宣布在自家产品全线支持 MCP（两家最大竞品实验室共推同一协议，这是它成为事实标准的关键时刻）；2025 年 12 月 9 日，Anthropic 把 MCP [捐赠给 Linux 基金会下属的 Agentic AI Foundation（AAIF）](https://aaif.io/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation-aaif-anchored-by-new-project-contributions-including-model-context-protocol-mcp-goose-and-agents-md/)，与 Block 的 goose、OpenAI 的 AGENTS.md 并列为三大创始项目，官方口径是超过一万个已发布的 MCP server。协议治理从单一厂商转向中立基金会，这基本锁定了它的基础设施地位。

### 它没解决什么

**MCP 标准化的是"连接"，不是"质量"。** 这是评价 MCP 时最容易被混淆的一点：

- **它不管工具设计的好坏。** 一个把 50 个 API 端点原样包出来的 MCP server，依然是糟糕的工具设计——前面几节的所有原则，MCP 一条都不替你强制执行。协议让烂工具更容易被接进来。
- **它放大了上下文膨胀。** 默认模式下 client 把所有 server 的所有工具定义一次性灌进上下文。挂得越多，前一节说的静态开销和行为开销越严重——这正是 code execution / 按需加载这类模式出现的直接原因。
- **它的信任模型很薄。** 工具描述对模型来说是指令，而 MCP server 是可以装恶意指令的第三方代码。Invariant Labs 在 2025 年 4 月披露了 [tool poisoning 攻击](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks)：把注入指令藏在工具描述里（用户界面上看不到的部分），操纵 agent 窃取数据；同一团队还演示了 [rug pull](https://invariantlabs.ai/blog/mcp-security-notification-rug-pulls)——server 在用户批准之后悄悄修改工具定义。装一个来路不明的 MCP server，约等于把一段不可信的 prompt 和一组可执行的权限同时请进你的 harness。相关的权限闸门设计见[权限与人机协作](/components/permissions)。
- **权限、审计、计费、生命周期**在协议层都还很初级，生产环境需要自己补这一层（网关、代理、审批）。

::: warning 一个诚实的判断
MCP 的价值是真实的——它消灭了重复集成，让工具生态可以独立演化。但"接上 MCP server"不是能力建设的终点，而是起点：**接进来之后，工具选取得对不对、结果设计得好不好、权限收得紧不紧，仍然全是 harness 的活**。生态的丰富反而让工具治理（选哪些、怎么裁剪、怎么防注入）变成新的核心问题。
:::

## 通用界面 vs 专用工具：computer use 的取舍

工具光谱的另一端是"通用工具"：不给任何专用接口，直接给模型一个屏幕截图加一套鼠标键盘动作（点击坐标、输入文本），让它像人一样操作图形界面。Anthropic 2024 年 10 月 22 日发布的 [computer use](https://www.anthropic.com/news/3-5-models-and-computer-use)（Claude 3.5 Sonnet 的公测能力）和 OpenAI 2025 年 1 月发布的 Operator 是这一路线的代表；browser use 类开源项目则是它在浏览器域的变体。

这条路线的诱惑显而易见：**零集成成本**。不用等任何软件开放 API，不用写 MCP server，只要它有界面，agent 就能用。对长尾的遗留软件、内部系统，这是唯一现实的接入方式。

但代价同样结构性：

| 维度 | 通用界面（截图 + 点击） | 专用工具（API / MCP） |
| --- | --- | --- |
| 集成成本 | 几乎为零 | 需要开发或现成 server |
| 每步开销 | 截图动辄上千 token，一步步走 | 一次调用完成多步 |
| 可靠性 | 脆弱：布局微调、弹窗、加载延迟都能打乱坐标 | 确定性高，可校验、可重试 |
| 可审计/可拦截 | 动作是"点击 (382, 511)"，语义模糊难审批 | 动作是 `transfer(amount=100)`，语义清晰可设闸 |
| 适用面 | 任何有 GUI 的软件 | 仅限有接口的系统 |

业界的收敛做法不是二选一，而是**分层**：专用工具为主干道，通用界面当兜底。有 API 的地方绝不让模型去点像素——不是因为它做不到，而是因为每一步都在为"通用性"支付 token、延迟和失败率。注意区分两个容易混淆的"通用"：Claude Code 的 `Read`/`Bash` 是**通用原语**（语义清晰、确定性执行的原子操作），computer use 是**通用界面**（在别人的 UI 上猜测语义）。前者是工具设计的优秀形态，后者是接入成本的下限保障，两者不可互相替代。

## 纯提示型工具：零运行时逻辑的形态

最后是一种容易被忽视、却最能体现"工具即界面"思想的形态：**工具的实现什么都不做，全部效果来自"模型调用了它"这个动作本身**。

两个标杆案例：

**TodoWrite。** Claude Code 的任务清单工具没有任何运行时逻辑——harness 不检查、不强制执行，它只是把模型写的清单留在上下文里，成为每轮决策可见的锚点。它生效的机制是认知卸载：写清单的动作强迫模型结构化任务，清单的存在对抗长程任务的目标漂移。这个工具把"规划问题"降维成了"工具调用问题"，完整拆解见[规划与任务分解](/components/planning)。

**think 工具。** Anthropic 2025 年 3 月发布的 [think tool](https://www.anthropic.com/engineering/claude-think-tool) 更纯粹：它的 description 直接写着"使用这个工具来思考。它不会获取新信息，也不会修改数据库，只是把想法记录到日志里"。在 τ-bench 这类需要遵守复杂策略、做多步决策的评测上，加这样一个空工具能显著提升表现；在 SWE-bench 上给 Claude 3.5 Sonnet 配一个定制描述的 think 工具，也拿到了当时 0.623 的最好成绩。机理与 TodoWrite 同源：**给"停下来想一想"一个显式的动作槽位，模型就会在关键节点真的停下来想一想**。

这类工具给 harness 设计的启示是深刻的：工具集不只是"模型能做什么"的清单，还是**模型行为的脚手架**。你希望模型在什么节点做什么样的认知动作（规划、反思、汇报进度），就可以设计一个对应的纯提示工具，再配合 system prompt 的纪律把它变成循环中的固定节律。[Skills](/components/skills) 里的渐进式披露、以及 [agent loop](/components/agent-loop) 里的结构化输出约定，本质上是同一思想在不同层的应用。

## 实践清单

如果你在为自家 agent 设计工具层，按顺序检查：

1. **先列工作流，再定工具。** 从评测任务（真实用户会怎么用这个 agent）倒推工具集，禁止从 API 文档正推。
2. **每个工具问一句：模型能靠现有工具组合出来吗？** 能，就不做；组合太绕，就做合并工具。
3. **schema 当 prompt 写。** 名字正交、描述含使用时机与反例、参数用 enum/必填收窄错误空间。
4. **错误信息写给模型看。** 每条报错回答三个问题：错在哪、正确格式是什么、下一步建议什么。
5. **返回结果设预算。** 默认截断 + 截断指引 + 分页/过滤参数；高信号字段优先，UUID 尽量解析成名称。
6. **工具过 30 个就要考虑加载策略。** 命名空间 → search_tools 按需加载 → code execution，逐级升级。
7. **MCP server 当第三方代码审。** 看工具描述全文（包括 UI 不显示的部分）、锁版本、最小权限；见[常见陷阱](/practice/pitfalls)。
8. **给工具写评测。** Anthropic 的方法论：原型 → 真实场景的评测任务 → 读失败轨迹改描述/schema → held-out 测试集防过拟合。工具是可以被评测驱动地优化的，别一次写完就不管。
9. **考虑要不要一个纯提示工具。** 如果 agent 在长任务上漂移或在关键节点不思考，TodoWrite / think 几乎是零成本的干预。

## 延伸阅读

- [Agent 循环](/components/agent-loop)——工具调用嵌入其中的主循环结构
- [上下文工程](/components/context-engineering)——工具 schema 与返回结果都是上下文的内容管理
- [规划与任务分解](/components/planning)——TodoWrite 这个纯提示工具的完整机制拆解
- [权限与人机协作](/components/permissions)——工具是权限闸门的落点，MCP 安全问题的对策层
- [Skills](/components/skills)——知识性能力写成说明书而非工具的分工
- [可观测性](/components/observability)——工具调用轨迹是调试 agent 行为的第一现场
- [Claude Code 案例](/case-studies/claude-code)——"通用原语 + 纯提示工具"的工具哲学范本
- [SWE-agent 案例](/case-studies/swe-agent)——ACI 概念的发源地，工具界面决定成绩的直接证据
- [核心论文](/papers/core-papers)——ReAct、SWE-agent 等原始文献导读

## 参考资料

- [Anthropic: Writing effective tools for agents — with agents](https://www.anthropic.com/engineering/writing-tools-for-agents)——工具选型、命名空间、返回结果优化、评测驱动优化的系统方法论
- [Anthropic: Code execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)——工具定义与中间结果的 token 开销分析，150K→2K 的代码执行改造
- [Anthropic: Introducing the Model Context Protocol（2024-11-25）](https://www.anthropic.com/news/model-context-protocol)
- [AAIF / Linux 基金会新闻稿（2025-12-09）：MCP、goose、AGENTS.md 成为创始项目](https://aaif.io/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation-aaif-anchored-by-new-project-contributions-including-model-context-protocol-mcp-goose-and-agents-md/)
- [Cloudflare: Code Mode — the better way to use MCP](https://blog.cloudflare.com/code-mode/)——"模型写代码调 API 优于直接调工具"的论证与实现
- [Invariant Labs: MCP Security Notification — Tool Poisoning Attacks](https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks)
- [Invariant Labs: MCP Security Notification — Rug Pulls](https://invariantlabs.ai/blog/mcp-security-notification-rug-pulls)
- [Anthropic: The "think" tool（2025-03-20）](https://www.anthropic.com/engineering/claude-think-tool)——零运行时逻辑工具的 τ-bench / SWE-bench 证据
- [Anthropic: Claude 3.5 Sonnet 与 computer use（2024-10-22）](https://www.anthropic.com/news/3-5-models-and-computer-use)
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793)
