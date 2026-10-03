# STAGE-01-REPORT.md

Stage 01 — Project Foundation and iOS Application Skeleton
执行者：DeepSeek Harness（Implementation Engineer）
日期：2026-10-02
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过任何验收；未开始 Stage 02）

---

## 0. Round 01 修正（2026-10-03）

Architect 第一轮 Review（`.ai/reviews/STAGE-01-ARCHITECT-ROUND-01.md`）判定「需要修复并再次 Review」。本节优先于本报告其他章节中与本轮冲突的表述；原文保留以便对照。

| 编号 | 修正内容 | 落地位置 |
| --- | --- | --- |
| R1 | `Layer.opacity` 改为 `private(set)`；程序化非有限输入（NaN/±Infinity）取 `defaultOpacity`(1)、其余越界取最近边界；自定义 `init(from:)` 对非有限或越界的**持久化**值抛 `DecodingError.dataCorruptedError`（不再静默修正）；`CodingKeys` 显式列出，与原 7 个字段名及顺序一致，编码形状未变 | `Models/Layer.swift` + 6 个新增边界测试 |
| R2 | 统一叠放语义：`zIndex` 越大越靠前；同值按数组位置、越后越靠前。只定义语义，未新增渲染器/排序 API；数组往返测试只断言**存储顺序** | `Models/Layer.swift`、`Models/CanvasDocument.swift`、`ARCHITECTURE.md` 5.1 |
| R3 | `ProjectStore` 与 `AppNavigationModel` 加 `@MainActor`；`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView`、`MomentsStudioApp` 入口**显式**标注（不依赖 SDK 对 `View` 的整体隔离推断，按 `.ai/reviews/STAGE-01-R3-CALLSITE-NOTE.md` 补充要求）；状态测试改为方法级 `@MainActor` + `async`；无 `@unchecked Sendable` / `nonisolated(unsafe)`、未提高最低 Xcode | `Services/ProjectStore.swift`、`Core/Navigation/AppNavigationModel.swift`、`App/RootView.swift`、`App/MomentsStudioApp.swift`、三个屏幕视图、`ProjectStoreTests.swift`、`AppNavigationModelTests.swift` |
| R4 | Settings 的 `Processing` 改为 `Not implemented`；`ARCHITECTURE.md` 第 1 节改为「已实现外壳源码与工程，运行未验证」 | `Features/Settings/SettingsPlaceholderView.swift`、`ARCHITECTURE.md` |
| R5 | 去掉「以后无需模型迁移」承诺：改为「受 Review 控制的 Stage 01 契约，持久化与迁移未实现、未决定」 | `Models/Project.swift`、`ARCHITECTURE.md` 第 5 节 |

**未改变**：任何序列化字段名与编码形状、现有契约测试、依赖、工程结构、Stage 范围。
**仍未执行**：Xcode 构建、XCTest、UI 测试（本机无 macOS/Xcode）——第 7–9 节的结论不变，本轮不产生任何构建或测试通过声明。

## 0.1 Round 03：云端运行证据与 FIX-02（2026-10-03）

### 云端证据（由 Architect 执行，非 DSH；DSH 未运行任何云服务）

| 项 | 值 |
| --- | --- |
| 私有仓库 / commit | `Icatly/moments-studio` / `49dc9f3467df41422d4894b5a1d6f36b899ade09` |
| 运行 | run 37108580699，成功；总时长 5m41s |
| 工具链 | Xcode 16.4 (16F6)，ARM macOS runner，iOS 18.5 / iPhone 16 Pro 模拟器 |
| 测试 | `xcodebuild test` 实际执行：**29 个单元测试 + 2 个 UI 测试全部通过**，日志含 `** TEST SUCCEEDED **` |
| 应用包 | 5,292,103 字节；SHA-256 `90796bf89f32988bd4f2bc0b84e7aa87ca99cccd9cbf10826171b435cf18084d` |
| 手动运行 | 模拟器安装/启动/截图成功；随后在 Appetize（iPhone 14 Pro / iOS 17.2）手动检查 Home、创建两个项目、返回、最近顺序、重开旧项目不新增、Settings、About/Done —— 均正常，无崩溃或严重遮挡 |
| 非零警告构建（已记录，未掩盖） | 模拟器同时匹配 arm64/x86_64（选中 arm64）；3 条 AppIntents metadata extraction skipped；模拟器 `eligibility.plist` 缺失与一次 XPC connection interrupted。Architect 判定不阻塞本阶段；DSH 未通过增加依赖或关闭警告来消除 |
| 未覆盖 | 最低 iOS 17 / Xcode 15.4 环境尚未执行，不能由 iOS 18.5 结果推断 |

### Round 03 结论：CHANGES_REQUESTED

- **V1**：深色模式下 Create Project 文字几乎不可读（同一构建，证据 `.ai/build/downloads/dark-button-before.png`）。
- **V2**：Home 的内存说明与 Settings 的无选项说明两处 List footer 在两种主题下都偏淡，Home 深色尤其难读。

