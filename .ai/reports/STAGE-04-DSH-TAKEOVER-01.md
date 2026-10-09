# Stage04 DSH 接手核验报告 — 2026-10-09

依据 [STAGE-04-DSH-TAKEOVER-01](../tasks/STAGE-04-DSH-TAKEOVER-01.md)、[Stage04规格](../../docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)、[实现任务](../tasks/STAGE-04-IMPLEMENT-01.md)与[工作须知](../../工作须知.md)（2026-10-09 恢复分工）。

**来源声明**：Stage04 现有本地实现（`CollageLayout.swift`、`CollageLayoutSheet.swift`、相关 App 改动、17 个新测试方法、两个 Stage04 工作流）均由 **Architect 此前直接写入**，不是 DSH 交付。本轮 DSH 按恢复后的分工**接手核验**：独立读实际差异、沿既有架构逐项核对、执行本机可用的精确检查、给出基线与问题清单。

**本轮 DSH 改动**：**源码/测试/工作流零改动**（未发现需要修复的明确缺陷；下述观察项交 Architect 决定，理由见 §6）。仅新增本报告、更新根交接、写入私密基线证据 `.ai/build/stage04-dsh-takeover-20261009/`。未 `git commit`/推送、未派发工作流、未付费/续租、未改账户或安全设置、未触碰 Stage05 文件、未动 `.ai/build` 既有私密材料。

---

## 1. 核验方法与范围

读取：规格、实现任务、[实现报告](STAGE-04-IMPLEMENTATION-2026-10-09.md)、[本地Review](../reviews/STAGE-04-LOCAL-REVIEW-2026-10-09.md)、[验收](../acceptance/STAGE-04.md)，以及实际代码：`CollageLayout.swift`、`CollageLayoutSheet.swift`、`PhotoImportModel`（`.layout`/`.save` 意图、原子失败与重试）、`RootView`/`AppRoute`/`AppNavigationModelTests`、`EditorPlaceholderView`（Layouts 入口）、`Stage04LayoutTests`、`Stage04StorageTests`、`Stage04LayoutUITests`、`stage04-tests.yml`、`stage04-device.yml`，并回溯 `CanvasGeometry`/`CanvasEditor`/`Layer`/`CanvasDocument`/`ImportedPhoto`/`ProjectPackage`/`PhotoLibrary`（含写入路径与 `PhotoLibraryPathGuard`）。

执行（本机 Windows，详见 §3）：工程接线校验、Stage04 工作流自带的清单步骤实跑、10 个 Stage04 Swift 文件的语法树解析、`git` 精确差异核对、逐文件与聚合 SHA256。

**未重新执行** Architect 已做过的完整 YAML/Bash/11 段内嵌 Python 全量语法扫描（任务要求不重跑未变更的完整静态检查）。本机**无 Swift/Xcode 工具链**（实测 `swift`/`swiftc` 不存在），因此**没有任何 Swift 类型检查或 XCTest 执行**。

## 2. 逐项核验结论

### 2.1 编译类型与 actor isolation（静态阅读，未编译器验证）
- 新增 `CollagePreset`/`CollageLayout`/`CollageLayoutError` 为纯 Foundation、非 actor 隔离；只依赖同模块已存在的 `CanvasDocument`/`Layer`/`ImportedPhoto`/`CanvasGeometry`/`CanvasEditor`/`ProjectPackage` 常量。未引入新依赖、包拆分或空接口。
- `CollageLayoutSheet` 标 `@MainActor`，只经 `ProjectStore`/`PhotoImportModel`/`AppNavigationModel` 三个既有环境对象读写；`RootView` 在 `.sheet` 上显式注入这三个对象（与 Stage02 修过的 modal 环境缺口同一处理方式）。
- `Stage04LayoutTests` 只调用非隔离纯函数，无需 `@MainActor`；`Stage04StorageTests` 的 4 个方法均标 `@MainActor`（与 Stage03 已原生通过的模式一致），辅助 `package(_:)` 为异步且只经 `PhotoLibrary` actor。
- 结论：未发现类型/隔离阻断。**但这不是类型的证明**——只有真实 `xcodebuild` 能确认。

