# One-click generation for Moments

朋友圈创意照片应用项目（iOS 优先，面向 App Store）。当前处于 **Stage02：Photo Import and Asset Pipeline**。Stage01已由所有者明确批准。

## 当前状态

| 项 | 值 |
| --- | --- |
| Stage | Stage02 — Photo Import and Asset Pipeline |
| 状态 | `READY_FOR_ARCHITECT_REVIEW`（DSH已交付并停止；正在准备实际macOS验证，Stage02验收PENDING） |
| 代码 | Stage02实现与FIX01已交付；76单元+4UI测试尚未在Xcode执行 |
| 可运行版本 | 最近可运行包仍是已批准Stage01源码 `6e8f449`；不是Stage02版本 |
| 下一步 | [Stage02执行任务](.ai/tasks/STAGE-02-IMPLEMENT-01.md) → 自动测试 → Architect Review → 可运行包 → 所有者验收 |

## 快速导航

- [Stage02架构与完成标准](docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md)
- [Stage02验收清单](.ai/acceptance/STAGE-02.md)
- [项目要求与上下文交接](项目要求与上下文交接.md)：所有者要求、执行标准、当前版本与关键进展；更换上下文先读
- [项目说明](项目说明.md)：目标、位置、约束与进度
- [MomentsStudio/README.md](MomentsStudio/README.md)：**如何构建、运行与测试**
- [AGENTS.md](AGENTS.md)：角色、权限、依赖与验收规则
- [ARCHITECTURE.md](ARCHITECTURE.md)：分层、状态流、导航、模型契约、未来扩展位置
- [TASKS.md](TASKS.md)：当前Stage02任务与路线图草案（Stage03–15未批准）与当前状态
- [APP_STORE_REQUIREMENTS.md](APP_STORE_REQUIREMENTS.md)：上架工程核对清单
- [.ai/reports/STAGE-01-REPORT.md](.ai/reports/STAGE-01-REPORT.md)：Stage 01 实现报告
- [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)：Stage01验收与所有者批准记录

## 基线文档

- [产品与架构基线](docs/产品与架构基线.md)
- [Stage 01 原始 Prompt](docs/Stage-01-用户原始Prompt.txt)（Stage01唯一原始需求依据；Stage02以当前架构与执行任务为准）
- [Stage 01 Architect Review 备忘](docs/Stage-01-Architect-Review备忘.md)

## 重要提醒

- 本项目由 DeepSeek Harness 以 Implementation Engineer 身份实现，**不得在未获得项目所有者明确批准的情况下开始下一 Stage**。
- 测试、构建和Review不替代所有者验收；Stage01已获本人确认，Stage02仍待独立验收，Stage03–15未批准。