### DSH 的 FIX-02 局部修正（仅授权范围）

| 编号 | 改动 | 文件 |
| --- | --- | --- |
| V1 | `HomeView` 读取原生 `@Environment(\.colorScheme)`；**仅** Create Project 的 Label 内容按主题显式取色（浅色 `Color.white`、深色 `Color.black`）。`borderedProminent`、`tint(Palette.accent)`、按钮动作与 accessibility identifier 全部保留；未替换 AccentColor、未新增 ButtonStyle / 颜色 token / 协议 | `Features/Home/HomeView.swift` |
| V2 | **仅** Home 与 Settings 的 List footer 由层级 `.foregroundStyle(.secondary)` 改为明确 `.foregroundStyle(Color.secondary)`；字体、文案、布局不变 | `Features/Home/HomeView.swift`、`Features/Settings/SettingsPlaceholderView.swift` |

**未改动**：公开模型与序列化字段、导航契约、工程设置、目录边界、依赖、资源颜色（`Assets.xcassets` 未触碰）、品牌设计、测试（仍为 29 单元 + 2 UI，未为颜色常量增加镜像测试）。

**关键诚实声明**：上表云端结果对应的是 **FIX-02 之前的源码**（`49dc9f3`）。本轮修正后的**新源码尚未经过任何 Xcode 编译或测试**，不得把旧 commit 的通过结果当作新源码的结果。待 Architect 对新源码重新构建并运行同一批 31 项测试，再在模拟器检查两种主题下的按钮与 footer 可读性。**Dynamic Type 最大常规字号仍未检查，不能记为通过。**

**构建路径状态**：Architect 已把工作流草案从 `.ai/build/stage01-macos.yml` 安装为 `.github/workflows/stage01-macos.yml`（DSH 未创建、未修改、未运行；原草案路径现已不存在），并把 destination 固定为 `arch=arm64`。DSH 对该安装版本做了只读静态核对：工程路径、共享 scheme 名、Debug 配置、测试产物名与启动 bundle id 均与本工程一致（详见 review packet 第 9.1 节）。

## 1. Summary

按项目所有者原始 Prompt（`docs/Stage-01-用户原始Prompt.txt`，本 Stage 唯一任务来源）交付了 iOS 应用骨架：

- 一个 Swift/SwiftUI、iPhone 优先（可扩展 iPad）的 Xcode 工程，deployment target iOS 17.0，**零第三方依赖**。
- 三个界面：Home（临时标题 + 创建项目 + 近期项目区）、编辑器占位页、设置占位页（含 About 弹层）。
- `NavigationStack` + 路由枚举的导航，push 与 sheet 两种目的地，路由只携带 `UUID`。
- 可序列化的最小模型：`Project`、`CanvasDocument`、`Asset`、`Layer`（含 `LayerTransform`、`CanvasSize`），以及内存版 `ProjectStore`（创建 / 重命名 / 打开 / 近期列表）。
- 29 个单元测试 + 2 个 UI smoke test（已编写，**未执行**；其中 6 个透明度边界测试为 Round 01 新增）。
- 治理与架构文档：`AGENTS.md`、`ARCHITECTURE.md`、`TASKS.md`、`APP_STORE_REQUIREMENTS.md`、`.ai/{acceptance,tasks,reviews,reports}`、`docs/{architecture,design,product}`。
- 明确未做：照片导入、拼贴、布局、滤镜/LUT、抠图、剪影、贴纸、文字、AI、动画、视频、导出、订阅、账户、云后端、模板市场、最终品牌视觉。

**最关键的事实：本 Stage 没有可运行版本。** 开发机为 Windows，无 macOS、无 Xcode、无 Swift 工具链，`xcodebuild build` / `xcodebuild test` **从未执行**。工程文件由脚本生成并做过结构与静态语法校验，但从未被 Xcode 打开或编译。本报告不把任何未运行的结果写成通过。

## 2. Files created

以下均为本次新建（经磁盘清点共 **43 个文件**；其中 `MomentsStudio/MomentsStudio/` 下 19 个 = 16 个 Swift + 3 个资源 JSON）。

### 2.1 仓库治理与文档（根目录，4 个）

| 文件 | 内容 |
| --- | --- |
| `AGENTS.md` | 角色与权限（ChatGPT / DSH / 项目所有者）、架构修改政策、依赖政策、测试要求、人工验收闸门、Stage 规则、性能原则、视觉权威、文档纪律。含明确条款：**DSH 不得在未获项目所有者明确批准前开始下一 Stage** |
| `ARCHITECTURE.md` | 分层与目录职责、状态流、导航、模型与序列化契约、未来图像处理/AI/渲染的归属、UI 与处理分离、性能策略、预览素材 vs 原始素材、已知架构缺口 |
| `TASKS.md` | 当前 Stage 状态 + Stage 02–15 路线图草案（标注未批准、可调整；静态导出应先于动态系统） |
| `APP_STORE_REQUIREMENTS.md` | 上架工程核对清单：照片权限、隐私、端上/云端、用户数据、AI 披露、导出行为、App Review 准备、可访问性、购买/订阅。明确不是法律意见，且 Stage 01 实际状态为「无网络、无权限、无数据收集」 |

