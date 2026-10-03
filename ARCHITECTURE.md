# ARCHITECTURE.md

现存代码仍为Stage01基础框架（所有者2026-10-03已批准）。Stage02照片导入/素材管线执行已授权，设计见 [Stage02架构](docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md)，尚未实现；下文现存结构与字段仍适用于Stage01。新增包模型、文件actor、编排状态和只读预览路由严格按Stage02设计实施，不提前改现有编码契约。

## 1. 当前范围

已实现（源码与工程）：SwiftUI 应用外壳（Home / 编辑器占位页 / 设置占位页）、导航、最小可序列化模型、内存项目状态、测试源码与工程文档。
**运行已验证的范围**：Architect 在macOS云端对源码 `6e8f449` 使用Xcode16.4 / iOS18.5执行编译及29个单元、2个UI测试（零失败），安装启动成功；并在Appetize iPhone14Pro / iOS17.2检查外壳交互、浅/深色与深色XXXL。Windows本机仍无Xcode；精确iOS17.0 / Xcode15.4、Xcode26和真机性能未验证。证据见 [.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md](.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md)。Stage01已由所有者明确批准；Stage02当前IMPLEMENTING，尚无构建结果。
未实现：照片导入、图像处理、拼贴、抠图/剪影/贴纸、AI 分析、滤镜/调色、动画、视频、导出、云、账户、付费、最终视觉。

## 2. 应用分层与目录

工程：`MomentsStudio/MomentsStudio.xcodeproj`（3 个 target：App、单元测试、UI 测试）。App 源码根为 `MomentsStudio/MomentsStudio/`。

| 目录 | 职责 | Stage 01 实际内容 |
| --- | --- | --- |
| `App/` | 应用入口与根视图，唯一把状态接到导航容器的地方 | `MomentsStudioApp`、`RootView` |
| `Core/` | 与具体功能无关的应用级机制 | `Navigation/AppRoute`、`Navigation/AppNavigationModel` |
| `Models/` | 可序列化的领域数据，纯 Foundation，不依赖 SwiftUI | Stage 01：`Project`、`CanvasDocument`、`Asset`、`Layer`；Stage 02 新增 `ImportedPhoto`、`ProjectPackage`、`PhotoLibraryPath`（含 `PhotoLibraryError`） |
| `Services/` | 状态、I/O 与图像处理的归属地 | `ProjectStore`（内存 + 已提交快照）；Stage 02 新增 `PhotoLibrary`（actor：文件事务、派生、恢复）、`PhotoDerivativeRenderer`（ImageIO）、`PhotoFileTransfer`（Transferable 摄取 + 应用自有暂存） |
| `Features/` | 各屏幕的 SwiftUI 视图 | `Home/HomeView`、`Editor/EditorPlaceholderView`、`Settings/SettingsPlaceholderView`、`Settings/AboutSheet`；Stage 02 新增 `PhotoImport/`（`PhotoImportModel`、`PhotoImportSection`、`PhotoPreviewSheet`、`DerivedImageView`） |
| `DesignSystem/` | 临时设计 token 与最小组件 | `DesignTokens`、`InfoRow` |
| `Utilities/` | 无状态小工具 | `AppInfo`（临时产品身份） |
| `Resources/` | 资源目录 | `Assets.xcassets`（AppIcon / AccentColor 占位） |

规则：`Models/` 与服务层不得 import SwiftUI；视图不得直接操作存储或做图像处理。

## 3. 状态流

```text
RootView（@State 持有三个对象）
  ├─ AppNavigationModel  → path: [AppRoute]、sheet: SheetRoute?
  ├─ ProjectStore        → projects: [Project]、photoCollections: [UUID: [ImportedPhoto]]、savedProjectIDs
  └─ PhotoImportModel    → 恢复状态、导入进度/错误/警告（@MainActor 编排）
        ↓ await
     PhotoLibrary（actor：文件事务、ImageIO 派生、manifest 读写、清理）
        ↓ 只回传已提交的 ProjectPackage
     ProjectStore.apply(_:) / restore(_:)
        ↓ .environment(...)
HomeView / EditorPlaceholderView / SettingsPlaceholderView / AboutSheet / PhotoPreviewSheet
```

- 视图通过 `@Environment(Type.self)` 读取；唯一的写入口是用户动作（创建项目、重命名、导入、移除、push/present）。
- `ProjectStore` 仍是状态唯一接缝，但**文件真相在 `PhotoLibrary`**：协调器只把已提交的 package 交给 `apply(_:)`，UI 不会先显示成功再落盘。
- `PhotoLibrary` 故意不是 `@MainActor`：复制、ImageIO 与 JSON 写盘都不在 UI 线程；主线程只编排与显示。
- 主 actor 隔离：`ProjectStore` 与 `AppNavigationModel` 都是 `@MainActor` 类，由编译器强制主线程访问。所有会触达这两个对象的视图（`RootView`、`HomeView`、`EditorPlaceholderView`、`SettingsPlaceholderView`）以及构造 `RootView` 的 `MomentsStudioApp` 入口都**显式**标注 `@MainActor`，不依赖「SwiftUI 会把整个 `View` 类型推断为主 actor」这一 SDK 层细节；`InfoRow`、`RecentProjectRow`、`AboutSheet` 是纯展示组件，只读不可变的 `AppInfo`/`Project` 值，不需要标注。测试在**方法级**使用 `@MainActor` + `async`，不改动 `XCTestCase` 子类的隔离，也不使用 `@unchecked Sendable`、`nonisolated(unsafe)` 等绕过手段。

