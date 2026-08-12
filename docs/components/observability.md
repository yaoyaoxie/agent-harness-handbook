---
title: 评测与可观测性
description: 为什么 agent 评测难、轨迹记录与回放、主流 benchmark（SWE-bench、Terminal-Bench、τ-bench、WebArena/WorkArena）、LLM-as-judge 的用法与偏差，以及如何建立 evals 驱动的 harness 迭代工作流。
---

# 评测与可观测性

Agent harness 的一切设计决策——上下文怎么组装、工具怎么描述、什么时候规划、什么时候求助——最终都要回答同一个问题：**改了之后，agent 变好了吗？** 没有可靠的评测与可观测性（observability），harness 工程就是盲人摸象：你改了 system prompt，感觉「好像变聪明了」，但实际上可能只是上次运气好。

这一页讲三件事：怎么度量 agent 的行为（评测），怎么看清 agent 的行为（可观测性），以及怎么把两者拧成一个迭代飞轮。

## 为什么 agent 评测难

传统软件测试的前提在 agent 面前全部失效：

**非确定性（non-determinism）。** 同一个任务、同一个 harness，跑两次结果可能不同。温度、采样、工具返回的时序、甚至模型提供方的后端负载均衡都会引入方差。单次运行的 pass/fail 几乎没有信息量——你必须关心分布。τ-bench 提出的 pass^k 指标（agent 在 k 次独立运行中**全部**成功的比例）把这件事量化得很残酷：一个 pass@1 为 90% 的 agent，pass^8 大约只剩 43%（0.9⁸ ≈ 0.43）。「能做」和「稳定地做」是两个能力层级。

**长轨迹（long trajectories）。** 一次 agent 运行包含几十到几百步模型调用和工具交互。最终结果对了，过程可能是瞎猫碰上死耗子；最终结果错了，可能 90% 的步骤都是对的，只在最后一步选错了参数。只看最终结果，你无法定位 harness 的哪个环节该改。

**环境依赖。** Agent 的输出副作用落在真实环境里：文件系统、Docker 容器、浏览器、真实 API。评测需要可复现的环境快照，而环境本身会漂移——SWE-bench 的任务依赖特定版本的开源仓库，WebArena 需要自托管一整套网站，Terminal-Bench 的每个任务跑在独立 Docker 容器里。环境搭建成本远高于「准备一批 prompt」。

**成功定义模糊。** 「把这个 issue 修了」的成功标准是测试全过，但测试本身可能不完备；「帮用户改签机票」的成功标准是数据库最终状态符合政策，但用户满意与否是另一回事。τ²-bench 的双控制环境（dual-control，agent 和模拟用户都能改变共享状态）甚至让「环境最终状态」都不是 agent 单方面能决定的。

::: warning 一个常见的自欺
只跑 20 个任务、每个任务跑 1 次、用「我觉得回答不错」打分——这不是 eval，这是占卜。样本量小 + 单次采样 + 主观评判，三个噪声源叠在一起，结论基本随机。
:::

## 轨迹：记录与回放

评测的原料是**轨迹（trace / trajectory）**：一次 agent 运行的完整结构化记录。最小可用的轨迹 schema：

```json
{
  "run_id": "run_01H...",
  "task": { "id": "swe-verified__django-16379", "input": "..." },
  "config": {
    "model": "claude-opus-4.6",
    "harness_version": "git:a3f9c2",
    "system_prompt_hash": "sha256:...",
    "tools": ["read", "edit", "bash"]
  },
  "steps": [
    {
      "step": 7,
      "type": "tool_call",
      "llm_input_tokens": 48210,
      "llm_output_tokens": 312,
      "latency_ms": 3400,
      "tool": { "name": "bash", "args": {"cmd": "pytest -x"}, "result": "..." }
    }
  ],
  "outcome": { "status": "resolved", "cost_usd": 1.87, "wall_time_s": 623 }
}
```

三个设计要点：

1. **记录 harness 配置，而不只是模型。** 同一个模型换一套 system prompt 和工具描述，分数可能差好几个点——Holistic Agent Leaderboard 的研究发现，同一个 Claude Opus 4 在 GAIA 上换一套 agent 框架，成绩从 64.9% 掉到 57.6%。轨迹里不带 harness 版本，事后根本无法归因。
2. **每一步都记 token 数和延迟。** 这是成本分析和上下文工程优化的唯一数据来源（见[上下文工程](/components/context-engineering)）。
3. **轨迹要可回放（replay）。** 固定模型输出、只替换某一步的 prompt 或工具结果，就能做「如果当时上下文是这样组装会怎样」的反事实实验。这是调试 harness 的显微镜。