### 2.2 应用工程（`MomentsStudio/`）

| 文件 | 内容 |
| --- | --- |
| `MomentsStudio/README.md` | 构建 / 运行 / 测试命令、环境要求、工程文件维护规则、当前限制 |
| `MomentsStudio/.gitignore` | Xcode 与构建产物忽略规则 |
| `MomentsStudio/MomentsStudio.xcodeproj/project.pbxproj` | 脚本生成的工程文件（3 个 target，95 个对象） |
| `MomentsStudio/MomentsStudio.xcodeproj/project.xcworkspace/contents.xcworkspacedata` | 工程工作区 |
| `MomentsStudio/MomentsStudio.xcodeproj/xcshareddata/xcschemes/MomentsStudio.xcscheme` | 共享 scheme（Build / Test / Launch / Profile / Analyze / Archive） |
| `MomentsStudio/MomentsStudio/Resources/Assets.xcassets/**/Contents.json`（3 个） | 资源目录、AppIcon 占位（空图标槽）、AccentColor 中性占位色 |

### 2.3 App 源码（16 个 Swift 文件）

| 文件 | 职责 |
| --- | --- |
| `App/MomentsStudioApp.swift` | `@main` 入口 |
| `App/RootView.swift` | 唯一把 `ProjectStore`、`AppNavigationModel` 接到 `NavigationStack` 与 `.sheet` 的地方 |
| `Core/Navigation/AppRoute.swift` | `AppRoute`（push）、`SheetRoute`（modal） |
| `Core/Navigation/AppNavigationModel.swift` | `path` / `sheet` 状态与 push / pop / popToRoot / present / dismiss |
| `Models/Project.swift` | 身份、名称、时间戳、文档；`rename(to:at:)` 拒绝空白名 |
| `Models/CanvasDocument.swift` | `CanvasSize` + 画布文档；`layers` 顺序即叠放顺序 |
| `Models/Layer.swift` | `LayerKind`、`LayerTransform`、`Layer`（透明度钳制到 0…1） |
| `Models/Asset.swift` | 素材身份与沙盒相对路径（Stage 01 不创建实例） |
| `Services/ProjectStore.swift` | 内存项目状态：创建（唯一默认名）、打开、重命名、近期列表 |
| `DesignSystem/DesignTokens.swift` | 临时 token：`Spacing`、`Radius`、`Palette`、`Typography`、`Motion`、`Layout` |
| `DesignSystem/InfoRow.swift` | 最小组件：标签/值行 |
| `Features/Home/HomeView.swift` | 标题、创建项目、近期项目区（含「仅本次运行」说明）、设置入口 |
| `Features/Editor/EditorPlaceholderView.swift` | 显示真实项目状态并明确写「Stage 01 未实现」 |
| `Features/Settings/SettingsPlaceholderView.swift` | 状态清单（权限未申请、仅端上、无云、未实现项）与 About 入口 |
| `Features/Settings/AboutSheet.swift` | 验证 modal 接缝的 About 弹层 |
| `Utilities/AppInfo.swift` | 临时产品身份（占位名称、版本、Stage 标签） |

### 2.4 测试（6 个文件）

`MomentsStudioTests/ProjectModelTests.swift`、`CanvasDocumentTests.swift`、`LayerModelTests.swift`、`ProjectStoreTests.swift`、`AppNavigationModelTests.swift`、`MomentsStudioUITests/Stage01SmokeUITests.swift`。

### 2.5 Windows 侧工程工具（2 个）

| 文件 | 用途 |
| --- | --- |
| `tools/generate_xcodeproj.py` | 由源码目录确定性生成 `.xcodeproj`（仅 Python 标准库） |
| `tools/verify_project.py` | 校验工程引用完整性、Sources 覆盖、构建设置、scheme、资源 JSON、Swift 静态语法与 UI 测试 identifier 一致性（仅标准库） |

### 2.6 `.ai/` 与 `docs/`

| 文件 | 内容 |
| --- | --- |
| `.ai/acceptance/STAGE-01.md` | 验收清单（9 项全部未勾选）、`User Decision: PENDING`、状态取值说明与阻塞项 |
| `.ai/tasks/STAGE-01-TASKS.md` | Stage 01 任务分解与逐项状态、状态变更记录 |
| `.ai/reviews/STAGE-01-ARCHITECT-REVIEW-PACKET.md` | 供 Architect 审查的问题清单与证据位置，含「DSH 无法验证的事项」 |
| `.ai/reports/STAGE-01-REPORT.md` | 本文件 |
| `docs/architecture/ADR-0001-stage01-foundation.md` | 10 条决策记录（D1–D10）含理由、代价、替代方案 |
| `docs/design/UI_DESIGN_SYSTEM.md` | 状态「未定义」；记录当前实际使用的 token 与待所有者决定项 |
| `docs/product/README.md` | 产品文档索引与当前产品状态、未决问题 |

