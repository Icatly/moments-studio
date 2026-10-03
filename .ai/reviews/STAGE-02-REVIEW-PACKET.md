# Stage 02 架构 Review 包（供 ChatGPT Architect 使用）

本文件只列出**需要审查的问题**与**证据位置**，不下结论。DSH 未执行的部分已明确标注。

## 0. 请优先确认的前提

1. **无编译/运行证据**：本机为 Windows，无 macOS/Xcode。76 个单元测试 + 4 个 UI 测试**从未执行**；代码只经过工程结构、tree-sitter 语法与契约一致性静态校验。请勿把 Stage 01 的云端结果或 Appetize 包当作 Stage 02 证据。
2. **Stage 02 可运行版本不存在**：需要 Architect 在 macOS/云端对新源码构建。
3. **状态**：`.ai/acceptance/STAGE-02.md` 为 `READY_FOR_ARCHITECT_REVIEW`，9 项所有者判断全部未勾选，`User Decision: PENDING`。
4. **本机实际输出**见 `.ai/reports/STAGE-02-REPORT.md` 第 6 节。

## 1. 范围与排除项

- [ ] 是否只实现了架构允许的范围（导入、original 副本、派生图、包持久化与恢复、导入/网格/只读预览/移除 UI）？有没有越界实现（画布、图层、裁剪、AI、拼贴、滤镜、抠图、动画、导出、云、账户、订阅、品牌视觉）？
- [ ] `Project` / `CanvasDocument` / `Asset` / `Layer` / `LayerTransform` / `CanvasSize` 的字段、日期策略、枚举原始值与旧 fixture 是否完全未变？
- [ ] 是否新增了未批准的依赖、包、协议、缓存或任务队列？

证据：`MomentsStudio/MomentsStudio/**`、`ARCHITECTURE.md`、第 6 节一致性脚本输出。

## 2. 数据契约与序列化

- [ ] `ImportedPhoto` 的 7 个编码键与含义是否与架构文档表格一致（`asset`、`thumbnailReference`、`previewReference`、`pixelWidth`、`pixelHeight`、`orientation`、`contentType`）？`id` 派生自 `asset.id` 是否可接受？
- [ ] `ProjectPackage`（`schemaVersion`=1、`project`、`photos`）显式编码键是否认可？未知 `schemaVersion` 抛错并保留文件的行为是否符合预期？
- [ ] 解码校验范围是否恰当：非正尺寸、orientation 越界、重复照片 ID、超过 20 张、引用不属于本项目/素材？
- [ ] 路径规则（仅生成式路径；拒绝绝对路径、`..`、跨项目、跨素材、类型不符、缺扩展名）是否过严或过松？特别关注：`original` 允许任意字母数字扩展名（由 ImageIO 探测决定），派生图只允许 jpg/jpeg/png。
- [ ] 是否接受“`Asset.localReference` 存 original、派生图各存自己的引用”这一划分，以及不新增 `Layer.assetID`？

证据：`Models/ImportedPhoto.swift`、`Models/ProjectPackage.swift`、`Models/PhotoLibraryPath.swift`、`MomentsStudioTests/ProjectPackageTests.swift`。

## 3. 文件归属与事务

- [ ] 磁盘布局是否符合架构（`Projects/<projectID>/manifest.json`、`assets/<assetID>/{original.*,thumbnail.*,preview.*}`，库根 `Application Support/MomentsStudio`，暂存 `Temporary/`）？
- [ ] **提交顺序**是否满足“先文件、后原子 manifest、才返回已提交值”（见 `PhotoLibrary.importPhoto` 与协调器只调用 `store.apply(result.package)`）？
- [ ] **回滚**：提交前失败/取消是否只删除该项新文件、绝不改动旧 manifest 与已导入照片？
- [ ] **移除**：是否先提交不含该照片的 manifest、再清理素材目录；清理失败是否只告警（不恢复记录）？
- [ ] **恢复**：损坏/未知版本是否只 warning、保留文件、不静默重置；缺失派生图是否仍列出照片；是否只清理未被引用的素材目录与应用自有暂存残留；启动是否避免解码原图？
- [ ] 符号链接逃逸检查（`resolvingSymlinksInPath` + 根前缀）是否足够？是否遗漏了其他逃逸面（例如硬链接、非 UUID 目录名）？
- [ ] `Data.write(options: .atomic)` 作为原子提交是否被接受（替代 `replaceItemAt`）？

