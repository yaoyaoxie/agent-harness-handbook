# Agent Harness 手册

> 系统拆解 AI 智能体骨架（Agent Harness）的设计与实现——智能体循环、上下文工程、工具系统、记忆、子代理、权限安全与评测。

**在线阅读：<https://harness.zhigouread.com>**

## 这是什么

同一个大模型，装进不同的「骨架」（Harness），能力天差地别。这个开源手册系统性地拆解了 AI Agent 背后那层鲜被讨论、却真正决定上限的工程结构：

- **导读**：什么是 Agent Harness、为什么 Harness 决定上限、演进简史、总体架构
- **核心组件**：智能体循环（Agent Loop）、上下文工程、工具系统与 MCP、规划、记忆、子代理、权限安全、评测与可观测性
- **经典案例**：Claude Code、Cursor、SWE-agent、OpenHands、Aider、Devin、Codex、LangGraph、扣子、Manus、Dify
- **论文精读**：经典论文、前沿进展、阅读路径
- **实践指南**：从零构建最小 Harness、评测搭建、设计原则、常见陷阱
- **求职向**：JD 知识点拆解、简历对标、面试题库

## 技术栈

- [VitePress](https://vitepress.dev/) 静态站点，`npm run docs:dev` 本地预览，`npm run docs:build` 构建
- `deploy/`：自托管部署与运维资产（Nginx 配置、一键发布脚本、自研访问统计）
- `deploy/track/`：通用前端埋点统计（tracker.js），可接入任意第三方站点

## 访问统计

站点使用自研的零依赖统计方案（Nginx 日志分析 + 静态看板），公开可见：<https://harness.zhigouread.com/stats/>
