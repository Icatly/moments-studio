# Stage 01 架构 Review 包（供 ChatGPT Architect 使用）

本文件只列出**需要审查的问题**与**对应证据位置**，不下结论。DSH 未执行的部分已明确标注。

## 0. 请优先确认的前提

1. **状态流程（Round 01 已裁定）**：Architect 明确 `READY_FOR_ARCHITECT_REVIEW` 合适；修复期间记 `IMPLEMENTING`，交付后回到 `READY_FOR_ARCHITECT_REVIEW`；用户未批准且无可运行版本，不得写 `WAITING_FOR_USER` 或 `APPROVED`。`.ai/acceptance/STAGE-01.md` 按此取值，复选框与 `User Decision` 仍未勾选/PENDING。
2. **未运行构建**：开发机为 Windows，无 Xcode。工程文件由脚本生成，只做过结构与静态语法校验。**不存在已验证可启动的构建。** 请勿把本 Stage 当作「已可运行」。
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
- [ ] **这些测试从未执行过。** 请检查断言逻辑本身是否正确（尤其是 `Layer` 透明度不变量与非法解码路径、`recentProjects` 顺序、golden JSON fixture 与模型字段是否一致）。Round 01 修正的正是「旧测试只验证了钳制、没有验证非法解码」这一缺口。

证据：`MomentsStudioTests/*.swift`、`MomentsStudioUITests/Stage01SmokeUITests.swift`。

## 7. 原生视觉与可访问性

- [ ] 三个占位页与 Home 是否足够「原生、克制」，有没有与最终方向冲突的样式（卡片化、自造配色、装饰动画）？
- [ ] 占位文案是否清楚表明「未实现」，有没有任何地方让用户误以为功能已存在？Round 01 已把 Settings 的 `Processing` 从 `On-device only` 改为 `Not implemented`（R4），请复查其余行是否也有暗示已实现能力的措辞。
- [ ] 主要触控区域、VoiceOver 语义、Dynamic Type 是否达标？

证据：`Features/**/*.swift`、`DesignSystem/*.swift`。

## 8. DSH 无法验证的事项（请勿视为已通过）

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

### 9.1 与构建路径草案的静态一致性（供 Architect 参考）

按 `.ai/build/stage01-macos.yml` 的假设与本工程逐项静态核对（**未执行**）：工作区根含 `MomentsStudio/` ✓；工程路径 `MomentsStudio/MomentsStudio.xcodeproj` ✓；共享 scheme 名 `MomentsStudio` ✓；产物名 `MomentsStudio.app` ✓；启动用的 bundle id `com.example.MomentsStudio` 与工程设置一致 ✓；`-configuration Debug` 走 scheme 的 Test Action（已包含单元测试与 UI 测试两个 target）✓；`-parallel-testing-enabled NO` 与 `CODE_SIGNING_ALLOWED=NO` 对模拟器构建无冲突 ✓。**未核对**：`actions/checkout@v7`、`actions/upload-artifact@v7`、`macos-15` runner 标签在首次运行时是否可用（DSH 无网络验证，不猜测）。

**仍未验证**：编译、类型检查、actor 隔离诊断、XCTest、UI 测试、真实界面。上述检查不能替代它们。