### 2.2 布局边界（几何推演 + 既有断言核对）
- 完整等比例容纳：`fittedTransform` 以 `min(cell.w·fill/rotatedW, cell.h·fill/rotatedH)` 求 scale，宽高比恒等不变（测试对 1…20 张逐张核 `base.w/base.h == display 比例`）。
- 旋转边界：Offset 旋转 ±5°，按旋转后 AABB 取 90% 格内适配并叠加 ≤3%/2.5% 中心错位 → 距格中心最大 0.45+0.03（宽）与 0.45+0.025（高），**始终 < 0.5**，即旋转后仍完整落在所属格内，且格与格之间有 `gap` 分隔 → 不重叠。
- 网格枚举 1…N 列，取“照片占面积和”最大的可行网格，末行按实际列数居中；`score > best + 1e-12` 保证**同分保留最早枚举**；某列数使任一照片不可行则跳过该列数；全部不可行才抛 `cannotFit`。
- 范围：`fitScale < 0.1` 直接拒绝（不 clamp 越界）；上界 `min(fitScale, 8)`（见 §6-O3）；位置为格中心（≥5% 画布边距内），不越画布；不裁切、不拉伸。
- 空画布按导入顺序建层，已有画布只重排 `isBoundToAsset && !isHidden && !isLocked` 的层；未使用的库内照片不偷偷加回。

### 2.3 保留锁定/隐藏/身份/baseSize/堆叠/不透明度/数组顺序
`arrange` 从输入文档复制后再只写被重排层的 `.transform`：`result.layers.indices` 中仅命中 `transforms` 的条目被改写；`id`、`assetID`、`baseSize`、`opacity`、`zIndex`、数组顺序、锁定/隐藏/历史未绑定层全部原样。若绑定层的素材不在传入照片列表则 `invalidPhoto`（不静默丢弃）。测试逐字段断言了这些保护值，我逐条与实现对照一致。

### 2.4 重复 Apply 不增层
空画布分支只在 `layers.isEmpty` 时执行，并固定 `layerID = photo.id`（无 `UUID()`、无随机）→ 预览/应用/重试完全一致；第二次应用走“已有层只重排”分支 → 层数不变、文档逐字节等价（新增单测断言 `first == second`）。已有画布上传入 21 张素材也不回填，仅按上限拒绝。

### 2.5 原子保存、失败分类与重试
- `applyCanvasIntent(.layout(preset))` 复用 `editCanvas` → `performEdit`：单一 `mutationToken` 门槛、`library.saveEdit` 先 `validatePackageEntry` 再原子写 manifest、成功后 `store.apply`。
- 分类正确：布局校验错误（`CollageLayoutError`）→ `rejected` + `editMessage`，**不产生失败草稿、不写盘**；真正的文件写入错误 → `saveFailed` + 保留 `CanvasDraft(.layout(...))`。
- 重试路径 `retryFailedDraft` 对**最新** committed 文档重跑 `CollageLayout.arrange`，因此新的锁定/隐藏状态生效，不回放过期整文档（存储测试用“先失败 → 写入一个更晚的已锁定层 → Retry”证明）。
- 失败保持旧盘：`PhotoLibraryPathGuard.resolve` 对**每一个已存在路径分量（含末段）**拒绝符号链接，因此存储测试用 manifest 符号链接制造的失败发生在任何字节改写之前；`writeManifest` 的 `.atomic` 写入保证不会留下半截文件。

