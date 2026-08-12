#!/usr/bin/env python3
"""v3_with_planning_memory.py — 第三版：todo 规划工具 + 会话摘要压缩。

在 v2（注册表 + 截断 + 审批）之上新增两个组件，同样各自对应一个可观察的症状：

    症状 1：任务一拉长，agent 中途忘了最初目标、反复做已完成的事。
        → 新增【todo 规划工具】：把计划外化成一份驻留在上下文里的清单。
          它零运行时逻辑——harness 不检查、不催促、不强制执行，
          生效机制是认知卸载：每轮决策都能重新读到"我在哪、还剩什么"。
    症状 2：会话越长，上下文越臃肿，早期关键信息被工具输出淹没。
        → 新增【会话摘要压缩】：轮次超过阈值时，把旧轮次压成一条摘要，
          保留最近几轮原文。截断管单次输出的体积，压缩管会话级的膨胀。

对照阅读：/components/planning、/components/memory、/components/context-engineering。

运行（MockLLM，无需 API key，纯标准库）：
    AUTO_APPROVE=1 python3 examples/v3_with_planning_memory.py
    （演示脚本较长，会真实触发一次上下文压缩，观察输出中的 [上下文压缩] 行）
"""
import json
import os
import subprocess
import tempfile

MAX_OUTPUT_CHARS = 1000
MAX_STEPS = 20
COMPACT_THRESHOLD = 14  # 消息数超过此值即触发压缩（演示用小阈值，生产按 token 计）
KEEP_RECENT = 6         # 压缩时保留最近几轮原文

# ---------- 工具实现（同 v2，新增 tool_todo） ----------

def truncate(text: str, limit: int = MAX_OUTPUT_CHARS) -> str:
    if len(text) <= limit:
        return text
    head, tail = text[: limit // 2], text[-limit // 2 :]
    return f"{head}\n... [截断：省略 {len(text) - limit} 字符] ...\n{tail}"

def tool_echo(text: str) -> str:
    return text

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

# ---------- 新增组件①：todo 规划工具（显式工作记忆） ----------
# 注意它没有任何运行时逻辑：harness 只是把清单渲染回上下文。
# 它是模型写给自己的外部记忆，不是给用户的进度条（虽然也起这个作用）。

def tool_todo(items: list) -> str:
    lines = [f"[{'x' if i.get('done') else ' '}] {i['task']}" for i in items]
    return "计划已更新：\n" + "\n".join(lines)

TOOLS = {
    "echo":  (tool_echo,  False),
    "read":  (tool_read,  False),
    "todo":  (tool_todo,  False),
    "write": (tool_write, True),
    "bash":  (tool_bash,  True),
}

def run_tool(name: str, args: dict) -> str:
    if name not in TOOLS:
        return f"错误：未知工具 {name}"
    fn, dangerous = TOOLS[name]
    if dangerous and os.environ.get("AUTO_APPROVE") != "1":
        print(f"\n⚠️  Agent 请求执行危险操作：{name}({json.dumps(args, ensure_ascii=False)[:80]})")
        if input("允许？(y/n) ").strip().lower() != "y":
            return "用户拒绝了该操作"
    try:
        return truncate(str(fn(**args)))
    except Exception as e:
        return f"工具执行异常：{e}"

# ---------- 新增组件②：会话摘要压缩 ----------
# 触发由 harness 负责（模型靠不住），摘要生成是可插拔的：
# 默认用规则式摘要做零成本演示，生产实现把 summarize() 换成一次 LLM 调用。

def summarize(old_turns: list) -> str:
    """把一段旧轮次压成摘要。规则式实现：每轮留下"谁、调了什么工具、结果开头"。

    ── 生产挂载点 ───────────────────────────────────────────────
    换成 LLM 摘要：summary = llm([{"role": "user", "content":
        "把以下 agent 轨迹压缩成保留关键决策与结论的摘要：..."}])
    Claude Code 的 /compact 就是一次真实的 LLM 摘要调用。
    """
    lines = []
    for m in old_turns:
        if m["role"] == "assistant":
            lines.append(f"模型决策: {m['content'][:60]}")
        elif m["content"].startswith("[工具"):
            first = m["content"].split("\n", 1)[-1][:60]
            lines.append(f"  → 结果: {first}")
    return "\n".join(lines)

def compact(messages: list) -> list:
    """保头（system + 原始任务）、压中间、留尾（最近 KEEP_RECENT 条原文）。"""
    head, middle, tail = messages[:2], messages[2:-KEEP_RECENT], messages[-KEEP_RECENT:]
    summary = "[早期轨迹摘要]\n" + summarize(middle)
    print(f"\n🗜️  [上下文压缩] {len(messages)} 条 → {2 + 1 + KEEP_RECENT} 条"
          f"（压缩了 {len(middle)} 条旧轮次）")
    return head + [{"role": "user", "content": summary}] + tail

# ---------- Agent Loop：与 v2 同构，只在每步末尾多一行压缩检查 ----------

SYSTEM = """你是一个 coding agent。每一步只输出一个 JSON 对象：
- 调用工具：{"tool": "工具名", "args": {...}}
- 结束任务：{"done": "总结"}
可用工具：echo(text), read(path), write(path, content), bash(command), todo(items: [{task, done}])。
先制定 todo 计划，再逐步执行，完成一项就在下次 todo 调用中标记完成。"""

def agent_loop(llm, task: str):
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": "任务：" + task},
    ]
    for step in range(1, MAX_STEPS + 1):
        reply = llm(messages)
        print(f"\n── 第 {step} 步 ── 模型输出: {reply}")
        try:
            action = json.loads(reply)
        except json.JSONDecodeError:
            messages.append({"role": "user", "content": "格式错误：请输出一个 JSON 对象"})
            continue
        if "done" in action:
            print(f"\n✅ 完成：{action['done']}")
            return action["done"]
        messages.append({"role": "assistant", "content": reply})
        result = run_tool(action["tool"], action.get("args", {}))
        print(f"   工具结果: {result[:200]}")
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})
        if len(messages) > COMPACT_THRESHOLD:      # 唯一的新增行：事件驱动的压缩
            messages = compact(messages)
    print(f"\n⛔ 达到最大步数 {MAX_STEPS}，强制停止")
    return None

