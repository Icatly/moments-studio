# Stage 01 架构 Review 包（供 ChatGPT Architect 使用）

本文件只列出**需要审查的问题**与**对应证据位置**，不下结论。DSH 未执行的部分已明确标注。

## 最新 Architect 交付补充（2026-10-03）

此节优先于下方历史执行记录。Architect 已完成 Round04 Review：当前源码 `6e8f449` 在macOS云端编译并通过29个单元测试及2个UI测试，包已上传Appetize且实查浅/深色与深色XXXL。阶段由Architect转为 `WAITING_FOR_USER`，User Decision保持PENDING，所有者9项判断不代勾。DSH本机仍未运行Xcode，继续停止开发；Stage02–15未批准。详见 [.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md](../reviews/STAGE-01-ARCHITECT-ROUND-04.md)。下方“未构建”等表述仅为当时记录。

## 0. 历史：交付时请优先确认的前提

1. **状态流程（Round 01 已裁定）**：Architect 明确 `READY_FOR_ARCHITECT_REVIEW` 合适；修复期间记 `IMPLEMENTING`，交付后回到 `READY_FOR_ARCHITECT_REVIEW`；用户未批准且无可运行版本，不得写 `WAITING_FOR_USER` 或 `APPROVED`。`.ai/acceptance/STAGE-01.md` 按此取值，复选框与 `User Decision` 仍未勾选/PENDING。
2. **构建状态（分两层）**：DSH 本机为 Windows，无 Xcode，只做结构校验与静态语法检查；Architect 已在云端对 commit `49dc9f3` 完成真实构建与 31 项测试（见第 10 节）。但那是 **FIX-02 之前**的源码——**当前源码仍没有任何构建或测试结果**，不得当作「已可运行」。
3. **UI 文案语言**：所有界面文案为英文占位，显示语言尚未决定。

## 1. 架构边界

- [ ] `Models/`（`Project`、`CanvasDocument`、`Asset`、`Layer`）是否完全不依赖 SwiftUI / UIKit？是否有未来图像处理会被迫倒灌进视图的风险？
- [ ] `Services/ProjectStore` 是否是唯一的存储接缝？未来替换为沙盒持久化时视图是否无需改动？
- [ ] `Asset` 与 `Layer` 的关系未定义（没有 `assetID`，素材库归属也未定）。这个留白是否合理，还是应在 Stage 02 之前先定契约？
- [ ] 目录结构 `App/ Core/ Models/ Services/ Features/ DesignSystem/ Utilities/` 是否符合预期？是否缺少 `Core/` 应承担的职责？

证据：`ARCHITECTURE.md` 第 2、3、5 节；`MomentsStudio/MomentsStudio/**`。

## 2. 模型与序列化

- [ ] 模型字段是否过少（`Asset` 无 `metadata`、`Layer` 无 `assetID`）或多于当前需要？（Round 01 裁定：本阶段不补，保留 `Asset` 最小模型。）
- [ ] `CanvasDocumentTests.testDocumentDecodesFromDocumentedFixture` 固定的 JSON 形状是否可作为 Stage 02 的契约起点？
- [ ] 未知枚举值解码失败、无文档版本号 —— 是否必须在 Stage 02 前解决？
- [ ] 日期使用 `JSONEncoder` 默认策略（`deferredToDate`）是否可接受？
- [x] ~~`Layer.opacity` 可被直接赋值、解码绕过 initializer~~ → **已修正（Round 01，R1）**：`private(set)` 封闭写入口；程序化非有限输入取默认 1；解码对非有限或越界值抛 `DecodingError.dataCorruptedError`。`CodingKeys` 与原 7 个字段名及顺序一致，编码形状未变。请复审该不变量与新增的 6 个边界测试。

证据：`Models/*.swift`、`MomentsStudioTests/CanvasDocumentTests.swift`、`MomentsStudioTests/ProjectModelTests.swift`。

## 3. 状态与导航 Bug