### 2.6 三预览、搜索、取消与可访问性
- 三个预设各自渲染本人照片的只读预览：复用 `EditorCanvasView`，`selectedLayerID: .constant(nil)`、`isEditingDisabled: true`、`.allowsHitTesting(false)`，只用 320 缩略图（`selectedLayerID` 为 nil ⇒ 不加载 2048 预览），图像 I/O 仍在既有 actor。
- 预览外层 `.accessibilityElement(children: .ignore)` + 自有标签与标识，避免三个重复的编辑器画布标识外泄（该点只有真机能最终确认，见 §4/§6-O4）。
- 每项有标题、差异描述、预览、选择按钮（≥44pt）与 `Selected/Not selected` 可访问值；搜索覆盖内置中英文关键词、无结果有 `layout.noResults` 与 `layout.clearSearch`、**搜索不重置所选**；`Cancel` 不写盘；`Apply` 仅在所选预设对当前文档可排版且不忙时可用；保存中禁用 Cancel/冲突控件并 `interactiveDismissDisabled`；失败显示真实错误与 Retry/Discard，不静默丢稿。
- `editor.layouts` 入口位于既有滚动容器内、画布手势区之外，无照片/未就绪/忙时禁用。

### 2.7 公开契约与依赖
`git diff -- MomentsStudio/MomentsStudio/Models` **为空**（无 Codable 字段增删改名）；`ProjectPackage.currentSchemaVersion`、schema1 兼容、原图与既有资产路径均未触碰；`CollagePreset`/`CollageLayout` 不 Codable、不持久化；零新增运行期依赖。

### 2.8 工作流入口
- `stage04-tests.yml`（42323 bytes，709 行）：仅 `workflow_dispatch`、`contents: read`、checkout 不存凭据、`macos-26`、30 分钟、产物保留 2 天；边界 **146 unit + 9 UI = 155**；测试前用标准库生成方法清单与逐文件 SHA256 并核 scheme 的两个 testable、逐文件方法数；原生门禁在缺 manifest / 缺 summary / 非 155/155/0/0/0 / 设备不匹配时一律失败，且门禁计数绑定 `GITHUB_ENV` 里清单实算值；运行完整 scheme（无 `-only-testing`/skip/retry）；保留 log/xcresult/附件导出、内容字号与外观的设置-读回-测试后读回-还原；证据守卫保留早期失败诊断并写 `SOURCE_MANIFEST_MISSING/NOT_VERIFIED`（不因缺清单丢日志、也不因此转绿），凭据类文件与来源不明媒体仍拒传。
- `stage04-device.yml`（5484 bytes，102 行）：手动无签名设备 Release 构建 + Info.plist/iPhoneOS/arm64/Mach-O/IPA Payload 校验 + 允许清单与 ≤100MiB 证据守卫；明示不是设备测试或本人验收。
- **Stage01/02/03 工作流逐字未改**（`git status` 只新增两份 Stage04 工作流）。

## 3. 实际执行的本机检查与真实输出

| 检查 | 命令/方式 | 结果 |
| --- | --- | --- |
| 工程接线 | `python tools/verify_project.py` | **PASS**：154 objects、52 文件引用、Sources 覆盖 31/15/5、51 Swift 11636 行、15 个 UI 标识符解析、App 声明 60 个 |
| Stage04 清单步骤（工作流自带同一段内嵌代码，本机实跑） | 提取 `stage04-tests.yml` 的 heredoc 后运行 | **rc=0**，`stage04 manifest: unit=146 ui=9 total=155`，`manifest_sha256=375696b27fe962c4877fc37421565aab89d5e6149c59b2cc75be224c16bbf542` |
| 语法树 | tree-sitter + tree_sitter_swift，10 个 Stage04 Swift 文件 | **每文件 0 个 ERROR/missing 节点** |
| 差异范围 | `git diff --stat` / `git status --porcelain` | 见 §5.1；除导航新增 1 测外**无旧测试文件改动**，**无 Models 改动**，**无 Stage01–03 工作流改动** |
| 源基线 | 51 个 Swift 文件逐文件 SHA256 + 聚合 | 聚合 `3a560ab15f3c31b9b38f2ec469803386561cc2bb49a7f3358f90a6b36344c227` |

