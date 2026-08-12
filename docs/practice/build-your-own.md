---
title: 从零构建一个最小 Harness
description: 用一个约 130 行、无需框架的 Python 文件从零实现最小 agent harness：上下文组装、模型调用、工具解析与执行、结果回写、人工审批五个环节逐一拆解，再沿"什么症状加什么组件"的路径把 todo 规划、记忆压缩、子代理、观测逐个挂载上去。
---

# 从零构建一个最小 Harness

在[常见陷阱](/practice/pitfalls)里，反模式第一条就是"过度框架化"：想改一个行为要读三层抽象，最后被框架的抽象绑架。而 12-Factor Agents 的作者 Dex Horthy 在[原仓库](https://github.com/humanlayer/12-factor-agents)里给出的解法更激进：先别碰框架，用裸 API 加一个 while 循环把 agent 跑起来——Factor 8 就叫 "Own your control flow"（拥有你自己的控制流）。

本页就把这个建议兑现成代码。我们要写的 harness 只有约 130 行 Python，不含任何框架依赖，甚至不含任何 LLM SDK——先用一个基于规则的 MockLLM 把结构跑通，真实模型只是换掉一个函数签名的事。全部代码在仓库的 `.scratch/mini_harness.py`，本页是它的逐层拆解。

::: info 本页的立场
harness 的每一个组件都应该"挣得自己的位置"。我们先写一个**故意简陋**的版本，然后像做加法一样，每出现一类症状，才挂上对应的一味药。这和 Anthropic 在[《Building effective agents》](https://www.anthropic.com/research/building-effective-agents)里的立场一致：先找能用的最简方案，只在确有必要时增加复杂度。
:::

## 最小 Loop 的全貌

剥掉一切产品级装饰，agent loop 只干七件事（[什么是 Agent Harness](/guide/what-is-harness) 里已经给过伪代码，这里是它的可运行版本）：

```text
┌──────────────────────────────────────────────────────┐
│                  最小 agent loop                     │
│                                                      │
│  ①组装上下文 ──> ②调模型 ──> ③解析输出                │
│      ▲                            │                  │
│      │                       ┌────┴────┐             │
│      │                  是工具调用   宣告完成          │
│      │                       │          │            │
│  ⑤回写结果 <── ④执行工具     │          ▼            │
│                    （含审批闸口）     返回最终答案      │
│                                                      │
│  循环外：步数上限兜底、异常回喂、输出截断               │
└──────────────────────────────────────────────────────┘
```

下面分四步把这个图写成代码。每一步只解决一个问题，不提前优化。

## 第一步：Agent Loop 骨架

```python
import json

MAX_STEPS = 20  # 最大循环步数，防止 agent 失控空转

SYSTEM = """你是一个 coding agent。每一步只输出一个 JSON 对象：
- 调用工具：{"tool": "工具名", "args": {...}}
- 结束任务：{"done": "总结"}
先制定 todo 计划，再逐步执行，每步根据上一步的工具结果决定下一步。"""

def agent_loop(llm, task: str):
    messages = [{"role": "user", "content": "任务：" + task}]
    for step in range(1, MAX_STEPS + 1):
        reply = llm(messages)                   # ② 模型看完整上下文，输出决策
        try:
            action = json.loads(reply)          # ③ harness 解析决策
        except json.JSONDecodeError:
            messages.append({"role": "user", "content": "格式错误：请输出一个 JSON 对象"})
            continue
        if "done" in action:                    # 模型宣告完成，循环退出
            return action["done"]
        messages.append({"role": "assistant", "content": reply})
        result = run_tool(action["tool"], action.get("args", {}))  # ④ 执行
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})
    return f"达到最大步数 {MAX_STEPS}，强制停止"  # 兜底刹车
```

三个设计决策值得停下来看：

**一、协议是 JSON，不是 function calling。** 我们让模型每步输出一个 JSON 对象，而不是依赖各家 API 的原生 tool calling 字段。这有真实的代价（模型可能输出非法 JSON，所以要捕获 `json.JSONDecodeError` 并把格式错误**回喂**给模型让它重试），但换来的是结构透明：整个 loop 里没有任何 SDK 特有的概念，换模型、换 API 厂商都不动 harness。生产实现会用原生 tool calling 加 JSON schema 校验，但机制完全同构——都是"模型输出结构化决策，harness 解析执行"。这个思路正是 ReAct（[arXiv:2210.03629](https://arxiv.org/abs/2210.03629)）确立的：思考与行动的交替，本质是模型输出格式与 harness 执行器之间的一份协议。

**二、错误是上下文，不是异常。** `json.loads` 失败不抛异常退出，而是把"格式错误"作为一条消息塞回 `messages`。同理，后面 `run_tool` 里工具执行抛异常也被捕获并转成文本结果。这是 harness 工程的一条铁律：**模型能看到的错误才是可恢复的错误**。静默失败（[陷阱 #5](/practice/pitfalls)）的反义操作就是"一切失败结构化地回到上下文"——12-Factor Agents 的 Factor 9 说的也是同一件事："Compact errors into context window"。

**三、停止条件必须是 harness 的硬约束。** `MAX_STEPS` 这行代码看起来不起眼，但它是模型之外**唯一确定会生效**的刹车。模型的"我干完了"可以信，但不能全信——[无终止条件的死循环烧 token](/practice/pitfalls) 是真实事故的高发区。生产 harness 还会加上成本上限、时间上限、超时检测，但第一步永远是一个 `for` 循环的硬上限。

## 第二步：工具的定义与注册

工具是这个 loop 里模型唯一能改变世界的通道。注意我们的工具实现朴素得近乎草率：

```python
import os, subprocess

def tool_read(path: str) -> str:
    if not os.path.exists(path):
        return f"错误：文件不存在 {path}"
    with open(path, encoding="utf-8") as f:
        return f.read()

def tool_write(path: str, content: str) -> str:
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    return f"已写入 {path}（{len(content)} 字符）"

def tool_bash(command: str) -> str:
    r = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
    return (r.stdout + r.stderr).strip() or "(无输出)"
```

三个约定比实现本身重要：

- **签名即接口。** 每个工具是"若干简单类型参数进、一个字符串出"的纯函数。字符串返回值就是模型的"观察"——工具输出最终都会变成上下文里的文本，所以保持文本形式意味着任何工具都能即插即用。
- **错误返回字符串，而不是抛异常。** `tool_read` 对不存在的文件返回 `"错误：文件不存在 …"`。这让"读了一个不存在的路径"成为模型可以从中学习的观察，而不是一次崩溃。
- **注册表是唯一权威。** 工具集中在一个字典里登记，loop 只查表，不 `eval`：

```python
TOOLS = {  # name -> (函数, 是否危险)
    "echo":  (tool_echo,  False),
    "read":  (tool_read,  False),
    "todo":  (tool_todo,  False),
    "write": (tool_write, True),   # 写文件、执行命令会改变世界，
    "bash":  (tool_bash,  True),   # 必须让人类有一票否决权
}

def run_tool(name: str, args: dict) -> str:
    if name not in TOOLS:
        return f"错误：未知工具 {name}"   # 模型幻觉出的工具名，安全地拒绝
    fn, dangerous = TOOLS[name]
    ...
    try:
        return truncate(str(fn(**args)))
    except Exception as e:                # 工具失败不是世界末日，把异常喂回给模型
        return f"工具执行异常：{e}"
```

`name not in TOOLS` 这一行是安全边界的第一块砖：模型幻觉出 `delete_everything` 这样的工具名时，harness 的回答是一句无害的文本，而不是一次灾难。关于工具数量、参数设计、以及"工具爆炸"为什么是反模式，见[工具系统](/components/tools)。

## 第三步：工具输出的第一道防线——截断

`run_tool` 里那个 `truncate()` 是本页第一个"非玩具"组件：

```python
MAX_OUTPUT_CHARS = 1000  # 工具输出截断阈值

def truncate(text: str, limit: int = MAX_OUTPUT_CHARS) -> str:
    """超长输出截头去尾：文件头尾通常最有信息，中间可省。"""
    if len(text) <= limit:
        return text
    head, tail = text[: limit // 2], text[-limit // 2 :]
    return f"{head}\n... [截断：省略 {len(text) - limit} 字符] ...\n{tail}"
```

为什么这是刚需？因为 `tool_bash("cat huge.log")` 会把几十 MB 文本灌进上下文，一次就把窗口塞爆、把账单烧穿。截头去尾是个粗糙但有效的启发式：日志和文件的头尾通常信息密度最高。这里埋着整个[上下文工程](/components/context-engineering)的种子——harness 决定模型看到什么，而"**不**让模型看到什么"同样重要。注意截断信息本身（"省略 N 字符"）也写进了返回值：模型需要知道数据被砍过，否则它会基于不完整的观察自信地犯错。

## 第四步：加上中断与审批

最后一块拼图是把人从回路外拉回回路内。`TOOLS` 表里那个 `dangerous` 布尔值在这里生效：

```python
def run_tool(name: str, args: dict) -> str:
    fn, dangerous = TOOLS[name]
    if dangerous and os.environ.get("AUTO_APPROVE") != "1":
        print(f"\n⚠️  Agent 请求执行危险操作：{name}({json.dumps(args, ensure_ascii=False)[:80]})")
        if input("允许？(y/n) ").strip().lower() != "y":
            return "用户拒绝了该操作"
    ...
```

设计要点只有两条：

- **按不可逆性分级，而不是按工具名拍脑袋。** `read`/`todo` 只读不写，放行；`write`/`bash` 改变世界，拦下。这是[权限与人机协作](/components/permissions)里"按不可逆性分级拦截"的最小实现。真实的 coding agent 会把分级做细得多：bash 命令按白名单/正则分类、`write` 限定工作目录内、网络访问单独审批——但判断的轴心是同一根：**这个操作能不能撤销？**
- **拒绝也是观察。** 用户按了 `n`，返回的是 `"用户拒绝了该操作"` 而不是中断。模型据此可以换方案、先解释意图、或者放弃——人机协商被建模成了 loop 里的一次普通交互。`AUTO_APPROVE=1` 环境变量则是面向批量任务的逃生门，默认关闭。

至此，130 行的 harness 已经具备全部本质结构：上下文、循环、工具、审批、兜底。用 MockLLM 跑一遍（`printf 'y\ny\n' | python3 mini_harness.py`），你会看到它按预写脚本依次执行：建 todo → 读文件 → 跑 `wc -l` → 写报告 → 宣告完成，两次危险操作各询问一次。

## 增量路线：什么时候该加什么

骨架跑通之后，诱惑是把所有组件一次性堆上去。这是错的。正确的姿势是**等症状出现再给药**——每个组件都应该有它在生产上对应的痛点。下表是症状到处方的映射，后面逐个展开：

| 你观察到的症状 | 该挂上的组件 | 深入阅读 |
| --- | --- | --- |
| 长任务中途忘了最初目标、反复做已完成的事 | Todo 规划（显式工作记忆） | [规划与任务分解](/components/planning) |
| 会话变长后 agent 变蠢、变贵 | 输出截断之外的上下文管理、记忆压缩 | [上下文工程](/components/context-engineering)、[记忆系统](/components/memory) |
| 单线程探索污染主上下文、注意力发散 | 子代理（subagent） | [子 Agent](/components/subagents) |
| 出了问题无法回答"它在哪步走偏的" | 结构化日志与轨迹记录 | [可观测性](/components/observability) |
| 危险操作越来越多，`y/n` 按到手麻 | 细粒度权限与规则引擎 | [权限与人机协作](/components/permissions) |

### 增量一：Todo 规划

我们的 `tool_todo` 已经是个简化版：模型把任务清单作为工具调用提交，渲染结果回写上下文。它零运行时逻辑——harness 不检查、不催促、不强制执行——生效的全部机制是认知卸载：清单驻留在上下文里，每轮决策都可见。Claude Code 的 TodoWrite 就是这个思路的成熟形态（三态状态机、全量覆写、系统提示规定纪律），完整拆解见[规划与任务分解](/components/planning)。**挂载时机**：任务稳定超过三步、或多需求并行时。单步任务挂它纯属仪式。

### 增量二：记忆压缩与上下文管理

`truncate` 只解决单次输出的体积，解决不了**会话级**的膨胀：几十轮工具调用之后，早期关键信息（用户的原始需求、中途的决策理由）被淹没。下一步是分层处理：滚动摘要（把旧轮次压缩成摘要，保留最近 N 轮原文）、外置笔记（agent 主动把关键发现写进文件，需要时再读回来）、以及跨会话的持久记忆文件。这些分别是[上下文工程](/components/context-engineering)和[记忆系统](/components/memory)的核心议题。**挂载时机**：观察到"会话越长越蠢、越贵"——也就是[陷阱 #3](/practice/pitfalls) 的上下文垃圾堆积。

### 增量三：子代理

当任务里出现"探索性很强但与主线无关"的子问题（"搜一下这个库的用法"、"把这个报错查清楚"），让主 agent 亲自去搜会把几十条检索轨迹灌进主上下文。解法是派生一个子代理：给它一个窄任务和一份小上下文，它跑完自己的 loop，只把结论返回主循环。主 agent 的上下文因此保持干净——子代理本质上是**一次可以内部循环很多轮的"工具调用"**。实现上它就是对 `agent_loop` 的递归调用加一个结果汇总，但什么时候该拆、拆多深、子代理之间要不要共享记忆，是真问题，见[子 Agent](/components/subagents)。**挂载时机**：探索轨迹开始显著稀释主线注意力——注意这通常比直觉预期来得晚，过早多智能体化是[陷阱 #10](/practice/pitfalls)。

### 增量四：可观测性

我们的 loop 里已经有一行最原始的观测：`print` 每步的模型输出和工具结果。当它不够用的时候（典型场景：用户报告"agent 昨天半夜做了一件蠢事"，而你无法回答"它在哪步走偏的"），就该把 print 换成结构化轨迹记录：每步的输入哈希、模型决策、工具调用与结果、耗时与 token 数，落成可回放的 JSONL。轨迹是 harness 调试的基本粒子，也是评测的数据源，见[可观测性](/components/observability)。**挂载时机**：第一次需要回答"为什么"而答不上来的时候。

## 什么时候该停手

这条增量路线没有终点——你还能加沙箱、加并行工具调用、加断点恢复、加 evals。所以更稀缺的能力是**判断何时停手**。三条来自本站的元规则：

1. **复杂度要用症状换，不用想象力换。** 每加一个组件，说得出它治的是哪个真实出现过的症状。Anthropic 的原话是：找到能用的最简方案，只在确有必要时增加复杂度。
2. **保持工具通用而原始。** Claude Code 的工具集长期停留在"读、写、grep、bash"这一层（见 [Claude Code 案例](/case-studies/claude-code)），把智能留给模型而不是 harness——harness 越厚，模型换代时要重写的越多。
3. **先写 evals 再谈能力。** 想给 harness 加功能之前，先有一个能度量它好坏的最小评测集，否则你无法区分"改进"和"折腾"（[陷阱 #8：Demo 驱动开发](/practice/pitfalls)）。

更多的判断框架收在 [Harness 设计原则](/practice/design-principles)；如果你想看这些原则在真实产品里的形态，案例区有 [SWE-agent](/case-studies/swe-agent)（极简 scaffold 的标杆）和 [OpenHands](/case-studies/openhands)（全功能开源 harness）两个对照样本。

::: tip 动手之后的下一步
把这个最小 harness 接到真实模型上（换掉 MockLLM，约十行 API 调用），然后挑一个你自己的小任务跑三轮：第一轮裸跑，第二轮只加 todo 工具，第三轮加上截断和审批。对比三轮的轨迹，你对"每个组件到底买到了什么"的理解会超过读十篇文章。
:::

## 延伸阅读

- [Agent 循环](/components/agent-loop)——本页 loop 在生产级实现中的完整形态：停止条件、错误处理、并发
- [上下文工程](/components/context-engineering)——截断只是入口，摘要、外置、注入才是全貌
- [工具系统](/components/tools)——工具数量、命名、参数设计与 MCP
- [规划与任务分解](/components/planning)——TodoWrite 机制的完整拆解
- [记忆系统](/components/memory)——从会话内清单到跨会话持久记忆
- [子 Agent](/components/subagents)——上下文隔离与任务委托
- [权限与人机协作](/components/permissions)——审批分级、沙箱与不可逆操作
- [Harness 设计原则](/practice/design-principles)——决定加什么、不加什么的八条规则
- [常见陷阱与反模式](/practice/pitfalls)——本页每一步对应的反面教材

## 参考资料

- [12-Factor Agents（humanlayer/12-factor-agents）](https://github.com/humanlayer/12-factor-agents)——"Own your control flow" 与 "Compact errors into context window" 的出处
- [Anthropic: Building effective agents](https://www.anthropic.com/research/building-effective-agents)——"先找最简方案，只在必要时增加复杂度"的原始表述
- [ReAct: Synergizing Reasoning and Acting in Language Models (arXiv:2210.03629)](https://arxiv.org/abs/2210.03629)——思考-行动交替协议的原始论文
- [Claude Code 案例：极简工具集的产品设计](/case-studies/claude-code)