证据：`Services/PhotoLibrary.swift`、`MomentsStudioTests/PhotoLibraryTests.swift`（回滚、取消、移除、恢复、清理用例）。

## 4. 图像管线与性能

- [ ] 是否避免整文件 `Data`/`UIImage` 加载（`CGImageSource` + `CGImageSourceCreateThumbnailAtIndex`）？派生写入是否只写一张？
- [ ] 320/2048 上限、**不上采样**（上限再与源长边取 min）与 EXIF 1...8 处理（含镜像）是否正确？镜像是否有真实像素证据（半图平均取色）而非只看元数据？
- [ ] 透明 PNG 与 JPEG 0.85 的选择是否合理？是否确认未把 GPS/完整 EXIF 复制进派生图（只写压缩质量）？
- [ ] 重工作是否确实不在主线程（`PhotoLibrary` actor；MainActor 只编排与显示）？
- [ ] 每项 `autoreleasepool`、串行处理、取消检查点（入口/写后/提交前）是否足够？
- [ ] `loadDerivedImage` 是否无法成为加载 original 的旁路（只接受派生引用 + 尺寸上限）？
- [ ] 是否有任何 Stage 02 需要额外优化的证据（本阶段无批量解码/无原图渲染）？

证据：`Services/PhotoDerivativeRenderer.swift`、`Services/PhotoLibrary.swift`、`Features/PhotoImport/DerivedImageView.swift`。

## 5. 状态与 UI

- [ ] `ProjectStore` 新增是否严格限于批准的接缝？`init` 是否仍无文件 I/O、Stage 01 API 与测试是否保持？
- [ ] `restore(_:)` 的顺序语义（内存项目留在前部、恢复包按 createdAt 追加）是否可接受？是否会破坏“近期=创建顺序”？
- [ ] `PhotoImportModel` 的单一批次、batchID/projectID 捕获、晚到结果不写入其他项目、取消语义（已提交保留、取消不算失败）是否正确？
- [ ] Home 的 loading/retry/warning 与“恢复完成前禁用 Create/Import”是否足够防止状态竞争？
- [ ] 未保存空项目 vs 已保存项目的文案是否真实无误导？
- [ ] 系统 `PhotosPicker` 的 selection 绑定作为局部例外是否可接受？不申请完整图库权限、未添加未使用的用途描述是否成立（当前 Info.plist 未声明任何权限键）？
- [ ] 离开 Editor 时按导航路径判断取消（预览 sheet 不取消）是否可靠？是否应改为不取消？
- [ ] UI 是否仍为原生中性样式、保留 FIX-02 的按钮取色与两处 footer 修复、未引入品牌设计？

证据：`Services/ProjectStore.swift`、`Features/PhotoImport/*`、`Features/Home/HomeView.swift`、`Features/Editor/EditorPlaceholderView.swift`、`Core/Navigation/AppRoute.swift`、`App/RootView.swift`。

## 6. 测试真实性

- [ ] 新增 38 单元 + 2 UI 测试是否覆盖架构点名的类别：包/ImportedPhoto 编码键与往返、未知版本/非法引用、JPEG/PNG/HEIC 派生尺寸与方向/alpha、原图字节不变、跨项目隔离、失败回滚、取消、顺序、项目容量、恢复/重复恢复、移除与文件清理？是否还覆盖了 INFLIGHT-NOTE-01 追加的风险（symlink 逃逸、manifest 与文件夹 ID 不一致、未知条目不被清理、staging 归属、并发 mutation 串行化）？
- [ ] 合成图是否完全程序生成（无真实照片、无网络、无生产 UI 测试数据）？fixture 写入是否只在测试临时目录？
- [ ] 断言是否存在“看起来通过但没有验证行为”的问题（例如只断言文件存在而不断言字节/尺寸）？请特别检查回滚测试与镜像测试。
- [ ] **这些测试从未执行**；请检查断言逻辑本身是否正确，并注意第 10 节的 API 风险清单。

证据：`MomentsStudioTests/*`、`MomentsStudioUITests/Stage02ImportUITests.swift`。

## 7. 已披露的实现取舍（请裁定）

