# TASKS.md — 路线图与当前状态

## 当前状态

| 项 | 值 |
| --- | --- |
| 当前 Stage | **Stage02 — Photo Import and Asset Pipeline** |
| Stage 状态 | `READY_FOR_ARCHITECT_REVIEW`（DSH 已交付实现与报告，等待 Architect Review；Stage02验收 PENDING，Stage03 未开始） |
| 实现 | Stage01 已完成并获所有者批准；Stage02 已实现，并完成 Architect 实现中检查 13 项、FIX-01 六项、FIX-02 三项、FIX-03 调用标签修正：多图导入、应用自有 original 副本、ImageIO 缩略图/预览、项目包持久化与恢复、导入/网格/只读预览/移除 UI |
| Xcode 构建 / 测试 | **Stage02 仍未编译通过**（两次 macOS 运行都在编译阶段失败，0 个测试执行、无运行包）：① run 37131111464（source `dcfacd0f489b5fe517e07a5f2c283773d2eb37c6`，Xcode 16.4，3m50s）= `PhotoImportModel.swift` 缺公开 `SwiftUI` 交叉导入致 `PhotosPickerItem` 不在作用域（含 1 条级联）；② run 37132895287（source `20e9d5f4b12be4010862a46d61b7e745aeccbd7e`，4m25s）= 首轮诊断已消失，改为 5 处 `extraneous argument label 'projectID:'`（`assetDirectoryReference` 首参无标签）→ FIX-03 已修正全部 10 处 App/测试调用，等待重跑。本机（Windows）无 Xcode，**当前 78 单元 + 4 UI（82 项）测试从未运行**；仅完成结构/语法/契约静态校验。Stage01 源码 `6e8f449` 的 31 项测试通过证据**不属于** Stage02 |
| 可运行版本 | 当前仅有已批准 Stage01 包；Stage02 没有运行产物 |
| 下一步 | Architect 复审 FIX-03（[STAGE-02-FIX-03-REPORT.md](.ai/reports/STAGE-02-FIX-03-REPORT.md)）→ 对当前源码重跑 macOS 云端构建与 78 单元 + 4 UI 测试（含 12 MP 批次耗时/内存记录）→ 所有者亲自验收 |

Stage 01 的详细任务见 [.ai/tasks/STAGE-01-TASKS.md](.ai/tasks/STAGE-01-TASKS.md)，验收清单见 [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)。

## 路线图（Stage01已批准；Stage02实现已授权；后续为草案）

以下路线图来自原始Prompt。Stage01已通过，所有者明确要求继续Stage02；Stage02细化范围见执行任务和架构。Stage03–15仍未批准，不是自动执行队列。

| Stage | 名称 | 说明 | 状态 |
| --- | --- | --- | --- |
| 01 | Project Foundation | 工程骨架、导航、基础模型、测试 | APPROVED（所有者2026-10-03明确确认） |
| 02 | Photo Import and Asset Pipeline | 多图导入、原始副本/派生图、关联包与导入项目恢复 | IMPLEMENTING（DSH已开始，验收PENDING） |
| 03 | Editable Canvas and Layer System | 可编辑画布、图层模型扩展、手势与变换 | 未批准 |
| 04 | Deterministic Collage Layout Engine | 确定性布局引擎（同一文档 → 可复现结果） | 未批准 |
| 05 | Photo Analysis Foundation | 每图测量、置信度、失败原因 | 未批准 |
| 06 | Photo Role Classification | 角色分类（主图、次要、可抠主体、剪影/贴纸候选、不用） | 未批准 |
| 07 | Cutout / Silhouette / Sticker Engine | 主体分割、剪影与贴纸生成 | 未批准 |
| 08 | Adaptive Style Engine | 目标观感 + 每图测量 + 独立调整量 | 未批准 |
| 09 | AI Art Direction and Collage Planning | 结构化拼贴规划提案 | 未批准 |
| 10 | Sticker Placement Intelligence | 贴纸摆放建议 | 未批准 |
| 11 | Advanced Manual Editing | 完整手动编辑与用户锁定 | 未批准 |
| 12 | Motion Layer System | 轻量动态图层 | 未批准 |
| 13 | Export Pipeline | 静态导出（含动态导出） | 未批准 |
| 14 | Template System | 模板与预设 | 未批准 |
| 15 | App Store Production Readiness | 上架准备、隐私、元数据、性能 | 未批准 |

### 关于顺序的两点约束

1. **静态导出应早于动态系统**：必须在静态渲染与导出链路被验证之后，才在其上建立动态图层。因此上表中 Stage 12/13 的编号与顺序仅是草案，具体编号与顺序留待 Stage 01 通过后由项目所有者与 Architect 决定。
2. 每进入一个 Stage 前，都需要重新确认该 Stage 的范围、验收标准与技术选型。

## 待办登记（Backlog，未排期）

- 应用显示语言（当前所有界面文案为英文占位）。
- 产品名称、Bundle ID、App 图标占位替换（提审前必须完成）。
- 已按所有者授权初始化根目录Git，并上传私有仓库；嵌套空仓库保持独立，不纳入提交。
- `tools/` 生成式 Xcode 工程与 Xcode 直接管理工程之间的取舍。
