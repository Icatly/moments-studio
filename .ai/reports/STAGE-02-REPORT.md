# STAGE-02-REPORT.md

Stage 02 — Photo Import and Asset Pipeline
执行者：DeepSeek Harness（Implementation Engineer）
授权：项目所有者 2026-10-03“确认验收 继续下一阶段任务”（Stage 01 APPROVED）；执行依据 `.ai/tasks/STAGE-02-IMPLEMENT-01.md` 与 `docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md`
状态：`READY_FOR_ARCHITECT_REVIEW`（**未**通过 Architect Review，**未**交所有者验收；未开始 Stage 03）

> 本文件在 2026-10-03 被一次 PowerShell 文本替换破坏过编码（部分多字节字符末字节变成 `?`，无法还原），已按原文重写为 UTF-8；事实与计数以本版为准。同期扫描确认只有本文件受损，其他文档均为有效 UTF-8。

---

## 0. 修正汇总

| 批次 | 来源 | 项数 | 明细 |
| --- | --- | --- | --- |
| 实现中检查 | `.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md`（先 10 项，后扩展为 13 项） | 13 | §0.1 |
| Round 01 Review | `.ai/reviews/STAGE-02-ARCHITECT-ROUND-01.md` + `.ai/tasks/STAGE-02-ARCHITECT-FIX-01.md`（5 项，随后追加第 6 项） | 6 + 附加 `@MainActor` 要求 | §0.2 与 `.ai/reports/STAGE-02-FIX-01-REPORT.md` |

### 0.1 实现中检查（13 项）

| # | 问题 | 修正 |
| --- | --- | --- |
| 1 | `makeDerivatives` 中同名遮蔽会让第二次调用类型检查失败 | 私有辅助函数改名 `renderedThumbnail(from:maxPixelSize:)` |
| 2 | 派生图未做 8-bit sRGB 转换 | 新增 `convertToSRGB8`，两个派生图重绘进 8-bit sRGB（有 alpha 用 RGBA）；**original 仍为字节复制** |
| 3 | `decodeDerivative` 允许 `maxPixelSize * 2` 再全尺寸解码 | 改为 role 上限（320/2048）且与文件真实长边取 min 的受限解码 |
| 4 | 只有读派生图做 symlink 检查；写入/删除/清理未校验；manifest 与文件夹 ID 未比对 | 生成式路径统一严格校验；恢复要求 `manifest.project.id == 文件夹 UUID`；清理只处理 UUID 命名且是目录的未引用项 |
| 5 | `removePhoto` 未在 await 前占用 mutation 状态 | 单一 `mutationToken` 串行化 restore / 导入 / 移除；UI 用 `isBusy`/`isRemoving` 禁用 |
| 6 | `runBatch` 提交成功后仍丢弃返回的 package | 身份匹配时始终 `store.apply`；取消只阻止后续项 |
| 7 | 失败/取消后 staged 文件只在下次启动清理 | actor `discardStagedFile(at:)`，协调器在成功与失败/取消两条路径都调用 |
| 8 | 图片视图失败永久转圈；晚到结果可能覆盖新结果；预览显示原始 UTI | loading/loaded/failed + Retry；`Task.isCancelled` 丢弃晚到结果；预览显示 JPEG/PNG/HEIC |
| 9 | 测试缺少 HEIC 覆盖 | 真实 ImageIO 合成 HEIC 导入测试 |
| 10 | 未传 `selectionBehavior: .ordered`；Create/Import 仅在 loading 时禁用 | 加上 ordered；Create/Import 只在协调器 ready 时可用 |
| 11 | picker smoke 可空洞通过；点击可能命中禁用控件 | 断言 picker 真出现（Cancel 或 `Photos` 导航栏）、必须按下 Cancel、再确认可操作；新增 `waitUntilEnabled()` |
| 12 | `stageCopy` 同步复制、检查未前置 | `nonisolated async`，字节/取消检查前置，复制后再次检查取消，失败只删自建副本 |
| 13 | 库根创建被自身校验拒绝（真实缺陷）；库内跨项目 symlink 别名可污染别的项目 | 解析结果必须**恰好等于** `canonicalRoot/<生成式相对路径>`；空路径仅库根创建可用；清理要求 UUID **且**目录 |