1. `PhotoLibrary.init(rootURL:limits:)` 的 `limits` 注入（测试接缝，默认 `.standard`）。
2. 取消只依赖标准 `Task.isCancelled`（不引入自定义取消协议）。
3. `ProjectPackage.validate` 在写入前与解码时共用（保证“写不进去的就解不出来”）。
4. 恢复时保留“文件缺失”的照片并给出 warning。
5. 网格固定 96pt、Import 按钮使用系统默认样式（避免重演对比度问题，等待设计批准）。
6. `tools/verify_project.py` 新增系统控件标签豁免表（`Cancel` 等）并在输出中显式列出豁免项；这是对 Stage 01 检查的**收紧+透明化**，不是绕过。

## 8. DSH 无法验证的事项（针对当前源码；请勿视为已通过）

| 事项 | 原因 |
| --- | --- |
| 编译、类型检查、actor 隔离、API 标签 | 本机无 Xcode |
| 59 单元 + 4 UI 测试通过 | 同上 |
| 真实选择器多选、真实照片导入、预览、移除 | 需模拟器与相册素材 |
| terminate/relaunch 恢复、相册原图未被修改 | 需真机/模拟器实查 |
| 大图批次耗时/内存、取消反应、浅深色与最大字号观感 | 同上 |
| iPad、VoiceOver、真机性能 | 未纳入本阶段证据 |

## 9. 建议的 Review 顺序

1. 数据契约（第 2 节）——一旦字段或校验要改，测试与实现要一起改。
2. 事务与回滚（第 3 节）——最难回退的风险点。
3. 图像管线正确性（第 4 节）。
4. 状态与 UI（第 5 节）。
5. 第 7 节取舍裁定与报告第 10 节的 API 风险清单。

## 10. INFLIGHT-NOTE-01 的修正与证据（2026-10-03）

Architect 的实现中检查 `.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md` 先列出 10 项、随后扩展为 13 项；DSH 已全部修正（第 11–13 项在读完扩展版后实施），并用一次性静态脚本逐项核对：`INFLIGHT_NOTE_01_CHECK_13: PASS`。

| # | 修正点 | 可核验证据 |
| --- | --- | --- |
| 1 | 私有辅助函数改名 `renderedThumbnail(from:maxPixelSize:)`，消除 `thumbnail` 局部值遮蔽 | `PhotoDerivativeRenderer.swift` 中已无 `thumbnail(from:` 调用；两处调用 `renderedThumbnail(from: source, maxPixelSize:)` |
| 2 | 两个派生图经 `convertToSRGB8` 重绘为 8-bit sRGB（有 alpha 用 RGBA）；original 仍为字节复制 | `convertToSRGB8(rawThumbnail…)` 与 `convertToSRGB8(rawPreview…)` 各一处；`PhotoLibrary` 只 `copyItem` 不转换 |
| 3 | `decodeDerivative` 改用 role 上限（320/2048）且与文件真实长边取 min 的 ImageIO thumbnail 解码 | 代码中无 `maxPixelSize * 2`、无 `CGImageSourceCreateImageAtIndex`；含 `min(maxPixelSize, sourceLongestEdge)` |
| 4 | 统一 `validatedInsideLibrary` 覆盖创建/写 manifest/复制/回滚/删除/清理；manifest 的 project.id 必须等于文件夹 UUID；清理只处理 UUID 素材目录 | 见 `PhotoLibrary.swift` 对应调用点；告警文案 “manifest project id does not match its folder”、“unrecognised item” |
| 5 | restore / 导入 / 移除共享 `mutationToken` 串行化，重复操作被拒绝；UI 用 `isBusy`/`isRemoving` | `PhotoImportModel` 三处 `mutationToken == nil` 守卫；`PhotoImportModelTests.testConcurrentRemovalsAreSerialised` |
| 6 | 提交成功后只要 project/batch 身份匹配就 `store.apply`，取消只阻止后续项 | `runBatch` 中 `if batchID == batch, importingProjectID == projectID`；原 `isBatchActive` 丢弃逻辑已移除 |
| 7 | actor 新增 `discardStagedFile(at:)`（归属校验）；协调器在成功与失败/取消两条路径都清理 | `runBatch` 中两次 `await library.discardStagedFile(at: stagedFileURL)`；`PhotoLibraryTests.testDiscardStagedFileOnlyRemovesOwnedStagingCopies` |
| 8 | `DerivedImageView` 三态 + Retry + `Task.isCancelled` 丢弃晚到结果；预览显示 JPEG/PNG/HEIC | `DerivedImageView.swift` 的 `Phase` 与 `guard !Task.isCancelled`；`PhotoPreviewSheet.displayName(forContentType:)` |
| 9 | 新增真实合成 HEIC 导入测试 | `PhotoLibraryTests.testImportAcceptsSyntheticHEICAndKeepsItsDerivativesBounded` |
| 10 | `selectionBehavior: .ordered`；Create/Import 仅在协调器 ready 时可用 | `PhotoImportSection` 的 `selectionBehavior: .ordered`、`!photoImport.isReady \|\| photoImport.isBusy`；`HomeView` 的 `.disabled(!photoImport.isReady)` |
| 11 | picker smoke 非空洞：断言 picker 控件真的出现、按下 Cancel、再确认 editor 可操作；点击前等待 enabled | `Stage02ImportUITests` 断言 `pickerAppeared`（Cancel 或 `Photos` 导航栏）与 `pickerCancel.exists`，按下后断言 Cancel 消失；新增 `UITestSupport.waitUntilEnabled()`，Stage 01 两个 smoke 保留并改用该等待 |
| 12 | staging 复制的异步非 MainActor 边界 + 复制前字节/取消校验 + 失败只清理自有副本 | `PhotoFileTransfer.stageCopy` 为 `nonisolated static func … async throws`，闭包内 `try await`；`maxSourceBytes` 与 `Task.checkCancellation()` 在 `copyItem` 之前；catch 中只 `removeItem(at: destination)`；文件中唯一的类型声明是 `struct`，无 `DispatchQueue`/新 actor/协议 |
| 13 | 库根创建被自身校验拒绝（真实缺陷）；且仅 root containment 不够，库内跨项目 symlink 别名会污染/清理别的项目 | `resolvedLibraryPath` 要求解析结果**恰好等于** `canonicalRoot/<相对路径>`；空相对路径仅库根创建可用（`createDirectory("")`）；`cleanupUnreferencedAssets` 要求 UUID **且** `isDirectory`；新增 `testRestoreCreatesTheLibraryOnFirstLaunchWithAMissingRoot`、`testSymlinkAliasInsideTheLibraryCannotRedirectAnotherProjectsAssets`、`testCleanupKeepsAUUIDNamedRegularFileInAnAssetsFolder` |