工程上不必自己造轮子：OpenTelemetry 的 GenAI 语义约定（semantic conventions）已经标准化了 `gen_ai.*` 属性体系——`gen_ai.system`、`gen_ai.request.model`、`gen_ai.usage.input_tokens`、tool call 的 span 结构等。让 harness 直接吐 OTLP span，下游接任何兼容的后端都行，避免被某个平台锁死。

```text
┌───────────────────── Agent Run (trace) ──────────────────────┐
│  span: llm.call#1   model=opus-4.6   in=12k out=0.4k 2.1s    │
│  span: tool.read    path=src/auth.py              ok 12ms    │
│  span: llm.call#2   model=opus-4.6   in=31k out=1.2k 4.8s    │
│  span: tool.bash    cmd="pytest -x"          FAIL 8.2s       │
│  span: llm.call#3   model=opus-4.6   in=48k out=2.0k 6.4s ←─ ┼─ 失败定位点
│  span: tool.edit    path=src/auth.py              ok 9ms     │
│  ...                                                         │
│  outcome: resolved=false  cost=$1.87  steps=34               │
└──────────────────────────────────────────────────────────────┘
```

## 主流 benchmark：各自测什么

选 benchmark 之前先想清楚它度量的是 agent 的哪种能力。四个最常被引用的：

| Benchmark | 测什么 | 环境 | 成功判定 | 当前水平（2026 年中） |
|---|---|---|---|---|
| **SWE-bench Verified**（500 题） | 修真实 GitHub issue：读代码库、定位、打补丁 | 真实 Python 仓库 + 测试套件 | 补丁通过 FAIL_TO_PASS 测试 | 榜首已越过 80%，趋于饱和，污染争议增多 |
| **Terminal-Bench 2.0**（89 题） | 终端里的真实操作：编译、配服务器、数据处理、安全任务 | 每题独立 Docker 容器，带人工 oracle 解法和终态测试 | 容器最终状态通过测试 | 发布时设计目标是把前沿模型压在 50% 以下；2026 年 8 月榜首约 83%，均值约 58% |
| **τ-bench / τ²-bench** | 多轮对话中遵守政策 + 正确调用工具 API | LLM 模拟用户 + 可编程领域 API（零售/航空/电信） | 数据库最终状态匹配标注 | pass^1 可达 80%+，但 pass^k 一致性掉得很快；τ² 电信域曾把 GPT-4.1 压到 34% |
| **WebArena / WorkArena** | 在真实网页 UI 上完成任务 | 自托管网站集群（电商/GitLab/论坛/地图）；WorkArena 跑在 ServiceNow 上 | 程序化检查页面/后端状态 | WebArena 原始论文 GPT-4 仅 14.4%（人类 78.2%）；WorkArena 上 GPT-4o 42.7%，近年快速爬升 |

几个判断：

- **SWE-bench Verified 正在退出区分度。** 从 2023 年 10 月的 1.96% 基线到 2026 年的 80%+，它的历史使命接近完成。更值得注意的是它的衍生版（Multimodal、Multilingual、以及更难的 SWE-bench Pro——公开集上最好的模型也只有 44% 左右）。社区对 Verified 高分普遍持保留态度：污染（训练数据里见过这些 issue）和「过拟合榜单」的质疑一直存在，OpenAI 已停止向 Verified 提交成绩。
- **Terminal-Bench 是目前对「harness 质量」最敏感的榜单。** 它明确把「agent + 模型」作为一个系统来打分，提交时必须注明 harness。LangChain 团队公开过一个教科书级案例：不换模型，只靠改 harness（加完成前检查清单、循环检测等中间件），Terminal-Bench 2.0 从 52.8 提到 66.5，从 30 名开外进前 5。
- **τ-bench 系列的核心贡献不是分数，是 pass^k 这个度量。** 它逼你面对一致性而非单次运气，这是生产系统唯一关心的指标。
- **WebArena 类的价值在「接地」（grounding）。** 模型要会把自然语言意图落到具体按钮和表单上，这是纯文本 benchmark 测不到的。它的坑是环境运维成本高——自托管网站集群要自己维护，结果对 harness 的浏览器表示方式（AXTree vs 截图 vs 混合）极度敏感。