## 4. 导航

- `NavigationStack` 只由 `RootView` 绑定；`AppRoute`（`editor(projectID:)`、`settings`）是 push 目的地，`SheetRoute`（`about`、`photoPreview(projectID:assetID:)`）是模态目的地。
- 路由只携带**标识符**，不携带模型值：目标页面从 `ProjectStore` 读取当前状态，避免显示过期副本。
- 没有引入路由框架：屏幕用 `switch` 足够；新增屏幕只需要加一个 `case`。
- 未来模态（模板、导出等）加在 `SheetRoute`，不引入各页面私有的 presentation flag。唯一的局部例外是系统照片选择器的 selection 绑定，它属于导入 UI 状态而不是应用导航。

## 5. 核心模型与序列化契约

全部为 `Codable + Equatable + Hashable` 值类型；`CanvasDocumentTests` 中的 JSON fixture 固定了字段名与枚举原始值。当前字段集是**受 Review 控制的 Stage 01 契约**，不是「以后永不改变」的承诺：持久化与迁移策略尚未实现、也尚未决定，任何字段增删改名或编码策略变化都需要 Review。

| 类型 | 字段 |
| --- | --- |
| `Project` | `id`、`name`、`createdAt`、`updatedAt`、`document` |
| `CanvasDocument` | `id`、`canvasSize`、`layers`（叠放规则见下） |
| `CanvasSize` | `width`、`height`（Double，画布单位，1 单位 = 导出时 1 像素） |
| `Layer` | `id`、`kind`、`transform`、`opacity`、`zIndex`、`isLocked`、`isHidden` |
| `LayerTransform` | `translationX`、`translationY`、`scale`、`rotationRadians` |
| `Asset` | `id`、`kind`、`localReference`（沙盒相对路径，绝不存绝对 URL） |
| `ImportedPhoto`（Stage 02） | `asset`、`thumbnailReference`、`previewReference`、`pixelWidth`、`pixelHeight`、`orientation`（EXIF 1...8）、`contentType`（ImageIO 探测 UTI）；`id` 派生自 `asset.id` |
| `ProjectPackage`（Stage 02） | `schemaVersion`（当前 1）、`project`、`photos`（导入顺序） |

### 5.0 Stage 02：照片库属于包，不属于创作文档

素材库放在 `ProjectPackage` 里，`Project` 只保留创作文档。这样导入阶段不必提前决定画布/图层结构，也不新增 `Layer.assetID`。

磁盘布局（库根 = `Application Support/MomentsStudio/`，本地持久数据而非 Caches）：

```text
Projects/<projectUUID>/manifest.json
Projects/<projectUUID>/assets/<assetUUID>/original.<detectedExtension>
Projects/<projectUUID>/assets/<assetUUID>/thumbnail.<jpgOrPng>
Projects/<projectUUID>/assets/<assetUUID>/preview.<jpgOrPng>
Temporary/<uuid>.<ext>          # 应用自有暂存：选择器文件在被接管前的副本
```

- 所有引用都是**库根相对路径**，恢复时重算沙盒 URL；不序列化绝对 URL、picker item、图片对象、相册标识或完整 EXIF/GPS。
- 路径规则由 `PhotoLibraryPath` 单一实现，同时用于写入与解码校验：只接受生成的 `Projects/<uuid>/assets/<uuid>/<original|thumbnail|preview>.<ext>`，拒绝绝对路径、`..`、跨项目/跨素材引用与类型不符。
- **每张照片是一个提交单元**：验证源 → 写 original 与派生 → 校验 package → 原子写 manifest → 才返回已提交值；提交前失败或取消回滚该项文件，旧 manifest 与已导入照片不变。
- 移除先提交不含该照片的 manifest，再清理素材目录；清理失败只告警并在后续启动重试。
- 恢复逐包容错：损坏或未知 `schemaVersion` 只告警并**保留文件**，不静默重置；缺失派生图仍列出该照片；只清理可验证包中未被引用的素材目录与 `Temporary/` 残留，启动不解码原图。
- 派生图由 ImageIO 生成：thumbnail 长边 ≤320、preview 长边 ≤2048、不上采样、EXIF 1...8 含镜像按显示方向处理、透明 PNG 保留 alpha、其余 JPEG 0.85。

### 5.1 叠放语义

Stage 01 只**定义语义**，不含渲染器、排序 API 或任何相关功能：

- `Layer.zIndex` 越大越靠前；
- `zIndex` 相同的图层由 `layers` 数组位置决定次序，**数组越后越靠前**；
- `layers` 按写入原样存储。数组的 Codable 往返测试验证的是**存储顺序保持**，不是渲染结果。