## 3. Files modified

| 文件 | 改动 | 说明 |
| --- | --- | --- |
| `README.md`（根） | 重写 | 原为 7 行标题 + 3 个链接。会话进行中发现该文件**从磁盘消失**（非 DSH 删除，见第 10.12 节），已按原意重建并扩展为状态表 + 文档索引 |
| `项目说明.md` | 定点更新 | 仅改「当前范围与交付物」「当前进度与验收」两节的状态与链接，保留原作者内容与 `One-click generation for Moments/` Git 仓库记录 |

**DSH 未修改**：`docs/产品与架构基线.md`、`docs/Stage-01-用户原始Prompt.txt`、`docs/Stage-01-Architect-Review备忘.md`。

**观察到但不是 DSH 所为的变更（并发写入）**：会话进行中，`docs/Stage-01-DeepSeek执行任务.md` 被删除、`docs/Stage-01-Architect-Review备忘.md` 被新增、`docs/产品与架构基线.md` 与 `项目说明.md` 被更新（时间戳 00:56:32–00:56:40，早于 DSH 写入的 01:06–01:09）。DSH 已据此把全部指向已删除文档的引用改为指向原始 Prompt + 基线 v0.2 + Review 备忘（涉及 `AGENTS.md`、`README.md`、`docs/product/README.md`、ADR-0001、`.ai/acceptance/STAGE-01.md`、`.ai/tasks/STAGE-01-TASKS.md`、`.ai/reviews/…`）。

## 4. Architecture decisions

完整版本见 `docs/architecture/ADR-0001-stage01-foundation.md`。摘要：

| # | 决策 | 关键理由 |
| --- | --- | --- |
| D1 | Deployment target **iOS 17.0** | `NavigationStack` 需 16.0，`@Observable` 与 `@Environment(Type.self)` 需 17.0 |
| D2 | **（Round 01 修正）** 两个状态对象使用 `@MainActor`，`RootView` 显式标注，状态测试方法级 `@MainActor` + `async` | 原决定「用文档约定代替」已被 Architect Round 01 否决：正确性不应依赖注释。修正与理由见 ADR-0001 D2 |
| D3 | 近期项目**只存内存**，界面明确标注 | 基线要求「宣称可恢复就必须真的持久化」，因此选择不宣称 |
| D4 | **零第三方依赖**，不引入数据库 | 依赖政策；数据量不需要数据库 |
| D5 | `.xcodeproj` 由脚本确定性生成 | Windows 无 Xcode；手写易错，脚本保证源码↔引用一致且可复现。**风险：从未被 Xcode 打开** |
| D6 | 路由只携带 `UUID`，页面自取当前状态 | 避免导航栈内模型副本过期 |
| D7 | 用一个真实 About 弹层验证 sheet 接缝 | 避免空抽象，同时满足「未来 sheet 可支持」 |
| D8 | UI 文案用**英文占位**，不做本地化 | 显示语言属产品/设计决定，DSH 不自行发明 |
| D9 | 只定义**被引用**的设计 token | 兼顾原始 Prompt 的 token 清单与「内容短、真实、目录按代码出现」的规则 |
| D10 | 文档中文、代码与 identifier 英文 | 与仓库既有文档及 Xcode/Apple 文档习惯一致 |

分层与边界：视图只展示与派发动作；`ProjectStore` 是唯一存储接缝；`Models/` 为纯 Foundation 值类型、不依赖 SwiftUI；未来处理与分析归 `Services/` 下的独立层，AI 只产出结构化数据、不直接控制渲染。

## 5. Dependencies used

- **App 运行期依赖：零。** 只使用 Apple 原生框架：`SwiftUI`、`Foundation`、`Observation`。未使用 UIKit、Core Image、Vision、Core ML、Metal、StoreKit。
- **工程依赖：零第三方包**（无 SPM、无 CocoaPods、无 Carthage）。
- **Windows 侧校验工具（不进 App 产物）**：
  - `tools/*.py` 只用 Python 标准库（`hashlib`、`pathlib`、`json`、`xml.etree`、`re`）。
  - 额外一次性语法校验使用了 `tree_sitter` + `tree_sitter_swift`（通过 `pip install` 到开发机环境）。**它们不是项目依赖**，未提交到仓库，也不被 `verify_project.py` 引用。

## 6. Tests added