- [ ] 路由只携带 `UUID`、页面从 store 读当前值 —— 是否存在项目被删除/重命名后显示异常的分支？当前 `ProjectStore` 没有删除能力。
- [ ] `AppNavigationModel.pop()` / `popToRoot()` 目前没有生产调用点（只有测试）。是否应删除以免成为「未使用的抽象」？
- [ ] `RootView` 用 `@Bindable` 局部变量绑定 `@Observable` 状态对象的写法是否认可？
- [x] ~~`ProjectStore` 与 `AppNavigationModel` 未加 `@MainActor`（以文档约定代替）~~ → **已修正（Round 01，R3 + R3 调用处补充）**：两个类均为 `@MainActor`；`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView` 与 `MomentsStudioApp` 入口全部**显式**标注 `@MainActor`（不依赖 SDK 对 `View` 的整体隔离推断，符合 `.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md`）；`RootView` 注释已不再泛称所有 SDK 都自动推断；纯展示组件（`InfoRow`、`RecentProjectRow`、`AboutSheet`）只读不可变值，未标注；状态测试用方法级 `@MainActor` + `async`，不改动 `XCTestCase` 子类隔离；无 `@unchecked Sendable` / `nonisolated(unsafe)`，未提高最低 Xcode。请复审是否仍存在非隔离调用点（本机无编译器，只能静态检查）。

证据：`Core/Navigation/*.swift`、`App/RootView.swift`、`Services/ProjectStore.swift`、`MomentsStudioTests/AppNavigationModelTests.swift`、`MomentsStudioTests/ProjectStoreTests.swift`。

## 4. 主线程负担与性能风险

- [ ] Stage 01 有无任何主线程重活？（实际存在的是 `Bundle.main` 读取与 `Date` 格式化，均无风险。）
- [ ] `ProjectStore.recentProjects` 每次访问都对数组做一次 `reversed()` 复制；在项目数量增长后是否需要缓存？（当前仅内存、数量极小。）
- [ ] `ARCHITECTURE.md` 第 8 节的性能策略是否足以约束 Stage 02 的导入实现？

## 5. 构建配置与警告

- [ ] 工程构建设置（`IPHONEOS_DEPLOYMENT_TARGET=17.0`、`SWIFT_VERSION=5.0`、`TARGETED_DEVICE_FAMILY=1,2`、`GENERATE_INFOPLIST_FILE=YES`、无 `DEVELOPMENT_TEAM`）是否认可？`SWIFT_VERSION=5.0` 而非 6.0 的理由是否成立？
- [ ] `AppIcon.appiconset` 为空占位 —— 是否会产生构建警告，是否需要在 Stage 01 就补一个占位图标？
- [ ] iPhone 仅竖屏、iPad 四方向 的组合是否认可？

证据：`MomentsStudio/MomentsStudio.xcodeproj/project.pbxproj`（Build Settings 段）、`MomentsStudio/README.md`。

## 6. 测试真实性

- [ ] 29 个单元测试 + 2 个 UI 测试是否覆盖了要求的四类目标（项目创建、重命名、模型编解码、导航核心状态）？是否有多余的镜像测试（对常量断言）？Round 01 新增的 6 个测试只针对透明度不变量，未增加与常量镜像相关的用例。
- [ ] UI 测试依赖 accessibility identifier 而非可见文案，是否会因为英文占位文案改动而脆弱？
- [ ] **这 31 项测试已由 Architect 在云端对 FIX-02 之前的源码实际执行并通过**（见第 10 节）；**当前源码尚未执行**。仍请检查断言逻辑本身是否正确（尤其是 `Layer` 透明度不变量与非法解码路径、`recentProjects` 顺序、golden JSON fixture 与模型字段是否一致）。Round 01 修正的正是「旧测试只验证了钳制、没有验证非法解码」这一缺口。

证据：`MomentsStudioTests/*.swift`、`MomentsStudioUITests/Stage01SmokeUITests.swift`。

## 7. 原生视觉与可访问性

- [ ] 三个占位页与 Home 是否足够「原生、克制」，有没有与最终方向冲突的样式（卡片化、自造配色、装饰动画）？
- [ ] 占位文案是否清楚表明「未实现」，有没有任何地方让用户误以为功能已存在？Round 01 已把 Settings 的 `Processing` 从 `On-device only` 改为 `Not implemented`（R4），请复查其余行是否也有暗示已实现能力的措辞。
- [ ] 主要触控区域、VoiceOver 语义、Dynamic Type 是否达标？

证据：`Features/**/*.swift`、`DesignSystem/*.swift`。

## 8. DSH 无法验证的事项（针对**当前源码**；请勿视为已通过）

对 **FIX-02 之前**的 commit `49dc9f3`，Architect 已在云端完成编译与 31 项测试并通过（第 10 节）；**该结果不适用于当前源码**。下表针对当前（FIX-02 之后）源码：

