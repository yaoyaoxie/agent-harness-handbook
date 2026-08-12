---
title: 智能体循环（Agent Loop）
description: Agent Loop 是 Harness 的心脏：一个 while 循环如何组装上下文、调用模型、执行工具、处理错误并决定何时停止——从 ReAct 论文到生产级实现的完整拆解。
---

# 智能体循环（Agent Loop）

## 概念定义：心脏就是一个 while 循环

剥掉所有框架、协议和营销话术，一个 AI 智能体（agent）的核心控制流可以写在一张便签上：

```text
while not done:
    context   = assemble(history, memory, tools)   # 观察：组装模型要看到的一切
    response  = llm(context)                        # 思考：模型产出文本或 tool call
    if response.has_tool_calls():
        results = execute(response.tool_calls)      # 行动：harness 代为执行工具
        history.append(response, results)           # 把观察结果追加回上下文
    else:
        done = True                                  # 没有 tool call = 模型认为干完了
```

这就是**智能体循环（agent loop）**：模型提出建议，harness 负责执行并把结果喂回去，如此往复，直到任务完成或被迫停止。Anthropic 在 2024 年 12 月发布的《Building effective agents》中把智能体定义为「LLM 动态指挥自身流程与工具使用的系统」——这个「动态指挥」在代码层面就物化为这个循环：循环的**每一轮迭代走几步、何时退出，都不是程序员写死的，而是模型当场决定的**。

这正是 agent 与 workflow 的分水岭。Workflow 的控制流写在代码里（先检索、再摘要、再生成），agent 的控制流写在循环里——代码只提供原语（工具、上下文、终止条件），模型决定编排。

::: info 术语
学术界常把这个结构称为 **observe–think–act**（观察–思考–行动）循环，源于强化学习中的智能体–环境交互范式。在 LLM 语境下：环境 = 文件系统、终端、浏览器、API；观察 = 工具执行结果；思考 = 模型的推理输出（常表现为 tool call 之前的自然语言推理）。
:::

## 为什么需要循环：一次推理解决不了真实任务

单轮 LLM 调用是无状态的函数：`f(prompt) -> text`。但真实任务有三个性质，决定了你必须把它包进循环：

1. **信息是逐步暴露的。** 修一个 bug 需要先读报错、再定位文件、再看调用链——下一步要看什么，取决于上一步看到了什么。任何静态编排都无法预先穷举这条路径。
2. **动作会改变世界。** 编辑文件、跑测试、发请求都会改变环境状态，而后续决策必须基于**新**状态。循环是把「行动的后果」重新注入决策的唯一通道。
3. **错误是常态，恢复靠反馈。** 命令拼错、测试失败、API 超时——模型需要看到失败输出才能自我修正。把错误输出原样追加进上下文，就是最简单也最有效的纠错机制。

换一个角度：**模型提供的是「下一步做什么」的判断力，循环提供的是「把判断执行到底」的持久性。** 没有循环，模型只是一个顾问；有了循环，它才变成一个干活的系统。这也是为什么同一批模型，在 SWE-bench 这类榜单上的成绩差异主要来自 harness——循环及其周边设施（上下文组装、工具设计、终止判断）正是 harness 的核心，参见 [什么是 Agent Harness](/guide/what-is-harness) 与 [模型 vs 骨架](/guide/model-vs-harness)。

## 解剖一轮迭代：harness 每圈到底做什么

「模型想一步」听起来简单，但一轮迭代里 harness 要干六件事，每一件都有真实的工程决策：

```text
                 ┌─────────────────────────── 一轮迭代 ───────────────────────────┐
                 │                                                              │
                 ▼                                                              │
   ┌──────────────────┐   ┌───────────────┐   ┌────────────────────────────┐    │
   │ 1. 组装上下文      │──▶│ 2. 调用模型    │──▶│ 3. 解析输出                 │    │
   │ system prompt    │   │ 流式接收       │   │ tool call 参数校验          │    │
   │ 历史消息(可压缩)  │   │ 超时/重试      │   │ 无 tool call → 终止判断     │    │
   │ 工具 schema      │   │ 可被打断       │   └─────────────┬──────────────┘    │
   │ 记忆/检索结果     │   └───────────────┘                 │                   │
   └──────────────────┘                                     ▼                   │
                                              ┌────────────────────────────┐    │
                 ┌────────────────────────────│ 4. 权限检查 → 执行工具       │────┘
                 │                            │ 超时 / 沙箱 / 并发          │
                 ▼                            └────────────────────────────┘
   ┌──────────────────┐   ┌────────────────────────────┐
   │ 6. 检查终止条件    │◀──│ 5. 追加观察                  │
   │ 完成? 超预算?      │   │ 结果截断/摘要后进 history     │
   │ 熔断? 人工打断?    │   │ 更新成本/步数计数器           │
   └──────────────────┘   └────────────────────────────┘
```