| 文件 | 用例数 | 覆盖 |
| --- | --- | --- |
| `ProjectModelTests.swift` | 5 | 新项目初始状态与时间戳、重命名去空格并记录时间、拒绝空白名且不改状态、JSON 往返相等、编码键名契约 |
| `CanvasDocumentTests.swift` | 3 | 空文档默认画布、**golden JSON fixture 解码**（锁定字段名/嵌套/枚举原始值）、图层顺序在往返后保持 |
| `LayerModelTests.swift` | 9 | JSON 往返、默认可见未锁定且不透明、透明度钳制、**合法边界 0/1**、**非有限输入取默认值**、**解码拒绝负数/大于 1/非有限**、边界值可解码（后 6 项为 Round 01 新增） |
| `ProjectStoreTests.swift` | 7 | 创建并入列表、默认名唯一递增、显式名去空格/空白回退、未知 id 打开返回 nil、重命名更新存储、空白名与未知 id 重命名失败、近期列表新→旧（方法级 `@MainActor` + `async`，Round 01 修正隔离） |
| `AppNavigationModelTests.swift` | 5 | 初始为空、push/pop、根处 pop 无副作用、popToRoot、sheet 呈现与关闭（方法级 `@MainActor` + `async`，Round 01 修正隔离） |
| `Stage01SmokeUITests.swift` | 2 | 启动→点击 Create Project→编辑器占位页出现；返回导航回到 Home |

**合计：29 个单元测试 + 2 个 UI 测试 = 31 个测试用例。** 未为无逻辑的常量写镜像测试。

## 7. Tests executed

| 测试类别 | 是否执行 | 结果 |
| --- | --- | --- |
| Xcode 单元测试（23 个） | **未执行** | 本机无 macOS/Xcode/Swift，无法运行 XCTest |
| Xcode UI 测试（2 个） | **未执行** | 同上，且无 iOS 模拟器 |
| `xcodebuild build` | **未执行** | 同上 |

本机**实际执行**的替代性校验（详见第 8 节）：工程结构校验脚本与 tree-sitter Swift 语法解析。它们**不能替代编译与测试**。

## 8. Test results

### 8.1 实际执行的校验与真实输出

**命令 1：`python tools/generate_xcodeproj.py`**（exit 0）

```text
wrote MomentsStudio\MomentsStudio.xcodeproj\project.pbxproj
wrote MomentsStudio\MomentsStudio.xcodeproj\project.xcworkspace\contents.xcworkspacedata
wrote MomentsStudio\MomentsStudio.xcodeproj\xcshareddata\xcschemes\MomentsStudio.xcscheme
  MomentsStudio: 17 file references
  MomentsStudioTests: 5 file references
  MomentsStudioUITests: 1 file references
  objects: 95
```

**命令 2：`python tools/verify_project.py`**（exit 0）

```text
PASS: Stage 01 project structure verified (Xcode build/test NOT covered)
  - 95 objects, all references resolved
  - 23 file references exist on disk
  - Sources phases cover every Swift file exactly once: MomentsStudio=16, MomentsStudioTests=5, MomentsStudioUITests=1
  - build settings, product types and test-target wiring match the Stage 01 contract
  - shared scheme 'MomentsStudio' references all three targets
  - asset catalog JSON valid (3 files)
  - 22 Swift files parsed cleanly (1130 lines)
  - 2 UI-test identifiers resolve (editor.placeholder, home.createProject); 8 identifiers declared in the app
```

该脚本实际检查的内容：pbxproj 可解析且 rootObject 为 `PBXProject`；95 个对象 id 唯一且全部引用可解析；每个文件引用都能在磁盘上解析；每个 target 的 Sources phase 恰好覆盖该 target 目录下所有 `.swift`（无遗漏、无重复、无跨 target 重复）；`Assets.xcassets` 在 app Resources phase；三 target 的 productType、Bundle ID 唯一性、`BUNDLE_LOADER`/`TEST_HOST`/`TEST_TARGET_NAME`、app 的 `GENERATE_INFOPLIST_FILE` 与 `INFOPLIST_KEY_*`、project 级 `SDKROOT`/deployment target/`SWIFT_VERSION`；workspace 与 scheme XML 可解析且 scheme 的 Blueprint/Product 与 target 一致；资源 JSON 合法；源码编码/LF/无 Tab/括号配平（字符串与插值感知）；UI 测试查询的 accessibility identifier 在 App 源码中确实存在。

**命令 3：tree-sitter Swift 语法解析（一次性，非项目依赖）**（exit 0）

```text
TREE_SITTER_PARSED=22 WITH_ERRORS=0
```

首次运行时有 1 处报错（`Utilities/AppInfo.swift` 的 `as? String ?? "unknown"`）。经最小用例隔离确认：该 grammar 对「未加括号的条件转换后接 `??`」一律报错，对 `as? T`、`??`、加括号形式均正常。

```text
plain_as_question                  has_error=True
as_question_only                   has_error=False
coalesce_only                      has_error=False
parenthesised                      has_error=False
multiline_call_unparenthesised     has_error=True
```

为消除这一歧义（无论问题在 grammar 还是代码），已把 `AppInfo` 改写为私有辅助函数 `infoString(forKey:)`，使 `as?` 成为整个表达式。改写后 22/22 文件零错误。