私密证据目录 `.ai/build/stage04-dsh-takeover-20261009/`：`test-manifest.txt`、`test-methods.txt`、`test-source-hashes.txt`、`test-method-counts.txt`、`env-values.txt`、`project-wiring.txt`、`swift-source-hashes.txt`、`BASELINE.txt`、`HOW-THESE-WERE-PRODUCED.txt`（明示是编码清单与源哈希，**不是** XCTest 结果）。

## 4. 未执行 / 不得冒充

- **没有任何原生结果**：无 Xcode 编译、无 XCTest（155 项未运行）、无模拟器/真机、无 Stage04 IPA/签名/安装、无本人验收；手机仍是 Stage03 包。
- 本机无 Swift 工具链 ⇒ 类型检查、actor 隔离错误、真实运行期行为（预览标识是否真的不外泄、`layout.scroll` 是否作为 ScrollView 暴露、搜索字段与键盘交互、真实照片渲染视觉）**均未验证**。
- 未核 GitHub 免费额度、未提交/推送、未派发工作流、未产生费用；未触碰 Stage05 规格/任务文件。
- §2 的结论是**源码级核验**，不等于 Stage04 通过或可运行。

## 5. 基线

### 5.1 Stage04 差异范围（相对 HEAD `14eb1b6`）

跟踪文件修改：`MomentsStudio.xcodeproj/project.pbxproj`(+60)、`App/RootView.swift`(+2)、`Core/Navigation/AppRoute.swift`(+1)、`Features/Editor/EditorPlaceholderView.swift`(+8)、`Features/PhotoImport/PhotoImportModel.swift`(+12)、`MomentsStudioTests/AppNavigationModelTests.swift`(+13)、`MomentsStudio/README.md`(+42/−5)。
新增未跟踪：`Models/CollageLayout.swift`、`Features/Editor/CollageLayoutSheet.swift`、`MomentsStudioTests/Stage04LayoutTests.swift`、`MomentsStudioTests/Stage04StorageTests.swift`、`MomentsStudioUITests/Stage04LayoutUITests.swift`、`.github/workflows/stage04-tests.yml`、`.github/workflows/stage04-device.yml`。

关键文件 SHA256：CollageLayout.swift `996159fc…0cc7`、CollageLayoutSheet.swift `9a0c5837…51f2`、EditorPlaceholderView.swift `46a6bbec…2213`、PhotoImportModel.swift `3efce0d2…4616`、RootView.swift `1f489224…e09d`、AppRoute.swift `90f56371…9a06`、Stage04LayoutTests.swift `b4f33057…f0ea`、Stage04StorageTests.swift `6b740b27…dc10`、Stage04LayoutUITests.swift `50f7de04…9fda`、AppNavigationModelTests.swift `c58719f0…7aa9`、stage04-tests.yml `1a0f19d0…e4e`、stage04-device.yml `95719815…3a77`。

### 5.2 测试方法清单（实际源码，146 unit + 9 UI = 155；**编码清单，未运行**）

| Target / 文件 | 方法数 |
| --- | --- |
| unit `AppNavigationModelTests` | 6（含 Stage04 新增 1） |
| unit `CanvasDocumentTests` | 3 |
| unit `LargePhotoBatchTests` | 2 |
| unit `LayerModelTests` | 9 |
| unit `PhotoImportModelTests` | 6 |
| unit `PhotoLibraryTests` | 31 |
| unit `ProjectModelTests` | 5 |
| unit `ProjectPackageTests` | 8 |
| unit `ProjectStoreTests` | 11 |
| unit `Stage03ContractTests` | 34 |
| unit `Stage03StorageCoordinatorTests` | 16 |
| unit **`Stage04LayoutTests`** | **11** |
| unit **`Stage04StorageTests`** | **4** |
| unit `SyntheticImageFactory` / `TestGate`（支持文件） | 0 / 0 |
| UI `Stage01SmokeUITests` | 2 |
| UI `Stage02ImportUITests` | 3（旧 99 断言保持） |
| UI `Stage03CanvasUITests` | 3 |
| UI **`Stage04LayoutUITests`** | **1** |
| UI `UITestSupport`（helper） | 0 |