**1. 组装上下文。** 每轮开头，harness 把 system prompt、对话历史、工具定义、记忆检索结果拼成一次完整的模型调用。上下文不是只增不减的——超限时要做压缩或截断，这是 [上下文工程](/components/context-engineering) 的核心问题。

**2. 调用模型。** 通常是流式调用（见下文「流式与中断」），带超时和重试。生产环境还必须处理限流（HTTP 429）和负载均衡。

**3. 解析输出。** 模型输出两种东西：自然语言（推理过程、给用户的解释）和结构化的 tool call。harness 要校验 tool call 的参数是否符合工具的 JSON Schema——模型生成非法参数是家常便饭，不能直接把未校验的输入送进工具。

**4. 执行工具。** 执行前过 [权限系统](/components/permissions)（危险命令要用户批准），执行中带超时和输出截断。注意：**工具的执行者是 harness，不是模型**。模型只产出「意图」，这一分离是所有安全边界的根基。

**5. 追加观察。** 把 tool call 及其结果追加到历史。关键细节是**结果预处理**：一次 `grep` 可能返回 10MB 文本，直接塞回上下文会把窗口撑爆，必须截断、分页或摘要。

**6. 检查终止条件。** 这是最容易被低估、却最决定系统行为的一步，值得单独展开。

## 终止条件：让循环停下来的艺术

一个不知道什么时候停的智能体，比一个不聪明的智能体更危险——它会烧光预算、改坏文件、在死循环里空转。生产级 loop 通常叠加四层终止条件：

| 终止类型 | 触发条件 | 典型问题 | 工程要点 |
|---|---|---|---|
| **任务完成** | 模型本轮不发起任何 tool call，直接输出最终答复 | 模型可能「假装完成」——没验证就宣称修好了 | 用验证工具兜底（如要求跑测试通过后才算完成）；或在最终答复后追加一轮确认 |
| **步数 / 预算上限** | 迭代次数、token 消耗、美元成本、墙钟时间任一超限 | 硬性截断会留下半成品状态 | 到达软上限时先注入提醒（「还剩 3 步，请收尾」），硬上限才真正掐断 |
| **连续错误熔断** | 连续 N 次工具失败、模型重复输出相同 tool call、上下文超限且无法压缩 | 阈值太敏感会误杀正常的长任务 | 区分「同类错误重复」（危险信号）与「不同错误的正常探索」 |
| **人工打断** | 用户按 Esc / Ctrl-C，或权限系统要求批准时被拒绝 | 打断后状态不一致（文件改了一半） | 中断要传递为协作信号而非异常——把「用户拒绝了此操作」作为观察反馈给模型，让它换条路走 |

::: warning 「模型说完成了」不等于「任务完成了」
最常见的失控模式不是死循环，而是**提前收工**：模型改了代码但没有跑测试，就输出「已修复」。对策不是相信模型的口头承诺，而是把验证设计成任务的一部分——例如 harness 在收到完成信号后检查「本任务是否至少运行过一次测试」，或者干脆由外部评测脚本判定完成（SWE-bench 就是这么做的）。参见 [评测与可观测性](/components/observability)。
:::

## 错误恢复与重试：把失败变成上下文

循环里的错误分两类，处理方式完全不同：

**瞬时错误（重试）**：网络超时、API 限流、模型输出格式非法（如 tool call 的 JSON 没闭合）。这类错误对模型不可见，harness 用指数退避静默重试；格式错误则把解析报错本身作为反馈追加进上下文（「你的 tool call 参数非法：`Unexpected end of JSON`」），模型下一轮通常能自我修正。

**任务级错误（反馈）**：工具正常执行了，但结果是失败——编译报错、测试红了、文件不存在。**这类错误不该重试，而该原样喂回循环**。这是 agent loop 相对传统程序最反直觉的地方：在传统代码里异常意味着流程中断，在 agent loop 里失败输出是最有价值的新信息。模型看到 `AssertionError: expected 3, got 4` 之后自己就知道去改哪里。

