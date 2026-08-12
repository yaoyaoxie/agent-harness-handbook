---
title: Manus 案例
dataAsOf: 2026-08
description: 剖析"通用 AI 智能体"Manus 的 harness：每个任务一台云端虚拟机的隔离执行架构、团队公开的上下文工程六条经验与其背后的成本逻辑、Wide Research 的百 agent 并行实验，以及从病毒式发布到 Meta 收购再被中国监管叫停的完整弧线——一个 harness-first 团队如何用上下文工程对抗模型同质化。
---

# Manus 案例

2025 年 3 月 6 日，一支做浏览器插件出海起家的中国团队——蝴蝶效应（Butterfly Effect，Monica 的母公司）——发布了一段 4 分钟的演示视频，把 Manus 称为"全球首款通用智能体"（general AI agent）：你只丢给它一句话的目标，它自己在云端打开电脑、浏览网页、写代码、跑数据，几十分钟后交付一个网站、一份报告或一张表格。视频 20 小时内播放量破百万，邀请码在二手平台被炒到数万元人民币，几周内等待名单超过 200 万（据多家媒体报道）。

Manus 的特殊之处不在于它演示了什么任务——那些任务 [Devin](/case-studies/devin) 和各家 Deep Research 都在做——而在于它的团队构成与技术立场：这是一家**没有自研基础模型、也不打算自研**的公司，从第一天起就把全部筹码押在模型之外的那套系统上。联合创始人兼首席科学家季逸超（Yichao 'Peak' Ji）在后来的工程博客里把话说得很直白：

> "If model progress is the rising tide, we want Manus to be the boat, not the pillar stuck to the seabed."
> （如果模型进步是上涨的潮水，我们要做船，而不是钉死在海床上的柱子。）

这句话就是 [什么是 Agent Harness](/guide/what-is-harness) 里"Agent = Model + Harness"公式的一家之言版本：**当底层模型对所有玩家同质可得时，竞争力只能来自 harness。** Manus 因此成为观察"harness-first"路线的最好样本——它的架构、它公开的工程经验、它的商业模式、乃至它的被收购与监管风波，全部是这条路线的注脚。

## 时间线速览

