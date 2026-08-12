---
title: 案例：LangGraph
description: 深入拆解 LangGraph 的 harness 设计——用状态图显式建模 agent 控制流的「框架派」思路，与 Claude Code 式自由 loop 的哲学对比，以及什么时候该用框架、什么时候该手写循环。
---

# 案例：LangGraph

> LangChain 团队 2024 年 1 月发布的 agent 编排框架。它代表 harness 设计的「框架派」：不信任一个裸奔的 while 循环，而是用**图（graph）**把 agent 的控制流显式建模出来——状态、节点、边、断点、持久化，全部由开发者显式声明。

## 它是什么：图，而不是循环

在 [Claude Code 案例](/case-studies/claude-code)中你会看到另一种极端：harness 的核心就是一个主循环（主 loop），模型自己决定何时调用工具、何时结束，整个「认知架构」藏在 prompt 和工具设计里，控制流对开发者几乎是隐形的。

LangGraph 站在对面。它的主张是：**当 agent 要上生产环境，自由循环不够可控**。LangChain 在发布公告里讲得很直白——实践中他们发现，把 agent 推入生产的公司往往需要更强的控制：强制 agent 第一步必须调某个工具、不同状态下用不同 prompt、对工具调用方式做精细约束。他们内部把这种更受控的形态称为「状态机（state machine）」：

> 状态机保留了循环的能力——能处理比简单 chain 更模糊的输入——但循环的构造方式里仍有人类的引导。

LangGraph 就是把这种状态机用图来表达的方式。整个框架对外暴露的核心接口窄得惊人：**一个 `StateGraph` 类**。你定义状态，加节点，连边，编译，运行——仅此而已。

::: info 一句话定位
LangGraph 官方的自我定位是「低层 agent 编排框架（low-level agent orchestration framework）」：没有隐藏 prompt，没有内置的认知架构，给你的是持久执行（durable execution）和细粒度控制。它要解决的问题不是「帮你快速搭个 demo」，而是「让复杂 agentic 系统在生产环境跑得稳」。
:::

## 为什么需要它：从 DAG 到循环，从循环到受控的循环

要理解 LangGraph 的动机，得先看 LangChain 自己的演进教训：

1. **第一阶段：链（Chain/DAG）**。LangChain 早期的核心抽象是 chain——一步接一步的流水线，本质是**有向无环图（DAG）**。典型如 RAG：检索 → 生成，一条路走到底。问题是 DAG 无法表达「检索结果不好就换个查询再来一次」这种**循环**。
2. **第二阶段：自由循环（AgentExecutor）**。引入循环，让 LLM 在循环里推理下一步做什么——「本质上就是把 LLM 放进一个 for 循环」。这就是 AutoGPT 那套，也是 Claude Code 主循环的近亲。它最简单，也最激进：**几乎所有决策权都交给了模型**。
3. **第三阶段：受控循环（LangGraph）**。自由的代价是不可控。生产中你需要的是：循环可以存在，但**循环的拓扑结构由人定义**，模型只在结构允许的范围内做选择。

```
演化路径：

  Chain (DAG)          AgentExecutor            LangGraph
 ┌────┐   ┌────┐      ┌──────────┐             ┌──────────┐
 │检索 │ → │生成 │      │  LLM     │             │  LLM     │←──┐
 └────┘   └────┘      │ ↓     ↑  │             │    ↓     │   │
                      │ 工具调用  │             │  条件边   │   │
                      └──────────┘             │    ↓     │   │
  无循环，可控           └── 模型全权决定 ──┘      │  工具    │───┘
  但死板                                        └──────────┘
                                                有循环，但拓扑由人画
```

注意一个微妙的事实：**自由循环是 LangGraph 的真子集**。用 LangGraph 复刻一个 ReAct 循环只需要两个节点（模型节点 + 工具节点）加一条条件边。所以这场「哲学之争」不是能不能做，而是**默认值和控制权归谁**。

## 核心机制拆解

### State：带合并规则的共享状态

图的所有节点共享一个状态对象。创建 `StateGraph` 时传入状态定义，每个字段要声明两件事：**存什么**和**怎么合并（reducer）**：

- **覆盖（override）**：节点返回新值，直接替换旧值。适合「当前计划」「下一步动作」这类字段。
- **追加（add）**：节点返回增量，自动累加到旧值上。典型应用是消息列表——每个节点只返回新产生的消息，框架负责拼接历史。