实践中还有一条分界线：**同一个错误出现第三次，就要升级处理**——注入强提示（「此路不通，请换方案」）、要求模型先解释为什么失败再继续，或者直接触发熔断。让模型和同一个报错搏斗二十轮，是烧 token 最快的姿势。

## 流式输出与中断处理

生产级 loop 必须是流式的，原因有两个：

- **延迟感。** 一轮迭代可能包含几十秒的推理。流式把思考过程实时展示给用户，这是 Claude Code 这类工具「感觉快」的主要来源——实际总时长没变，但用户能看到它在干什么。
- **可中断性。** 用户看到模型走向错误方向时，必须能立刻打断，而不是等它把 500 行错误代码写完。中断在实现上是三层协作：传输层取消 HTTP 流、执行层给正在运行的工具发终止信号（SIGTERM → SIGKILL）、逻辑层把「被用户打断」作为一条观察追加进历史，让模型知道发生了什么、接下来该收敛。

::: tip 中断是输入，不是异常
把用户打断建模为异常（`try/except InterruptedError` 然后退出）是新手常见错误。正确姿势是把它建模为**一条新的用户消息**：循环不退出，只是当前动作作废，控制权交还用户。用户可能会纠正方向（「别改那个文件，问题在配置里」），然后循环带着新信息继续转。这个设计决定了你的工具是「易碎的自动机」还是「可协作的伙伴」。
:::

## 从 ReAct 到生产级循环：一段演化史

**2022 年 10 月，ReAct。** Shunyu Yao 等人的论文《ReAct: Synergizing Reasoning and Acting in Language Models》（发表于 ICLR 2023）首次系统论证了「推理轨迹（Thought）与行动（Action）交错」的范式：模型每一步先写出推理，再发起动作，环境的观察（Observation）回填后继续推理。这篇论文本质上是给 agent loop 立了法——此后的几乎所有智能体框架，控制流都是 observe–think–act 的变体。值得注意的是，ReAct 时代还没有 tool calling API，「动作」是模型输出里的纯文本行（`Action: search[query]`），靠正则解析。

**2023 年，AutoGPT 热与幻灭。** AutoGPT 把循环包装成「全自主智能体」，暴露了裸循环的所有短板：目标漂移、死循环、无限烧钱。教训沉淀为两条共识：循环必须有硬预算；自主性必须用权限和确认机制约束。同年 OpenAI 推出 function calling，tool call 从「正则解析的文本」变成「带 schema 的结构化输出」，解析层大幅简化。

**2024 年，工程化收敛。** SWE-agent（NeurIPS 2024）证明 harness 的接口设计——论文称之为 Agent-Computer Interface（ACI）——对 SWE-bench 成绩的影响不亚于模型本身：给模型配什么样的文件编辑命令、错误反馈怎么格式化，直接决定循环的效率。同年 Anthropic 的《Building effective agents》把业界实践收敛为一个主张：**最成功的智能体实现往往是最简单的——一个while 循环加几个工具，而不是复杂的框架编排。** OpenHands（ICLR 2025）等平台则把事件流、沙箱执行、并发工具调用做成了标准化的 loop 基础设施。

演化的方向很清晰：循环本身没有变复杂，变复杂的是**循环每一圈里 harness 提供的服务质量**——更稳的解析、更聪明的上下文管理、更细的权限粒度、更好的可观测性。模型越来越强，loop 越来越朴素，这是同一个趋势的两面。

## 生产级 Loop 骨架（约 60 行伪代码）

把上面所有机制装进一个循环，大致长这样：

