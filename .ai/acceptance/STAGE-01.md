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
| App launches successfully | 项目所有者 | **已有运行证据（FIX-02 之前的源码）**：云端 commit `49dc9f3` 在模拟器安装/启动/截图成功；Appetize（iPhone 14 Pro / iOS 17.2）手动启动正常。**FIX-02 新源码尚未运行。** 所有者判断项仍未勾选 |
| Home screen loads | 项目所有者 | **已有运行证据（旧源码）**：云端 `launch.png` 与 Appetize 手动查看均显示 Home；新源码待重新运行 |
| Create Project works | 项目所有者 + UI 测试 | **已有证据（旧源码）**：云端 UI 测试通过；Appetize 手动创建两个项目正常；新源码待重跑 |
| Editor placeholder opens | 项目所有者 + UI 测试 | **已有证据（旧源码）**：云端 `testCreateProjectOpensEditorPlaceholder` 通过；新源码待重跑 |
| Back navigation works | 项目所有者 + UI 测试 | **已有证据（旧源码）**：云端 `testBackNavigationReturnsToHome` 通过；Appetize 手动返回正常；新源码待重跑 |
| Basic UI interaction feels responsive | 项目所有者 | **未评估**：Appetize 有网络延迟，手感结论必须由所有者亲自体验给出 |
| No visible critical UI errors | 项目所有者 | **已发现缺陷并退回（旧源码）**：Round 03 发现深色模式按钮内容对比度缺陷与两处 footer 偏淡；已按 FIX-02 修正，修正后的新源码尚未运行确认 |
| Project models compile and tests pass | 自动测试（macOS） | **旧源码已通过**：云端 `49dc9f3` 实际执行 29 个单元测试 + 2 个 UI 测试，零失败（日志含 `** TEST SUCCEEDED **`）。**FIX-02 新源码尚未编译或测试**；本机（Windows）仅结构校验与静态语法检查（22 个 Swift 文件，1378 行） |
| User has reviewed the Stage 01 build | 项目所有者 | **未开始**：需先由 Architect 完成新源码的构建/运行与 Review，再交所有者验收 |

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

## Round 03 / 云端运行与 FIX-02 记录（2026-10-03）

- **云端证据（Architect 执行，非 DSH；DSH 未上传源码、未操作账户、未运行云服务）**：私有仓库 `Icatly/moments-studio`，commit `49dc9f3467df41422d4894b5a1d6f36b899ade09`，run 37108580699 成功（5m41s）；Xcode 16.4、iOS 18.5 / iPhone 16 Pro 模拟器；`xcodebuild test` 实际执行 **29 个单元测试 + 2 个 UI 测试全部通过**；应用包 5,292,103 字节，SHA-256 `90796bf89f32988bd4f2bc0b84e7aa87ca99cccd9cbf10826171b435cf18084d`；随后在 Appetize（iPhone 14 Pro / iOS 17.2）手动检查 Home、创建两个项目、返回、最近顺序、重开旧项目不新增、Settings、About/Done 均正常。非零警告构建：arm64/x86_64 目的地方案提示、3 条 AppIntents metadata skip、模拟器 `eligibility.plist` 缺失与一次 XPC interrupted —— Architect 判定不阻塞本阶段。
- 最低 iOS 17 / Xcode 15.4 环境**尚未执行**，不能由 iOS 18.5 结果推断。
- 上述结果**不能代替所有者验收**，9 项判断仍未勾选。
- Round 03 判定 `CHANGES_REQUESTED`：**V1** 深色模式 Create Project 文字几乎不可读；**V2** Home 内存说明与 Settings 无选项说明两处 footer 偏淡。
- DSH 已完成 FIX-02 局部修正（严格限于授权范围）：V1 仅 Create Project 的 Label 按原生 `colorScheme` 显式取色（浅色白 / 深色黑），保留 `borderedProminent`、tint、动作与 identifier；V2 仅两处 footer 改用明确 `Color.secondary`。**未改**公开契约、导航、工程设置、依赖、资源颜色、架构与测试（仍 29 单元 + 2 UI）。
- **FIX-02 之后的新源码尚未经过任何 Xcode 编译或测试**；旧 commit `49dc9f3` 的结果不得当作新源码结果。待 Architect 重跑同一批 31 项测试，并在模拟器检查两种主题下的按钮与 footer 可读性。**Dynamic Type 最大常规字号仍未检查，不能记为通过。**
- 状态：`READY_FOR_ARCHITECT_REVIEW`；新源码尚无运行证据，不得写 `WAITING_FOR_USER`。

## 阻塞项

1. **无可运行版本**：当前开发机为 Windows，无 Xcode。需要一台 macOS 设备（或 Xcode Cloud / macOS CI）执行 `xcodebuild build` 与 `xcodebuild test`，并生成可安装到模拟器/真机的构建。
2. **首次构建结果未知**：工程文件由脚本生成并经结构校验，但从未被 Xcode 实际打开与编译。首次在 Mac 上构建可能需要修正工程设置（见 `MomentsStudio/README.md` 的维护规则）。

## 批准规则提醒

测试通过、构建成功、实现完成、ChatGPT Review 通过、无已知 Bug、DSH 自身判断，**都不构成**批准。只有项目所有者明确表示 Stage 01 通过，才可把 `User Decision` 改为 `APPROVED`。
