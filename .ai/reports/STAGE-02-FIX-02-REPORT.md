# STAGE-02-FIX-02-REPORT.md

Stage 02 — Architect Fix 02（首个 macOS 运行在编译阶段失败后的修正）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-02.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-03.md`、证据目录 `.ai/build/downloads/run-37131111464/evidence/`
状态：`READY_FOR_ARCHITECT_REVIEW`（**未**通过 Review，**未**交所有者验收；Stage03 未授权）

---

## 1. Summary

首个真实 macOS 运行（source `dcfacd0f489b5fe517e07a5f2c283773d2eb37c6`，run 37131111464，Xcode 16.4 / macOS 15 ARM / iOS 18.5 模拟器，FAILURE 3m50s）在**编译阶段**失败，单元与 UI 测试均未执行。本机日志（已下载的 `xcodebuild.log`）中的真实诊断只有一组，根因是**缺少公开 SwiftUI 交叉导入**，导致 `PhotosPickerItem` 不在作用域。

本轮只做三项授权修正，未改任何契约、序列化字段或既有行为测试：

1. 在引用 `PhotosPickerItem` 的文件中补上公开 `SwiftUI` 导入（与 `PhotosUI` 并列），并审计全部直接引用点。
2. 把弱引用的 `runBatch` 任务显式声明为 `Task<Void, Never>`，用 `guard let self else { return }` 与非可选 `await self.runBatch(...)`。
3. 补齐已定义的性能/取消验证缺口：3 张 4000×3000（12 MP）JPEG 经真实库串行导入的 XCTest，记录实际耗时与**明确标注单位**的可观测进程内存，并加一个用 `TestGate` 的确定性批次取消用例。

**关键事实**：本机（Windows）仍无 Xcode。**本轮 78 个单元测试 + 4 个 UI 测试全部未执行，编译与内存/耗时测量均未在本机验证**；本报告只包含 Windows 侧结构、语法与契约静态校验。上一轮的真实编译错误是本轮唯一被 Xcode 证实的证据。

## 2. 真实失败证据（本地读取下载日志）

`.ai/build/downloads/run-37131111464/evidence/xcodebuild.log`（455 行）中的全部 error 行：

```text
:342  PhotoImportModel.swift:35:44: error: cannot find type 'PhotosPickerItem' in scope
:345  PhotoImportModel.swift:63:24: error: @escaping attribute only applies to function types
:349  PhotoImportModel.swift:146:36: error: cannot find type 'PhotosPickerItem' in scope
:352  PhotoImportModel.swift:243:37: error: cannot find type 'PhotosPickerItem' in scope
```

- `:35` 是 `typealias PhotoFileLoader = @Sendable (PhotosPickerItem) async throws -> URL`，`:146` 是 `importSelection` 的参数类型，`:243` 是 `runBatch` 的参数类型。
- `:345` 的 `@escaping` 报错是**上游类型缺失的级联诊断**（其位置正是 `init(loadPhotoFile: @escaping PhotoFileLoader = ...)`）。
- 日志中**没有**任何关于 `Task<Void?, Never>` 与 `Task<Void, Never>` 不匹配的诊断：编译在该点之前已失败。因此第 2 项是按 Architect 指示的**预防性**修正，**不声称已被 Xcode 证实**，需下一次云端运行确认。
- 未打包运行版本，单元/UI 测试未执行，`Stage02.xcresult` 中无测试用例结果。

## 3. 三项修正与证据

### 3.1 公开 SwiftUI/PhotosUI 交叉导入

- **改动**：`PhotoImportModel.swift` 与 `PhotoImportModelTests.swift` 各补一行 `import SwiftUI`（与既有 `import PhotosUI` 并列），并写明原因注释：`PhotosPickerItem` 由 PhotosUI 的 SwiftUI 支持层声明，需要公开 SwiftUI 模块在作用域内；未使用下划线/私有 overlay 模块。
- **审计全部直接引用点**（4 个文件，全部同时导入 PhotosUI 与 SwiftUI）：

| 文件 | 改前 | 改后 |
| --- | --- | --- |
| `Features/PhotoImport/PhotoImportModel.swift` | 仅有 `PhotosUI`（**缺 SwiftUI，编译失败根因**） | `PhotosUI` + `SwiftUI` |
| `MomentsStudioTests/PhotoImportModelTests.swift` | 仅有 `PhotosUI`（**缺 SwiftUI**） | `PhotosUI` + `SwiftUI` |
| `Features/PhotoImport/PhotoImportSection.swift` | 已同时导入两者 | 未改 |
| `MomentsStudioTests/LargePhotoBatchTests.swift`（本轮新增） | — | 同时导入两者 |

- **未改动**：没有替换 picker/provider 流程，`PhotoFileLoader` 类型与生产默认 loader（`item.loadTransferable(type: PhotoFileTransfer.self)` → `stagedFileURL`）保持原样，workspace 中无 `import _...`。

### 3.2 显式 `Task<Void, Never>`

```swift
let task: Task<Void, Never> = Task { [weak self] in
    guard let self else { return }
    await self.runBatch(items, projectID: projectID, batchID: batch)
}
```

- 保留了弱引用、`batchTask` 契约（`Task<Void, Never>?` 未改）、`mutationToken` 生命周期（`if mutationToken == token { mutationToken = nil }`）、取消转发（`cancelImport` → `batchTask?.cancel()`）与“提交成功后仍 apply”分支（`if batchID == batch, importingProjectID == projectID`）。
- `importSelection(_ items: [PhotosPickerItem], projectID: UUID) async` 公开签名未变。
- 全仓审计确认没有其他 `await self?.runBatch` 形式的可选推断点；`.task { }`（RootView）是 SwiftUI 修饰符，与 `Task` 初始化无关。

### 3.3 12 MP 串行批次与确定性取消（性能验证缺口）

新增 `MomentsStudioTests/LargePhotoBatchTests.swift`（两个用例）：

- `testSerialThreeLargePhotoBatchCommitsOrderedBoundedAndRecordsMetrics`
  - 3 张 **4000×3000** JPEG 由合成工厂生成，**生成发生在计时之前**；导入经真实 `PhotoLibrary` 串行逐张提交。
  - 断言（只有行为契约）：提交顺序等于导入顺序、3 张各自唯一、`pixelWidth/Height == 4000/3000`、`contentType == public.jpeg`、original 与源文件**逐字节相等**、thumbnail 长边 ≤320、preview 长边 ≤2048 且 preview > thumbnail、`restore()` 得到相同顺序的 3 张且无 warning。
  - **记录**（不断言、无阈值）：`elapsed_import_seconds`、以字节为单位的 `phys_footprint`/`resident_size` 前后快照及差值，并把同样内容作为 `XCTAttachment`（`lifetime = .keepAlways`）挂到测试证据上，名称 `stage02-large-batch-metrics`。
  - 内存快照经 `task_info(TASK_VM_INFO)` 读取，返回 `nil` 时记录 `unavailable` 而非失败；报告文本明确写出“快照是两次调用点的值，不是峰值 RSS，模拟器/CI 数值不代表真机性能”。
  - 每轮循环内只解码一对派生图，原件不解码、不保留，故不会同时持有三张原始像素。
- `testBatchCancellationKeepsCommittedPhotoAndCleansStaging`
  - 用既有 `TestGate` + 窄注入 loader：第 1 项正常提交，第 2/3 项阻塞在 gate 上；测试等到 gate 被进入（即第 1 项已提交）后调用 `model.cancelImport(projectID:)`，再放行。
  - 断言：`store` 仍为 1 张、`completedCount == 1`、`isImporting == false`、`itemErrors` 为空（取消不算失败）、`restore()` 与 store 一致且无 warning、**staging 目录为空**（已提交项与取消项的暂存副本都被清理）。
- 未新增生产 benchmark UI/服务，未新增协议/仓储/第二调度器，未设置任何硬编码时间或内存阈值。

## 4. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `MomentsStudio/MomentsStudio/Features/PhotoImport/PhotoImportModel.swift` | 加 `import SwiftUI`（+ 原因注释）；弱引用任务改为显式 `Task<Void, Never>` + `guard let self` + 非可选 await |
| `MomentsStudio/MomentsStudioTests/PhotoImportModelTests.swift` | 加 `import SwiftUI`（+ 原因注释） |
| `MomentsStudio/MomentsStudioTests/LargePhotoBatchTests.swift`（新增） | 12 MP 串行批次行为+指标记录用例；`TestGate` 确定性取消用例；`LoadCallCounter`（测试私有 actor） |
| `MomentsStudio/MomentsStudio.xcodeproj/project.pbxproj` | 由 `tools/generate_xcodeproj.py` 重新生成（新增 1 个测试文件：132 对象、41 文件引用） |

**未改动**：序列化字段/编码、`ProjectStore` 公开签名、导航契约、依赖、部署目标（仍 17.0）与 Swift 语言模式（仍 5.0）、工程构建设置、Architect 的 Task/Review/工作流/证据文件。FIX-01 六项与实现中检查 13 项全部保留。

## 5. 测试

| 文件 | 用例数 | 本轮变化 |
| --- | --- | --- |
| `PhotoLibraryTests.swift` | 29 | 未改 |
| `PhotoImportModelTests.swift` | 6 | 仅补导入 |
| `LargePhotoBatchTests.swift`（新增） | 2 | 新增（12 MP 批次 + 确定性取消） |
| `ProjectPackageTests.swift` | 8 | 未改 |
| `ProjectStoreTests.swift` + Stage 01 其余 | 33 | 未改，全部保留 |

**合计 78 单元 + 4 UI 测试（82 项）。全部未执行。**

## 6. 本机实际执行的检查（Windows）

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 工程生成 | `python tools/generate_xcodeproj.py` | exit 0：132 对象 / 41 文件引用（App 26 + 单元 11 + UI 3） |
| 结构校验 | `python tools/verify_project.py` | **PASS**：Sources 恰好覆盖 40 个 `.swift`、构建设置/scheme/资源 JSON 通过、6 个 UI identifier 解析 |
| Swift 语法 | tree-sitter | `TREE_SITTER_PARSED=40 WITH_ERRORS=0`，5989 行 |
| FIX-02 一致性 | 一次性脚本 `STAGE02_FIX02_CHECK` | **20/20 通过**：4 个 `PhotosPickerItem` 引用文件（含新增测试）均同时导入 PhotosUI+SwiftUI；全仓无下划线/私有模块导入；部署目标在**全部 8 个 build configuration** 均为 17.0、Swift 语言模式均为 5.0；无第三方依赖；`Task<Void, Never>` + `guard let self` + 非可选 await 且无 `await self?.runBatch`；`importSelection` 签名与 loader 类型/生产默认实现未变；取消转发、token 生命周期、提交后 apply 保留；12 MP 三张、串行、顺序/字节/320-2048 断言、记录耗时与字节单位内存、无阈值断言、生成先于计时、`#if canImport(Darwin)` 守卫且失败返回 `nil`；确定性取消用 `TestGate` 并断言已提交保留/剩余不提交/staging 清空；生产代码无 benchmark |
| 契约一致性 | `dsh_stage02_conformance.py` | PASS（40 项）。其中框架白名单**由 DSH 为平台系统模块 `Darwin` 增加了一项带注释的豁免**：它只被测试文件中 `#if canImport(Darwin)` 包裹的 `task_info(TASK_VM_INFO)` 内存快照 helper 使用，是 Apple 平台系统模块，不是第三方依赖；同一脚本的 “no dependencies added（无 Package.swift/Podfile）” 仍 PASS。该豁免是本次唯一放行的白名单变更，供 Architect 复核 |
| 部署目标/SDK 未变 | 一次性脚本 | 确认 `"IPHONEOS_DEPLOYMENT_TARGET" = "17.0"` 与 `"SWIFT_VERSION" = "5.0"` 出现 8/8 次、无其他取值 |
| 日志复核 | 本地读取 `xcodebuild.log` | 4 条 error 全部为 `PhotosPickerItem` 缺失与其 `@escaping` 级联；**无** Task 推断诊断 |