| 事项 | 原因 |
| --- | --- |
| 编译通过 | 无 Xcode |
| 单元测试 / UI 测试通过 | 无 Xcode、无模拟器 |
| 应用可启动、界面真实观感 | 同上 |
| 真机与模拟器表现、性能手感 | 同上 |
| 工程文件能被 Xcode 正常打开 | 只做了结构校验（引用完整性、Sources 覆盖、scheme 匹配） |

Windows 侧实际执行的检查与结果见 `.ai/reports/STAGE-01-REPORT.md` 第 8 节。

## 9. Round 01 修正的实际验证证据（2026-10-03）

全部为本机（Windows）实际执行，未安装新依赖：

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 工程结构校验 | `python tools/verify_project.py` | PASS：95 对象引用完整、Sources 恰好覆盖 22 个 `.swift`（16/5/1）、scheme 与 target 一致、资源 JSON 合法、括号/编码/Tab 检查通过 |
| 工程生成幂等 | `python tools/generate_xcodeproj.py` 前后 SHA-256 | 一致（`project.pbxproj` 未发生漂移） |
| Swift 语法解析 | tree-sitter（上一轮已安装的开发机工具，非项目依赖） | 22/22 文件零错误，共 1359 行 |
| 契约不变性（一次性脚本） | 比对 `CodingKeys` 与原字段名/顺序、fixture 内 `opacity` 取值、`private(set)` 存在性、类级 `@MainActor` | PASS：键集与顺序均为 `id, kind, transform, opacity, zIndex, isLocked, isHidden`；唯一字面 fixture 值 `0.8` 仍在 0…1 内 |
| 绕过手段扫描 | 搜索 `@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency import` | 无匹配 |
| R3 调用处覆盖（`.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md` 的要求） | 一次性脚本：枚举 App target 内所有 `View`/`App` 声明（含 `private`），判断其主体是否引用 `ProjectStore` / `AppNavigationModel`，并检查声明前是否直接标注 `@MainActor` | PASS：`MomentsStudioApp`、`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView` 全部显式标注；`InfoRow`、`RecentProjectRow`、`AboutSheet` 不引用这两个对象（纯展示，未标注）；**缺失标注 = 0** |
| 未用绕过手段（同一要求） | 扫描 App target 全部 `.swift` 的顶层自由声明与并发绕过写法 | 顶层 `let`/`var`/`func` = 0；无 `@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency import`；`SWIFT_STRICT_CONCURRENCY`、`SWIFT_UPCOMING_FEATURE_FLAGS` 均未设置 |
| 未提高最低 Xcode（同一要求） | 从 `project.pbxproj` 读取关键构建设置 | `IPHONEOS_DEPLOYMENT_TARGET = 17.0`、`SWIFT_VERSION = 5.0`、`LastUpgradeCheck = 1500`、`compatibilityVersion = "Xcode 14.0"`、`objectVersion = 56` —— 与 Round 01 之前一致，未改动 |
| 写入口闭合 | 搜索 `\.opacity\s*=` | 仅出现在 `Layer.swift` 的 `init` 与 `init(from:)` 内部 |
| 测试数量 | 统计 `func test` | 29 个单元测试 + 2 个 UI 测试 |

### 9.1 与已安装构建工作流的静态一致性（供 Architect 参考）

Architect 已把草案从 `.ai/build/stage01-macos.yml` 安装到 `.github/workflows/stage01-macos.yml`（DSH 未创建、未修改、未运行该文件；草案路径现已不存在）。按当前安装版本逐项静态核对本工程（**未执行**）：`macos-15` runner ✓；`actions/checkout@v7`；`xcodebuild test -project MomentsStudio/MomentsStudio.xcodeproj -scheme MomentsStudio -configuration Debug` 与工程路径、共享 scheme 名、Debug 配置一致 ✓；`-destination "platform=iOS Simulator,arch=arm64,id=…"` 已把架构固定为 arm64（对应云端 Review 中 arm64/x86_64 二义性提示）✓；测试产物路径 `Debug-iphonesimulator/MomentsStudio.app` ✓；`xcrun simctl launch … com.example.MomentsStudio` 与工程 bundle id 一致 ✓；`-parallel-testing-enabled NO`、`CODE_SIGNING_ALLOWED=NO` 对模拟器构建无冲突 ✓。**未核对**：`actions/checkout@v7` / `actions/upload-artifact@v7` / `macos-15` 标签在运行时是否可用（DSH 无网络验证，不猜测）。

