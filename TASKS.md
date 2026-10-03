# TASKS.md — 路线图与当前状态

## 当前状态

| 项 | 值 |
| --- | --- |
| 当前 Stage | **Stage 01 — Project Foundation and iOS Application Skeleton** |
| Stage 状态 | `READY_FOR_ARCHITECT_REVIEW`（Architect Round 01 的 R1–R5 修正已实施，等待复审；DSH 不得自行转为 `WAITING_FOR_USER`） |
| 实现 | 源码与工程已完成（应用外壳、导航、基础模型、内存状态、测试、文档）；Round 01 修正见 [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md) |
| Xcode 构建 / 测试 | **未执行**：当前工作机为 Windows，无 Xcode。命令见 [MomentsStudio/README.md](MomentsStudio/README.md) |
| 可运行版本 | 尚未产出，需在 macOS + Xcode 上构建 |
| 下一步 | Architect 复审 → 生成可运行版本 → 项目所有者亲自验收 |

Stage 01 的详细任务见 [.ai/tasks/STAGE-01-TASKS.md](.ai/tasks/STAGE-01-TASKS.md)，验收清单见 [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)。

## 路线图（草案，未批准，可调整）

以下阶段来自项目所有者 Prompt，**不是**已批准的工作队列。任何阶段都不得在项目所有者批准当前 Stage 之前开始。

| Stage | 名称 | 说明 | 状态 |
| --- | --- | --- | --- |
| 01 | Project Foundation | 工程骨架、导航、基础模型、测试 | 实现完成，待 Review 与验收 |
| 02 | Photo Import and Asset Pipeline | 多图导入、沙盒素材存储、缩略图与预览素材 | 未批准 |
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
- 仓库是否使用 Git 管理（当前目录未初始化 Git）。
- `tools/` 生成式 Xcode 工程与 Xcode 直接管理工程之间的取舍。
