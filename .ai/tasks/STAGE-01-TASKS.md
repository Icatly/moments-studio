# Stage 01 任务分解与状态

对应 `.ai/acceptance/STAGE-01.md`。来源：项目所有者原始 Prompt（`docs/Stage-01-用户原始Prompt.txt`，本 Stage 唯一任务来源）+ `docs/产品与架构基线.md` v0.2 的约束。

状态图例：`DONE`（已完成并有证据）/ `DONE_WITH_CAVEAT`（完成但有未验证部分）/ `BLOCKED`（阻塞）。

| # | 任务 | 状态 | 证据 / 说明 |
| --- | --- | --- | --- |
| 1 | 建立 Swift/SwiftUI iPhone 优先 Xcode 工程，deployment target 17.0 并写明依据 | DONE_WITH_CAVEAT | `MomentsStudio/MomentsStudio.xcodeproj`（由 `tools/generate_xcodeproj.py` 生成）；依据写在 `MomentsStudio/README.md`。**工程未被 Xcode 实际打开过** |
| 2 | 实现 Home / 编辑器占位页 / 设置占位页，Home 含标题、创建项目、近期项目区 | DONE | `Features/Home/HomeView.swift`、`Features/Editor/EditorPlaceholderView.swift`、`Features/Settings/SettingsPlaceholderView.swift`、`Features/Settings/AboutSheet.swift` |
| 3 | 最简导航 Home → Project/Editor，支持未来 sheet | DONE | `Core/Navigation/AppRoute.swift`（push + sheet 两种目的地）、`AppNavigationModel`、`App/RootView.swift` |
| 4 | 最小 `Codable` 模型：Project / Asset / Layer / CanvasDocument + 轻量 ProjectStore（创建/重命名/打开/近期列表） | DONE | `Models/*.swift`、`Services/ProjectStore.swift`；无数据库、无第三方依赖 |
| 5 | 中性系统颜色/字体/间距，触控与 VoiceOver 基本可用 | DONE | `DesignSystem/DesignTokens.swift`、`DesignSystem/InfoRow.swift`；系统文本样式（支持 Dynamic Type）、44pt 最小触控高度、accessibility label/hint/identifier |
| 6 | 治理文档 AGENTS/ARCHITECTURE/TASKS/APP_STORE_REQUIREMENTS + `.ai/acceptance/STAGE-01.md` | DONE | 根目录四个文件 + `.ai/acceptance/`；`.ai/tasks`、`.ai/reviews`、`.ai/reports` 在有内容时创建 |
| 7 | 自动测试覆盖项目创建/重命名/模型编解码/导航核心状态；UI smoke test 覆盖 启动→创建→编辑器占位页 | DONE_WITH_CAVEAT | 29 个单元测试 + 2 个 UI 测试已编写（Round 01 新增 6 个透明度边界测试）；**尚未在任何设备上执行**（无 Xcode） |
| 8 | 在 macOS/Xcode 运行构建与测试，交付可启动版本；若环境不允许则保留源码与明确阻碍 | BLOCKED | 开发机为 Windows，无 Xcode；阻碍与所需命令见 `.ai/acceptance/STAGE-01.md` 与 `MomentsStudio/README.md`。未把未运行的构建写成成功 |
| 9 | 交付 `.ai/reports/STAGE-01-REPORT.md` | DONE | `.ai/reports/STAGE-01-REPORT.md` |
| 10 | Architect Round 01 修正 R1–R5（`.ai/tasks/STAGE-01-ARCHITECT-FIX-01.md`），含主 actor 调用处补充要求（`.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md`） | DONE_WITH_CAVEAT | 透明度不变量、叠放语义、`@MainActor`（状态类 + 全部相关视图 + App 入口显式标注）、真实文案、迁移承诺；未改序列化字段。详见 `.ai/reports/STAGE-01-REPORT.md` 第 0 节与 `.ai/acceptance/STAGE-01.md` 的 Round 01 记录。**编译与测试仍未执行** |

## 未做（按指令明确不做）

照片导入、拼贴/布局、滤镜/LUT、抠图、剪影、贴纸、文字工具、动画、视频导出、订阅、账户、云后端、模板市场、最终 UI 品牌视觉。占位页文案明确写「未实现」，界面不展示假照片或假草稿。

## Stage 状态变更记录

| 时间 | 状态 | 触发 |
| --- | --- | --- |
| 2026-10-02 | `IMPLEMENTING` | DSH 开始 Stage 01 |
| 2026-10-02 | `READY_FOR_ARCHITECT_REVIEW` | 编码、自动校验与自查结束；等待 ChatGPT 架构 Review |
| 2026-10-03 | `CHANGES_REQUESTED` → `IMPLEMENTING`（Architect corrections） | Architect Round 01 判定需要修复（R1–R5） |
| 2026-10-03 | `READY_FOR_ARCHITECT_REVIEW` | R1–R5 已实施并重跑 Windows 侧校验；等待 Architect 复审（用户仍未批准） |
