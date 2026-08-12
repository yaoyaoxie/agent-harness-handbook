#!/usr/bin/env python3
"""v2_with_tools.py — 第二版：工具注册表 + 输出截断 + 审批闸口。

在 v1 的最小 loop 上新增三个组件，每个都对应 v1 跑起来后能观察到的真实症状：

    症状 1：工具分派是 if/elif，工具一多就没法维护；
            模型幻觉出的工具名也没有统一的拒绝通道。
        → 新增【工具注册表】：TOOLS 字典是唯一权威，loop 只查表。
    症状 2：read / bash 可能把几十 MB 文本灌进上下文，一次塞爆窗口。
        → 新增【输出截断】truncate()：截头去尾，并告知模型省略了多少。
    症状 3：引入 write / bash 这类会改变世界的工具后，
            agent 无人值守乱跑的风险不可接受。
        → 新增【审批闸口】：危险工具执行前必须人类确认，拒绝也是观察。

对照阅读：/components/tools、/components/context-engineering、/components/permissions。

运行（MockLLM，无需 API key，纯标准库）：
    printf 'y\\ny\\n' | python3 examples/v2_with_tools.py   # 两次危险操作各确认一次
    AUTO_APPROVE=1 python3 examples/v2_with_tools.py        # 批量任务的逃生门
"""
import json
import os
import subprocess
import tempfile

MAX_OUTPUT_CHARS = 1000  # 工具输出截断阈值
MAX_STEPS = 20           # 最大循环步数，防止 agent 失控空转

# ---------- 新增组件①：输出截断（上下文体积的第一道防线） ----------

def truncate(text: str, limit: int = MAX_OUTPUT_CHARS) -> str:
    """超长输出截头去尾：文件头尾通常最有信息，中间可省。
    截断信息本身也写进返回值——模型需要知道数据被砍过。"""
    if len(text) <= limit:
        return text
    head, tail = text[: limit // 2], text[-limit // 2 :]
    return f"{head}\n... [截断：省略 {len(text) - limit} 字符] ...\n{tail}"

# ---------- 工具实现：v2 引入会改变世界的 write / bash ----------

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

# ---------- 新增组件②：工具注册表（唯一权威 + 危险分级标记） ----------

TOOLS = {  # name -> (函数, 是否危险)
    "echo":  (tool_echo,  False),
    "read":  (tool_read,  False),
    "write": (tool_write, True),   # 写文件、执行命令会改变世界，
    "bash":  (tool_bash,  True),   # 必须让人类有一票否决权
}

def run_tool(name: str, args: dict) -> str:
    if name not in TOOLS:
        return f"错误：未知工具 {name}"  # 模型幻觉出的工具名，安全地拒绝
    fn, dangerous = TOOLS[name]
    # ---------- 新增组件③：审批闸口（按不可逆性分级，而非按工具名拍脑袋） ----------
    if dangerous and os.environ.get("AUTO_APPROVE") != "1":
        print(f"\n⚠️  Agent 请求执行危险操作：{name}({json.dumps(args, ensure_ascii=False)[:80]})")
        if input("允许？(y/n) ").strip().lower() != "y":
            return "用户拒绝了该操作"  # 拒绝也是观察：模型可以换方案或先解释意图
    try:
        return truncate(str(fn(**args)))
    except Exception as e:  # 工具失败不是世界末日，把异常喂回给模型
        return f"工具执行异常：{e}"

# ---------- Agent Loop：与 v1 同构，只有分派换成了查注册表 ----------

SYSTEM = """你是一个 coding agent。每一步只输出一个 JSON 对象：
- 调用工具：{"tool": "工具名", "args": {...}}
- 结束任务：{"done": "总结"}
可用工具：echo(text), read(path), write(path, content), bash(command)。
每步根据上一步的工具结果决定下一步。"""

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
        result = run_tool(action["tool"], action.get("args", {}))  # 唯一的改动点
        print(f"   工具结果: {result[:200]}")
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})
    print(f"\n⛔ 达到最大步数 {MAX_STEPS}，强制停止")
    return None

# ---------- MockLLM：同 v1，预写脚本模拟合理决策序列 ----------

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

# ── 真实模型挂载点：与 v1 相同，替换 MockLLM 为 (messages) -> str 的
# API 调用即可，注册表、截断、审批逻辑对真实模型原样生效。

if __name__ == "__main__":
    os.chdir(tempfile.mkdtemp(prefix="harness_v2_"))
    with open("notes.txt", "w") as f:
        f.write("harness 决定模型看到什么\n工具决定模型能做什么\n循环决定模型走多远\n")

    script = [
        {"tool": "read", "args": {"path": "notes.txt"}},
        {"tool": "bash", "args": {"command": "wc -l notes.txt"}},       # 危险，需审批
        {"tool": "write", "args": {"path": "report.md",
                                   "content": "# 报告\n\nnotes.txt 共 3 行。\n"}},  # 危险，需审批
        {"done": "已生成 report.md，任务完成"},
    ]
    agent_loop(MockLLM(script), "统计 notes.txt 的行数并写一份 report.md")