### 5.2 `Layer.opacity` 不变量

字段名与编码形状不变，但写入口被封闭（`private(set)`，只能经 `init(...)` 或 `setOpacity(_:)`）：

- **程序化输入**：非有限值（`NaN`、`±Infinity`）取 `Layer.defaultOpacity`（1）；其余越界值取最近边界 0 或 1。
- **解码**：持久化的 `opacity` 必须有限且落在 `0...1`，否则抛 `DecodingError.dataCorruptedError`。损坏的存档不会被悄悄修正，也不会被静默裁剪。

有意省略的字段（等 Stage 02+ 有了真实需求再定，需 Review）：`Asset` 的几何/元数据、图层与素材的引用关系（`Layer.assetID`）、素材库放在 `Project` 还是 `CanvasDocument`、文档版本号与未知枚举值的容错。当前**解码遇到未知 `kind` 会失败**，属已知限制。

日期编码使用 `JSONEncoder` 默认策略（`deferredToDate`）；持久化落地时是否改为 ISO 8601 由 Architect 决定。

## 6. 未来扩展位置（尚未实现）

照片导入与素材管线已在 Stage 02 实现（见 5.0 节），其余仍未实现：

| 能力 | 归属 | 约束 |
| --- | --- | --- |
| 图像处理（裁剪、切图、批量调色） | 独立于视图的处理层，运行在非主线程 | 不 import SwiftUI；输入输出为模型与素材引用，不直接改视图；Stage 02 的 `PhotoLibrary`/`PhotoDerivativeRenderer` 是当前位置 |
| AI 分析 | `Services/` 下的分析器（PhotoAnalyzer），输出结构化测量 + 置信度 + 失败原因 | 不产像素、不直接控制渲染；失败可回退 |
| 布局/风格决策 | CompositionPlanner，输出可序列化提案 | 不覆盖用户锁定的编辑；提案被接受后成为普通项目数据 |
| 编辑器渲染 | `Features/Editor/` + 独立确定性渲染引擎 | 同一份文档几何数据分别消费预览素材与原始素材；视图截图不能作为导出结果 |
| 导出 | 独立导出管线（可评估 `ImageRenderer`，注意其对 UIKit 混合内容的限制） | 导出在后台、使用原始素材 |

## 7. UI 与处理分离

- 视图只表达「显示什么」和「用户做了什么」；不包含图像算法、不持有大图缓存。
- 处理层以纯输入/输出形式存在，可脱离 SwiftUI 单元测试。
- AI 的产出是数据，不是绘制指令，因此可被用户逐项修改，也可被重新生成而不静默覆盖用户改动。

## 8. 未来性能策略

- 预览与导出走同一份几何数据、不同的素材分辨率；编辑器只用预览素材。
- 清单/缩略图与全尺寸解码分离，按需解码、及时释放，避免同一张图多份副本。
- 重计算离开主线程；导入、分析、渲染需要可取消与进度反馈。
- 原图只读：任何调整以「参数 + 引用」表达，不写回原文件。
- Stage 02 暂定工程上限：每项目 20 张、每文件 100 MiB、每图 80 MP、串行处理且一次最多解码一张；这些是工程策略，**尚未**用真机内存/耗时数据验证，需要在实际素材上测量后调整。

## 9. 工程与验证

- 构建/测试命令见 [MomentsStudio/README.md](MomentsStudio/README.md)。
- `tools/generate_xcodeproj.py` 由源码目录生成 Xcode 工程文件（本机无 Xcode 的替代方案）；`tools/verify_project.py` 校验工程文件引用完整性、Sources 覆盖、构建设置、scheme 与源码静态语法。
- 这两个脚本是 Windows 侧工程工具，不进 App 产物，不是 App 依赖。

## 10. 已知架构缺口（需 Architect 决定）

1. `Asset` 与 `Layer` 的引用关系（`Layer.assetID`）仍未定义；Stage 02 已决定素材库归属 `ProjectPackage`，画布层引用留到画布阶段。
2. 文档版本号与未知枚举容错策略：Stage 02 引入了 `ProjectPackage.schemaVersion`（当前 1）与拒绝未知版本的规则，但**迁移机制本身仍未设计**；Stage 01 的 `Layer.kind` 未知值仍会解码失败。
3. iOS 最低版本 17.0 与 `@Observable` 的取舍（Round 01 已接受，保留）。
4. 应用显示语言（当前所有 UI 文案为英文占位）。
5. 脚本生成工程文件的正式可用性，最终由 Xcode 实际打开/构建验证。
6. Stage 02 待裁定：恢复时“文件缺失的照片仍列出”、清理失败仅告警、`PhotoLibrary.init` 的 limits 测试注入（见 `.ai/reviews/STAGE-02-REVIEW-PACKET.md` 第 7 节）。

已解决、不再列为缺口：`ProjectStore` / `AppNavigationModel` 的主 actor 隔离（Round 01 起由 `@MainActor` 强制）。
