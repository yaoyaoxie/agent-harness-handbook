---
title: 从零搭一套 Agent 评测
description: 动手搭建 agent 评测的完整路径：单元级、轨迹级、结果级三层评测各自断言什么，评测数据集如何从真实失败回流、为什么 20 条就够起步，程序化断言与 LLM-as-judge 的分工边界，以及如何接入 CI 做回归并在成本与抽样之间做权衡——最后给 mini_harness 配上一个最小评测脚本。
---

# 从零搭一套 Agent 评测

[评测与可观测性](/components/observability)回答了"是什么"：为什么 agent 评测难、轨迹怎么记录、主流 benchmark 各测什么。本页回答"动手做"：假设你刚写完一个 harness（比如[从零构建一个最小 Harness](/practice/build-your-own)里的那一个），从零开始，第一套评测应该怎么搭。

这件事值得认真对待的直接理由来自招聘市场：本站对国内外 agent 岗位 JD 的调研（见 [JD 清单](/career/jd-list)）里，"evaluation / evals"是出现频率最高的硬技能关键词——Cursor 设了 "Agent Evaluation and Quality" 专职岗，腾讯混元在招"Agent 评测 Infra 工程师"，Anthropic 的 FDE 岗把 "build evals that actually capture what matters" 写进职责第一条。会写 agent 的人越来越多，会**度量** agent 的人仍然稀缺。