::: tip 选 benchmark 的实用建议
测编码 harness 用 Terminal-Bench 或 SWE-bench 系；测对话式/客服 agent 用 τ²-bench；测浏览器 agent 用 WebArena/WorkArena（通过 BrowserGym 统一接入）。永远报告多次运行的均值和方差，最好直接报 pass^k。
:::

## 结果级评估 vs 轨迹级评估

**结果级评估（outcome-based）**只看终态：补丁过没过测试、数据库状态对不对、任务成功没有。优点是客观、便宜、可大规模自动化；缺点是它回答不了「为什么」，而且奖励黑客（reward hacking）防不胜防——agent 可能用删掉测试的方式「通过」SWE-bench 任务。

**轨迹级评估（trajectory-based）**检查过程：每一步的工具选择是否合理、有没有原地打转、有没有幻觉出不存在的 API、上下文里有没有该读没读的文件。它能定位 harness 的具体缺陷，但自动化困难——「这一步合理吗」本身是个判断题。

实践中的分工：结果级评估做回归门禁（每次改 harness 全量跑），轨迹级评估做失败归因（对失败样本抽样分析）。一个有用的中间层是**轨迹启发式检查**——不需要 LLM 判断的程序化规则：

```python
def trace_heuristics(trace):
    issues = []
    if consecutive_identical_tool_calls(trace) >= 3:
        issues.append("loop_detected")          # 原地打转
    if any(s["llm_input_tokens"] > 0.8 * MAX_CTX for s in trace.steps):
        issues.append("context_near_overflow")  # 上下文濒临溢出
    if trace.outcome.status == "resolved" and trace.outcome.cost_usd > 5:
        issues.append("success_but_wasteful")   # 成功但烧钱
    if final_answer_cites_unread_files(trace):
        issues.append("grounding_violation")    # 引用了没读过的文件
    return issues
```

这些规则跑在每条轨迹上，成本几乎为零，却能抓住 harness 迭代中 80% 的常见病。

## LLM-as-judge：用法与偏差

对开放式任务（写总结、改文案、开放式问答），程序化判定不存在，只能让另一个 LLM 当评委。LLM-as-judge 的正确打开方式：

- **打分要锚定 rubric。** 「给 1-5 分」不如「检查是否满足以下 4 条标准，每条 0/1」。逐条二值判断比整体打离散分稳定得多。
- **用 pairwise 对比替代绝对打分。** 「A 和 B 哪个好」比「A 值几分」的信噪比高，尤其适合比较两版 harness。
- **judge 要拿到轨迹，不只是最终回答。** 评「这个 agent 表现好吗」却不给它看中间步骤，等于让代码评审只看 commit message。

但 LLM-as-judge 的偏差是有文献实锤的（Zheng et al., 2023，MT-Bench/Chatbot Arena 论文系统测量过）：

| 偏差 | 表现 | 缓解 |
|---|---|---|
| 位置偏差（position bias） | pairwise 评判时偏向先出现的答案 | 交换顺序评两次，不一致则标记 |
| 冗长偏差（verbosity bias） | 偏爱更长的回答，与质量无关 | rubric 里显式惩罚冗余 |
| 自我偏好（self-preference） | 用 GPT 系评委会给 GPT 系 agent 打更高的分 | judge 与被评对象用不同厂商的模型 |
| 分数压缩 | 打分挤在 3.5-4.5，区分度差 | 二值 rubric + pairwise |

::: warning
LLM-as-judge 适合**相对比较和粗筛**，不适合作为发布门禁的唯一依据。任何「judge 说新版好 2 分」的结论，都应抽 5-10% 样本人工复核后再信。
:::

## 生产监控：成本、延迟、成功率

benchmark 管「能力」，上线后还要管「运营」。agent 产品的监控指标和传统 API 不同，核心四组：