旧 138 项（130 unit + 8 UI）完整保留：相对 HEAD 唯一被改动的测试文件是 `AppNavigationModelTests.swift`（+1 新方法），其余测试文件与 Stage01–03 工作流逐字未动。

### 5.3 源文件清单
51 个 Swift 文件（app 31 / unit 15 / UI 5）的逐文件 SHA256 与聚合哈希见 `.ai/build/stage04-dsh-takeover-20261009/swift-source-hashes.txt`（聚合 `3a560ab15f3c31b9b38f2ec469803386561cc2bb49a7f3358f90a6b36344c227`）。

## 6. 观察与建议（交 Architect 决定，本轮未改）

- **O1（规格/验收措辞，建议 Architect 定）**：`editor.layouts` 在项目**无照片**时禁用（EditorPlaceholderView 入口条件含 `photos.isEmpty`），因此 sheet 内 `.noPhotos` 的“导入照片后再选布局”说明无法从 UI 到达。[验收清单](../acceptance/STAGE-04.md)第 6 条要求“无照片、全部层不可排列、非法几何有真实反馈”：后两者**可达**（sheet 打开后逐项显示 `noEditableLayers`/`cannotFit`），仅“无照片”这一支只剩编辑器 Add-to-canvas 区的 “Import a photo first, then add it to the canvas.” 与禁用按钮。建议二选一：(i) 认为该既有文案即真实反馈，把口径写进规格；(ii) 若要求布局自身的说明，我可做最小增补（Layouts 按钮下加一行仅 `photos.isEmpty` 时显示的 caption + 标识符，纯增量、不动行为/测试/契约），本轮未擅自改。
- **O2（语义确认）**：Focus 的“第一张”取 `orderedBackToFront` 的首层——空画布即**导入顺序第一张**（Stage04 主流程）；已有画布则是**最底层**而非层列表最上方那一层。确定性且已被测试覆盖，但规格未定义“第一张”。建议确认是否希望改为“最上层/最近添加”。
- **O3（显式解释）**：`fittedTransform` 在 `fitScale > 8` 时按下取 8（而非拒绝），因此极小历史 `baseSize` 的层会小于其格但不越界、不裁切；这与“维持 0.1…8 范围”一致，与“不用 clamp 掩盖越界”也不冲突（不放大、不外溢）。建议在规格或注释中固化该解释。
- **O4（验证缺口，不建议现在改）**：规格要求“避免三个重复的编辑器 canvas 标识泄漏到选择页面”，实现用 `.accessibilityElement(children: .ignore)` 处理，但 UI smoke 未断言 sheet 打开时不存在 `editor.canvas` / `editor.canvasSurface`。我可加一行断言，但本机无法验证 SwiftUI 的可访问性合并行为；考虑到**当前只获批一次原生运行**，我不在无法验证的断言上冒险，交 Architect 决定是否在原生运行中顺带核对。
- **O5（能力边界）**：Windows 无 Swift 工具链，本轮全部结论建立在源码阅读、语法解析、工程接线与几何推演上；首次 `xcodebuild` 仍是唯一的类型/运行证明。

## 7. 状态

- 本轮本地核验完成，**停在 READY_FOR_ARCHITECT_REVIEW**，等待 Architect 独立复审差异与本报告；Stage04 **未 APPROVED**、未转 WAITING_FOR_USER。
- 本轮**未修改 Stage05 任何文件**；Stage05 实施任务待 Architect 在 Stage04 技术检查点留存后按已获授权发送。
- 未提交/推送/派发/付费、未改账户安全；私密 `.ai/build` 与无关未提交文件均保留。