::: info 本页的立场
评测不是 harness 建成之后的验收环节，而是和 harness 同步生长的另一半代码。没有评测集的 harness 改动，本质上是[陷阱 #8：Demo 驱动开发](/practice/pitfalls)——凭一次好看的演示就宣布胜利。本页给出的每一步都可以在一个下午内落地，不需要任何平台账号。
:::

## 为什么难：一页纸版

详细的论证在[评测与可观测性](/components/observability)里，这里只压缩成三条对"动手"有直接影响的结论：

1. **非确定性 → 你不能只跑一次。** 同一任务同一 harness，跑两次结果可能不同。单次 pass/fail 没有信息量，指标必须是分布（均值、方差、pass^k）。这直接决定了后面"每个 case 至少跑 N 次"的工程要求。
2. **轨迹 vs 结果 → 你不能只测一层。** 最终结果对了不代表过程健康（可能瞎猫碰上死耗子），结果错了也不代表全盘皆输（可能只在最后一步选错参数）。只看终态你无法定位 harness 该改哪里。
3. **长尾 → 你不可能穷尽测试。** 传统测试追求用例覆盖代码路径，agent 的输入空间是自然语言 × 环境状态，本质上是无限的。评测集的目标从"覆盖"变成"采样真实分布"——这决定了数据集该怎么建（下文展开）。

## 评测三层：各自断言什么

把"评测 agent"这个笼统诉求拆成三层，每层的断言对象、写法和成本完全不同：

```text
┌────────────────────────────────────────────────────────────┐
│  结果级   任务成功了吗？（终态断言：文件/测试/DB 状态）       │
│    ▲       客观、可全自动，但回答不了"为什么"                │
│  轨迹级   过程健康吗？（步骤序列、效率、无循环、无幻觉调用）   │
│    ▲       能定位 harness 缺陷，适合程序化启发式规则          │
│  单元级   单次工具调用对吗？（工具名、参数、调用时机断言）     │
│    ▲       最便宜、最确定，相当于 agent 世界的"单元测试"      │
└────────────────────────────────────────────────────────────┘
```

| 层 | 断言对象 | 典型判定 | 类比传统测试 | 何时写 |
|---|---|---|---|---|
| 单元级 | 一次模型决策/工具调用 | 给定上下文，模型该调 `read("config.yaml")` 而不是 `bash("cat ...")`；参数 schema 合法；不幻觉工具名 | 单元测试 | 工具协议改动时 |
| 轨迹级 | 一次完整运行的步骤序列 | 先读后写、无连续 3 次相同调用、步数/成本在预算内、不引用没读过的文件 | 集成测试 + linter | 出现过程性 bad case 时 |
| 结果级 | 任务终态 | 补丁通过测试、产物文件存在且内容正确、数据库状态符合预期 | 端到端验收 | 每个 eval case 必备 |

两个实践要点：

- **结果级是骨架，另外两层是诊断工具。** 每个 eval case 必须有结果级判定，否则它不构成"测试"；单元级和轨迹级断言按需添加，主要价值是失败时告诉你**在哪一层**出的问题。
- **单元级断言最容易被忽视，但性价比最高。** agent 的大量低级失败——参数格式错、幻觉工具名、该用 `read` 却用 `bash cat`——在单次调用层面就能抓到，不需要跑完整轨迹。给工具调用写断言，等于给 harness 的协议层装上了编译器检查。

## 第一步：构建评测数据集

### 从真实失败回流，不要闭门造题

这是整个评测体系里投入产出比最高的一条纪律：**每一个生产 bad case，第一反应是固化成 eval case。** 用户报告"agent 把配置文件改坏了"——把当时的任务描述、环境快照、失败轨迹存下来，配上"配置文件应被正确修改"的判定器，就是一个新 case。真实失败的分布就是你的业务分布，拍脑袋编的"测试题"则不是。

回流机制可以极简：harness 的轨迹日志（JSONL）加一个 `tag: failed` 标记，每周把带标记的轨迹过一遍，值得固化的转成 eval case。关键不是流程，是**肌肉记忆**——bad case 不修进评测集，等于白失败了一次。

### 合成数据的三个陷阱

用 LLM 批量生成评测题很诱人，但有三个有实证的坑：

- **难度失真。** 模型生成的题目偏向"看起来像在考能力、实际一步就能解决"的形态，区分度远低于真实任务。合成题测出来的 90% 成功率，可能在真实分布上只有 60%。
- **分布偏移。** 合成数据反映的是生成模型的"想象力分布"，不是你的用户分布。用 GPT 出题测自己的产品，测的是"GPT 觉得难的事"。
- **答案不可靠。** 合成题的标注答案本身可能是错的（生成模型的幻觉直接进入 ground truth），判定器会把正确行为判成失败——这种"坏题"比没有题更糟，它会奖励错误行为。

::: warning
合成数据可以用来**扩充**评测集（在真实 case 周围做扰动、生成变体），不能用来**冷启动**评测集。第一批 case 必须来自真实轨迹或人工构造的真实任务。
:::

### 规模：20 条起步

不要等"攒够 500 条再开始"。20 条精心挑选的真实 case——覆盖你最常做的 3-5 类任务、每类包含已知失败和已知成功——就足以开始暴露 harness 的问题。原因很朴素：harness 早期迭代面对的不是统计显著性问题，而是"这么明显的 bug 居然没人发现"的问题。20 条 case 每次改动跑一遍，比 500 条从来跑不动的 case 有价值得多。

规模的扩张节奏跟着迭代阶段走：冷启动 20 条 → 日常回归 50-100 条 → 发布门禁数百条 + 多次采样。holdout 的纪律（留一批永不查看详情的题防过拟合）在[评测与可观测性](/components/observability)里讲过，同样适用。

## 第二步：写评分器（grader）

### 程序化断言 vs LLM-as-judge：适用边界

| | 程序化断言 | LLM-as-judge |
|---|---|---|
| 适用 | 有客观终态：测试通过、文件存在、命令输出匹配、schema 合法 | 开放式产出：总结质量、回答相关性、代码可读性 |
| 成本 | 写起来贵，跑起来免费、零方差 | 写起来快，跑起来按 token 收费、有方差 |
| 偏差 | 无（但有覆盖盲区） | 位置偏差、冗长偏差、自我偏好（有文献实锤，见[评测与可观测性](/components/observability)） |
| 角色 | 发布门禁的唯一依据 | 相对比较和粗筛，结论需人工抽样复核 |

一句话原则：**能程序化的判定，永远程序化。** "report.md 存在且包含正确行数"不需要一个 LLM 来判断，`grep` 就够了。只有判定本身需要语义理解时，才付出 LLM-as-judge 的成本和方差。

即使用了 LLM judge，也要按[评测与可观测性](/components/observability)里的纪律来：rubric 逐条二值判断、pairwise 优先于绝对打分、judge 与被评对象用不同厂商模型、抽 5-10% 人工复核。

### 判定器先行，且判定器本身也要测

加 eval case 的正确顺序是反直觉的：**先写判定器，再修 harness。** 具体做法——新 case 入库时，先确认判定器能把已知失败判成失败、把已知成功判成成功（用历史轨迹回放验证），这个判定器才算"校准"过。一个没校准过的判定器混入评测集，你测的就不是 agent 而是判定器的 bug。这与传统测试里"先写会失败的测试"是同一个思想。

## 第三步：给 mini_harness 加评测脚本

理论够了，落地。[构建你自己的 Harness](/practice/build-your-own)里的 `.scratch/mini_harness.py` 有一个干净的结构：`agent_loop(llm, task)` 接受任意 `llm` 可调用对象（MockLLM 或真实 API 封装），所有工具调用必经 `run_tool`。这两个接缝就是评测脚本的挂载点：替换 `llm` 注入被测模型，包裹 `run_tool` 录制轨迹。

```python
# eval_mini.py — mini_harness 的最小评测脚本（与 mini_harness.py 同目录运行）
import json, os
import mini_harness as mh

# 评测集：任务 + 环境准备 + 程序化判定器（三层断言各来一个示例）
CASES = [
    {
        "id": "wc-report",
        "task": "统计 notes.txt 的行数并写一份 report.md",
        "setup": lambda: open("notes.txt", "w").write("a\nb\nc\n"),
        # 结果级：产物存在且内容正确
        "grade_outcome": lambda t: os.path.exists("report.md")
                                   and "3" in open("report.md").read(),
        # 轨迹级：先读过文件，且没有任何工具报错
        "grade_trace": lambda t: any(c["tool"] == "read" for c in t)
                                 and not any("错误" in c["result"] for c in t),
        # 单元级：不允许用 bash cat 代替 read（协议纪律断言）
        "grade_unit": lambda t: not any(
            c["tool"] == "bash" and "cat " in c["args"].get("command", "") for c in t),
    },
    # ... 真实 case 从失败轨迹回流，攒到 20 条起步
]

N_RUNS = 3  # 非确定性：每个 case 跑多次，看通过率而非单次结果

def run_once(case, llm):
    """跑一次：包裹 run_tool 录制轨迹，跑完恢复。"""
    trace, orig = [], mh.run_tool
    def recording(name, args):
        result = orig(name, args)
        trace.append({"tool": name, "args": args, "result": result})
        return result
    mh.run_tool = recording
    try:
        case["setup"]()
        mh.agent_loop(llm, case["task"])   # llm 由调用方注入：真实 API 或 MockLLM
    finally:
        mh.run_tool = orig
    return trace

def main(make_llm):
    os.environ["AUTO_APPROVE"] = "1"       # CI 环境无人值守，跳过审批闸口
    for case in CASES:
        passes = 0
        for _ in range(N_RUNS):
            t = run_once(case, make_llm())
            ok = (case["grade_outcome"](t) and case["grade_trace"](t)
                  and case["grade_unit"](t))
            passes += ok
        print(f"{case['id']}: {passes}/{N_RUNS} 通过")
        # 关键 case 应记录轨迹到 JSONL，供失败归因与数据集回流

if __name__ == "__main__":
    main(lambda: mh.MockLLM([  # 先用 MockLLM 验证评测脚本本身；接真实模型即换掉这里
        {"tool": "read", "args": {"path": "notes.txt"}},
        {"tool": "bash", "args": {"command": "wc -l notes.txt"}},
        {"tool": "write", "args": {"path": "report.md", "content": "共 3 行\n"}},
        {"done": "完成"},
    ]))
```

这个脚本故意保留了三个"评测工程的元结构"，换任何框架都成立：

- **判定器与 case 绑定。** 每条 case 自带 `setup` + 三层 `grade_*`，新增 case 就是新增一个 dict——评测集因此可以像代码一样 review、diff、版本化。
- **先拿 MockLLM 测评测脚本。** 接真实模型之前，用脚本化的 MockLLM 跑通：能确认判定器本身工作正常（把"已知好轨迹"判成通过）。这一步就是上一节说的"判定器校准"的最小实现。
- **`N_RUNS` 不是可选项。** 接真实模型后把它调到 3-5，报告 `k/N` 通过率；单次运行的绿色不代表任何东西。

## 第四步：接入 CI 做回归

评测集攒起来之后，最大的浪费是"只在想起来的时候跑"。两类变更必须自动触发评测：

- **harness 改动**：system prompt、工具描述、上下文组装逻辑、权限规则的每一次提交。这正是[模型与 harness 的分野](/guide/model-vs-harness)里你真正能控制的那一半，每次动它都要有分数佐证。
- **模型升级**：换模型版本、换厂商、甚至同一家模型静默更新（API 后端漂移是真实存在的）。升级前后各跑一遍同一评测集，差值就是这次升级的净效应——这是你被允许相信"新模型更好"的唯一方式。

分层跑，控制 CI 时长（分层思想来自[评测与可观测性](/components/observability)的权衡讨论）：

| 层级 | 规模 | 触发时机 | 失败动作 |
|---|---|---|---|
| smoke | 10-20 条核心 case，单次采样 | 每次提交 | 阻断合并 |
| regression | 全量，3-5 次采样 | 合并到主分支 / 模型升级 | 阻断发布，人工归因 |
| full | 全量 + holdout，更多采样 | 里程碑 | 出报告，更新基线 |

CI 集成的工程细节只有三个：API key 走 secrets 管理；评测产物（轨迹 JSONL + 汇总报告）作为 build artifact 存档，失败时能直接打开轨迹归因；通过率阈值设为**不比当前基线差**，而不是拍一个绝对值——门禁的意义是防退化，不是追求完美。

## 成本与抽样的权衡

评测是要烧钱的，先算一笔账：100 条 case × 每条 5 次采样 × 每次平均 $0.5（一个中等复杂度 coding 任务的典型量级）= 一轮 $250。每天跑十轮就是不可接受的。降本的四根杠杆，按推荐顺序：

1. **先降采样次数，再砍 case 数。** case 覆盖的是分布，采样次数只影响置信度——砍掉一半 case 的伤害大于把 5 次采样降到 3 次。
2. **分层触发**（上表）：贵的全量评测只在合并和里程碑时跑，日常提交只跑 smoke。
3. **轨迹级启发式规则几乎免费。** 循环检测、上下文使用率、成本超预算这类程序化检查跑在每条轨迹上，成本为零却能抓住大部分常见病——先让它们全量跑，昂贵的 LLM judge 只抽 10-20% 的轨迹。
4. **judge 抽样复核制度化。** LLM-as-judge 的结论按 5-10% 人工抽查，这既是成本控制，也是偏差控制。

::: tip
把评测成本当作 harness 的固有开销做进预算，而不是等账单失控再砍——被砍掉的评测通常恰好是你最需要的那部分（长尾 case 和多次采样）。一个诚实的基线是：评测花费约占 agent 生产花费的 10-20%。
:::

## 工具选型

上面的脚本展示的是机制，不必自己全部重写。三个经过验证的选择，按介入程度排列：

| 工具 | 形态 | 适合场景 |
|---|---|---|
| [promptfoo](https://github.com/promptfoo/promptfoo) | 开源 CLI（MIT），YAML 定义 case + 断言，原生支持 CI | 从本页脚本升级的第一步：把 CASES 搬进 YAML，断言、矩阵对比（多模型 × 多 prompt）、CI 门禁开箱即用 |
| [inspect_ai](https://github.com/UKGovernmentBEIS/inspect_ai) | 开源 Python 框架（MIT），UK AI Security Institute 出品 | 需要严肃的多步 agent 评测：Task = dataset + solver + scorer，scorer 从精确匹配到 model-graded 都有，带沙箱执行与完整轨迹日志 |
| [Braintrust](https://www.braintrust.dev/) | 商业 eval 平台 | 团队化工作流：生产轨迹一键转数据集、实验 diff 对比、trace 级打分，把"bad case 回流"做成产品功能 |

选型建议只有一条：**机制先跑通，再上工具。** 先用本页 60 行脚本把"数据集 + 判定器 + CI 触发"的闭环跑一遍，你会清楚自己到底需要工具的哪一部分——多数团队真正缺的从来不是平台，而是前 20 条从真实失败里长出来的 case。

## 延伸阅读

- [评测与可观测性](/components/observability)——本页的概念地基：为什么难、轨迹 schema、benchmark 巡礼、LLM-as-judge 偏差
- [从零构建一个最小 Harness](/practice/build-your-own)——本页评测脚本的宿主，以及"组件要挣得自己位置"的同一哲学
- [常见陷阱与反模式](/practice/pitfalls)——Demo 驱动开发是评测要治的本病
- [Harness 设计原则](/practice/design-principles)——评测门禁应该挂在哪些变更上
- [JD 清单](/career/jd-list)——evals 作为最高频岗位要求的原始证据

## 参考资料

- [promptfoo（GitHub）](https://github.com/promptfoo/promptfoo) 与 [CI/CD 集成文档](https://www.promptfoo.dev/docs/integrations/ci-cd/)——开源、MIT、CLI 优先的 eval 与 red-teaming 工具
- [inspect_ai（GitHub）](https://github.com/UKGovernmentBEIS/inspect_ai)——UK AI Security Institute 的 Task/Solver/Scorer 评测框架，前沿实验室系统卡评测的常用底座
- [Braintrust 官方文档](https://www.braintrust.dev/docs)——生产轨迹转数据集、实验对比的商业平台
- [OpenAI Evals（GitHub）](https://github.com/openai/evals)——早期开源 eval 框架与注册表，适合参考其 case/判定器的组织方式
