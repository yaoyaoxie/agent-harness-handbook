#!/usr/bin/env python3
"""v1_minimal_loop.py — 第一版：最小 agent loop。

本版是渐进式教程的起点，只保留一个 harness 的骨架五环节：

    组装上下文 → 调模型 → 解析工具调用 → 执行工具 → 把结果回写上下文

刻意**没有**的东西（后续版本等症状出现再逐个挂上）：
    - 工具注册表与未知工具防护 ………………… v2
    - 工具输出截断（上下文体积防线）…………… v2
    - 危险操作的人工审批闸口 ……………………… v2
    - todo 规划工具、会话摘要压缩 ……………… v3

对照阅读：/components/agent-loop、/practice/build-your-own。

运行（MockLLM，无需 API key，纯标准库）：
    python3 examples/v1_minimal_loop.py
"""
import json
import os
import tempfile

MAX_STEPS = 10  # 最大循环步数：模型之外唯一确定会生效的刹车

# ---------- 工具：两个只读工具，内联实现 ----------

def tool_echo(text: str) -> str:
    return text

def tool_read(path: str) -> str:
    if not os.path.exists(path):
        return f"错误：文件不存在 {path}"  # 错误返回字符串，成为模型可学习的观察
    with open(path, encoding="utf-8") as f:
        return f.read()

# ---------- Agent Loop：五环节全在这一个函数里 ----------

SYSTEM = """你是一个 coding agent。每一步只输出一个 JSON 对象：
- 调用工具：{"tool": "工具名", "args": {...}}
- 结束任务：{"done": "总结"}
可用工具：echo(text), read(path)。每步根据上一步的工具结果决定下一步。"""

def agent_loop(llm, task: str):
    # ① 组装上下文：system 约定协议，messages 是模型每一步能看到的全部世界
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": "任务：" + task},
    ]
    for step in range(1, MAX_STEPS + 1):
        reply = llm(messages)                      # ② 调模型：唯一的"模型时刻"
        print(f"\n── 第 {step} 步 ── 模型输出: {reply}")
        try:
            action = json.loads(reply)             # ③ harness 解析结构化决策
        except json.JSONDecodeError:
            # 错误是上下文，不是异常：把格式错误回喂给模型让它重试
            messages.append({"role": "user", "content": "格式错误：请输出一个 JSON 对象"})
            continue
        if "done" in action:                       # 模型宣告完成，循环退出
            print(f"\n✅ 完成：{action['done']}")
            return action["done"]
        messages.append({"role": "assistant", "content": reply})
        # ④ 执行工具：v1 只有内联分派，没有注册表——幻觉出的工具名会在这里直接撞墙
        if action["tool"] == "echo":
            result = tool_echo(**action.get("args", {}))
        elif action["tool"] == "read":
            result = tool_read(**action.get("args", {}))
        else:
            result = f"错误：未知工具 {action['tool']}"
        print(f"   工具结果: {result[:200]}")
        # ⑤ 回写：工具结果作为新观察进入上下文，成为下一步决策的依据
        messages.append({"role": "user", "content": f"[工具 {action['tool']} 返回]\n{result}"})
    print(f"\n⛔ 达到最大步数 {MAX_STEPS}，强制停止")  # 兜底刹车
    return None

# ---------- MockLLM：基于规则的假模型 ----------

class MockLLM:
    """真实 LLM 会读 messages 里的完整轨迹再决策；MockLLM 用预写脚本模拟
    "合理决策序列"，遇到错误则立即终止汇报。harness 的循环结构对两者完全同构。"""
    def __init__(self, script):
        self.script = list(script)
    def __call__(self, messages):
        last = messages[-1]["content"]
        if "错误" in last:
            return json.dumps({"done": f"遇到错误，任务失败：{last[:80]}"}, ensure_ascii=False)
        if not self.script:
            return json.dumps({"done": "脚本耗尽"}, ensure_ascii=False)
        return json.dumps(self.script.pop(0), ensure_ascii=False)

# ── 真实模型挂载点 ─────────────────────────────────────────────
# 把 MockLLM 换成一个签名为 (messages) -> str 的 callable 即可，
# harness 其余部分一行都不用改。例如用 OpenAI 兼容 API：
#     import urllib.request
#     def real_llm(messages):
#         req = urllib.request.Request(
#             "https://api.example.com/v1/chat/completions",
#             data=json.dumps({"model": "...", "messages": messages}).encode(),
#             headers={"Authorization": "Bearer " + os.environ["API_KEY"]})
#         return json.loads(urllib.request.urlopen(req).read())["choices"][0]["message"]["content"]
#     agent_loop(real_llm, task)

if __name__ == "__main__":
    os.chdir(tempfile.mkdtemp(prefix="harness_v1_"))  # 演示文件写进临时目录，不污染仓库
    with open("notes.txt", "w") as f:
        f.write("harness 决定模型看到什么\n工具决定模型能做什么\n循环决定模型走多远\n")

    script = [
        {"tool": "read", "args": {"path": "notes.txt"}},
        {"tool": "echo", "args": {"text": "notes.txt 共 3 行"}},
        {"done": "已读取 notes.txt 并统计出行数"},
    ]
    agent_loop(MockLLM(script), "读取 notes.txt，告诉我它有几行")