### 0.2 Round 01 Review（FIX-01，6 项 + 附加要求）

| # | 修正 | 证据位置 |
| --- | --- | --- |
| 1 | `importing` 闭包返回 `PhotoFileTransfer` 自身 | `PhotoFileTransfer.transferRepresentation` |
| 2 | staging 目录必须解析为 `<canonical root>/Temporary`；复制后再次检查取消；清理只删精确匹配自有 staging 路径的文件 | `PhotoLibraryLocation.canonicalStagingDirectory` / `canonicalStagedFile` |
| 3 | `discardStagedFile(at:) -> [String]`，协调器追加 warnings | `PhotoLibrary`、`PhotoImportModel` |
| 4 | import/remove 入口与 `writeManifest` 前共享 package 校验；无 schema 降级 | `PhotoLibrary.validatePackageEntry`（三处） |
| 5 | 像素上限用 `multipliedReportingOverflow` 防溢出 | `PhotoLibrary.checkedPixelCount` |
| 6 | 合成 alpha fixture 必须真的有透明/半透明区域并断言派生图像素 alpha；补协调器 import-vs-removal 覆盖；允许注入窄文件加载闭包；关键 fixture/PNG/JPEG 失败必须失败而非 skip | `SyntheticImageFactory`（`context.clear` + alpha 0.5 band + `AlphaStats`）、`PhotoImportModel.PhotoFileLoader`、`PhotoImportModelTests` |
| 附加 | 访问主 actor 协调器/store 的新 UI 类型显式 `@MainActor` | `PhotoImportSection`、`PhotoPreviewSheet`、`DerivedImageView` |

明细见 `.ai/reports/STAGE-02-FIX-01-REPORT.md`。

---

## 1. Summary

按已批准的 Stage 02 架构实现了多照片导入管线：

- **系统选择器导入**：`PhotosPicker`（ordered 多选、`matching: .images`、`preferredItemEncoding: .current`、`selectionBehavior: .ordered`），不申请完整图库权限，不添加未使用的权限用途描述。
- **应用拥有的原始副本**：选择器文件在 Transferable `importing` 闭包返回前复制进应用自有暂存目录（`nonisolated async`，字节与取消检查前置），随后按字节复制为库内 original（不压缩、不重编码、不回写相册）；绝不把系统临时 URL 当作 original。
- **ImageIO 派生图**：thumbnail 长边 ≤320、preview 长边 ≤2048、不上采样；EXIF 1...8（含镜像）经 `CreateThumbnailWithTransform` 处理；两个派生图重绘为 8-bit sRGB；透明 PNG 保留像素 alpha（有测试断言），其余 JPEG q0.85；派生图不复制 GPS/完整 EXIF。
- **每张照片一个提交单元**：验证源 → 校验输入 package → 写 original 与派生文件 → 校验将要写入的 package → **原子写 manifest** → 才向调用方返回；提交前任何失败或取消都回滚该项新文件。
- **本地恢复**：`Projects/<projectID>/manifest.json` + `assets/<assetID>/`；启动异步恢复，逐包容错（损坏/未知版本只告警且保留文件），清理未引用素材与暂存残留，启动不解码原图。
- **最小原生 UI**：Editor 的 Import Photos、数量、缩略图网格、进度/取消、错误摘要、只读预览（`aspectFit`、Done）、带确认的移除；Home 区分“未保存的空项目”与“已保存项目”并显示恢复状态。