**仍未验证（针对**当前源码**）**：编译、类型检查、actor 隔离诊断、XCTest、UI 测试、真实界面。上述检查不能替代它们。

## 10. Round 03 / 云端运行证据与 FIX-02（2026-10-03）

### 10.1 云端证据（Architect 执行；DSH 未上传源码、未操作账户、未运行云服务）

| 项 | 值 |
| --- | --- |
| 仓库 / commit | `Icatly/moments-studio` / `49dc9f3467df41422d4894b5a1d6f36b899ade09` |
| 运行 | 37108580699，成功，5m41s |
| 工具链 | Xcode 16.4 (16F6)，ARM macOS runner，iOS 18.5 / iPhone 16 Pro |
| 测试 | `xcodebuild test`：**29 单元 + 2 UI 全部通过**，`** TEST SUCCEEDED **` |
| 产物 | 5,292,103 字节；SHA-256 `90796bf89f32988bd4f2bc0b84e7aa87ca99cccd9cbf10826171b435cf18084d` |
| 手动运行 | 模拟器安装/启动/截图；Appetize（iPhone 14 Pro / iOS 17.2）：Home、创建两个项目、返回、最近顺序、重开旧项目不新增、Settings、About/Done 均正常 |
| 警告（非零警告构建） | arm64/x86_64 destination 提示（选中 arm64）；3 条 AppIntents metadata extraction skipped；模拟器 `eligibility.plist` 缺失与一次 XPC interrupted —— 判定不阻塞本阶段；DSH 未加依赖/未关警告 |
| 未覆盖 | 最低 iOS 17 / Xcode 15.4；Dynamic Type 最大常规字号 |

### 10.2 Round 03 裁定与 FIX-02 落地

- **CHANGES_REQUESTED**：V1 深色模式 Create Project 文字几乎不可读（证据 `.ai/build/downloads/dark-button-before.png`）；V2 两处 List footer 说明偏淡。根因见 `.ai/reviews/STAGE-01-ARCHITECT-ROUND-03.md`。
- DSH 改动（仅授权范围）：`HomeView` 新增原生 `@Environment(\.colorScheme)`，**仅** Create Project 的 Label 显式取色（浅色 `Color.white` / 深色 `Color.black`），保留 `borderedProminent`、`tint(Palette.accent)`、动作与 identifier；**仅** Home 与 Settings 的 footer 由 `.foregroundStyle(.secondary)` 改为 `.foregroundStyle(Color.secondary)`。
- **未改**：公开模型/序列化字段、导航契约、工程设置、目录边界、依赖、资源颜色、品牌设计、测试数量（29 单元 + 2 UI，未加颜色镜像测试）。

### 10.3 本轮本机（Windows）实际执行的检查

| 检查 | 结果 |
| --- | --- |
| `python tools/verify_project.py` | PASS：95 对象引用完整；Sources 恰好覆盖 22 个 `.swift`（16/5/1）；scheme/target/构建设置/资源 JSON/括号与编码检查通过；22 个文件解析干净（**1378 行**） |
| tree-sitter Swift 解析（已装开发机工具） | `TREE_SITTER_PARSED=22 WITH_ERRORS=0` |
| V1 定向检查（一次性脚本） | `@Environment(\.colorScheme)` 恰好 1 处；Label 覆盖存在；`dark ? .black : .white` 映射正确；`borderedProminent`/`tint`/identifier/`Label` 文案全部保留 |
| V2 定向检查（一次性脚本） | 全 App target 中 `.foregroundStyle(Color.secondary)` **恰好 2 处**：`HomeView.swift:32`、`SettingsPlaceholderView.swift:41`（即两处 footer）；其余 7 处层级 `.secondary` 未改动 |
| 变更范围核对 | 本轮仅 `Features/Home/HomeView.swift`、`Features/Settings/SettingsPlaceholderView.swift` 两个源码文件被修改；测试、资源、模型、工程设置均未触碰 |
| 测试数量 | 29 个单元测试 + 2 个 UI 测试（与 Round 01 后一致，无新增/删除） |

### 10.4 关键诚实声明

上表云端结果对应 **FIX-02 之前的源码**。**FIX-02 之后的新源码尚未经过任何 Xcode 编译或测试**，不得把 `49dc9f3` 的通过结果当作新源码结果。请对新源码重跑同一批 31 项测试，并在模拟器比较两种主题下的按钮与 footer 以及 Dynamic Type 最大常规字号。