```python
from typing import TypedDict, Annotated
import operator
from langgraph.graph import StateGraph

class State(TypedDict):
    input: str
    # Annotated[..., operator.add] 声明：这个字段用「追加」方式合并
    all_actions: Annotated[list[str], operator.add]

graph = StateGraph(State)
```

这个 reducer 设计是 LangGraph 最被低估的决策。它让**节点保持纯粹**：节点不关心全局状态的历史，只声明「我这步产出了什么增量」。状态管理从业务代码里被剥离，沉到了框架层。对比手写 loop 里那个越滚越大、人人直接读写的 `messages` 列表，这是典型的框架派洁癖——多一层抽象，换一条纪律。

### Node：输入状态、输出增量

节点是普通函数（或 LangChain Runnable），签名为「读入状态字典 → 返回要更新的字段字典」：

```python
def call_model(state: State) -> dict:
    # 只返回增量，不碰全量状态
    return {"all_actions": ["model_called"]}

graph.add_node("model", call_model)
graph.add_node("tools", tool_executor)
```

还有一个特殊节点 `END`，表示图的终点。公告里特意提醒：**你的循环必须能最终走到 END**——图的表达能力包含无限循环，把「何时停」的责任还给了图的设计者。

### Edge：人画的边与模型选的边

LangGraph 有三种边，这三种边恰好对应控制权的三个层级：

| 边类型 | 写法 | 含义 | 决策权在谁 |
|---|---|---|---|
| 入口边 | `set_entry_point("model")` | 图从这里开始 | 人 |
| 普通边 | `add_edge("tools", "model")` | A 之后**永远**走 B | 人 |
| 条件边 | `add_conditional_edges(...)` | 函数（常由 LLM 驱动）决定去哪 | 人画选项，模型选 |

条件边是理解 LangGraph 哲学的钥匙。它接受三样东西：上游节点、一个路由函数、一个「路由结果 → 节点名」的映射表。注意这个映射表的存在——**模型只能在预定义的选项里选，不能去图里不存在的地方**。这就是「受控」的落点：模型的自由度被精确地圈定在边集合里。

```python
graph.add_conditional_edges(
    "model",
    should_continue,          # 路由函数：看模型输出决定去向
    {
        "end": END,           # 模型说「完成了」→ 结束
        "continue": "tools",  # 模型说「要调工具」→ 工具节点
    },
)

app = graph.compile()  # 编译成可运行的 Runnable
```

### Checkpointer：把「跑到哪了」变成一等公民

到这里为止，LangGraph 还只是一个「带循环的流程图引擎」。真正让它区别于普通编排库的是持久化层。

**Checkpointer（检查点器）**在图执行的每个超级步（super-step）把完整状态快照写入存储（内存、SQLite、Postgres 等），并用 `thread_id` 标识一条执行线索：

```python
from langgraph.checkpoint.memory import MemorySaver

checkpointer = MemorySaver()
app = graph.compile(checkpointer=checkpointer)

config = {"configurable": {"thread_id": "user-42"}}
app.invoke({"input": "帮我退款"}, config)   # 每个节点执行后自动存档
```

有了它，一批在自由 loop 里要自己硬造的能力变成了基础设施：

- **断点续跑**：进程崩了、机器重启了，从最后一个检查点恢复，不丢进度。
- **时间旅行（time travel）**：回放历史任意一步的状态，从中间某个检查点分叉重跑——调试 agent 的杀手锏。
- **多会话隔离**：不同 `thread_id` 是独立的状态流，天然支持多租户、多对话。

::: tip 与手写 loop 的本质差异
手写 loop 里，「当前状态」就是进程内存里的几个变量，进程死了就死了。LangGraph 把 agent 的执行变成类似数据库事务的东西：**状态外置、步步存档、可恢复可回放**。这是「框架派」最硬的工程价值，也是对长任务（跑几小时、跨人审几天）场景最实际的支撑。
:::

### Interrupt：把「人」建模成图的一种事件

人类在环（human-in-the-loop）在自由 loop 里通常意味着打断循环、弹个确认框、再把结果塞回去——处处是特例代码。LangGraph 的做法是把暂停/恢复做成运行时的一等机制。

在节点内任意位置调用 `interrupt()`，图就会**精确地停在那里**：状态存档，payload 抛给调用方，无限期等待。之后用 `Command(resume=...)` 重新调用图，resume 值会成为 `interrupt()` 调用的返回值，节点继续跑：

```python
from langgraph.types import interrupt, Command

def refund_node(state: State) -> dict:
    # 执行到这一行，图暂停，把退款信息抛出去等人审
    decision = interrupt({"action": "refund", "amount": state["amount"]})
    if decision["approved"]:
        do_refund(state["amount"])
    return {"all_actions": ["refund_processed"]}

# 外部（几小时后、另一个进程里）恢复执行：
app.invoke(Command(resume={"approved": True}), config)
```