**关键事实**：本机（Windows）**没有 Xcode**，未编译、未运行 XCTest/UI 测试；本报告只包含 Windows 侧结构/语法/契约静态校验。Stage 01 的云端结果与 Appetize 包**不是** Stage 02 的证据。

## 2. Files created

### 2.1 新增模型（`MomentsStudio/MomentsStudio/Models/`）

| 文件 | 内容 |
| --- | --- |
| `ImportedPhoto.swift` | `ImportedPhoto`（`asset`、`thumbnailReference`、`previewReference`、`pixelWidth`、`pixelHeight`、`orientation`、`contentType`）显式 `CodingKeys`；`displayPixelSize` |
| `ProjectPackage.swift` | `ProjectPackage`（`schemaVersion`=1、`project`、`photos`）显式 `CodingKeys`；解码拒绝未知版本/非法尺寸/越界 orientation/重复 ID/超上限/越权引用；`validate(photos:projectID:)` 供解码与写入共用 |
| `PhotoLibraryPath.swift` | `PhotoLibraryError`（含 `.cancelled`）与纯字符串路径规则 |

### 2.2 新增服务（`MomentsStudio/MomentsStudio/Services/`）

| 文件 | 内容 |
| --- | --- |
| `PhotoLibrary.swift` | 非 MainActor actor：`restore()`、`importPhoto`、`removePhoto`、`loadDerivedImage`、`discardStagedFile -> [String]`；`PhotoLibraryLimits`（20/100 MiB/80 MP/320/2048）、`PhotoLibraryLocation`（Application Support 库根 + `Temporary` 暂存 + canonical 校验）；严格路径匹配、原子 manifest、回滚、清理、入口校验、溢出安全像素计数 |
| `PhotoDerivativeRenderer.swift` | ImageIO：`openSource`、`metadata`、`makeDerivatives`（不上采样 + sRGB 重绘）、`write`、`decodeDerivative`（受限解码） |
| `PhotoFileTransfer.swift` | `Transferable` 摄取：`FileRepresentation(importedContentType: .image)`，闭包内 `try await stageCopy(...)` 并返回自身；staging canonical 校验、检查前置、失败只删自建副本 |

### 2.3 新增导入 UI（`MomentsStudio/MomentsStudio/Features/PhotoImport/`）

| 文件 | 内容 |
| --- | --- |
| `PhotoImportModel.swift` | `@MainActor @Observable` 协调器；`restoreProjects()`、`importSelection(_:projectID:)`、`cancelImport(projectID:)`、`removePhoto(projectID:assetID:)`、`loadImage(reference:)`；单一 mutation 串行、batch/project 身份捕获、只应用已提交值；`PhotoFileLoader` 注入点（默认走真实 Transferable） |
| `PhotoImportSection.swift` | 导入入口、数量、空状态、进度与取消、错误摘要、缩略图网格；非 ready 时显示不可用提示 |
| `PhotoPreviewSheet.swift` | 只读预览（2048 派生图 aspectFit）、Done、确认移除（busy 时禁用）、人类可读格式名 |
| `DerivedImageView.swift` | 按需加载派生图（loading/loaded/failed + Retry，晚到结果丢弃） |

### 2.4 新增测试