**未执行**：Xcode 编译、78 单元 + 4 UI 测试、耗时与内存测量、真实选择器导入、真机/模拟器性能与视觉。**本机静态校验通过不等于类型检查或运行通过。**

## 7. 未解决风险与待 macOS 确认项

1. **交叉导入的最终确认**：本地推断与 Apple 示例一致，但只有下一次云端运行能证明 4 处 error 消失；测试 target 新增 `import SwiftUI` 同样需要真实编译确认。
2. **`Task<Void, Never>` 未被 Xcode 证实**：日志中没有该诊断（编译更早失败）。若编译器原本就能推断，本改为等价且无害；若确有推断问题，本改为其对症修正。两种情况都需云端运行确认。
3. **Mach 测量 API 未在本机验证**：`task_info(mach_task_self_, TASK_VM_INFO, ...)`、`task_vm_info_data_t.phys_footprint/resident_size`、`kern_return_t`、`mach_msg_type_number_t` 均为 Apple 平台 API，Windows 无法编译；已用 `#if canImport(Darwin)` 包裹且在不可用时返回 `nil`，但类型/字段名仍需 Xcode 确认（若不通过，只是一处本地 helper 的修正，不影响生产代码）。若 Architect 认为平台系统模块 `Darwin` 不应出现在测试中，可改为 XCTest 原生 `XCTMemoryMetric`/`record(metric:)` 方案（需 `measure` 同步块或该 API 的可用性确认），或按任务允许的方式把该项测量明确留给 macOS。
4. **`XCTAttachment(string:)` + `add(_:)`** 需 Xcode 确认（标准 XCTest API，但本机无法编译）。
5. **CI 时长**：新增用例会生成 3 张 12 MP 图并做 3 次串行导入与派生解码，预计增加数十秒，可能影响工作流超时设置；未在本机测量，未设置阈值。
6. **指标的性质**：`elapsed_import_seconds` 与内存快照只是模拟器/CI 上的**可观测事实**，不是峰值 RSS，也不能推断真机性能；验收要求仍需实机检查。
7. 既有风险仍在（见 `.ai/reports/STAGE-02-REPORT.md` 第 10 节）：HEIC 用例在无法编码 HEIC 的环境会 skip 且不证明 HEIC 支持；真实选择器多选、预览、移除、terminate/relaunch 恢复、iPad/VoiceOver、大字号均未验证。

