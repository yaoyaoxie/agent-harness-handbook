#!/usr/bin/env python3
"""mini_harness.py — 一个约 130 行的最小 coding agent harness。

运行（MockLLM，无需 API key）：
    printf 'y\ny\n' | python3 mini_harness.py
"""
import json
import os
import subprocess

MAX_OUTPUT_CHARS = 1000  # 工具输出截断阈值
MAX_STEPS = 20           # 最大循环步数，防止 agent 失控空转

# ---------- 第 3 步：工具结果截断 ----------

def truncate(text: str, limit: int = MAX_OUTPUT_CHARS) -> str:
    """超长输出截头去尾：文件头尾通常最有信息，中间可省。"""
    if len(text) <= limit:
        return text
    head, tail = text[: limit // 2], text[-limit // 2 :]
    return f"{head}\n... [截断：省略 {len(text) - limit} 字符] ...\n{tail}"

# ---------- 第 1、2 步：工具实现 ----------

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

def tool_todo(items: list) -> str:
    lines = [f"[{'x' if i.get('done') else ' '}] {i['task']}" for i in items]
    return "计划已更新：\n" + "\n".join(lines)

# ---------- 第 4 步：权限——危险工具需要人类确认 ----------

TOOLS = {  # name -> (函数, 是否危险)
    "echo": (tool_echo, False),
    "read": (tool_read, False),
    "todo": (tool_todo, False),
    "write": (tool_write, True),   # 写文件、执行命令会改变世界，
    "bash": (tool_bash, True),     # 必须让人类有一票否决权
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
    except Exception as e:  # 工具失败不是世界末日，把异常喂回给模型
        return f"工具执行异常：{e}"

# ---------- 第 1 步：Agent Loop ----------

SYSTEM = """你是一个 coding agent。每一步只输出一个 JSON 对象：
- 调用工具：{"tool": "工具名", "args": {...}}
- 结束任务：{"done": "总结"}
可用工具：echo(text), read(path), write(path, content), bash(command), todo(items: [{task, done}])。
先制定 todo 计划，再逐步执行，每步根据上一步的工具结果决定下一步。"""

def agent_loop(llm, task: str):
    messages = [{"role": "user", "content": "任务：" + task}]
    for step in range(1, MAX_STEPS + 1):
        reply = llm(messages)                      # 1. 模型看完整上下文，输出决策
        print(f"\n── 第 {step} 步 ── 模型输出: {reply}")
        try:
            action = json.loads(reply)             # 2. harness 解析决策
        except json.JSONDecodeError:
            messages.append({"role": "user", "content": "格式错误：请输出一个 JSON 对象"})
            continue
        if "done" in action:                       # 3a. 模型宣告完成，循环退出
            print(f"\n✅ 完成：{action['done']}")
            return
        messages.append({"role": "assistant", "content": reply})
        result = run_tool(action["tool"], action.get("args", {}))  # 3b. harness 执行工具
        print(f"   工具结果: {result[:200]}")
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})
    print(f"\n⛔ 达到最大步数 {MAX_STEPS}，强制停止")  # 4. 兜底刹车

# ---------- MockLLM：基于规则的假模型，无需 API key ----------

class MockLLM:
    """真实 LLM 会读 messages 里的完整轨迹再决策；MockLLM 用两条规则模拟：
    规则 1：上一步工具出错 → 立即终止并汇报失败；
    规则 2：否则按预写脚本依次给出决策（等价于真实模型的"合理决策"）。"""
    def __init__(self, script):
        self.script = list(script)
    def __call__(self, messages):
        last = messages[-1]["content"]
        if "错误" in last or "异常" in last:
            return json.dumps({"done": f"遇到错误，任务失败：{last[:80]}"}, ensure_ascii=False)
        if not self.script:
            return json.dumps({"done": "脚本耗尽"}, ensure_ascii=False)
        return json.dumps(self.script.pop(0), ensure_ascii=False)

if __name__ == "__main__":
    if not os.path.exists("notes.txt"):
        with open("notes.txt", "w") as f:
            f.write("第一行：harness 决定模型看到什么\n第二行：工具决定模型能做什么\n第三行：循环决定模型走多远\n")

    script = [
        {"tool": "todo", "args": {"items": [
            {"task": "读取 notes.txt", "done": False},
            {"task": "统计行数", "done": False},
            {"task": "写出 report.md", "done": False}]}},
        {"tool": "read", "args": {"path": "notes.txt"}},
        {"tool": "bash", "args": {"command": "wc -l notes.txt"}},
        {"tool": "write", "args": {"path": "report.md",
                                   "content": "# 报告\n\nnotes.txt 共 3 行。\n"}},
        {"done": "已生成 report.md，任务完成"},
    ]
    agent_loop(MockLLM(script), "统计 notes.txt 的行数并写一份 report.md")