| 文件 | 用例数 | 覆盖 |
| --- | --- | --- |
| `MomentsStudioTests/SyntheticImageFactory.swift` | — | 程序生成合成图（左右双色、EXIF orientation、**真实透明区 + 半透明带**）、`AlphaStats`（逐像素 alpha 分类）、半图平均取色；**无真实照片**；fixture/context/PNG/JPEG 失败一律为真实失败，仅 HEIC 编码不可用可 skip 且用例中已说明其不证明 HEIC 支持 |
| `MomentsStudioTests/TestGate.swift` | — | 确定性测试闸门（actor，无 `@unchecked Sendable`），支持“任务确已挂起”时的注入与取消 |
| `MomentsStudioTests/ProjectPackageTests.swift` | 8 | 编码键契约、往返、未知版本/非法引用/重复/超限 |
| `MomentsStudioTests/PhotoLibraryTests.swift` | 29 | 字节不变、派生边界、不上采样、方向与镜像、**PNG 像素 alpha 保留（含 fixture 自身透明性校验）与 JPEG 无 alpha**、JPEG/PNG/HEIC 导入、非图片/GIF 拒绝、字节/像素/张数上限、manifest 失败回滚、取消不提交、移除隔离、恢复顺序与重复恢复、缺失派生图告警、未知版本保留、文件夹 ID 不一致保留、未知条目保留、UUID 命名普通文件保留、库外 symlink 拒绝、库内跨项目别名拒绝、首次空根恢复、staging 归属与同名冒充、staging 别名拒绝、staging 取消、坏/未来包拒绝无写入、派生 API 拒绝 original |
| `MomentsStudioTests/PhotoImportModelTests.swift` | 6 | 恢复合并；**注入 loader 的完整批次（store==磁盘、staging 清空）**；**导入进行中移除被拒**；**第二批次被拒**；两次移除串行化；移除未知照片只报错 |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | 2 | 新项目导入入口/数量/空状态；picker 真实出现→按下 Cancel→回到可操作 Editor（**未执行**） |
| `MomentsStudioUITests/UITestSupport.swift` | — | `XCUIElement.waitUntilEnabled()` |

### 2.5 修改文件

`Services/ProjectStore.swift`（五个照片接缝，旧签名与 `init` 无 I/O 不变）、`Core/Navigation/AppRoute.swift`（`.photoPreview`）、`App/RootView.swift`（注入 + 异步恢复 + sheet）、`Features/Editor/EditorPlaceholderView.swift`（导入区 + 真实文案，保留 `editor.placeholder`）、`Features/Home/HomeView.swift`（已保存/未保存区分、恢复状态、ready 门控、照片数）、`Features/Settings/*`+`Utilities/AppInfo.swift`（按实际状态更新）、`tools/verify_project.py`（系统控件标签豁免表）。

## 3. Architecture decisions（均在已批准边界内）

| # | 决定 | 理由 |
| --- | --- | --- |
| A1 | `PhotoLibrary` 是非 MainActor actor | 复制/ImageIO/JSON 都不在 UI 线程；协调器只应用已提交值 |
| A2 | `limits` 以默认参数注入 | 测试可在不生成 100 MiB 文件的前提下验证上限；App 用 `.standard` |
| A3 | 取消用 `Task.isCancelled` → `.cancelled` | 不引入自定义取消抽象 |
| A4 | manifest 用 `Data.write(options: .atomic)` | 同目录临时文件 + rename |
| A5 | 派生扩展名由 alpha 决定，original 由探测类型决定 | 保留透明、original 保留接收格式 |
| A6 | 派生加载只接受派生引用且 role 受限 | 防止绕过加载原图 |
| A7 | 网格/预览按需加载 | 不预载 20 张 preview |
| A8 | 选择器 selection 绑定是导入 UI 状态（唯一局部例外） | 架构明确允许 |
| A9 | 按导航路径判断离开 Editor 才取消批次 | 预览 sheet 不会误触发取消 |
| A10 | `ProjectPackage.photoLimit` 作为共用上限来源 | 单一数字 |
| A11 | 路径规则 = “解析结果 == canonical root + 生成式相对路径” | 阻止库内跨项目别名 |
| A12 | staging 摄取是 `nonisolated async` 边界 | 复制不在主线程，不依赖回调线程假设 |
| A13 | 协调器允许注入窄文件加载闭包（仅内部、仅测试） | 使批次可确定性驱动；无协议/mock 仓储/生产测试按钮/第二调度器 |

## 4. Dependencies used