### 8.2 明确未验证的部分

编译、链接、单元测试断言、UI 测试、应用启动、界面真实观感、真机/模拟器性能与 VoiceOver 行为 —— **全部未验证**。

### 8.3 Round 01 追加校验（2026-10-03，本机实际执行）

未安装新依赖（tree-sitter 为上一轮已安装的开发机工具，不是项目依赖），未修改任何 build/test 结论。

| 检查 | 命令 | 真实结果 |
| --- | --- | --- |
| 工程结构校验 | `python tools/verify_project.py` | PASS：95 对象引用完整；Sources 恰好覆盖 22 个 `.swift`（16/5/1）；scheme/target/构建设置/资源 JSON/括号与编码检查通过；22 个 Swift 文件解析干净（1359 行） |
| 工程生成幂等 | `python tools/generate_xcodeproj.py` 前后 SHA-256 | 一致，`project.pbxproj` 无漂移 |
| Swift 语法解析 | tree-sitter（开发机工具） | `TREE_SITTER_PARSED=22 WITH_ERRORS=0` |
| 序列化契约不变性 | 一次性脚本：比对 `CodingKeys`、fixture 内 opacity 字面值、`private(set)`、类级 `@MainActor` | PASS：键集与顺序 = `id, kind, transform, opacity, zIndex, isLocked, isHidden`；现有 JSON fixture 中唯一字面值 `0.8` 仍在 0…1 内，旧 fixture 仍可解码；`private(set) var opacity` 存在且无自由 `var opacity` |
| 绕过手段扫描 | 搜索 `@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency import` | 无匹配 |
| 写入口闭合 | 搜索 `\.opacity\s*=` | 仅出现在 `Layer.swift` 的 `init` 与 `init(from:)` 内部 |
| 测试数量 | 统计 `func test` | 29 个单元测试 + 2 个 UI 测试 |

仍**未验证**：编译、类型检查、actor 隔离诊断、XCTest / UI 测试、真实界面与手感。

## 9. Build result

**DSH 本机未构建。** 本机为 Windows（项目目录 `D:\朋友圈生成应用`），无 macOS、无 Xcode、无 Swift 工具链（已确认 `swift`、`swiftc`、`xcodebuild` 均不存在，仅有 Python 3.14 与 Node.js）。Architect 已另行在云端完成一次真实构建与测试（FIX-02 之前的 commit `49dc9f3`，证据见第 0.1 节），那是本次交付之外执行的结果。

- 本机不存在 `.app`、`.xcarchive`、`.ipa` 或任何构建产物。
- 工程文件在本机从未被 Xcode 打开，格式正确性仅由第 8.1 节的结构校验间接支持。
- **FIX-02 之后的新源码尚无任何构建或测试结果**；旧 commit 的通过结果不能用于新源码。

要得到构建结果，需要在 macOS 上执行：

