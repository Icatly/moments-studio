# STAGE-02-FIX-01-REPORT.md

Stage 02 — Architect Fix 01（Round 01 Review；5 项精准修正，随后追加第 6 项）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-01.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-01.md`（结论 CHANGES_REQUIRED）
状态：`READY_FOR_ARCHITECT_REVIEW`（**未**通过 Review，**未**交所有者验收；未开始 Stage03）

---

## 1. Summary

任务的全部 **6 项**（第 6 项为追加，见 §2.6）已完成，且**未回退**先前 13 项实现中检查的修正。本轮只改这些点：Transferable 返回类型、staging 路径边界与归属、清理错误可见性、mutation 入口校验、像素上限溢出防护、合成透明 fixture 与协调器 mutation 覆盖；并按附加要求给新 UI 类型加显式 `@MainActor`。

**关键事实**：本机（Windows）无 Xcode。**Xcode 编译、76 个单元测试、4 个 UI 测试全部未执行**；本报告只包含 Windows 侧结构/语法/契约静态校验。Stage 01 的云端构建结果不是 Stage 02 证据。

## 2. 六项修正

### 2.1（任务 1）Transferable 返回类型

- **问题**：`importing` 闭包直接返回 `stageCopy` 的 `URL`，而该 representation 必须产出 `PhotoFileTransfer` 自身；Windows 语法解析不检查泛型返回类型。
- **修正**：`PhotoFileTransfer(stagedFileURL: try await stageCopy(of: received.file))` —— 保留异步文件复制，并确保接管发生在闭包返回前。
- **证据**：`Services/PhotoFileTransfer.swift`（`transferRepresentation`）。

### 2.2（任务 2）staging 路径边界与归属

- **问题**：`stageCopy` 未验证 `Temporary` 父目录是否被 symlink 掉；复制后没有取消检查；`removeStagingCopyIfOwned` 只用 `lastPathComponent` 拼路径，同名文件即可冒充“自有文件”。
- **修正**：
  - `PhotoLibraryLocation.canonicalStagingDirectory(rootURL:)`：要求 staging 目录解析结果**恰好**是 `<canonical root>/Temporary`，创建/复制前先校验。
  - 复制**前**做 regular-file 与 100 MiB 校验、`Task.checkCancellation()`；复制**后**再次检查取消；失败/取消只 `removeItem(at: destination)`，源文件不动。
  - `PhotoLibraryLocation.canonicalStagedFile(_:rootURL:)`：要求传入 URL 解析后**恰好**是 `<canonical root>/Temporary/<其自身文件名>` 且父目录就是该 staging 目录；`removeStagingCopyIfOwned` 改用它。
  - 启动清理只处理 staging 目录内 **UUID 命名且是普通文件**的条目；未知文件/目录保留并告警。
- **证据**：`Services/PhotoLibrary.swift`、`Services/PhotoFileTransfer.swift`。

### 2.3（任务 3）清理错误不再被吞

- **问题**：`discardStagedFile` 建了 `warnings` 却丢弃。
- **修正**：`discardStagedFile(at:) -> [String]`（运行时结果，不改持久化契约、不新增 actor/服务/协议）；协调器在成功与失败/取消两条路径都 `appendWarnings(...)`；失败仍会在下次启动重试。
- **证据**：`Services/PhotoLibrary.swift`、`Features/PhotoImport/PhotoImportModel.swift`（两处）。

### 2.4（任务 4）mutation 入口与写入前校验

- **问题**：import 只校验“加入照片后”的 package；remove/`writeManifest` 没有共享校验；remove 会把未来 schemaVersion 的包重构成 schema1（静默降级）。
- **修正**：新增 `validatePackageEntry(_:)`（schemaVersion 必须等于当前版本 + `ProjectPackage.validate(photos:projectID:)` 全量校验），在 **import 入口**、**remove 入口**、**`writeManifest` 之前**各调用一次；拒绝时保留既有文件与 manifest。
- **证据**：`Services/PhotoLibrary.swift`（三处 `try validatePackageEntry(package)`）。

### 2.5（任务 5）像素上限溢出

- **问题**：`metadata.pixelWidth * metadata.pixelHeight` 在比较前计算，极端损坏属性可致 `Int` 溢出崩溃。
- **修正**：`checkedPixelCount(width:height:limit:fileName:)`：宽高必须为正（否则 `unreadableImage`），再用 `multipliedReportingOverflow(by:)`；溢出返回 `limit + 1`，由调用方抛出可区分的 `.tooManyPixels`。
- **证据**：`Services/PhotoLibrary.swift`。

### 2.6（任务 6）真实透明 fixture、像素 alpha 断言、协调器 mutation 覆盖

- **问题**：合成 alpha fixture 每个像素 alpha 都是 1，PNG 用例只断言扩展名，无法证明透明通道真的保住了；“`PhotosPickerItem` 无法构造”的注释是**错的**（Apple 提供 `init(itemIdentifier:)`）；协调器只测了两次移除，没有 import-vs-removal 覆盖。
- **修正**：
  1. `SyntheticImageFactory.makeImage(hasAlpha: true)` 现在**真的**画出一个 `context.clear` 的完全透明中心方块（alpha 0）与一条 `alpha: 0.5` 的半透明带；新增 `AlphaStats` + `alphaStats(of:)` 做逐像素 alpha 分类。
  2. `PhotoLibraryTests.testImportKeepsTransparencyAsPNGAndUsesJPEGOtherwise` 现在断言：fixture 自身含 alpha 0 与半透明像素 → PNG thumbnail/preview 的**像素**仍含 alpha 0 与半透明像素 → JPEG 路径 `transparent == 0 && semitransparent == 0`。
  3. 关键 fixture/context/PNG/JPEG 失败改为真实失败（`SyntheticImageFactory.FixtureError`）；**只有** HEIC/HEIF 编码不可用才 `XCTSkip`，并在用例/报告中说明该 skip **不证明** HEIC 支持。
  4. `PhotoImportModel` 增加任务授权的窄注入点 `PhotoFileLoader`（默认实现仍走真实 `PhotosPickerItem.loadTransferable`）；无服务协议、无 mock 仓储、无生产测试按钮、无第二调度器。
  5. `PhotoImportModelTests` 修正错误注释并新增：注入 loader 的完整批次（store 与磁盘一致、staging 清空、无 warnings）、**导入进行中移除被拒**（预先提交一张，批次挂起时移除被拒绝且报告错误，gate 打开后批次仍提交、旧照片存活、store==磁盘）、**第二批次被拒**（只提交第一批）。合成标识符从不交给真实照片库。
  6. 共享 `TestGate`（actor，替换原先 private `AsyncGate`）供库测试与协调器测试复用。
- **证据**：`MomentsStudioTests/SyntheticImageFactory.swift`、`MomentsStudioTests/TestGate.swift`、`MomentsStudioTests/PhotoLibraryTests.swift`、`MomentsStudioTests/PhotoImportModelTests.swift`、`Features/PhotoImport/PhotoImportModel.swift`。

### 附加（任务附加要求）显式 MainActor

访问主 actor 协调器/store 的新 UI 类型显式标注 `@MainActor`：`PhotoImportSection`、`PhotoPreviewSheet`，以及同目录的 `DerivedImageView`；与 Stage 01 的 actor 边界一致，不依赖新 SDK 的 `View` 整体隔离推断。

## 3. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `Services/PhotoFileTransfer.swift` | 闭包返回 `PhotoFileTransfer`；canonical staging 校验；复制前后取消检查；失败/取消只清自建文件 |
| `Services/PhotoLibrary.swift` | `canonicalStagingDirectory`/`canonicalStagedFile`；`discardStagedFile` 返回 warnings；精确归属校验；启动清理只认 UUID 普通文件、未知条目保留；`validatePackageEntry` 三处；`checkedPixelCount` |
| `Features/PhotoImport/PhotoImportModel.swift` | 两处追加 staging 清理 warnings；新增窄 `PhotoFileLoader` 注入点并在批次中使用 |
| `Features/PhotoImport/PhotoImportSection.swift`、`PhotoPreviewSheet.swift`、`DerivedImageView.swift` | 显式 `@MainActor` |
| `MomentsStudioTests/SyntheticImageFactory.swift` | 真实透明/半透明区域；`AlphaStats`/`alphaStats(of:)`；关键失败改为真实失败（仅 HEIC 可 skip） |
| `MomentsStudioTests/TestGate.swift`（新增） | 共享确定性测试闸门 |
| `MomentsStudioTests/PhotoLibraryTests.swift` | 异步 `await` 调用点；透明测试改为像素 alpha 断言；`TestGate`；staging 归属扩写；新增 3 个测试 |
| `MomentsStudioTests/PhotoImportModelTests.swift` | 修正错误注释；新增 3 个协调器测试（注入 loader 批次、导入中移除被拒、第二批次被拒） |

**未改动**：任何持久化字段/编码、`ProjectStore` 公开签名、导航契约、工程设置、依赖、资源颜色、Architect 的 Task/Review/工作流/证据文件。先前 13 项实现中检查修正全部保留。

## 4. 测试

| 文件 | 用例数 | 本轮变化 |
| --- | --- | --- |
| `MomentsStudioTests/ProjectPackageTests.swift` | 8 | 未改 |
| `MomentsStudioTests/PhotoLibraryTests.swift` | 29 | +3（staging 别名拒绝且源不变、staging 取消不留副本、坏/未来包拒绝无写入），扩写 staging 归属与透明像素断言 |
| `MomentsStudioTests/PhotoImportModelTests.swift` | 6 | +3 协调器用例（注入 loader 批次、导入中移除被拒、第二批次被拒） |
| `MomentsStudioTests/ProjectStoreTests.swift` | 11 | 未改 |
| Stage 01 其余单元测试（`ProjectModelTests`/`CanvasDocumentTests`/`LayerModelTests`/`AppNavigationModelTests`） | 29 中的其余部分 | 未改，全部保留 |

**合计 76 单元 + 4 UI 测试（80 项）。** 新增测试覆盖任务点名的行为：staging 别名与源不变、取消与清理、同名外部文件不删除自有暂存文件、坏/未来包被拒且无写入、透明像素真的保留、协调器 import-vs-removal 与双批次保护。Transferable 返回类型由真实 Xcode 编译验证（本机不可验证）。

## 5. 本机实际执行的检查

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 工程生成 | `python tools/generate_xcodeproj.py` | exit 0：130 对象 / 40 文件引用（App 26 + 单元 10 + UI 3） |
| 结构校验 | `python tools/verify_project.py` | **PASS**：Sources 恰好覆盖 39 个 `.swift`（26/10/3）、构建设置/scheme/资源 JSON 通过、6 个 UI identifier 解析（`Cancel`/`Photos` 为系统标签，显式豁免） |
| Swift 语法 | tree-sitter | `TREE_SITTER_PARSED=39 WITH_ERRORS=0`，5714 行 |
| 异步调用点 | 一次性脚本 | 4 处 `try await PhotoFileTransfer.stageCopy`，0 处未 await |
| FIX-01 一致性 | 一次性脚本 | 通过：闭包返回类型、canonical staging 校验先于创建/复制、复制后取消检查、精确归属匹配、未知 staging 条目保留、`discardStagedFile` 返回 warnings 并被协调器追加、import/remove/writeManifest 三处入口校验、无 schema 降级路径、溢出安全像素计算、三个新 UI 类型的显式 `@MainActor`、新增测试存在 |
| 13 项 + FIX-01 合并核对 | `STAGE02_ALL_CORRECTIONS_CHECK` | **19/19 通过**。注：该脚本早期的 item-12 子检查用纯文本匹配 `"protocol"`，命中文档注释里的「actor, queue or protocol」误报过一次 FAIL；改为只统计真实类型声明（`['struct']`、无 `DispatchQueue`）后通过 —— 脚本自身缺陷，不是代码缺陷 |
| 第 6 项静态核对 | 一次性脚本 | `XCTSkip` 只出现在 HEIC/HEIF 分支；`SyntheticImageFactory` 含 `context.clear` 与 `alpha: 0.5`；协调器含 `PhotoFileLoader` 注入点 |
| 契约一致性 | `STAGE02_CONFORMANCE` | PASS（接口签名、编码键、上限、库根/暂存、框架白名单、无新增依赖） |

**未执行**：Xcode 编译、76 单元 + 4 UI 测试、真实选择器导入、真机/模拟器性能与视觉、Appetize 运行。**本机静态校验通过不等于类型检查或运行通过。**

## 6. 已知限制（延续 Stage 02 报告，未变）

- 无 Stage 02 可运行版本；需 Architect 的 macOS 云端构建与实机检查。
- 仅静态图（JPEG/PNG/HEIC/HEIF）；拒绝 RAW/动画 GIF/视频；派生图为 8-bit sRGB，不承诺 HDR 预览保真。
- 上限 20 张/项目、100 MiB/图、80 MP/图、320/2048 为工程策略，未做真机测量；无内容去重。
- 恢复时缺失文件的照片仍列出并告警；清理失败只告警、下次启动重试（本轮起同时对用户可见）。
- **HEIC 用例在无法编码 HEIC 的环境会 skip**，该 skip 不证明 HEIC 支持，需实机补充。
- 首次编译仍可能暴露 API 标签问题（`FileRepresentation(importedContentType:)`、`PhotosPicker(selection:maxSelectionCount:selectionBehavior:matching:preferredItemEncoding:label:)`、`PhotosPickerItem(itemIdentifier:)`、`nonisolated` 静态成员等）；这些都需真实 Xcode 验证。

## 7. 下一步

Architect 对本轮修正复审；随后对**当前 commit**（而非 Stage 01 的 `6e8f449`）执行 macOS 构建与测试，再做 Appetize/模拟器验收。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER` 或 `APPROVED`，未开始 Stage03，未运行任何云端服务作业。
