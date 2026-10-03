# Stage 01 验收

Stage: 01

Name: Project Foundation and iOS Application Skeleton

Status: APPROVED

User Decision: APPROVED

所有者于2026-10-03明确回复：“确认验收 继续下一阶段任务”。据此将Stage01记为APPROVED，以下9项记录所有者的整体验收确认，不是DSH或Architect代替判断。认可范围为Stage01基础框架和功能外壳，不包含最终UI设计、后续照片能力或未执行的设备/辅助功能技术验证。批准包源码为6e8f449e83141f209051081451613a3f22ca0cbb；Stage02实现已获授权，仍须独立验收。

## 验收清单

- [x] App launches successfully
- [x] Home screen loads
- [x] Create Project works
- [x] Editor placeholder opens
- [x] Back navigation works
- [x] Basic UI interaction feels responsive
- [x] No visible critical UI errors
- [x] Project models compile and tests pass
- [x] User has reviewed the Stage 01 build

## 当前版本与证据

- 构建源码：6e8f449e83141f209051081451613a3f22ca0cbb。
- [macOS实际构建及测试](https://github.com/Icatly/moments-studio/actions/runs/37110049889)：Xcode16.4 / iOS18.5，29个单元测试 + 2个UI测试零失败；模拟器安装、启动、截图成功。
- [亲自运行](https://appetize.io/app/ios/com.example.MomentsStudio?device=iphone14pro&osVersion=17.2&toolbar=true)：Appetize iPhone14Pro / iOS17.2；现有应用已更新为本包，需登录所有者账户。
- [操作说明](STAGE-01-操作说明.md)；完整技术结论、SHA-256与限制见 [Round 04](../reviews/STAGE-01-ARCHITECT-ROUND-04.md)。
- Architect 已实查最新包浅/深色按钮与两处footer，并检查深色XXXL下Home、创建/返回、Editor、Settings、About/Done，未观察到关键遮挡或崩溃。首次构建的两个项目/重开路径证据仅作历史，不冒充本次逐项实查。
- 本机Windows未运行Xcode；云端检查由Architect执行。所有者已明确确认验收，依据为上方原话。

## 待验收与已知限制

Stage01闸门已由所有者明确确认。以下限制在批准时仍存在，不扩张已批准范围。Appetize运行模拟器，不能直接安装到iPhone，不能证明真机性能；免费会话3分钟，到时可重开但内存项目清空。本阶段仅应用外壳，没有导入、编辑、AI或导出。当前英文占位、图标/产品身份待后续批准阶段决定。精确iOS17.0/Xcode15.4、Xcode26、iPad、VoiceOver及更大辅助功能字号未验证。非零警告及判断见Round04。

## 历史记录说明

以下记录保留当时的执行结果与状态；“尚未构建”等仅描述当时，不代表当前版本。当前结论以本文上方与Round04为准。

## 历史：Round 01 修正记录（2026-10-03）

按 Architect 的 `.ai/reviews/STAGE-01-ARCHITECT-ROUND-01.md` 与 `.ai/tasks/STAGE-01-ARCHITECT-FIX-01.md` 完成 5 项修正，未改变任何序列化字段名或编码形状，未开始 Stage 02：

| 编号 | 修正 | 结果 |
| --- | --- | --- |
| R1 | `Layer.opacity` 封闭写入口（`private(set)`）、非有限输入策略、解码拒绝非法值 | 已实现；新增 6 个边界测试；`CodingKeys` 与原 7 个字段名及顺序一致 |
| R2 | 统一叠放语义（zIndex 越大越靠前，同值按数组位置、越后越靠前） | 已写入 `Layer` / `CanvasDocument` 注释与 `ARCHITECTURE.md` 5.1；未新增渲染或排序 API |
| R3 | `ProjectStore`、`AppNavigationModel` 加 `@MainActor`，修正调用处与测试隔离（含 `.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md` 的补充要求） | 已实现；`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView` 与 `MomentsStudioApp` 入口均**显式**标注 `@MainActor`，不依赖 SDK 对 `View` 的整体隔离推断；`RootView` 注释已改为不泛称所有 SDK 都自动推断；纯展示组件（`InfoRow`、`RecentProjectRow`、`AboutSheet`）保持不标注；状态测试方法级 `@MainActor` + `async`；无 `@unchecked Sendable` / `nonisolated(unsafe)`、未提高最低 Xcode |
| R4 | Settings 的 Processing 与文档中的「可运行」表述 | 已改为 `Not implemented`；`ARCHITECTURE.md` 第 1 节改为「已实现外壳源码与工程，运行未验证」 |
| R5 | 去掉「以后无需模型迁移」的承诺 | 已改为「受 Review 控制的 Stage 01 契约，持久化与迁移未实现、未决定」 |

本轮只重跑 Windows 侧已有校验（未安装新依赖、未改 build/test 结论）。状态：`READY_FOR_ARCHITECT_REVIEW`，等待 Architect 复审。

## 历史：Round 03 / 云端运行与 FIX-02 记录（2026-10-03）

- **云端证据（Architect 执行，非 DSH；DSH 未上传源码、未操作账户、未运行云服务）**：私有仓库 `Icatly/moments-studio`，commit `49dc9f3467df41422d4894b5a1d6f36b899ade09`，run 37108580699 成功（5m41s）；Xcode 16.4、iOS 18.5 / iPhone 16 Pro 模拟器；`xcodebuild test` 实际执行 **29 个单元测试 + 2 个 UI 测试全部通过**；应用包 5,292,103 字节，SHA-256 `90796bf89f32988bd4f2bc0b84e7aa87ca99cccd9cbf10826171b435cf18084d`；随后在 Appetize（iPhone 14 Pro / iOS 17.2）手动检查 Home、创建两个项目、返回、最近顺序、重开旧项目不新增、Settings、About/Done 均正常。非零警告构建：arm64/x86_64 目的地方案提示、3 条 AppIntents metadata skip、模拟器 `eligibility.plist` 缺失与一次 XPC interrupted —— Architect 判定不阻塞本阶段。
- 最低 iOS 17 / Xcode 15.4 环境**尚未执行**，不能由 iOS 18.5 结果推断。
- 上述结果**不能代替所有者验收**，9 项判断仍未勾选。
- Round 03 判定 `CHANGES_REQUESTED`：**V1** 深色模式 Create Project 文字几乎不可读；**V2** Home 内存说明与 Settings 无选项说明两处 footer 偏淡。
- DSH 已完成 FIX-02 局部修正（严格限于授权范围）：V1 仅 Create Project 的 Label 按原生 `colorScheme` 显式取色（浅色白 / 深色黑），保留 `borderedProminent`、tint、动作与 identifier；V2 仅两处 footer 改用明确 `Color.secondary`。**未改**公开契约、导航、工程设置、依赖、资源颜色、架构与测试（仍 29 单元 + 2 UI）。
- **FIX-02 之后的新源码尚未经过任何 Xcode 编译或测试**；旧 commit `49dc9f3` 的结果不得当作新源码结果。待 Architect 重跑同一批 31 项测试，并在模拟器检查两种主题下的按钮与 footer 可读性。**Dynamic Type 最大常规字号仍未检查，不能记为通过。**
- 状态：`READY_FOR_ARCHITECT_REVIEW`；新源码尚无运行证据，不得写 `WAITING_FOR_USER`。

## 批准规则

只有项目所有者亲自检查并明确表示“Stage 01 通过”，才可标记 APPROVED。测试、构建、实现或Architect Review完成都不构成批准。提出修改意见即 CHANGES_REQUESTED，只修当前Stage；Stage02–15未批准。

## 所有者批准记录

| 日期 | 决定者 | 原话 | 结果 |
| --- | --- | --- | --- |
| 2026-10-03 | 项目所有者 | 确认验收 继续下一阶段任务 | Stage01 APPROVED；允许定义并执行Stage02；不批准Stage02或Stage03验收 |