除了动态的 `interrupt()`，还有静态断点：编译或运行时设 `interrupt_before=["tools"]`，图会在执行某节点**之前**暂停——这正是「工具调用前人工审批」这个最常见安全模式的直接表达。

::: warning 一个容易踩的坑
`interrupt()` 的恢复语义是「**从头重跑整个节点**」，而不是从 `interrupt()` 那一行接着跑。官方文档因此立下几条规矩：`interrupt` 之前不要有非幂等的副作用（比如先写库再问人，恢复时会写两遍）；不要用裸 `try/except` 包住 `interrupt`（它是靠抛异常实现暂停的，会被你吞掉）；一个节点内多个 `interrupt` 的顺序在每次执行间必须保持一致。这些约束都是「重放式恢复」这个设计选择的代价。
:::

## 状态机 vs 自由循环：这场争论到底在争什么

把 LangGraph 和 Claude Code 放在一起，是理解整个 harness 设计空间最好的对照实验。两边用同一个量级的模型，却得出了相反的架构结论：

| 维度 | LangGraph（框架派） | Claude Code（自由循环派） |
|---|---|---|
| 控制流 | 显式：图的拓扑写死在代码里 | 隐式：模型在 loop 里即兴决定 |
| 核心抽象 | State / Node / Edge / Checkpointer | 一个主循环 + 一组工具 |
| 模型的自由度 | 被条件边圈定，只能选已有选项 | 几乎全权，直到自己说「完成」 |
| 认知架构的位置 | 在图结构里，代码可见、可审 | 在 system prompt 里，文本可见 |
| 状态持久化 | 框架级 checkpointer，免费获得 | 进程内存为主，自建会话存储 |
| 人在环 | 一等机制（interrupt / 断点） | 权限层拦截工具调用 |
| 调试方式 | 时间旅行、状态快照、图可视化 | 看轨迹日志、重放 transcript |
| 最痛的地方 | 图设计本身成了需要维护的软件 | 行为不可完全预测，边界靠 prompt 守 |

争论的实质是**「信任模型到什么程度」**。自由循环派押注：模型已经足够聪明，最好的 harness 是给它干净的工具和充分的上下文，然后**少管它**；任何人为画的流程图都是先验偏见，模型变强后都会变成束缚。框架派押注：企业场景容不下「大多数时候对」——每一步的可预测性、可审计性、可恢复性都是硬需求，而这些不可能从一团即兴的循环里长出来。

值得注意的是，连 Anthropic 自己也承认这个张力。其《Building effective agents》一文把系统分成两类：**工作流（workflow，LLM 沿预定义代码路径被编排）**和**智能体（agent，LLM 动态指挥自己的流程）**——这几乎就是 LangGraph 与 Claude Code 的定义。而该文的建议是：先找最简单的方案，很多任务根本不需要 agentic 系统；框架能让你快速起步，但也容易堆出难以调试的抽象层。

::: details 一个更微妙的观察：两边都在向对方收敛
LangGraph 1.0 时代的官方叙事已经软化：它提供了 `create_agent` 这类预建（prebuilt）高层接口，底层正是「模型节点 + 工具节点 + 条件边」的自由循环——用图实现一个 loop，承认 loop 是对的默认起点。而 Claude Code 这类产品也在长出框架派设施：权限规则、hooks、子代理（subagent）这些机制，本质都是在自由循环外面加显式结构。纯粹的立场都不存在了，剩下的是**滑杆上的位置选择**。
:::

## 适合与不适合的场景

**LangGraph 发光的地方：**

- **流程确定性强的业务**：客服工单处理、理赔审批、文档审核流水线——步骤基本固定，LLM 负责其中的理解和生成环节。把流程画成图，可读性、可审计性、可测试性全是收益。
- **强合规 / 强人审场景**：金融、医疗、政企。interrupt + checkpointer 组合让「每一步谁批的、当时状态是什么」有据可查，审批可以跨小时甚至跨天。
- **长任务与不可靠环境**：要跑几小时的批处理 agent，进程崩溃是常态而非意外，durable execution 是刚需。
- **多智能体编排**： supervisor 模式、层级团队等复杂拓扑，用图表达比用嵌套循环清晰得多。
- **需要精细控制模型行为的场合**：强制首步调工具、按状态切 prompt、限制可选动作集合——条件边就是为此而生。

**LangGraph 硌脚的地方：**