- **2022–2024 年**：肖弘在北京创立蝴蝶效应，收购 ChatGPT for Google 后推出主攻海外市场的 AI 浏览器插件 Monica；季逸超、张涛等于 2024 年加入（据[新浪财经对团队的梳理](https://t.cj.sina.cn/articles/view/7732457677/1cce3f0cd00101gahc)，字节跳动曾在 2024 年初出价 3000 万美元收购该公司被拒）。
- **2025 年 3 月 6 日**：Manus 早期预览版上线，邀请制；官方宣称在 GAIA 基准上取得 SOTA。演示 viral，邀请码被热炒。
- **2025 年 3 月 28 日**：公布收费方案——Starter 39 美元/月（3900 积分、2 个并发任务）、Pro 199 美元/月（19900 积分、5 个并发任务），并上线 iOS 应用（[TechCrunch 报道](https://techcrunch.com/2025/03/31/manus-launches-paid-subscription-plans-and-a-mobile-app/)）。
- **2025 年 4 月**：Benchmark 领投 7500 万美元，估值约 5 亿美元（[TechCrunch 转引彭博社](https://techcrunch.com/2025/04/25/chinese-ai-startup-manus-reportedly-gets-funding-from-benchmark-at-500m-valuation/)）；此后公司总部迁往新加坡、收缩国内团队。
- **2025 年 7 月 18 日**：季逸超发表工程博客[《Context Engineering for AI Agents: Lessons from Building Manus》](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)，公开六条上下文工程经验（下文详述）。
- **2025 年 7 月 31 日**：发布 Wide Research，单次任务可并行拉起 100 个以上全功能子 agent（[VentureBeat 报道](https://venturebeat.com/business/youve-heard-of-ai-deep-research-tools-now-manus-is-launching-wide-research-that-spins-up-100-agents-to-scour-the-web-for-you)）。
- **2025 年 12 月**：公司宣称上线 8 个月年化收入（ARR）突破 1 亿美元。
- **2025 年 12 月 29 日**：Meta 官宣收购 Manus，据报道金额超 20 亿美元，肖弘将出任 Meta 副总裁，产品继续独立运营订阅服务（[澎湃新闻报道](https://www.thepaper.cn/newsDetail_forward_32280629)）。
- **2026 年 1 月–4 月**：中国方面对该交易启动国家安全审查；2026 年 4 月 27 日，外商投资安全审查工作机制办公室决定禁止该交易并要求双方恢复原状——这是该机制首次被公开用于撤销已完成的跨境交易（[MMLC Group 解读](https://mmlcgroup.com/china-mofcom-meta-2026/)、[Trivium China 分析](https://triviumchina.com/research/china-blocks-metas-manus-acquisition-using-foreign-investment-security-review/)）。据报道，此后 Meta 开始将 Manus 与内部系统隔离并终止整合（[Codersera 的后续追踪](https://codersera.com/blog/manus-ai-2026-status-meta-block-desktop-app/)）。

## Harness 架构：每个任务一台云端 VM

Manus 官方对自己的描述不是"一个 agent"，而是"一台个人云计算平台"：**每个会话运行在一台专属的云端虚拟机上**，agent 在 VM 里拥有浏览器、终端、代码执行和文件系统，用户用自然语言调度这台电脑（VentureBeat 报道中引述的公司表述）。

```text
┌────────────── Manus 云端会话（每个任务一台专属 VM）──────────────┐
│                                                                │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│   │  浏览器   │  │ 终端/shell│  │ 文件系统  │  │ 代码执行/办公 │   │
│   │ 查资料/   │  │ 装依赖/   │  │ 读写产物/ │  │ 表格/幻灯片/  │   │
│   │ 操作网页  │  │ 跑脚本    │  │ 外置记忆  │  │ 部署网站     │   │
│   └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│        └─────────────┴──────┬──────┴───────────────┘           │
│                             ▼                                  │
│              ┌──────────────────────────┐                      │
│              │   Agent Loop（自研框架，  │  ← 据报道底层调用     │
│              │   上线后重写过 4 次）      │     Claude 等前沿模型 │
│              └─────────────┬────────────┘                      │
│                            ▼                                   │
│                     todo.md（复诵计划，                          │
│                     用户界面里实时可见）                           │
└────────────────────────────┬───────────────────────────────────┘
                             │ 交付物：网站 / 报告 / 表格 / 幻灯片
        用户：下达目标后离开，异步等待结果通知
```

放进同类产品里对比，Manus 的坐标很清楚：

| 产品 | 任务域 | 运行位置 | 人的角色 | 交付物 |
| --- | --- | --- | --- | --- |
| Manus | 通用任务 | 云端 VM，异步 | 派活后离开，等通知 | 网站 / 报告 / 表格 / 幻灯片 |
| Devin | 软件工程 | 云端沙箱，异步 | 派活 + Review PR | PR |
| Claude Code | 软件工程 | 本地终端，同步 | 在场结对、随时打断 | 代码改动 |
| Deep Research 类 | 深度调研 | 云端，异步 | 提问后等待 | 带引用的研究报告 |

把上面那张架构图和 [Devin 案例](/case-studies/devin)里的架构图并排放，会发现两者几乎同构：sandboxed VM + 浏览器 + shell + 文件读写，区别在任务域——Devin 收敛到软件工程（交付 PR），Manus 扩张到"任何能在电脑上完成的通用任务"（交付网站、报告、数据表、幻灯片）。这不意外：Manus 团队自己承认，2024 年 Cursor、Devin 这类产品的成熟是他们做 Manus 的直接灵感来源。

与 Devin 相比，Manus 在 harness 上有三个值得单独说的决策：

**1. 异步优先的人机接口。** 用户"下达目标、合上电脑、等通知"。这把人彻底移出执行回路，对 harness 的自主性要求比 Claude Code 式的"在场结对"高得多——中途没有人类纠偏，agent 必须自己从错误里恢复。这也是他们"把错误留在上下文里"这条经验（下文）如此重要的产品级原因。

**2. 用 VM 隔离换任务域的宽度。** 通用 agent 要跑任意脚本、登录任意网站、读写任意文件，风险敞口远大于只在代码库里干活的 coding agent。一次性云端 VM 把爆炸半径物理隔离——与 Devin 同款解法，详见[权限与人机协作](/components/permissions)里"沙箱隔离 vs 过程审批"的取舍讨论。

**3. 模型是插拔件。** Manus 不自研基础模型，据报道生产环境主要调用 Claude 等第三方前沿模型，靠自研编排层衔接。这意味着它的全部差异化都在 harness 里——也解释了为什么它愿意把 harness 经验写成博客公开：公开的是"手艺"，不是"资产"。

## 上下文工程六条经验：从产品全景重读

2025 年 7 月那篇工程博客，是 Manus 对行业最大的知识贡献。[上下文工程](/components/context-engineering)一章已经逐条拆解过其中与技术直接相关的部分（KV cache、mask-don't-remove、文件系统即上下文、todo.md 复诵、保留错误），这里不重复技术细节，改从**产品和商业的视角**回答一个问题：这六条经验合起来，说明 Manus 是一家什么样的公司？

先把六条列全：

1. **围绕 KV cache 做设计**：生产级 agent 最重要的单一指标是 KV cache 命中率；Manus 的平均输入输出 token 比约 100:1，缓存命中与否直接是 10 倍的成本差（Claude 缓存输入 0.3 美元/百万 token vs 未缓存 3 美元）。
2. **Mask, don't remove**：工具定义固定在上下文头部，中途用 logits 掩码限制可选动作，而不是动态增删工具——保住缓存，也避免模型对着已消失的工具定义产生幻觉。
3. **文件系统即终极上下文**：压缩必须是可恢复的——网页内容可以丢，只要 URL 还在；文档内容可以省，只要路径还在沙箱里。
4. **用复诵操纵注意力**：平均约 50 次工具调用的长任务里，反复重写 todo.md 把全局计划持续"复诵"到上下文尾部，对抗 lost-in-the-middle。
5. **把错误留在上下文里**：失败的动作和 stack trace 是模型自我修正的证据，清理轨迹等于销毁证据。
6. **别被 few-shot 困住**：上下文里高度同质的历史会让模型陷入惯性重复（批处理 20 份简历时尤其明显），要刻意注入结构化变化打破模式。

::: info 为什么六条里有两条半是"省钱"
注意第 1、2 条直接讲成本，第 3 条间接讲成本（外置存储替代昂贵的长上下文 prefill）。这不是巧合：Manus 的商业模式是**按积分（credits）计费的订阅制**，一个典型任务烧约 150 积分，而每个积分背后都是真金白银的 API 调用。对自研模型的公司，harness 优化省的是毛利；对 Manus 这样按量采购第三方模型的公司，**KV cache 命中率就是毛利率本身**。上下文工程对它不是性能技巧，是商业模型的生存条件。
:::

另一个容易被产品观察者忽略的信息是这句自嘲：上线以来，Manus 的 agent 框架**重写过四次**，每一次都是因为发现了更好的上下文塑形方式；团队把这套"手工架构搜索 + 提示微调 + 经验试错"的过程戏称为 "Stochastic Graduate Descent"（随机研究生下降）。四次重写说明两件事：其一，harness 设计目前没有理论，只有实验科学；其二，harness 的迭代速度（以小时计）远超模型微调（以周计）——这正是他们押注上下文工程而非自研模型的原始理由。

## Wide Research：并行 100 个"完整的 Manus"

2025 年 7 月 31 日发布的 Wide Research 是 Manus 在[子 Agent](/components/subagents)方向上最大胆的一次实验，也是对各家 Deep Research 的一次路线叫板：OpenAI、Google 的 Deep Research 用**一个** agent 花几十分钟往深处挖一个问题；Manus 的答案是往**宽**处走——为"比较 100 双跑鞋"这类任务瞬间拉起 100 个并发子 agent，每个负责一双鞋的设计、价格与库存分析，几分钟内汇总成可排序的表格和网页。

两个架构细节值得注意：

- **子 agent 不是专用角色，而是完整的 Manus 实例。** 没有"经理 agent / 检索 agent / 写作 agent"的分工模板，每个子 agent 都带全套工具、能独立承接任何通用任务。这规避了"为每类任务设计角色拓扑"的复杂性，代价是每个实例都背着完整 harness 的开销。
- **并行靠虚拟化底座。** 季逸超在演示中把 Wide Research 称为"优化后的虚拟化与 agent 架构的第一次应用，把算力扩展能力提升了 100 倍"——换言之，**Wide Research 的门槛不在 agent 智能，而在同时拉起并回收上百台 VM 的工程能力**。这再次印证 VM 底座是这个产品的真正资产。

::: warning 与 Cognition 的公开分歧
把 Wide Research 和 [Devin 案例](/case-studies/devin)里 Cognition 的《Don't Build Multi-Agents》放在一起读，会看到一个尚未收敛的行业争论：Cognition 认为上下文被切碎的多 agent 架构天然脆弱，首选单线程线性 agent；Manus 用"100 个全功能实例并行"直接下注对立面。两边的公开证据都不充分——VentureBeat 当时就指出 Manus 没有给出并行优于单 agent 串行的基准对比。对读者的实用建议是：Cognition 反对的是"上下文互不相通的任务切分"，Manus 的并行任务（100 双鞋互相独立）恰恰是上下文**不需要**互通的场景——两条经验未必矛盾，适用边界在任务的可分解性。
:::

## 商业化与被收购：harness 公司的定价与终局

Manus 的商业设计本身就是一篇 harness 经济学教材。它按积分计费：任务越复杂、工具调用越多，烧的积分越多——**定价模型直接暴露了成本结构**，即"成本 ≈ 模型 API 调用量 × 单 token 价格"，而 harness（KV cache、压缩、外置存储）是唯一的降本杠杆。39/199 美元两档上线后不久又重切为 Free/Basic 19/Plus 39/Pro 199 美元的阶梯（2025 年 7 月口径），积分焦虑与"烧 credit 太快"的用户抱怨伴随始终——这是所有"转售模型 token 的 agent 产品"共同的结构性难题。

然后是这个案例最戏剧性的部分。2025 年 12 月 29 日，上线不到 10 个月、宣称 ARR 破 1 亿美元的 Manus 被 Meta 官宣收购，据报道金额超 20 亿美元——Meta 史上第三大收购。值得停下来想的是：**Meta 买的是什么？** 不是模型（Manus 没有），不是用户关系（订阅盘子对 Meta 微不足道），而是一支把通用 agent harness 做到百万级用户生产环境的团队，以及那套重写过四次的工程 know-how。这笔收购本身就是"harness 是独立资产类别"这一命题迄今为止最贵的一次定价。

但故事没有停在那里。2026 年 1 月，中国方面对该交易启动国家安全审查；4 月 27 日，监管机构决定禁止交易并要求恢复原状——首次公开动用外商投资安全审查机制撤销一笔已交割的跨境 AI 交易。一家"洗澡式出海"的公司（中国团队、中国工程资产起步、迁册新加坡、卖给美国巨头）恰好撞在两国技术管制的交叉火力上。到 2026 年中，据报道 Meta 已在隔离并终止对 Manus 的整合，产品则以新加坡主体的身份继续运营。

::: tip 从 Manus 能带走的四条经验
1. **harness 的迭代速度是战略资产。** 小时级的上下文工程迭代 vs 周级的模型训练迭代，决定了没有自研模型的团队该把筹码押在哪。
2. **上下文工程的每条技巧都要能翻译成钱。** 100:1 的输入输出比意味着 KV cache 命中率≈毛利率；按 token 转售的产品，上下文工程就是财务工程。
3. **隔离底座决定任务域宽度。** VM 沙箱既给了 agent 通用行动自由，也给了 Wide Research 并行百实例的物理基础——架构决策的复利。
4. **harness 值钱，但 harness 团队不一定卖得掉。** 20 亿美元的报价证明了 harness 工程的市场价值；监管的否决证明了这类资产已上升为国家级筹码。出海架构的合规设计要与技术架构设计同步进行。
:::

## 分析：harness-first 的押注赢了吗

回到底层问题：当模型对所有人同质可得，靠 harness 能建立多深的护城河？

Manus 给出的证据是双向的。正面：它确实靠纯 harness 做到了 GAIA 宣称的 SOTA、8 个月 1 亿美元 ARR、以及让 Meta 出价 20 亿美元——在模型厂商眼皮底下。反面：它的护城河时刻被两股力量侵蚀——一是模型厂商把 harness 能力内化（Claude、GPT 各自的 agent 产品直接吃掉通用任务市场）；二是 harness 经验可公开复制（那篇六条经验的博客本身就在加速这件事）。Manus 的答案是把护城河从"技巧"搬到"重资产"：VM 调度底座、百万用户的行为数据、积分定价的运营 know-how——这些比 prompt 技巧难抄得多。

这与本站反复强调的动态视角一致（见[模型 vs Harness](/guide/model-vs-harness)）：harness 与模型共同演化，不存在一劳永逸的设计；Manus 的四次重写、以及从"通用 agent"到"被巨头收编"的终局，都是这个规律的实例。对从业者的启示不是"去做通用 agent"，而是：**harness 能力必须沉淀为不可随博客复制的东西**——基础设施、数据、或垂直领域的交付闭环——否则潮水上涨时，船和柱子都会被淹没。

## 延伸阅读

- [什么是 Agent Harness](/guide/what-is-harness)——"船与柱子"之喻的概念地基
- [模型 vs Harness](/guide/model-vs-harness)——模型同质化下的竞争力归因
- [上下文工程](/components/context-engineering)——六条经验的技术细节逐条拆解
- [规划与任务分解](/components/planning)——todo.md 复诵为什么有效：显式工作记忆的机制
- [子 Agent](/components/subagents)——Wide Research 与 Cognition 路线的设计空间对照
- [权限与人机协作](/components/permissions)——VM 沙箱与异步交付的取舍
- [Devin 案例](/case-studies/devin)——同构架构在 coding 域的版本，以及对立的多 agent 立场
- [OpenHands 案例](/case-studies/openhands)——同类架构的开源对照

## 参考资料

- [Manus 官方博客：Context Engineering for AI Agents: Lessons from Building Manus（2025-07-18，季逸超）](https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus)
- [TechCrunch：Manus 上线付费订阅与移动应用（2025-03-31）](https://techcrunch.com/2025/03/31/manus-launches-paid-subscription-plans-and-a-mobile-app/)
- [TechCrunch：Manus 获 Benchmark 投资、估值约 5 亿美元（2025-04-25，转引彭博社）](https://techcrunch.com/2025/04/25/chinese-ai-startup-manus-reportedly-gets-funding-from-benchmark-at-500m-valuation/)
- [VentureBeat：Manus 发布 Wide Research，并行拉起 100 个子 agent（2025-07-31）](https://venturebeat.com/business/youve-heard-of-ai-deep-research-tools-now-manus-is-launching-wide-research-that-spins-up-100-agents-to-scour-the-web-for-you)
- [新浪财经：Meta 为何收购 Manus——团队背景与创业脉络（2025-12-30）](https://t.cj.sina.cn/articles/view/7732457677/1cce3f0cd00101gahc)
- [澎湃新闻：Manus 官宣被 Meta 收购，将继续提供订阅服务（2025-12-30）](https://www.thepaper.cn/newsDetail_forward_32280629)
- [MMLC Group：China Blocks Meta's Acquisition of AI Firm Manus on National Security Grounds（2026-04-29）](https://mmlcgroup.com/china-mofcom-meta-2026/)
- [Trivium China：China blocks Meta's Manus acquisition using foreign investment security review（2026-05-18）](https://triviumchina.com/research/china-blocks-metas-manus-acquisition-using-foreign-investment-security-review/)
- [Codersera：Manus AI 2026 现状——Meta 交易被禁后的产品与整合走向（2026-05-25）](https://codersera.com/blog/manus-ai-2026-status-meta-block-desktop-app/)