**本机实际执行**（修正后重跑）：`generate_xcodeproj.py` exit 0（130 对象 / 40 文件引用，App 26 + 单元 10 + UI 3）；`verify_project.py` PASS（39 Swift 文件 5714 行、6 个 UI identifier 解析、`Cancel`/`Photos` 显式豁免）；tree-sitter `TREE_SITTER_PARSED=39 WITH_ERRORS=0`；`STAGE02_ALL_CORRECTIONS_CHECK: 19/19 PASS`；`STAGE02_CONFORMANCE: PASS`；测试计数 **76 单元 + 4 UI**。**仍未执行**任何 Xcode 编译或测试。注：13 项实现中检查的早期脚本 `INFLIGHT_NOTE_01_CHECK_13` 曾因 item-12 子检查用纯文本匹配 `"protocol"` 而误报一次 FAIL，改为只统计真实类型声明后通过（脚本缺陷，非代码缺陷）。

**未修改**：`.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md`、`.github/workflows/stage02-macos.yml`、`tools/generate_stage02_photo_fixtures.py` 等 Architect 文件/工作流；未运行工作流、未上传任何内容。

## 11. Round 01 Review 的 FIX-01 修正证据（2026-10-03）

`.ai/reviews/STAGE-02-ARCHITECT-ROUND-01.md` 判 CHANGES_REQUIRED 并授权 `.ai/tasks/STAGE-02-ARCHITECT-FIX-01.md` 的 **6 项**（第 6 项为报告生成前追加）；DSH 已全部完成，明细见 `.ai/reports/STAGE-02-FIX-01-REPORT.md`。一致性脚本与静态核对通过：