零第三方依赖（无 SPM/CocoaPods/Carthage）；一致性脚本确认 import 仅限批准的 Apple 框架：`Foundation`、`SwiftUI`、`Observation`、`CoreGraphics`、`ImageIO`、`UniformTypeIdentifiers`、`CoreTransferable`、`PhotosUI`（测试另用 `XCTest`）。未提高 deployment target（17.0）、未改工程设置、未关闭警告。`tools/*.py` 仅用 Python 标准库，不进 App 产物。

## 5. Tests added and executed

**新增 47 个单元测试 + 2 个 UI 测试；Stage 01 的 29 单元 + 2 UI 全部保留。合计 76 单元 + 4 UI（80 项）。**

| 类别 | 是否执行 | 结果 |
| --- | --- | --- |
| `tools/verify_project.py` | **已执行** | PASS（见第 6 节） |
| tree-sitter Swift 语法解析 | **已执行** | 39/39 文件 0 错误，5714 行 |
| 契约/修正一致性一次性脚本 | **已执行** | `STAGE02_CONFORMANCE: PASS`、`STAGE02_ALL_CORRECTIONS_CHECK: 19/19 PASS` |
| Xcode `xcodebuild build` | **未执行** | 本机无 macOS/Xcode |
| XCTest 76 个单元测试 | **未执行** | 同上 |
| UI 测试 4 个 | **未执行** | 同上，且无模拟器 |
| 真实多选导入、预览、移除、terminate/relaunch 恢复 | **未执行** | 需 Architect 在 macOS 模拟器/Appetize 实查 |

## 6. Actual check results（本机真实输出）

**`python tools/generate_xcodeproj.py`**：130 个对象、40 个文件引用（App 26 / 单元测试 10 / UI 测试 3）。

**`python tools/verify_project.py`**（exit 0）：

```text
PASS: Stage 01 project structure verified (Xcode build/test NOT covered)
  - 130 objects, all references resolved
  - 40 file references exist on disk
  - Sources phases cover every Swift file exactly once: MomentsStudio=26, MomentsStudioTests=10, MomentsStudioUITests=3
  - build settings, product types and test-target wiring match the Stage 01 contract
  - shared scheme 'MomentsStudio' references all three targets
  - asset catalog JSON valid (3 files)
  - 39 Swift files parsed cleanly (5714 lines)
  - 6 UI-test identifiers resolve (Cancel, Photos, editor.galleryEmpty, editor.photoCount, editor.placeholder, home.createProject); 27 identifiers declared in the app
  - system-owned control labels exempt from that check: Cancel, Photos
```

**tree-sitter**：`TREE_SITTER_PARSED=39 WITH_ERRORS=0`。

**一次性脚本（未提交）**：

- `STAGE02_ALL_CORRECTIONS_CHECK: PASS`（19/19，覆盖 13 项 + FIX-01 1–5 项 + `@MainActor` 附加要求）。注：早期脚本的 item-12 子检查用纯文本匹配 `"protocol"`，命中文档注释里的「actor, queue or protocol」误报过一次 FAIL；改为只统计真实类型声明后通过 —— 脚本自身缺陷。
- `ASYNC_CALLER_CHECK: PASS`（4 处 `try await PhotoFileTransfer.stageCopy`，0 处未 await）。
- `STAGE02_CONFORMANCE: PASS`。
- 静态核对：`XCTSkip` 仅出现在 HEIC/HEIF 编码不可用分支；alpha fixture 含 `context.clear` 与 `alpha: 0.5`；协调器含 `PhotoFileLoader` 注入点与 `loadPhotoFile` 调用。

### 6.1 真实行为设计（供 Review 对照代码）