```bash
cd MomentsStudio
xcodebuild build -project MomentsStudio.xcodeproj -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test  -project MomentsStudio.xcodeproj -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

替代路径：Xcode Cloud 或任意 macOS CI runner；也可让项目所有者把仓库复制到 Mac 上手动打开（注意路径含中文字符，若遇工具链问题请复制到纯 ASCII 路径）。

## 10. Known limitations

1. **DSH 本机（Windows）无法编译或测试**，且**FIX-02 之后的新源码尚无任何 Xcode 构建 / 测试结果**。可追溯的云端构建与 31 项测试通过记录（第 0.1 节）对应的是 FIX-02 之前的 commit `49dc9f3`，不能当作新源码的结果。
2. **工程文件未经 Xcode 验证。** 生成格式为 `objectVersion 56` / `compatibilityVersion Xcode 14.0`；若首次打开报错，可用 `tools/generate_xcodeproj.py` 重生成，或直接用 Xcode 新建工程后加入 `MomentsStudio/` 下的源码。
3. **无持久化。** 项目仅存于内存，退出即丢失；Home 已明确标注「仅本次运行」。`ProjectStore` 是未来接持久化的唯一接缝。
4. **App 图标为空占位**（`AppIcon.appiconset` 无图像文件）。可运行，但提审前必须替换；不排除归档/校验阶段出现图标相关告警。
5. **`Asset` 在运行期未被使用**：Stage 01 不导入照片，`Asset` 只被测试覆盖。图层与素材的引用关系（`Layer.assetID`）与素材库归属层级尚未定义。
6. **未实现原始 Prompt 示例中的 `Asset.metadata` 字段**：因 Stage 01 没有真实元数据需求，按「只建可解释字段、不提前承诺公共 API」的基线原则省略，已写入 `ARCHITECTURE.md` 第 5 节待 Review。
7. **序列化无版本号**：解码遇到未知的 `kind` 原始值会失败，没有未知枚举容错机制。
8. **Round 01 起：主 actor 隔离由编译器强制**（两个状态类 + `RootView`），但隔离相关的编译诊断在本机无法验证；同时 `Layer.opacity` 改为 `private(set)`，且**解码遇到非有限或越界的 opacity 会直接失败**（`dataCorruptedError`）——损坏存档不再被静默修正，这是预期行为而非 Bug。
9. **界面文案全为英文占位**，未做本地化；显示语言未定。
10. **产品身份为占位**：显示名 `Moments Studio`，Bundle ID `com.example.MomentsStudio`，版本 `0.1.0 (1)`。
11. **iPhone 仅竖屏**；target 声明支持 iPad（`TARGETED_DEVICE_FAMILY = 1,2`）但未做 iPad 专门布局，iPad 上未验收。
12. **根 `README.md` 在会话中一度从磁盘消失**（非 DSH 删除；同一目录内同时存在另一写入者与一个新建的 `One-click generation for Moments/` 空 Git 仓库，时间戳为会话开始时）。已按原意重建并扩展，内容含义未丢失，但**该文件的历史版本不可恢复**。
13. **并发写入者存在**：`docs/` 下多个文件在 DSH 工作期间被第三方修改/删除（见第 3 节）。若对方后续再次改动同一文件，可能覆盖本次更新。
14. **可访问性只做了代码层保证**（系统文本样式、44pt 触控高度、label/hint/identifier），未在模拟器上跑 VoiceOver 实测。
15. 未初始化 Git 仓库（项目根目录），因此本次交付没有提交历史可回溯。
16. **FIX-02 的对比度修正只经过源码级检查**：浅色/深色两种主题下的按钮与 footer 实际观感、以及 Dynamic Type 最大常规字号，均未在本机验证（本机无模拟器），必须在 Architect 的新源码云端构建/运行中确认。

## 11. Technical debt

| # | 债务 | 建议 |
| --- | --- | --- |
| 1 | `tools/generate_xcodeproj.py` 与 `verify_project.py` 是「无 Xcode 环境」的产物，且与 Xcode 直接管理工程存在双头风险 | 一旦在 Mac 上确立以 Xcode 管理工程，删除 `tools/`（并保留 `verify_project.py` 作为轻量 CI 校验，或一并删除） |
| 2 | `AppNavigationModel.pop()` / `popToRoot()` 目前没有生产调用点（只有测试） | 若 Architect 认为属未使用抽象，删除；否则保留并说明未来用途（如删除项目后回根） |
| 3 | `ProjectStore.recentProjects` 每次访问都做一次数组反转复制 | 数量增长后改为缓存或在写入时维护顺序 |
| 4 | 无 CI：没有 `xcodebuild` 与 `verify_project.py` 的自动化流水线 | Stage 02 建议接入 macOS CI，并把 `verify_project.py` 作为快速前置检查 |
| 5 | 文案内联在视图中，无字符串目录（`.xcstrings`） | 显示语言确定后统一迁移到 String Catalog |
| 6 | 测试未执行（本机），且 FIX-02 之后的新源码尚无任何 Xcode 构建/测试结果 | Architect 对新源码重新构建并运行同一批 31 项测试 |
| 7 | 工程设置中无 `DEVELOPMENT_TEAM`，真机运行需手动选择签名 | 属正常占位，提审前配置 |
| 8 | 无文档版本号/迁移机制 | Stage 02 定义 `schemaVersion` 与未知枚举容错 |

## 12. Questions requiring architecture review

1. ~~**状态取值**~~ **（Round 01 已裁定）**：Architect 明确 `READY_FOR_ARCHITECT_REVIEW` 合适；不得写 `WAITING_FOR_USER` / `APPROVED`。
2. ~~**`@MainActor`**~~ **（Round 01 已裁定并实施）**：两个状态类已加 `@MainActor`（D2 修正）。
3. **隔离覆盖复核**：本机无编译器，`@MainActor` 是否覆盖全部调用点（尤其 SwiftUI 闭包与 `@Bindable` 绑定）只能由首次 Xcode 构建确认。
4. **`Asset` 的去留**：Stage 02 之前是否保留？是否需要补 `metadata`？素材库应挂在 `Project` 还是 `CanvasDocument`？图层如何引用素材（`Layer.assetID`）？（Round 01 裁定：本阶段保留最小 `Asset`，不补，后续阶段前单独定契约。）
5. **序列化演进**：是否需要在 Stage 02 前加入 `schemaVersion` 与未知枚举容错？日期编码是否改为 ISO 8601？
6. **`Layer.opacity` 解码失败策略的后续影响**：Round 01 要求损坏存档一律失败，因此 Stage 02 的导入/持久化路径需要自己处理该错误（当前没有任何 UI 展示解码失败）。
7. **iOS 17 与 `@Observable`**：接受放弃 iOS 16，还是回退到 `ObservableObject`？（Round 01 已接受保留。）
8. **工程文件归属**：接受脚本生成的 `.xcodeproj`（D5），还是等 macOS 环境用 Xcode 重建？
9. **About 弹层**：保留（作为 modal 接缝验证）还是删除？
10. **`pop`/`popToRoot`**：保留还是删除（技术债 #2）？（Round 01 裁定：暂时保留。）
11. **显示语言**：界面继续英文占位，还是立即切换到中文/双语文案？
12. **App 图标占位**：是否需要在 Stage 01 就补一个临时图标以消除潜在告警？
13. **并发写入**：本目录同时存在其他写入者（`docs/` 多个文件被改动，另有 `One-click generation for Moments/` 空 Git 仓库）。请确认 DSH 的交付范围与写入边界，避免后续互相覆盖。

## 13. Exact instructions for the user to launch and test the app

> **前提：本 Stage 目前无法在本机（Windows）运行。** 要看到界面，需要一台 Mac（或 Xcode Cloud / macOS CI）。

### 13.1 需要准备什么

- 一台 macOS 设备，安装 **Xcode 15.4 或更高**（工程使用 iOS 17 SDK API）。
- 把整个项目目录复制到 Mac 上。若 `xcodebuild` 因路径中的中文字符（`朋友圈生成应用`）出现问题，请把 `MomentsStudio/` 复制到纯 ASCII 路径（例如 `~/Developer/MomentsStudio/`）再继续。
- 无需安装任何第三方依赖。

### 13.2 启动步骤（图形界面，最简单）

1. 在 Mac 上打开 `MomentsStudio/MomentsStudio.xcodeproj`。
2. 顶部 scheme 选择 `MomentsStudio`，设备选择任意 iPhone 模拟器（如 iPhone 16）。
3. 按 **⌘R** 运行。
4. 如果 Xcode 提示签名问题：选中 `MomentsStudio` target → Signing & Capabilities → Team 选择你自己的 Apple ID 团队（模拟器运行通常不需要）。
5. 如果工程文件无法打开或报格式错误：在终端执行 `python3 tools/generate_xcodeproj.py` 重新生成后再打开；若仍失败，请新建一个 iOS App 工程并把 `MomentsStudio/MomentsStudio/` 下的 `App/ Core/ Models/ Services/ Features/ DesignSystem/ Utilities/` 与 `Resources/Assets.xcassets` 拖入，测试目标加入 `MomentsStudioTests/` 与 `MomentsStudioUITests/` 两个目录。

### 13.3 启动步骤（命令行）

```bash
cd MomentsStudio
xcodebuild -list -project MomentsStudio.xcodeproj          # 确认 scheme 存在
xcrun simctl list devices available                        # 查看可用模拟器机型
open MomentsStudio.xcodeproj
```

构建与测试：

```bash
xcodebuild build -project MomentsStudio.xcodeproj -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'