## 8. 未做的动作（明确声明）

未运行任何云端构建/工作流，未操作任何账户或计费，未 push、未上传、未创建或修改 `.github/workflows/*`，未修改 Architect 的 Task/Review/证据文件，未开始 Stage03。本地读取了已下载的证据日志与 fixtures 目录（只读）。

## 9. 交付后的三项小修正（Architect Review 备注）

1. **`TASKS.md` 状态更正**：原表仍写“Stage02 尚未执行 / 59 单元 + 4 UI”。现改为：Stage02 已实现并完成实现中检查 13 项 + FIX-01 六项 + FIX-02 三项；**首次 macOS 运行 run 37131111464（source `dcfacd0`，Xcode 16.4，3m50s）在编译阶段失败、0 个单元/UI 测试执行、无运行包**；本机当前 **78 单元 + 4 UI（82 项）从未运行**；下一步为 FIX-02 复审后重跑云端构建与测试。
2. **去掉对同步方法的冗余 `await`**：`LargePhotoBatchTests` 中 `cancelImport(projectID:)` 是 `@MainActor` 同步方法，测试同为 MainActor，故改为直接调用（原写法会产生 “no async operations occur within await” 警告）。全仓复查确认没有其他对 `cancelImport`/`dismissWarnings`/`dismissItemErrors` 的冗余 `await`。
3. **时间戳不再留占位**：把 DSH 自己条目中的 `22:2x`、`22:4x`、`22:45`、`23:0x`、`23:2x` 等推测/占位时间，改为“日期 + 事项说明”，或用**实测时间**（本次 2026-10-03 23:14 +08:00，由系统时钟读取）。Architect 自己的条目未改动。

三项修正后重跑本机检查仍为：`verify_project.py` PASS（132 对象/41 文件引用/40 Swift 文件 5989 行）、tree-sitter `WITH_ERRORS=0`、`STAGE02_FIX02_CHECK` 20/20、`STAGE02_ALL_CORRECTIONS_CHECK` PASS、`STAGE02_CONFORMANCE` PASS、全仓 markdown 均为有效 UTF-8。测试仍为 **78 单元 + 4 UI，全部未执行**。

## 10. 下一步

Architect 复审本报告后对**当前源码**重跑 macOS 构建与测试；DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`，未标记 `WAITING_FOR_USER` 或 `APPROVED`，所有者判断保持 PENDING、9 项验收清单仍未勾选。