```python
def agent_loop(task, budget=Budget(max_steps=50, max_cost_usd=2.0)):
    history = [system_prompt(), user_message(task)]
    consecutive_failures = 0

    while True:
        # ── 终止检查：预算与熔断 ──────────────────
        if budget.exhausted():
            return finish("超出预算上限", history)
        if consecutive_failures >= 3:
            return finish("连续失败，触发熔断", history)

        # ── 组装上下文（必要时压缩历史）────────────
        context = assemble_context(history)
        if token_count(context) > CONTEXT_LIMIT:
            history = compress(history)          # 见上下文工程一章
            context = assemble_context(history)

        # ── 调用模型（流式，可中断，瞬时错误重试）──
        try:
            response = call_llm_with_retry(
                context, stream=True, retries=3, backoff=exponential)
        except UserInterrupt as e:               # 用户打断 = 新输入，非异常
            history.append(user_message(e.feedback or "已打断当前操作"))
            continue
        except LLMError as e:                    # 重试耗尽，真挂了
            return finish(f"模型服务不可用: {e}", history)

        # ── 无 tool call = 模型认为任务完成 ────────
        if not response.tool_calls:
            if not verify_completion(task, history):   # 口头完成不算数
                history.append(user_message(
                    "请先运行测试验证修复，再宣布完成"))
                continue
            return finish(response.text, history)

        # ── 逐个执行 tool call ────────────────────
        for call in response.tool_calls:
            history.append(assistant_tool_call(call))
            try:
                validate_args(call)                      # schema 校验
                require_permission(call)                 # 危险操作要批准
                result = execute_tool(call, timeout=120) # 沙箱 + 超时
                observation = truncate(result, max_chars=30_000)
                consecutive_failures = 0
            except ValidationError as e:           # 参数非法 → 反馈给模型
                observation, consecutive_failures = f"参数错误: {e}", +1
            except PermissionDenied as e:          # 用户拒绝 → 协作信号
                observation = f"用户拒绝了此操作: {e.reason}"
            except ToolTimeout:
                observation, consecutive_failures = "执行超时(120s)", +1
            except ToolError as e:                 # 任务级失败 = 有价值的信息
                observation = truncate(f"工具报错: {e}")
            history.append(tool_result(call.id, observation))
            budget.record(call, response.usage)    # 记账：步数、token、成本
```

这份骨架刻意省略了生产系统里的更多细节——事件溯源（把每一步落盘成可回放日志）、并行 tool call、子代理派生、遥测上报——但循环的骨架不会变：**组装 → 调用 → 解析 → 执行 → 追加 → 判停**。想自己动手实现一个最小可用版本，见 [动手构建你的第一个 Harness](/practice/build-your-own)。

## 权衡与取舍

**循环自主性 vs 可控性。** 终止条件越宽松，agent 能啃的任务越复杂，但失控风险和成本也越高。交互式工具（Claude Code）倾向宽松上限 + 人工打断；批处理评测（SWE-bench）倾向严格预算，因为没人盯着。给你的场景选错档位，比选错模型更致命。

**把什么暴露给模型。** 错误输出、token 消耗、剩余步数——每一样都会占用上下文、影响模型行为。暴露错误细节几乎总是对的（模型靠它自我修正）；暴露预算则要小心——有团队发现模型知道「还剩 3 步」后会草率收尾。信息是工具，也是干扰。

**压缩历史的时机与方式。** 上下文逼近上限时，截断会丢早期关键决策，摘要会引入失真，什么都不做会直接报错。没有银弹，只有「按任务类型选策略」——详见 [上下文工程](/components/context-engineering)。

**确定性 vs 灵活性。** 可以在循环里塞更多代码逻辑（强制工作流、硬编码检查点），每一步都更可控，但你就一步步滑回 workflow，丢掉了 agent 的核心价值：处理你没想到的路径。Anthropic 的建议是反过来的——先写最简单的 loop，只在遇到具体故障时加针对性约束。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness) —— 循环在整个 harness 中的位置
- [总体架构解剖](/guide/anatomy) —— loop 与其他组件如何拼装
- [上下文工程](/components/context-engineering) —— 每轮迭代第一步「组装上下文」的完整展开
- [工具系统](/components/tools) —— tool call 的 schema 设计与 ACI 思想
- [权限与安全边界](/components/permissions) —— 执行工具前的批准机制
- [评测与可观测性](/components/observability) —— 如何度量一个 loop 的表现
- [SWE-agent 案例](/case-studies/swe-agent) —— ACI 设计如何改变循环效率
- [Claude Code 案例](/case-studies/claude-code) —— 交互式 loop 的标杆实现
- [核心论文导读](/papers/core-papers) —— ReAct 等奠基性论文精读
- [常见陷阱](/practice/pitfalls) —— loop 失控的反模式清单

## 参考资料

- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629) —— Yao et al., ICLR 2023
- [SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering (arXiv:2405.15793)](https://arxiv.org/abs/2405.15793) —— Yang et al., NeurIPS 2024
- [Building effective agents](https://www.anthropic.com/research/building-effective-agents) —— Anthropic 工程博客，2024 年 12 月
- [OpenHands: An Open Platform for AI Software Developers as Generalist Agents (arXiv:2407.16741)](https://arxiv.org/abs/2407.16741) —— Wang et al., ICLR 2025