xcodebuild test -project MomentsStudio.xcodeproj -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

（`name=iPhone 16` 需替换为本机实际存在的机型；`-only-testing:MomentsStudioTests` 可只跑单元测试。）

### 13.4 请按验收清单逐项检查

1. **App 启动成功** —— 无崩溃，进入首页。
2. **首页加载** —— 看到临时标题 `Moments Studio`；一个明显的 **Create Project** 按钮；下方 `Recent Projects` 区域显示「No projects yet.」及「仅本次运行」说明；右上角设置齿轮。
3. **Create Project 可用** —— 点击后立即进入编辑器占位页；首页近期列表随后应出现一条 `Untitled Project`。
4. **编辑器占位页打开** —— 顶部显示项目名，正文明确写着编辑功能未实现，并列出真实的项目状态（名称、创建时间、画布 `1080 × 1350`、图层 0、素材未导入）。
5. **返回导航可用** —— 左上角返回箭头回到首页；再次创建一个项目，两个项目名应为 `Untitled Project` 与 `Untitled Project 2`。
6. **基础交互响应及时** —— 点击、导航、列表更新无明显卡顿。
7. **无可见严重界面错误** —— 无错位、无空白页、无遮挡、浅色/深色模式都可读。
8. **设置页与 About 弹层** —— 首页右上角齿轮进入设置；点击「About Moments Studio」弹出 About 面板，`Done` 可关闭。
9. **模型与测试** —— 请确认 `xcodebuild test` 的输出：单元测试 23 个、UI 测试 2 个是否全部通过（这是 DSH 无法在本机验证的部分）。
10. **已知限制确认** —— 退出应用后近期项目消失，这是 Stage 01 的预期行为，不是 Bug。

### 13.5 请反馈的内容

- 构建/测试的真实输出（特别是任何编译错误或警告）。
- 工程是否一次打开成功。
- 上述 10 项检查的结果，以及任何视觉与手感意见。
- 第 12 节中需要裁定的问题。

收到反馈后：若有修改意见，本 Stage 标记 `CHANGES_REQUESTED` 并只修 Stage 01；项目所有者明确说「通过」前，DSH 不开始任何 Stage 02 工作。