- **顺序**：每批从当前已提交 package 开始，逐项串行；`photos` 即导入顺序；重复选择是独立副本。
- **提交**：original + thumbnail + preview 写完后才原子写 manifest；只有提交成功值才回到 MainActor。
- **失败/取消**：提交前失败或取消 → 删除该项素材目录、重抛、旧数据不变；单项失败不阻塞后续项；取消不是失败；提交后取消仍会 apply 结果（身份匹配时）。
- **移除**：先提交不含该照片的 manifest，再删除素材目录；清理失败只告警并在下次启动重试。
- **恢复**：逐包容错；损坏/未知版本/文件夹 ID 不一致只告警且不改写文件；缺失派生图仍列出；只清理 UUID+目录的未引用素材与暂存残留；启动不解码原图。
- **路径与暂存**：生成式路径解析结果必须等于 `canonicalRoot/<相对路径>`；`Temporary` 与其中文件同样精确校验；每项结束（成功/失败/取消）清理自有暂存副本，失败以 warning 呈现。
- **色彩与解码**：派生图为 8-bit sRGB 且保留像素 alpha（PNG）；派生加载以 320/2048 上限受限解码，不放大、不整图解码。
- **单写者**：restore / 导入 / 移除共享一个 mutation 占用；重复操作被拒绝，协调器测试（含注入 loader 的批次）覆盖该保护。

## 7. Known limitations

1. **没有本机编译/运行证据**：Windows 无 Xcode；76+4 个测试从未执行。首次 Xcode 编译仍可能暴露类型/API 标签问题（第 10 节）。
2. **无 Stage 02 可运行版本**：需 Architect 的 macOS 云端构建；Stage 01 的 Appetize 包不是 Stage 02 证据。
3. **真实选择器与真实照片未验证**：UI smoke 覆盖入口与 picker 打开/取消；真实多选导入、预览、移除、terminate/relaunch 恢复需模拟器手查。
4. **只接收静态图**：JPEG/PNG/HEIC/HEIF；RAW、动画 GIF、视频被拒绝或忽略。
5. **上限是工程策略**：20 张/项目、100 MiB/图、80 MP/图、320/2048 未在真机测量；串行处理，一次最多解码一张。
6. **派生图为 8-bit sRGB**：宽色域/HDR 源在缩略图与预览中失去该保真度（original 完整保留）。
7. **无内容去重**：同一文件可导入多次。
8. **缺失文件的照片仍列出**（带 warning），网格显示可重试占位。
9. **清理失败只告警**：下次启动重试，无重试计数。
10. **不支持 iCloud 离线素材**：选择器表示必须可读。
11. **未实现**：画布、图层、裁剪、手势、AI、拼贴、滤镜、抠图/贴纸、动画、导出、模板、账户、云、订阅、最终品牌视觉。
12. **未验证矩阵**：精确 iOS 17.0/Xcode 15.4、Xcode 26、真机、iPad、VoiceOver、大于 XXXL 的字号。
13. **HEIC 测试可能跳过**：若运行环境无法编码 HEIC，该用例以 skip 结束，并且**不能**据此声称 HEIC 支持已被验证；Architect 的实机检查需覆盖真实 HEIC 素材。
14. 英文占位文案、占位图标与临时 Bundle ID 仍然有效；`AppInfo.stageLabel` 已更新为 Stage 02。

## 8. Technical debt

| # | 债务 | 建议 |
| --- | --- | --- |
| 1 | 无“照片文件缺失”独立状态 | 后续阶段在恢复结果上增加逐照片状态 |
| 2 | 只允许一个批次（符合本阶段） | 并发导入前先评审 |
| 3 | 清理失败无重试计数 | 可加轻量计数 |
| 4 | `DerivedImageView` 无缓存 | 20 张内可接受；大素材前评估 |
| 5 | 网格固定 96pt | 待设计批准 |
| 6 | 无 CI：结构校验未接入流水线 | 与构建工作流一起跑 |
| 7 | `recentProjects` 每次反转数组 | 数量增长后处理 |
| 8 | 无文档迁移机制 | v2 之前定义 |
| 9 | 一次性校验脚本只在 TEMP | 可把关键不变量并回 `verify_project.py`（需 Architect 同意） |

