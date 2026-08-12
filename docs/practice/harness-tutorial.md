---
title: 渐进式教程：三版跑起来
description: 把一个 130 行的最小 harness 拆成三个可独立运行的版本：v1 只有 agent loop 骨架，v2 挂上工具注册表、输出截断与审批闸口，v3 再补 todo 规划与会话摘要压缩——每版都能直接跑，每个组件都有它对应的可观察症状。
---

# 渐进式教程：三版跑起来

[从零构建一个最小 Harness](/practice/build-your-own) 把 `.scratch/mini_harness.py` 的 130 行代码逐层拆讲了一遍——那是"阅读理解"。本页是同一份代码的另一种学法：**把一次讲完的成品拆回三个渐进版本，每版都是一个可以直接运行的 Python 文件**，你亲手跑一遍、观察输出、对比轨迹，组件的存在理由会自己浮出来。

三个文件都在仓库的 `examples/` 目录下：

| 文件 | 在上一版基础上新增 | 对应的症状 |
| --- | --- | --- |
| `v1_minimal_loop.py` | （起点）最小 agent loop 五环节 | 没有 loop 就没有 agent |
| `v2_with_tools.py` | 工具注册表、输出截断、审批闸口 | 工具难维护、上下文被灌爆、危险操作无人把关 |
| `v3_with_planning_memory.py` | todo 规划工具、会话摘要压缩 | 长任务目标漂移、会话越长越蠢越贵 |

三个文件都只依赖 Python 标准库，不需要任何 API key——模型用一个基于预写脚本的 `MockLLM` 扮演。这不是偷懒，而是一个重要的教学方法论：**先把 harness 的结构跑通，真实模型只是换掉一个函数签名的事**。mock 模型让你零成本地反复实验 harness 行为，这也是 [evals 实践](/practice/evals-in-practice)里"用固定轨迹做回归测试"的最小形态。

## 运行方法

```bash
# v1：无任何交互，直接跑
python3 examples/v1_minimal_loop.py

# v2：会两次停下来等审批，管道喂入两个 y；或干脆自动放行
printf 'y\ny\n' | python3 examples/v2_with_tools.py
AUTO_APPROVE=1 python3 examples/v2_with_tools.py

# v3：脚本较长（9 步），会真实触发一次上下文压缩
AUTO_APPROVE=1 python3 examples/v3_with_planning_memory.py
```

三个脚本都把演示文件写进 `tempfile.mkdtemp()` 创建的临时目录，不会污染你的工作区。每个文件顶部的模块 docstring 写明了"本版新增了什么"，可以直接对照阅读源码。

::: tip 接真实模型的挂载点
每个文件末尾都留了一段注释：把 `MockLLM` 换成任意一个签名为 `(messages) -> str` 的 callable（OpenAI 兼容 API 约十行 `urllib.request` 代码），harness 其余部分一行都不用改。v3 的 `summarize()` 同理，换成一次 LLM 摘要调用即得到 Claude Code `/compact` 的同款机制。
:::

## v1：只有骨架的最小 loop

`v1_minimal_loop.py` 约 110 行，整个 harness 只有一个 `agent_loop` 函数加两个内联工具（`echo`、`read`）。它完整走通五环节：

```text
┌──────────────────────────────────────────────────────┐
│              v1：最小 agent loop                     │
│                                                      │
│  ①组装上下文 ──> ②调模型 ──> ③解析 JSON 决策          │
│      ▲                            │                  │
│      │                       ┌────┴────┐             │
│      │                  是工具调用   宣告完成          │
│      │                       │          │            │
│  ⑤回写结果 <── ④执行工具     │          ▼            │
│                (if/elif 分派)       返回最终答案      │
│                                                      │
│  循环外：MAX_STEPS 硬上限、格式错误回喂               │
└──────────────────────────────────────────────────────┘
```

核心代码就是这些（有删节）：

```python
def agent_loop(llm, task: str):
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": "任务：" + task},
    ]
    for step in range(1, MAX_STEPS + 1):
        reply = llm(messages)                      # ② 唯一的"模型时刻"
        action = json.loads(reply)                 # ③ 解析（异常则回喂格式错误）
        if "done" in action:
            return action["done"]                  # 模型宣告完成
        messages.append({"role": "assistant", "content": reply})
        if action["tool"] == "echo":                    # ④ 执行（v1 是内联分派）
            result = tool_echo(**action.get("args", {}))
        elif action["tool"] == "read":
            result = tool_read(**action.get("args", {}))
        else:
            result = f"错误：未知工具 {action['tool']}"
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})  # ⑤ 回写
```