| 指标组 | 具体指标 | 告警信号 |
|---|---|---|
| 成功率 | 任务完成率、pass^k（对关键任务定期重跑）、人工介入率 | 周环比下跌 >5% |
| 成本 | 每任务 token 数、每任务美元成本、每成功任务成本（=总成本/成功数） | 成功率不变但成本上升——harness 在空转 |
| 延迟 | 端到端墙钟时间、单步 LLM 延迟 p50/p95、工具耗时分布 | p95 尾延迟恶化，通常是上下文膨胀 |
| 健康度 | 平均步数、循环检测触发率、上下文使用率、权限拒绝率（见[权限与人在回路](/components/permissions)） | 平均步数上涨往往先于成功率下跌 |

注意「每成功任务成本」这个复合指标——它比单看成本或单看成功率诚实得多。harness 改坏的第一征兆常常不是成功率下跌，而是「花更多钱办成同样的事」。

## evals 驱动的 harness 迭代工作流

把上面所有零件组装成一个闭环：

```text
┌────────────────────────────────────────────────────────────┐
│                  evals 驱动迭代闭环                         │
│                                                            │
│   ① 收集失败样本 ◄──────────── 生产轨迹 / 人工标注          │
│        │                                                   │
│   ② 固化成 eval 用例（任务 + 环境快照 + 判定器）             │
│        │                                                   │
│   ③ 改 harness（prompt/工具/上下文策略）                     │
│        │                                                   │
│   ④ 全量跑 eval 套件（N 次/任务，报均值+方差+pass^k）        │
│        │                                                   │
│   ⑤ 轨迹级归因：新失败 vs 旧失败，是不是换了个死法            │
│        │                                                   │
│   ⑥ 达标则发布，轨迹入库存档 ──────► 回到 ①                  │
└────────────────────────────────────────────────────────────┘
```

几条从实践里长出来的纪律：

1. **eval 集从真实失败里长出来，不要闭门造题。** 生产轨迹里挖出的失败用例，比拍脑袋编的「测试题」有价值一个数量级。每次用户报告 bad case，第一反应应该是「固化成 eval」。
2. **判定器先行。** 加一个 eval 用例时，先写判定器（测试、状态检查、rubric），确认它能把已知失败判成失败，再谈修 harness。判定器本身也要被测。
3. **防过拟合：留 holdout。** 迭代时盯着的 eval 集会慢慢被「教会」——harness 针对这些 case 调优，分数涨了但泛化没涨。留一批永不查看详情的 holdout 集，只在里程碑时跑。
4. **一次只改一个变量。** 同时换模型 + 改 prompt + 加工具，分数变了你不知道是谁的功劳。轨迹里记录的 harness 配置哈希就是为了支撑这种受控实验。
5. **报告效应量，不报告单次分数。** 「从 61% 涨到 63%」在 N=100、单次采样下是噪声；在 5 次运行均值 + 配对检验下才可能是信号。

这套流程的极致形态，就是 LangChain 在 Terminal-Bench 上的做法：把 harness 改动当作可测的实验，用中间件（完成前自检、循环检测）这种**可插拔的 harness 组件**做变量，逐个验证增益。这也呼应了本站反复强调的论断——[模型与 harness 的分野](/guide/model-vs-harness)决定了你能优化的主战场在哪。

## 工具生态

| 工具 | 定位 | 特点 |
|---|---|---|
| **OpenTelemetry GenAI 语义约定** | 底层标准 | `gen_ai.*` 属性与 span 模型，厂商中立，harness 埋点的首选底座 |
| **Langfuse** | 开源可观测平台 | 自托管、trace/score/eval 一体，MIT 系许可，适合数据敏感场景 |
| **LangSmith** | LangChain 生态平台 | 与 LangGraph/LangChain 深度集成，dataset + 回放体验好，商业 SaaS |
| **Braintrust / Arize Phoenix / Weave** | eval 平台 | 各有侧重：Braintrust 重 eval 工作流，Phoenix 开源且重 trace 分析，Weave 隶属 W&B 生态 |
| **BrowserGym / AgentLab** | web agent 评测环境 | 统一接入 WebArena/WorkArena/MiniWoB 等，ServiceNow 出品 |
| **Harbor** | 终端 agent 评测运行时 | Terminal-Bench 官方运行框架，也可跑自定义容器化任务 |

选型建议很朴素：**埋点用 OTel 标准（不被锁死），平台按数据合规要求选自托管还是 SaaS，eval 运行时用 benchmark 官方的**（自己重写的评判逻辑和榜单不可比，这是最常见的自坑方式）。