- **开放探索型任务**：「修这个 repo 里的 bug」「调研这个主题」——解空间事先画不出图，强行画图只会得到一个「模型节点 → 工具节点 → 模型节点」的两节点图，框架的价值退化成提供 checkpointer，复杂度却照付。
- **快速原型 / 一次性脚本**：为一个周末项目引入状态 schema、reducer、编译、checkpointer 的概念税，不划算。
- **模型能力红利期**：模型每隔几个月就强一截，你精心画的控制流可能很快变成限制模型的天花板。自由 loop 自动吃红利，图要人工重画。
- **团队没有框架学习预算**：LangGraph 概念不多但相互咬合（state 合并、超级步、重放语义、Command），用错方式的隐性成本不低——`interrupt` 的重放语义就坑过不少人。

## 判断框架：框架还是手写循环？

把决策压缩成四个问题，按顺序问自己：

```
Q1. 任务的控制流能事先画出来吗？
    ├─ 能，且步骤相对固定 ──────→ 图/框架收益大（Q2）
    └─ 不能，路径高度开放 ──────→ 倾向手写 loop（Q4）

Q2. 需要跨进程持久化、断点续跑、人审断点吗？
    ├─ 需要 ───────────────────→ LangGraph 几乎是现成答案
    └─ 不需要 ─────────────────→ 手写 DAG/流程代码可能更简单

Q3. 失败的可接受成本是什么？
    ├─ 错一步 = 资损/合规事故 ──→ 受控循环，每个岔路都要人画
    └─ 错了重跑就好 ───────────→ 自由循环 + 好工具 + 评测

Q4. 你在押注模型未来的进步吗？
    ├─ 是，希望自动吃到能力红利 → 薄 harness，少硬编码流程
    └─ 否，要锁定当前行为 ──────→ 显式状态机，行为冻结在图里
```

实践中大量团队的落点是**混合架构**：外层是一个确定性的图（接单 → 分类 → 分流 → 归档），内层某个节点里跑一个自由循环的 agent（「处理这一类工单」）。图负责**可治理的部分**，loop 负责**不可预知的部分**——这也是本站[总体架构解剖](/guide/anatomy)中反复强调的分层思路。

最后记住一个反模式：**不要因为 LangGraph 存在，就把所有东西都塞进图里**。如果一个 `while` 循环加二十行代码就能表达你的逻辑，引入图抽象不是工程严谨，是仪式感。

## 延伸阅读

- [智能体循环（Agent Loop）](/components/agent-loop)——LangGraph 要替代/约束的那个东西，先看懂它
- [案例：Claude Code](/case-studies/claude-code)——哲学光谱的另一端，自由循环派的代表
- [记忆系统](/components/memory)——checkpointer 与 agent 记忆的关系
- [权限、安全与人类在环](/components/permissions)——interrupt 背后的通用问题：人该在环的哪个位置
- [规划与任务分解](/components/planning)——图结构本质上是一种静态规划
- [从零构建一个最小 Harness](/practice/build-your-own)——亲手写一个 loop，再决定要不要框架
- [Harness 设计原则](/practice/design-principles)——把本文的判断框架放进更大的原则体系

## 参考资料

- [LangGraph 发布公告（LangChain 官方博客，2024 年 1 月）](https://blog.langchain.dev/langgraph/)——动机、StateGraph API、三种边的原始定义，本文多处引述
- [LangChain & LangGraph 1.0 alpha 发布公告（2025 年 9 月）](https://blog.langchain.com/langgraph-v1/)——「低层编排框架」定位、Uber/LinkedIn/Klarna 生产使用、`create_agent` 与 prebuilt 的关系
- [LangChain 官方：LangGraph 1.0 GA 说明](https://www.langchain.com/resources/langchain-vs-autogen)——1.0 正式版于 2025 年 10 月 22 日发布
- [LangGraph 官方文档：Interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)——`interrupt()` / `Command(resume=...)` 语义、重放规则与使用约束
- [Building effective agents（Anthropic，2024 年 12 月）](https://www.anthropic.com/engineering/building-effective-agents)——workflow 与 agent 的二分法，以及「先找最简单方案」的建议
- [What is a cognitive architecture?（LangChain 博客）](https://blog.langchain.dev/what-is-a-cognitive-architecture/)——「状态机」谱系与认知架构的原始讨论
- [Top LangGraph agents in production 2024（LangChain 官方博客）](https://blog.langchain.dev/top-5-langgraph-agents-in-production-2024/)——「低层、可控、无隐藏 prompt」的框架定位自述