跑一遍，你会看到它三步走完：读 `notes.txt` → echo 统计结果 → 宣告完成。这个版本对应 [Agent 循环](/components/agent-loop) 一章的全部基础概念，其余什么都没有——**这是故意的**。

v1 的可教之处在于它的残缺。盯着代码和输出看一分钟，三个症状几乎是自明的：

1. 工具分派是一段 `if/elif`——加到十个工具就没法看了，而且模型幻觉出一个不存在的工具名时，拒绝逻辑散在分派里；
2. `tool_read` 读到什么就原样回写什么——`read` 一个几十 MB 的日志，上下文一次塞爆；
3. 现在敢加 `write`、`bash` 这种会改变世界的工具吗？不敢。加了就是无人值守的灾害。

记住这三个症状，它们是 v2 的存在理由。

## v2：工具注册表、截断与审批

`v2_with_tools.py` 在 v1 的 loop 上挂了三个组件，`agent_loop` 本身只改了一行（内联分派换成 `run_tool` 查表）：

**组件一：工具注册表。** 工具集中到 `TOOLS` 字典登记，loop 只查表，不 `eval`：

```python
TOOLS = {  # name -> (函数, 是否危险)
    "echo":  (tool_echo,  False),
    "read":  (tool_read,  False),
    "write": (tool_write, True),   # 会改变世界，
    "bash":  (tool_bash,  True),   # 必须让人类有一票否决权
}

def run_tool(name: str, args: dict) -> str:
    if name not in TOOLS:
        return f"错误：未知工具 {name}"   # 幻觉出的工具名，安全地拒绝
    ...
```

`name not in TOOLS` 是安全边界的第一块砖。注册表还是后续一切工具级策略（审批分级、参数校验、按工具截断阈值）的挂载点——深入讨论见[工具系统](/components/tools)。

**组件二：输出截断。** `truncate()` 截头去尾，并把"省略了 N 字符"写进返回值——模型必须知道数据被砍过，否则会基于残缺观察自信地犯错。这是[上下文工程](/components/context-engineering)的种子：harness 决定模型看到什么，**不**让它看到什么同样重要。

**组件三：审批闸口。** 注册表里那个 `dangerous` 布尔值在这里生效：

```python
    if dangerous and os.environ.get("AUTO_APPROVE") != "1":
        print(f"\n⚠️  Agent 请求执行危险操作：{name}(...)")
        if input("允许？(y/n) ").strip().lower() != "y":
            return "用户拒绝了该操作"   # 拒绝也是观察，不是中断
```

分级按**不可逆性**而非工具名拍脑袋：只读的放行，改变世界的拦下。拒绝被建模成一次普通的工具结果回写，模型可以据此换方案——人机协商留在 loop 内。这是[权限与人机协作](/components/permissions)里"按不可逆性分级拦截"的最小实现。

::: warning 为什么这三个组件绑在同一版
因为它们共同构成"让 agent 接触真实世界"的最小安全包：注册表管住**能调什么**，截断管住**能看到多少**，审批管住**能不能动手**。只加 `write`/`bash` 而不加这三件，等于把剪刀递给 toddler。反过来，v1 那两个只读工具配这三件纯属过度设计——这就是"时机"的含义。
:::

## v3：todo 规划与会话摘要压缩

`v3_with_planning_memory.py` 处理的是另一类症状——**时间维度上的失控**：任务拉长后目标漂移、会话膨胀。两个新组件分别对应[规划与任务分解](/components/planning)和[记忆系统](/components/memory)两章。

**组件一：todo 规划工具。** 模型把任务清单作为一次普通工具调用提交，harness 渲染回上下文：

```python
def tool_todo(items: list) -> str:
    lines = [f"[{'x' if i.get('done') else ' '}] {i['task']}" for i in items]
    return "计划已更新：\n" + "\n".join(lines)
```

注意它**没有任何运行时逻辑**——harness 不检查、不催促、不强制执行。它生效的全部机制是认知卸载：生成清单的动作强迫模型先结构化地想一遍任务，清单驻留在上下文里成为每轮决策的锚点，状态更新动作把"回顾进度"变成循环的固定节律。Claude Code 的 TodoWrite 就是这个思路的成熟形态（三态状态机、全量覆写、系统提示规定纪律），完整拆解见[规划与任务分解](/components/planning)。

