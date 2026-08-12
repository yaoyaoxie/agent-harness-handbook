---
title: 常见陷阱与反模式
description: Agent Harness 开发中的十个高频反模式：过度框架化、工具爆炸、上下文垃圾堆积、无终止条件、静默失败、过度自动化、Prompt 银弹、Demo 驱动开发、忽视成本与延迟、过早多智能体化——每条附症状、根因与解药。
---

# 常见陷阱与反模式

Harness 的失败和传统软件的失败长得很不一样。传统软件挂了会抛异常、打堆栈、亮红灯；harness 挂了往往是**安静地变蠢**——不报错，只是输出越来越差、循环越来越多、账单越来越长。等你从用户投诉里发现时，问题通常已经存在好几周了。

这个特点决定了 harness 反模式（anti-pattern）的形态：它们大多不是"写错了"，而是"少写了一个约束"。本页把社区实践中最常踩的十个坑整理成清单，每条按 **症状 → 根因 → 解药** 三段展开，并给出尽量贴近真实的示例场景。

::: tip 使用方式
建议先扫一遍下面的速查表，命中症状再跳去读对应小节。如果你正在从零搭 harness，可以把本页当验收清单（checklist）用。
:::

## 速查表

| # | 反模式 | 典型症状 | 一句话解药 |
|---|--------|----------|------------|
| 1 | 过度框架化 | 想改个行为要读三层抽象 | 先用裸 API + 一个 while 循环跑通 |
| 2 | 工具爆炸 | agent 选错工具、参数乱填 | 收敛到少量正交工具，其余按需加载 |
| 3 | 上下文垃圾堆积 | 会话越长越蠢、越贵 | 工具输出一律截断/压缩/外置 |
| 4 | 无终止条件 | 死循环烧 token，凌晨收到账单 | 步数/成本/时间三重硬上限 |
| 5 | 静默失败 | agent 重复同一个失败操作十次 | 错误必须结构化地回到上下文 |
| 6 | 过度自动化 | agent 删了生产库，没人点过头 | 按不可逆性分级拦截 |
| 7 | Prompt 银弹 | system prompt 三千行还在变坏 | 该改结构时改结构 |
| 8 | Demo 驱动开发 | "我演示给你看它能行" | 先写 evals 再谈能力 |
| 9 | 忽视成本与延迟 | 单次任务 \$8、首响应 40 秒 | 把成本当一等指标进观测 |
| 10 | 过早多智能体化 | 五个 agent 互相踢皮球 | 单 agent + 子任务隔离先做到极致 |

---

## 1. 过度框架化（Framework-First）

**症状**

项目第一天就引入重型 agent 框架，两周后团队的主要工作变成：读框架源码、给框架提 issue、绕开框架的默认行为。想调整一个重试逻辑，发现它被埋在第三层 callback 里；想换个模型，发现框架的抽象把 provider 特有参数挡在了外面。

**根因**

把"成熟度错觉"投射到了框架上：以为框架封装的是稳定领域知识。实际上 agent 领域 2023 年以后几乎每半年重构一次最佳实践，框架封装的往往是**上一个季度的共识**。Anthropic 在与数十个客户团队合作后给出的观察很直接：最成功的实现用的是简单、可组合的模式，而不是复杂框架（见 [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)，2024-12）。

**示例场景**

> 团队 A 用某框架的 `PlanAndExecuteAgent` 类做代码审查 agent。上线后发现 planner 生成的计划总是过度细分，想改成"一次只规划两步"。但 planner 是框架内置组件，prompt 模板是私有属性，最后只能用 monkey-patch 换掉半个类——此时他们维护的框架补丁已经比业务代码还长。

**解药**

- 第一版 harness 只允许三样东西：LLM API 调用、一个 `while` 循环、一个工具分发表。几十行代码就能跑起来，详见 [造一个自己的 Harness](/practice/build-your-own)。
- 框架可以引，但只在它解决**你已经疼过**的问题时引——比如你需要生产级的 checkpoint 持久化，再考虑 LangGraph 这类带状态图的框架（参见 [LangGraph 案例](/case-studies/langgraph)）。
- 判断标准：你能否在一张纸上画出框架替你做的事？画不出，就是框架在替你做决定。