| # | 修正 | 可核验证据 |
| --- | --- | --- |
| F1 | `importing` 闭包返回 `PhotoFileTransfer` 自身，而非 `stageCopy` 的 URL | `PhotoFileTransfer(stagedFileURL: try await stageCopy(of: received.file))` |
| F2 | staging 目录解析必须恰好是 `<canonical root>/Temporary`；复制后再次检查取消；只有精确匹配自有 staging 路径的文件才会被删除 | `canonicalStagingDirectory`、`canonicalStagedFile`（父目录 == staging 且解析路径 == 期望路径）、`Task.checkCancellation()` 出现在复制前后、未知 staging 条目保留并告警 |
| F3 | `discardStagedFile(at:) -> [String]`，协调器在两处追加 warnings | 协调器中两处 `appendWarnings(await library.discardStagedFile(at: stagedFileURL))` |
| F4 | import/remove 入口与 `writeManifest` 前做共享 package 校验；无 schema 降级 | 三处 `try validatePackageEntry(package)`；`remove` 不再构造 schema1 覆盖未来版本 |
| F5 | 像素上限用 `multipliedReportingOverflow` 防溢出；非正尺寸报 unreadable | `checkedPixelCount`；代码中已无 `metadata.pixelWidth * metadata.pixelHeight` |
| F6 | 合成 fixture 真的含透明/半透明像素并断言派生图**像素** alpha；协调器补 import-vs-removal 与双批次保护；窄注入 loader；关键 fixture/PNG/JPEG 失败必须失败而非 skip | `SyntheticImageFactory`（`context.clear` + `alpha: 0.5` + `AlphaStats`/`alphaStats(of:)`，`XCTSkip` 仅存在于 HEIC/HEIF 分支）；`PhotoImportModel.PhotoFileLoader`；`PhotoImportModelTests` 三个新用例；`TestGate` |
| 附 | 新 UI 类型显式 `@MainActor`（不依赖新 SDK 推断） | `PhotoImportSection`、`PhotoPreviewSheet`、`DerivedImageView` |

**本轮本机实际执行**：130 对象 / 40 文件引用 / 39 Swift 文件 5714 行、`verify_project.py` PASS、tree-sitter `WITH_ERRORS=0`、`STAGE02_ALL_CORRECTIONS_CHECK` 19/19 通过、`STAGE02_CONFORMANCE` PASS；测试计数 **76 单元 + 4 UI**。**仍未执行**任何 Xcode 编译或测试。

## 12. FIX-02：首个 macOS 运行的编译失败与修正（2026-10-03）

真实证据：run 37131111464（source `dcfacd0f489b5fe517e07a5f2c283773d2eb37c6`，Xcode 16.4 / macOS 15 ARM / iOS 18.5 模拟器，FAILURE 3m50s）**编译失败，0 个单元/UI 测试执行，无运行包**。本地读取 `.ai/build/downloads/run-37131111464/evidence/xcodebuild.log` 得到全部 4 条 error：

| 日志行 | 诊断 | 性质 |
| --- | --- | --- |
| :342 | `PhotoImportModel.swift:35:44: cannot find type 'PhotosPickerItem' in scope` | 根因（`PhotoFileLoader` typealias） |
| :349 | 同文件 `:146:36` 同诊断 | 根因（`importSelection` 参数） |
| :352 | 同文件 `:243:37` 同诊断 | 根因（`runBatch` 参数） |
| :345 | 同文件 `:63:24: @escaping attribute only applies to function types` | 上游类型缺失的级联 |

修正（完整证据见 `.ai/reports/STAGE-02-FIX-02-REPORT.md`）：

1. **公开交叉导入**：`PhotoImportModel.swift` 与 `PhotoImportModelTests.swift` 各补 `import SwiftUI`；审计确认 4 个引用 `PhotosPickerItem` 的文件全部同时导入 PhotosUI 与 SwiftUI；未用下划线/私有模块，未改 picker 流程、`PhotoFileLoader` 类型或生产默认 loader。
2. **显式 Void 任务**：`let task: Task<Void, Never> = Task { [weak self] in guard let self else { return }; await self.runBatch(...) }`；`batchTask` 契约、token 生命周期、取消转发、提交后 apply 全部保留；`importSelection` 签名不变。日志中**没有** Task 推断诊断，故此项为 Architect 指示的预防性修正，未被 Xcode 证实。
3. **12 MP 批次与取消验证**：新增 `MomentsStudioTests/LargePhotoBatchTests.swift`（3×4000×3000 JPEG，生成在计时外、串行经真实库；断言顺序/字节/320-2048 边界；记录耗时与字节单位内存快照，无阈值）+ `TestGate` 确定性取消用例（已提交保留、剩余不提交、staging 清空）。

本机实际执行：132 对象 / 41 文件引用 / 40 Swift 文件 5989 行、`verify_project.py` PASS、tree-sitter `WITH_ERRORS=0`、FIX-02 一致性脚本通过（部署目标 8/8 处 17.0、Swift 语言模式 8/8 处 5.0 未变）；**78 单元 + 4 UI 全部未执行**。未运行云端服务、未推送/上传。