**组件二：会话摘要压缩。** `truncate` 管单次输出的体积，管不了会话级的膨胀。v3 在 loop 末尾加了一行事件驱动的检查：

```python
        if len(messages) > COMPACT_THRESHOLD:   # 唯一的新增行
            messages = compact(messages)
```

`compact()` 的策略是"保头、压中间、留尾"：system 和原始任务不动，旧轮次压成一条摘要，最近 `KEEP_RECENT` 条保留原文。演示用的 `summarize()` 是规则式实现（每轮留一行"调了什么工具、结果开头"），生产实现把它换成一次 LLM 调用——Claude Code 的 `/compact` 就是这个机制。压缩的**触发**必须由 harness 负责，指望模型自觉压缩上下文是不可靠的，这一点在[上下文工程](/components/context-engineering)里有展开。

::: info 运行 v3 时你会亲眼看到压缩发生
演示脚本是 9 步，消息数在第 7 步后越过阈值（14 条），终端会打出一行 `🗜️ [上下文压缩] 16 条 → 9 条（压缩了 8 条旧轮次）`。把 `COMPACT_THRESHOLD` 调大再跑一遍，压缩消失——同一个 harness，行为由参数决定，这正是 harness 是"系统"而非"脚本"的含义。
:::

## 三版对照：复杂度要用症状换

| 维度 | v1 最小 loop | v2 加工具系统 | v3 加规划与记忆 |
| --- | --- | --- | --- |
| 行数（约） | 110 | 140 | 190 |
| 新增组件 | — | 注册表、截断、审批 | todo 工具、摘要压缩 |
| 能治的任务 | 单步只读 | 多步、会改变世界 | 长任务、长会话 |
| 新增症状对应 | 没有 agent | 工具失控、上下文灌爆、操作无闸 | 目标漂移、会话膨胀 |
| 对应章节 | [Agent 循环](/components/agent-loop) | [工具](/components/tools)、[权限](/components/permissions)、[上下文工程](/components/context-engineering) | [规划](/components/planning)、[记忆](/components/memory) |

三版共享同一条设计哲学（也是本站反复引用的 Anthropic《Building effective agents》原则）：**先找能用的最简方案，只在确有必要时增加复杂度。** 每个组件都必须说得出它治的是哪个真实出现过的症状——复杂度用症状换，不用想象力换。这套"等症状再给药"的判断框架在[设计原则](/practice/design-principles)里系统化，反面教材收在[常见陷阱](/practice/pitfalls)。

::: tip 动手之后的下一步
1. 把 `MockLLM` 换成真实模型（每个文件末尾的注释里有挂载点），用同一个任务对比三版轨迹；
2. 故意制造故障：让 `read` 读一个不存在的文件、在审批时按 `n`、把 `COMPACT_THRESHOLD` 调到 8——观察 agent 如何从每种失败中恢复；
3. 给三版各写一组固定脚本当回归测试，然后试着改 harness（比如给 `bash` 加白名单），用轨迹对比验证你的"改进"是不是折腾——这就是 [evals 实践](/practice/evals-in-practice)的入口。
:::

## 延伸阅读

- [从零构建一个最小 Harness](/practice/build-your-own)——同一份代码的逐层拆讲版，与本页互为表里
- [Agent 循环](/components/agent-loop)——v1 的 loop 在生产级实现中的完整形态
- [工具系统](/components/tools)——注册表之后：工具数量、命名、参数设计与 MCP
- [权限与人机协作](/components/permissions)——v2 审批闸口的完整分级体系
- [上下文工程](/components/context-engineering)——截断与压缩之外：注入、外置、隔离
- [规划与任务分解](/components/planning)——TodoWrite 机制的完整拆解与三种规划模式
- [记忆系统](/components/memory)——从会话内摘要到跨会话持久记忆
- [evals 实践](/practice/evals-in-practice)——怎么度量你刚搭的这三版 harness 的好坏
- [SWE-agent 案例](/case-studies/swe-agent)——极简 scaffold 路线的真实产品样本

## 参考资料

- [Anthropic: Building effective agents](https://www.anthropic.com/research/building-effective-agents)——"先找最简方案，只在必要时增加复杂度"的原始表述
- [12-Factor Agents（humanlayer/12-factor-agents）](https://github.com/humanlayer/12-factor-agents)——"Own your control flow" 与 "Compact errors into context window" 的出处
- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)——思考-行动交替协议的原始论文