::: info 一条经验
你在框架里学的 API，换个框架就作废；你在裸循环里学的 agent 循环、上下文组装、错误处理，换一个项目照样成立。先把后者练熟。
:::

---

## 2. 工具爆炸（Tool Sprawl）

**症状**

agent 有 50 个工具：`read_file`、`read_lines`、`read_file_range`、`read_file_with_encoding`……然后它开始：调错工具、把 A 工具的参数填给 B 工具、在三个功能重叠的工具之间反复横跳，或者在根本不需要工具时硬调一个。

**根因**

每加一个工具，模型的选择问题就难一分，而且所有工具的 schema 都占着上下文窗口。研究侧对此有相当一致的证据：候选工具变多会主动拉低选择准确率（[How Many Tools Should an LLM Agent See?](https://arxiv.org/abs/2605.24660)，arXiv 2605.24660）；RAG-MCP 的论文直接把"把所有工具塞进 prompt"命名为 prompt bloat，并用检索式选择缓解（arXiv 2505.03275）；QLCoder 团队的工程复盘也记录过：给 agent 一大套异构工具导致选择混乱，收敛到一个小而明确的工具箱后行为立刻稳定下来（arXiv 2511.08462）。

**示例场景**

> 一个运维 agent 接了公司内部 40 个 API。排查"服务 502"时，它先调 `get_service_status`（返回正常），再调 `list_pods`（参数填错），再调 `get_metrics`（选了错的时间窗口），二十分钟后给出结论"一切正常"。把工具裁到 8 个、并把三个状态查询合并成一个带 `scope` 参数的 `inspect_service` 之后，同类任务平均 6 步收敛。

**解药**

- **合并同类项**：凡是"读文件"的工具合成一个，用参数表达差异。好的工具设计准则见 [工具设计](/components/tools)。
- **按任务阶段动态挂载**：规划阶段只给只读工具，执行阶段才给写工具。工具集是 per-step 的，不是 per-agent 的。
- **真需要大规模工具库时**，加一层检索/路由（RAG-MCP 式），让模型每步只看 5–10 个候选，而不是整个注册表。
- 参考 SWE-agent 的做法：它的 ACI（agent-computer interface）设计刻意把接口收敛到少量高内聚命令，还专门证明接口设计本身显著影响成功率（[SWE-agent 论文](https://arxiv.org/abs/2405.15793)，NeurIPS 2024；另见 [SWE-agent 案例](/case-studies/swe-agent)）。

---

## 3. 上下文垃圾堆积（Context Hoarding）

**症状**

会话进行到第 30 轮，agent 开始"失忆"：忘了开头定下的约束，重复读已经读过的文件，结论质量肉眼可见地下滑。查看 trace，发现上下文里躺着一份 8,000 行的 `npm install` 输出、三份完整的 SQL dump、和某次 `git log` 的全部历史。

**根因**

两个认知误区叠加：一是"窗口够大，塞得下"；二是"万一后面要用呢"。但上下文不是硬盘——**每个 token 都在消耗模型的注意力预算**。Liu 等人的 Lost in the Middle（[arXiv 2307.03172](https://arxiv.org/abs/2307.03172)，2023）证明模型对上下文中段信息的利用呈 U 型塌陷；Anthropic 后来把这个现象工程化地命名为 context rot：随着窗口填满，召回精度持续下降（[Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)，2025-09）。

**示例场景**

```
[step 12] $ grep -rn "TODO" src/          → 返回 2,300 行，全部进上下文
[step 13] $ cat package-lock.json          → 41,000 行，全部进上下文
[step 14] $ python manage.py test          → 失败堆栈 600 行，进上下文
...
[step 30] 模型：我看到你的问题是……（已经忘了用户在 step 1 说的"不要动 db 目录"）
```

**解药**

- **工具输出永远过一道闸门**：截断（head/tail）、摘要、或写入临时文件后只把路径和摘要放回上下文。这就是 [上下文工程](/components/context-engineering) 的核心动作。
- **区分"引用"与"内容"**：上下文里放文件路径、行号区间、查询条件这类轻量指针，让模型需要时自己取——just-in-time 检索，而不是预先全量装载。
- **会话长了就压缩（compaction）**：把历史总结成"已确认事实 + 未完成事项"，开新窗口继续。Claude Code 用的正是这套策略，见 [Claude Code 案例](/case-studies/claude-code)。

::: warning 一个反直觉的点
"让 agent 记住一切"不是美德。人类工程师排查问题时会关掉无关的终端标签页，harness 也应该替 agent 做同样的事。
:::

---

## 4. 无终止条件（Runaway Loop）

**症状**

某个周五晚上，agent 接到一个边界情况任务，在"尝试 → 失败 → 换个说法再尝试 → 失败"里转了四个小时，烧了 \$300，第二天早上你看着用量面板以为系统被打了。

**根因**

Agent 循环的本质是 `while not done: step()`，而 `done` 由模型自己判断。模型在困难任务上的自我评估不可靠——它永远觉得"再试一次就快成了"。ReAct 式的循环（[ReAct 论文](https://arxiv.org/abs/2210.03629)，ICLR 2023）本身不内置任何预算概念，预算必须由 harness 层强行注入。

**解药**

终止条件必须是**多层硬约束**，写死在循环里，不依赖模型自觉：

```python
MAX_STEPS = 50
MAX_COST_USD = 2.0
MAX_WALL_CLOCK = 1800  # 秒

while True:
    if state.steps >= MAX_STEPS:
        return fail("step budget exhausted", partial=state)
    if state.cost_usd >= MAX_COST_USD:
        return fail("cost budget exhausted", partial=state)
    if time.monotonic() - state.started_at > MAX_WALL_CLOCK:
        return fail("time budget exhausted", partial=state)
    step(state)
```

再加一条行为级检测：**连续 N 步无状态变化**（同工具同参数、或 diff 为空）直接判死循环退出。预算耗尽时的返回值要带上 partial state——部分进度往往比"重来一次"值钱。更多终止条件设计见 [Agent 循环](/components/agent-loop)。

---

## 5. 静默失败（Swallowed Errors）

**症状**

日志显示任务"成功完成"，但产物是错的。回放 trace 才发现：第 4 步的写文件其实失败了，第 7 步的 API 调用返回 403——但 agent 对此一无所知，继续在错误前提上搭了二十步积木。

**根因**

两类典型写法：

```python
# 反模式 A：吞掉异常
try:
    result = run_tool(name, args)
except Exception:
    result = None          # 模型看到的是"没有输出"，不是"失败了"

# 反模式 B：把错误降级成模糊文本
except Exception as e:
    result = "something went wrong"   # 模型无法据此修正行为
```

模型收不到"失败"这个信号，自然不会重试或换路径；更糟的是，它会把失败步的空输出当成"操作成功但没有结果"写进后续推理。

**解药**

- 错误**结构化地回注上下文**：错误类型、错误消息、（脱敏后的）堆栈摘要、建议的修正方向。让"失败"成为模型可以推理的一等输入。
- 区分**可重试错误**（网络超时、限流）与**不可重试错误**（权限不足、参数非法）——前者 harness 自动退避重试，后者必须明确告诉模型"此路不通，换方案"。
- 工具返回约定一个统一信封：`{ ok: bool, output?: string, error?: { kind, message, hint } }`。Anthropic 在 SWE-bench 的实践中也提到，他们花在打磨工具（包括错误信息如何回传）上的时间比调 prompt 还多（[Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)）。

::: details 一个好的错误回注长什么样
```json
{
  "ok": false,
  "error": {
    "kind": "permission_denied",
    "message": "EACCES: cannot write to /etc/nginx/nginx.conf",
    "hint": "该路径需要 root。可选：1) 写入 ./nginx.conf 并提示用户手动部署；2) 若 sudo 可用，调用 run_shell 时设置 sudo=true"
  }
}
```
模型拿到这个，下一步就能做出有意义的修正；拿到 `null`，它只会瞎猜。
:::

---

## 6. 过度自动化（Full-Auto Everything）

**症状**

为了演示"端到端无人值守"，agent 上线第一周就自动：`git push --force` 覆盖了同事的提交、`rm -rf` 了一个还没进版本控制的目录、把内部讨论内容回复到了公开 issue。每一次的 trace 都显示模型"做了当时看来合理的事"。

**根因**

把"自主（autonomy）"当成布尔值，而不是刻度盘。实际上操作的危险度至少分三档：只读 < 可逆写入 < 不可逆/外发。对三档用同一套放行策略，等于把最高风险档的赌注押在模型每一步的判断上。

**解药**

按不可逆性分级，逐级收紧：

| 级别 | 例子 | 默认策略 |
|------|------|----------|
| L0 只读 | 读文件、搜索、查询状态 | 自动放行 |
| L1 可逆写入 | 改工作区文件、跑测试 | 自动放行，但留审计日志 |
| L2 难逆操作 | 删文件、改数据库、提交代码 | 默认需人工确认，可配置白名单 |
| L3 外发/资金 | 发邮件、发 PR 评论、调用付费 API、部署生产 | 永远需人工确认 |

这就是 [权限与人机协作](/components/permissions) 整页讨论的主题。工程上还有两个便宜但高收益的动作：**dry-run 模式**（先让 agent 输出"我打算做什么"给人看）和**影响面预览**（删除前列出将受影响的文件清单）。

::: tip
"需要人确认"不是对模型能力的不信任，而是对**错误成本分布**的尊重：漏拦一次的代价远大于多点九十九次确认的代价。
:::

---

## 7. 把 Prompt 当银弹（Prompt-Only Tuning）

**症状**

system prompt 从 200 词膨胀到 3,000 词，里面塞满"非常重要：""永远不要：""再次强调："——但 agent 的行为没有变好，反而出现新的诡异失败。每次出 bad case 就往 prompt 里加一条禁令，prompt 变成一本没人（包括模型）能读完的规章制度。

**根因**

很多问题在 prompt 层**根本没有解**：

```
"agent 总是选错工具"     → 根因是 50 个工具的选择空间，不是措辞
"agent 忘记早期约束"     → 根因是 context rot，不是提醒不够多
"agent 调错参数格式"     → 根因是工具 schema 设计歧义，不是示例不够
"agent 死循环"           → 根因是没有终止条件，prompt 喊破喉咙也没用
```

往 prompt 里加补丁，本质是把结构性债务转成上下文噪音——还顺便加速了 context rot。

**解药**

养成一个排障顺序的纪律：

1. **先看 trace，定位失败发生在哪一层**：工具集？上下文组装？终止条件？权限？观测？
2. 能在结构层改的，不在 prompt 层改。工具太多就裁工具，上下文脏就加闸门，循环失控就加预算。
3. Prompt 只负责表达**无法用结构表达**的东西：领域偏好、语气、判断准则的软边界。
4. 每加一条 prompt 规则，问一句："六个月后模型换代了，这条还需要吗？"答案多为"不需要"的规则，大概率本该由 harness 承担。

SWE-agent 的论文提供了一个正面参照：他们提升成功率的关键手段不是更好的 prompt，而是重新设计 agent 与计算机之间的接口（ACI）——让正确行为更容易、错误行为更难发生（[arXiv 2405.15793](https://arxiv.org/abs/2405.15793)）。

---

## 8. Demo 驱动开发（Demo-Driven Development）

**症状**

能力证明靠"你看，我演示一遍"——演示三次成功两次，挑成功的那次截图。上线后用户报 bad case，团队的修复流程是：手动复现 → 调一下 → 再手动复现 → 祈祷没引入新问题。没有任何数字能回答"这周的版本比上周好还是差"。

**根因**

Agent 行为是概率性的，单次演示几乎不携带信息。没有 evals，所有改动都是盲人摸象：prompt 微调、模型升级、工具增删——每一个都可能让某个任务簇变好、另一个任务簇崩塌，而你没有仪器能看见。

**解药**

- **第一天就建 eval 集**，哪怕只有 20 条：真实任务 + 期望结果 + 一个能自动判分的 checker（测试通过？diff 匹配？另一个模型当裁判？）。
- 把 eval 挂进 CI：每次改 prompt、换模型、动工具，跑一遍，看成功率、平均步数、平均成本三条曲线。
- bad case 的归宿是 eval 集，不是聊天记录——每个线上失败都固化成一条回归用例。
- 这块和 [可观测性](/components/observability) 是一体两面：trace 让你看清单次运行，evals 让你看清整体趋势。

::: info 一个务实起点
不要等"完美的 eval 框架"。一个 JSONL 文件 + 一个跑完输出 pass rate 的脚本，就超过了大多数团队的现状。先有了数字，再谈数字的质量。
:::

---

## 9. 忽视成本与延迟（Blind to Cost & Latency）

**症状**

功能验收一切正常，直到财务或用户找上门：单个任务平均 \$8、P50 首响应 40 秒；客服 agent 回答"营业时间几点"也要先规划三步、调两个工具、花 90 秒。

**根因**

开发期只盯着成功率一个指标。但 agent 系统是**按步数乘法烧钱**的：每一步都重放（或重摘要）整个上下文，token 消耗随轮数近似平方增长；每一步的延迟直接叠加到用户等待上。Anthropic 的上下文工程文章里有一个值得记住的口径：agent 交互消耗的 token 量级远高于普通聊天，多智能体架构尤甚（[Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)）。

**解药**

- **成本进 trace**：每个 span 记录 input/output token、模型、单价、耗时；任务级汇总成 "成本/步数/时长" 三指标，和成功率放在同一个 dashboard 上。
- **分级路由**：简单请求路由到小模型甚至确定性代码，只有难题才上大模型。routing 是 [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) 里列出的基础模式之一，也是性价比最高的一档优化。
- **能缓存就缓存**：system prompt 和工具 schema 是稳定的，用 prompt caching；重复检索结果按 key 缓存。
- **并行化独立的工具调用**，别把可并行的步骤排成串行。
- 设预算告警（呼应第 4 条）：单次任务成本超阈值时，宁可降级为"输出部分结果 + 说明"，也不要硬跑完。

---

## 10. 过早多智能体化（Premature Multi-Agent）

**症状**

单 agent 还没调顺，架构图上已经出现了 Orchestrator、Researcher、Coder、Reviewer、Critic 五个角色。运行时五个 agent 各看各的上下文：Coder 不知道 Researcher 查到了什么，Reviewer 在批评一份基于错误前提的代码，Orchestrator 把同样的任务分派了两次。Token 账单是单 agent 的数倍，成功率却更低。

**根因**

多智能体拆分的是**上下文**，不是**能力**。子 agent 之间不共享工作记忆，所有协调都要靠显式消息传递——而每次传递都是一次有损压缩。Cognition（Devin 的团队）在 [Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents)（2025-06，Walden Yan）里把这条讲得很透：并行子 agent 各自做决定时，隐含假设一旦不一致，合并阶段就会产生无法调和的冲突；他们给出的原则是"共享上下文，共享完整 trace"。

**示例场景**

> 团队给数据分析 agent 拆出"取数 agent"和"画图 agent"。取数 agent 发现某字段全是 null 于是换了一张表——这个决定只存在于它的 trace 里。画图 agent 拿到结果后对着"错误的表"精心排版，还写了一段解读。人类检查时要同时回放两条 trace 才能定位分歧点，排查成本翻倍。

**解药**

- 先把**单 agent + 好上下文管理**做到上限：compaction、just-in-time 检索、结构化笔记（见 [记忆](/components/memory)）。很多"需要多 agent"的场景，其实需要的是单 agent 的上下文不脏。
- 真正的多 agent 适用信号：子任务**可并行、弱耦合、产出可独立验证**（典型如广度优先的资料调研）。不满足这三条，拆分只会放大协调税。
- 退一步的折中是 [子代理](/components/subagents) 模式：子 agent 在干净窗口里做聚焦任务，只把压缩后的结论交还主 agent——上下文隔离的收益拿到了，决策权仍集中在一处。
- 读一下对立面的论据再决定：LangChain 的 [How and when to build multi-agent systems](https://blog.langchain.com/how-and-when-to-build-multi-agent-systems/)（2025-06）回应了 Cognition 的文章，把两边的适用边界讲得比较平衡。

---

## 反模式与 harness 组件的对应关系

排查问题时，可以用这张表反查"该去读哪一章"：

| 反模式 | 主战场组件 |
|--------|------------|
| 过度框架化 | 整体架构，见 [Harness 解剖](/guide/anatomy) |
| 工具爆炸、静默失败、Prompt 银弹（部分） | [工具设计](/components/tools) |
| 上下文垃圾堆积、Prompt 银弹（部分） | [上下文工程](/components/context-engineering) |
| 无终止条件 | [Agent 循环](/components/agent-loop) |
| 过度自动化 | [权限与人机协作](/components/permissions) |
| Demo 驱动开发、忽视成本与延迟 | [可观测性](/components/observability) |
| 过早多智能体化 | [子代理](/components/subagents) |

## 三条通用防御原则

把所有反模式抽象到一层，病因只有三个，对应的防御也只有三个：

1. **一切进 trace，trace 进 evals。** 静默是 harness 的头号敌人。看不见的运行无法调试，无法量化的改进不算改进。
2. **约束写在结构里，不写在祈祷里。** 预算、权限、终止条件、输出闸门——凡是"模型不应该做"的事，都应该让模型**做不到**，而不是"被嘱咐不要做"。
3. **复杂度是债，按还息速度决定借多少。** 框架、多智能体、长 prompt、大工具箱，每一项都是借来的复杂度。借之前先问：它偿付的利息（调试成本、上下文噪音、协调税）低于它带来的收益吗？

## 延伸阅读

- [设计原则](/practice/design-principles)：本页的正面版本——反模式告诉你不要做什么，设计原则告诉你该做什么
- [造一个自己的 Harness](/practice/build-your-own)：用最小实现亲手踩一遍这些坑的浅层版本
- [模型 vs Harness](/guide/model-vs-harness)：为什么这些坑大多与模型能力无关
- [核心论文清单](/papers/core-papers)：本页引用的 ReAct、Lost in the Middle、SWE-agent 等论文的完整导读

## 参考资料

- [Anthropic — Building effective agents（2024-12-19）](https://www.anthropic.com/engineering/building-effective-agents)：简单可组合模式优于复杂框架；工具打磨比 prompt 调优更耗时；routing 等基础模式
- [Anthropic — Effective context engineering for AI agents（2025-09-29）](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)：context rot、注意力预算、compaction、just-in-time 检索
- [Cognition — Don't Build Multi-Agents（2025-06-12）](https://cognition.com/blog/dont-build-multi-agents)：多智能体的上下文碎片化问题与"共享上下文"原则
- [LangChain — How and when to build multi-agent systems（2025-06-16）](https://blog.langchain.com/how-and-when-to-build-multi-agent-systems/)：对 Cognition 文章的回应，多智能体的适用边界
- [Liu et al. — Lost in the Middle: How Language Models Use Long Contexts（2023，arXiv 2307.03172）](https://arxiv.org/abs/2307.03172)：长上下文中段信息利用率的 U 型塌陷
- [Yao et al. — ReAct: Synergizing Reasoning and Acting in Language Models（ICLR 2023，arXiv 2210.03629）](https://arxiv.org/abs/2210.03629)：推理-行动交替的 agent 循环范式
- [Yang et al. — SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering（NeurIPS 2024，arXiv 2405.15793）](https://arxiv.org/abs/2405.15793)：接口/工具设计对 agent 成功率的显著影响
- [How Many Tools Should an LLM Agent See?（arXiv 2605.24660）](https://arxiv.org/abs/2605.24660)：候选工具数量对选择准确率的负面影响
- [RAG-MCP: Mitigating Prompt Bloat in LLM Tool Selection via Retrieval-Augmented Generation（2025，arXiv 2505.03275）](https://arxiv.org/abs/2505.03275)：工具注册表过大时的检索式选择方案
- [QLCoder: A Query Synthesizer for Static Analysis（arXiv 2511.08462）](https://arxiv.org/abs/2511.08462)：工程复盘中"大工具箱导致选择混乱、小工具箱更可靠"的实证记录