## 9. Questions requiring architecture review

1. **API 标签确认**：`FileRepresentation(importedContentType:)`、`PhotosPicker(selection:maxSelectionCount:selectionBehavior:matching:preferredItemEncoding:label:)`、`PhotosPickerItem(itemIdentifier:)`、`nonisolated` 静态成员 —— 本机无法编译确认；如需最小改写（语义不变）请授权。
2. **`limits` 注入**与**`PhotoFileLoader` 注入**（内部测试接缝）是否认可。
3. **`Data.write(options: .atomic)`** 作为原子提交是否认可。
4. **移除时清理失败只告警**是否满足完成标准。
5. **恢复时仍列出缺失文件的照片**是否可接受。
6. **旧包目录只告警不清理**是否合适。
7. **`ProjectStore.restore` 顺序语义**是否要全局按 createdAt 排序。
8. **Import Photos 视觉**是否要与 Create Project 对齐（当前系统默认样式）。

## 10. Risk list for the first Xcode compile（诚实披露）

1. `FileRepresentation(importedContentType:shouldAttemptToOpenInPlace:importing:)` 标签名。
2. `PhotosPicker` 含 `selectionBehavior` 的重载。
3. `PhotosPickerItem(itemIdentifier:)` 在目标 SDK 的可用性。
4. `DerivedImageView` 的 `@ViewBuilder let placeholder` 成员初始化写法。
5. `Image(decorative:scale:)` 与 `.task(id:)` 组合。
6. `CGImageSourceCopyPropertiesAtIndex` → `[CFString: Any]` 的 `as? Int`/`as? Bool`。
7. 8-bit sRGB 重绘的 `CGContext(bitmapInfo:)` 组合。
8. 回滚测试假设“目标是目录时 `Data.write(.atomic)` 必失败”。
9. `TestGate`（actor + `Task.yield()`）在测试中的确定性。
10. symlink 测试依赖 `FileManager.createSymbolicLink`。
11. `nonisolated`（结构体静态成员）的编译器接受度。
12. UI 测试的 `NSPredicate`/`XCTNSPredicateExpectation` 与系统 picker 元素查询。

## 11. Exact manual acceptance steps（给 Architect / 所有者）

1. macOS（Xcode 15.4+）执行 `xcodebuild test -project MomentsStudio/MomentsStudio.xcodeproj -scheme MomentsStudio -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'`，确认编译零错误、76 单元 + 4 UI 测试通过，并记录真实警告。
2. 用 `tools/generate_stage02_photo_fixtures.py` 生成合成 PNG（竖/横/透明）放入模拟器相册；另需一张真实 HEIC 素材（HEIC 自动用例可能跳过，不能替代实机验证）。
3. Create Project → Import Photos → 一次多选 3 张：核对顺序、数量、进度与取消。
4. 点缩略图 → 只读预览 → Remove 确认 → 网格与数量同步减少；确认相册原图未被修改。
5. 追加导入第 4 张；返回 Home 核对项目行照片数；重开项目照片仍在。
6. terminate 后 relaunch：项目与照片恢复（Home 显示 loading → 正常）。
7. 导入中 Cancel / 返回：已完成项保留、剩余停止、无错误摘要。
8. 浅色/深色 + 最大常规字号检查导入区、网格、预览、移除确认与 44pt 触控。
9. 复核 `Application Support/MomentsStudio/Projects/<uuid>/{manifest.json,assets/<uuid>/{original.*,thumbnail.*,preview.*}}`，确认无绝对路径、暂存目录为空。
10. 受控失败（可选）：把 manifest 换成目录后导入一次，确认失败且旧数据保持。

**结论**：Stage 02 实现完成、两批 Architect 记录（13 项 + FIX-01 六项）全部落地，但**未经编译、测试或运行验证**；交付止于 `READY_FOR_ARCHITECT_REVIEW`，Stage 03 未开始。