# ---------- MockLLM：同前两版 ----------

class MockLLM:
    def __init__(self, script):
        self.script = list(script)
    def __call__(self, messages):
        last = messages[-1]["content"]
        if "错误" in last or "异常" in last or "拒绝" in last:
            return json.dumps({"done": f"操作受阻，任务终止：{last[:80]}"}, ensure_ascii=False)
        if not self.script:
            return json.dumps({"done": "脚本耗尽"}, ensure_ascii=False)
        return json.dumps(self.script.pop(0), ensure_ascii=False)

# ── 真实模型挂载点：与 v1/v2 相同。注意接上真实模型后，
# summarize() 也应换成 LLM 调用（见上方注释），压缩质量会远好于规则式。

if __name__ == "__main__":
    os.chdir(tempfile.mkdtemp(prefix="harness_v3_"))
    for name, n in [("a.txt", 3), ("b.txt", 5), ("c.txt", 2)]:
        with open(name, "w") as f:
            f.write("\n".join(f"{name} 第 {i} 行" for i in range(1, n + 1)) + "\n")

    # 9 步脚本：足够长，会在第 6 步后真实触发一次上下文压缩
    script = [
        {"tool": "todo", "args": {"items": [
            {"task": "列出所有 .txt 文件", "done": False},
            {"task": "逐个统计行数", "done": False},
            {"task": "写出 summary.md", "done": False}]}},
        {"tool": "bash", "args": {"command": "ls *.txt"}},
        {"tool": "bash", "args": {"command": "wc -l a.txt"}},
        {"tool": "bash", "args": {"command": "wc -l b.txt"}},
        {"tool": "bash", "args": {"command": "wc -l c.txt"}},
        {"tool": "todo", "args": {"items": [
            {"task": "列出所有 .txt 文件", "done": True},
            {"task": "逐个统计行数", "done": True},
            {"task": "写出 summary.md", "done": False}]}},
        {"tool": "write", "args": {"path": "summary.md",
                                   "content": "# 汇总\n\na.txt 3 行，b.txt 5 行，c.txt 2 行，共 10 行。\n"}},
        {"done": "已生成 summary.md，三个文件共 10 行"},
    ]
    agent_loop(MockLLM(script), "统计目录里所有 .txt 文件的行数并写一份 summary.md")
