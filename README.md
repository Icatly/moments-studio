# One-click generation for Moments

朋友圈创意照片应用项目（iOS 优先，面向 App Store）。当前处于 **Stage 01：Project Foundation and iOS Application Skeleton**。

## 当前状态

| 项 | 值 |
| --- | --- |
| Stage | Stage 01 — Project Foundation and iOS Application Skeleton |
| 状态 | `READY_FOR_ARCHITECT_REVIEW`（等待 ChatGPT 架构 Review；DSH 不得自行转为 `WAITING_FOR_USER`） |
| 代码 | 已实现 iOS 应用骨架，见 [MomentsStudio/](MomentsStudio/README.md) |
| 可运行版本 | **尚未产出**：开发机为 Windows，无 Xcode，工程从未被实际编译或运行 |
| 下一步 | ChatGPT Review → 在 macOS 上构建 → 项目所有者亲自验收 |

## 快速导航

- [项目说明](项目说明.md)：目标、位置、约束与进度
- [MomentsStudio/README.md](MomentsStudio/README.md)：**如何构建、运行与测试**
- [AGENTS.md](AGENTS.md)：角色、权限、依赖与验收规则
- [ARCHITECTURE.md](ARCHITECTURE.md)：分层、状态流、导航、模型契约、未来扩展位置
- [TASKS.md](TASKS.md)：路线图草案（Stage 02–15 未批准）与当前状态
- [APP_STORE_REQUIREMENTS.md](APP_STORE_REQUIREMENTS.md)：上架工程核对清单
- [.ai/reports/STAGE-01-REPORT.md](.ai/reports/STAGE-01-REPORT.md)：Stage 01 实现报告
- [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)：Stage 01 验收清单（待项目所有者验收）

## 基线文档

- [产品与架构基线](docs/产品与架构基线.md)
- [Stage 01 原始 Prompt](docs/Stage-01-用户原始Prompt.txt)（本 Stage 唯一任务来源）
- [Stage 01 Architect Review 备忘](docs/Stage-01-Architect-Review备忘.md)

## 重要提醒

- 本项目由 DeepSeek Harness 以 Implementation Engineer 身份实现，**不得在未获得项目所有者明确批准的情况下开始下一 Stage**。
- 测试通过、构建成功、Review 通过都不构成阶段批准；Stage 01 尚未被任何人批准。
