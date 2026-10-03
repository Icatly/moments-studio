# Stage 01 验收

Stage:
01

Name:
Project Foundation and iOS Application Skeleton

Status:
READY_FOR_ARCHITECT_REVIEW

> 状态取值说明：项目所有者原始 Prompt（`docs/Stage-01-用户原始Prompt.txt`，本 Stage 唯一任务来源）要求此文件写 `WAITING_FOR_USER`；`docs/产品与架构基线.md` v0.2 则规定 DSH 完成代码与测试后「只可报告 `READY_FOR_ARCHITECT_REVIEW`」，由 ChatGPT Review 确认存在可运行版本后再转为 `WAITING_FOR_USER`；`docs/Stage-01-Architect-Review备忘.md` 明确该差异属「Prompt 状态定义问题」，两种写法都不算 DSH 越权，但**任何情况下此文件状态都不得被当作阶段已通过**。
>
> 本文件取 `READY_FOR_ARCHITECT_REVIEW`：这是两者中更保守的取值，因为**当前不存在可运行版本**（开发机为 Windows，无 Xcode），不具备进入用户验收的条件。本文件中的用户判断题不得由 DSH 勾选。

## 验收清单

- [ ] App launches successfully
- [ ] Home screen loads
- [ ] Create Project works
- [ ] Editor placeholder opens
- [ ] Back navigation works
- [ ] Basic UI interaction feels responsive
- [ ] No visible critical UI errors
- [ ] Project models compile and tests pass
- [ ] User has reviewed the Stage 01 build

User Decision:

PENDING

## 每项由谁验证、当前证据

| 清单项 | 验证者 | 当前状态与证据 |
| --- | --- | --- |
| App launches successfully | 项目所有者（真机/模拟器） | **未验证**：本机无 Xcode。已提供工程与源码，构建命令见 `MomentsStudio/README.md` |
| Home screen loads | 项目所有者 | **未验证**：同上；代码见 `Features/Home/HomeView.swift` |
| Create Project works | 项目所有者 + UI 测试 | **未运行**：UI 测试 `testCreateProjectOpensEditorPlaceholder` 已编写，等待在 macOS 执行 |
| Editor placeholder opens | 项目所有者 + UI 测试 | **未运行**：同上；代码见 `Features/Editor/EditorPlaceholderView.swift` |
| Back navigation works | 项目所有者 + UI 测试 | **未运行**：UI 测试 `testBackNavigationReturnsToHome` 已编写 |
| Basic UI interaction feels responsive | 项目所有者 | **未验证**：需真机/模拟器手感确认 |
| No visible critical UI errors | 项目所有者 | **未验证**：需运行确认 |
| Project models compile and tests pass | 自动测试（macOS） | **未执行**：29 个单元测试 + 2 个 UI 测试已编写（Round 01 新增 6 个透明度边界测试）；Windows 侧只完成结构校验与静态语法检查（22 个 Swift 文件语法解析通过），不能替代 Xcode 编译与测试 |
| User has reviewed the Stage 01 build | 项目所有者 | **未开始**：需先产出可运行版本 |

## Round 01 修正记录（2026-10-03）

按 Architect 的 `.ai/reviews/STAGE-01-ARCHITECT-ROUND-01.md` 与 `.ai/tasks/STAGE-01-ARCHITECT-FIX-01.md` 完成 5 项修正，未改变任何序列化字段名或编码形状，未开始 Stage 02：

| 编号 | 修正 | 结果 |
| --- | --- | --- |
| R1 | `Layer.opacity` 封闭写入口（`private(set)`）、非有限输入策略、解码拒绝非法值 | 已实现；新增 6 个边界测试；`CodingKeys` 与原 7 个字段名及顺序一致 |
| R2 | 统一叠放语义（zIndex 越大越靠前，同值按数组位置、越后越靠前） | 已写入 `Layer` / `CanvasDocument` 注释与 `ARCHITECTURE.md` 5.1；未新增渲染或排序 API |
| R3 | `ProjectStore`、`AppNavigationModel` 加 `@MainActor`，修正调用处与测试隔离（含 `.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md` 的补充要求） | 已实现；`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView` 与 `MomentsStudioApp` 入口均**显式**标注 `@MainActor`，不依赖 SDK 对 `View` 的整体隔离推断；`RootView` 注释已改为不泛称所有 SDK 都自动推断；纯展示组件（`InfoRow`、`RecentProjectRow`、`AboutSheet`）保持不标注；状态测试方法级 `@MainActor` + `async`；无 `@unchecked Sendable` / `nonisolated(unsafe)`、未提高最低 Xcode |
| R4 | Settings 的 Processing 与文档中的「可运行」表述 | 已改为 `Not implemented`；`ARCHITECTURE.md` 第 1 节改为「已实现外壳源码与工程，运行未验证」 |
| R5 | 去掉「以后无需模型迁移」的承诺 | 已改为「受 Review 控制的 Stage 01 契约，持久化与迁移未实现、未决定」 |

本轮只重跑 Windows 侧已有校验（未安装新依赖、未改 build/test 结论）。状态：`READY_FOR_ARCHITECT_REVIEW`，等待 Architect 复审。

## 阻塞项

1. **无可运行版本**：当前开发机为 Windows，无 Xcode。需要一台 macOS 设备（或 Xcode Cloud / macOS CI）执行 `xcodebuild build` 与 `xcodebuild test`，并生成可安装到模拟器/真机的构建。
2. **首次构建结果未知**：工程文件由脚本生成并经结构校验，但从未被 Xcode 实际打开与编译。首次在 Mac 上构建可能需要修正工程设置（见 `MomentsStudio/README.md` 的维护规则）。

## 批准规则提醒

测试通过、构建成功、实现完成、ChatGPT Review 通过、无已知 Bug、DSH 自身判断，**都不构成**批准。只有项目所有者明确表示 Stage 01 通过，才可把 `User Decision` 改为 `APPROVED`。