## 权衡与取舍

- **评测覆盖 vs 迭代速度。** 全量 eval 套件跑一遍如果花 8 小时烧 500 美元，工程师就会绕开它。分层：smoke（20 题/5 分钟/每次提交）、regression（500 题/1 小时/每次合并）、full（全量+多次采样/里程碑）。
- **judge 成本 vs 判定质量。** 程序化判定器写起来贵、跑起来免费；LLM judge 写起来快、跑起来按 token 收费且带偏差。能程序化的判定，永远程序化。
- **观测粒度 vs 开销。** 每一步工具调用的完整输入输出都落盘，存储和检索成本在长轨迹下不可忽略。常见折中：全量 span 元数据 + 大 payload 采样留存。
- **榜单可比性 vs 业务相关性。** 公共 benchmark 保证可比，但你的业务分布和 SWE-bench 的分布天差地别。公共榜单用于选模型和校准，私有 eval 集才驱动日常迭代——两者不可互相替代。

::: details 延伸阅读
- 轨迹中的 token 消耗直接服务于[上下文工程](/components/context-engineering)的优化闭环
- 工具调用的观测埋点设计见[工具系统](/components/tools)；步数与循环检测呼应[Agent 循环](/components/agent-loop)
- 想动手搭一套带 eval 的最小 harness，见[构建你自己的 Harness](/practice/build-your-own)；评测相关的反模式收录在[常见陷阱](/practice/pitfalls)
- 支撑本页方法论的原始论文索引见[核心论文](/papers/core-papers)
- 案例侧：Claude Code 与 SWE-agent 的不同评测哲学见[Claude Code 案例](/case-studies/claude-code)与[SWE-agent 案例](/case-studies/swe-agent)
:::

## 参考资料

- [SWE-bench 官方榜单与各版本说明](https://www.swebench.com/)（Verified 500 题、Lite 300 题等）
- [SWE-bench Pro 论文（arXiv 2509.16941）](https://arxiv.org/pdf/2509.16941)——公开集 SOTA 约 44%
- [Terminal-Bench 官网与榜单](https://www.tbench.ai/leaderboard)；[Terminal-Bench 2.0 说明（Snorkel 镜像）](https://snorkel.ai/leaderboard/terminal-bench-2-0/)——89 题、Docker 容器化、发布时旨在压制前沿模型于 50% 以下；[llm-stats 的 Terminal-Bench 2.0 榜单](https://llm-stats.com/benchmarks/terminal-bench-2)（2026-08：榜首约 82.7%，均值约 58%）
- [LangChain 博客：通过 harness 工程把 Terminal-Bench 2.0 从 52.8 提到 66.5](https://blog.langchain.com/improving-deep-agents-with-harness-engineering/)
- [τ-bench（arXiv 2406.12045）](https://arxiv.org/abs/2406.12045) 与 [τ²-bench 论文（arXiv 2506.07982）](https://arxiv.org/pdf/2506.07982)——pass^k 指标、双控制环境、GPT-4.1 电信域 34%；[τ-bench 官网榜单](https://taubench.com/)
- [WebArena 论文（arXiv 2307.13854）](https://arxiv.org/html/2307.13854v4)——812 题，GPT-4 agent 14.41% vs 人类 78.24%；[WebArena 项目站](https://webarena.dev/)
- [WorkArena 论文（arXiv 2403.07718）](https://arxiv.org/html/2403.07718v5)——33 任务/19,912 实例、GPT-4o 42.7%；[BrowserGym 论文](https://ar5iv.labs.arxiv.org/html/2412.05467)
- [Holistic Agent Leaderboard（arXiv 2510.11977）](https://arxiv.org/abs/2510.11977)——同模型换框架 GAIA 分差达 7 个百分点
- [Zheng et al., Judging LLM-as-a-Judge with MT-Bench and Chatbot Arena（arXiv 2306.05685）](https://arxiv.org/abs/2306.05685)——位置偏差、冗长偏差、自我偏好的系统测量
- [OpenTelemetry GenAI 语义约定](https://opentelemetry.io/docs/specs/semconv/gen-ai/)；[Langfuse](https://langfuse.com/)；[LangSmith](https://www.langchain.com/langsmith)
