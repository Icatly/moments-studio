# Stage05 本地实现报告 — 2026-10-10

角色：DSH（Implementation Engineer，实施/工程/测试）；Architect 负责规格与独立 Review，不代写实现。授权：所有者 2026-10-09“把 stage04 和 stage05 都做了”；Stage04 技术检查点已留存（[STAGE-04-DSH-CHECKPOINT-2026-10-10](../reviews/STAGE-04-DSH-CHECKPOINT-2026-10-10.md)），Stage04 冻结基线 commit `edeca4ddaba03c727a7779bbbf042d899e408222`。范围：[STAGE-05-PHOTO-ANALYSIS](../../docs/architecture/STAGE-05-PHOTO-ANALYSIS.md)、[任务](../tasks/STAGE-05-IMPLEMENT-01.md)。

**状态：READY_FOR_ARCHITECT_REVIEW。** 本报告覆盖首版本地实现与 Review FIX01–FIX06。**首次 Stage05 原生运行 `37964463618` 已真实发生且失败**：设备 App Release 编译通过，但 UI test target **编译失败、0 项测试执行**（见 §FIX06），修复后**尚未重新原生运行**；**没有** 新 IPA/真机/本人验收，也没有 git 提交/推送、工作流派发、付费或账户设置更改。Stage06 未开始。Stage04 原生 run `37957684567` 的输入只有冻结 commit `edeca4d`；Stage05 run `37964463618` 的输入是 commit `bc166d4517b9bced0f10e01b0240fd6ad4695543`，均与本文档的当前工作树不同。

## 0. 补正（Review FIX01–FIX06，2026-10-10）

Architect 独立复审首版后提出四项问题（[FIX01](../tasks/STAGE-05-REVIEW-FIX-01.md)），第二轮复审又提出四项（[FIX02](../tasks/STAGE-05-REVIEW-FIX-02.md)）。两轮都在批准边界内最小修复：**未改**公开 Codable 字段/schema2、未放宽任何旧 155 项断言、未改 Stage04 两个冻结工作流、未加生产测试入口或空服务。**历史时点说明**：FIX01/FIX02 当时确实**未改**既有共享 `UITestSupport.swift`；FIX03 依据真实失败 A 才最小修改该共享 helper（`prepareEditorGallery` 有界慢拖实例化 lazy 图库），此后它不再属于“未改”清单，见 §FIX03 与 §1。

### FIX01（已完成）

1. **异步过期身份检查走真实 UI 路径**：新增 `PhotoAnalysisRun` 值类型，sheet 的写回与显示都只经它；`restart()`/`invalidate()` 清空结果并作废旧 token。新增 `Stage05AnalysisRunTests` 直接测该 guard。
2. **UI 测试容器类型**：`analysis.row.` 用 `descendants(matching: .any)` 前缀查真实 `.contain` 容器，并断言它不是 `staticTexts`、恰好 1 行、行 asset 身份与估计行一致。
3. **弱采样提示保持用户语言**：UI 只显示 “Not much visible detail to measure here — treat this as a rough estimate.”；像素数/coverage/阈值留在 `PhotoAnalysis.confidenceExplanation`、报告与测试。
4. **严格 sRGB 与守卫/边界实证**：sRGB 颜色空间创建失败抛类型化 `.unreadable`（不静默回退 DeviceRGB）；新增真实 thumbnail 符号链接拒绝与 `PhotoLibraryPathGuard` 越界引用回归；新增 alpha 门槛 12/13 边界数值回归。

### FIX02（已完成；计数见下方 FIX03）

1. **编译阻断**：`Stage05PhotoSummaryUITests` 同作用域重复 `let row` → 分别为 `projectRow`（Home 行）与 `analysisRow`（分析行容器），所有断言保留。
2. **保留真实门槛、去掉重复滚动**：删除 `tapFullyVisible` 里丢结果的 `_ = scrollEditorToMakeHittable(...)`、追加的最多 4 次全屏 swipe 与镜像的 `isFullyVisible`/viewport helper；改为 `tapEditorControl`：**要求既有共享 `scrollEditorToMakeHittable` 返回 true**（它自带 nav 裁切与有限正 frame 门槛），再 `waitUntilEnabledAndHittable` 后 tap。该轮**当时**未改 `UITestSupport.swift`、既有 smoke 行为断言未删（FIX03 才最小修改该共享 helper 的图库实例化一段）。
3. **取消与项目身份完整接线**（`PhotoAnalysisRun`）：
   - `accept`/`reject`/`measurement(for:)`/`failure(for:)` 都新增并核 **`currentProjectID`**（sheet 当前呈现的 project）；同一 run 用另一个 currentProjectID 的成功与失败都被拒，读取也返回 nil；
   - `accept` 还核 **测量结果的 `assetID` 与 display 尺寸**必须等于该照片的身份与 `displayPixelSize`，错 asset / 错尺寸结果一律拒绝（旋转照片的 display 尺寸是交换的，未旋转值也会被拒）；
   - `invalidate()` 在**关闭**与**重算**的用户动作里同步调用（`.onDisappear`、`Analyze again` 按钮），不依赖新 task 开始才失效；`startRun` 不再自己轮换/清空 token，因此**过期的旧任务不可能清空或写回新 state**；
   - `startRun` 与每次 await 之后都显式检查 `Task.isCancelled`、`run.token`、`isSheetCurrent`（当前呈现 project + 项目仍存在）。
4. **测试 fixture 与回归**：`Stage05AnalysisRunTests` 的 `analysis` helper 改为**按传入 metadata 生成**（不再硬填 320×240），并新增回归：错 asset/错 display 尺寸被拒、切换 `currentProjectID` 拒绝成功与失败、`invalidate()` 后旧 token 不能写且值立即消失、旧尺寸结果不得作为新 metadata 结果读取。

### FIX03（已完成）

1. **Stage02 图库实例化（真实失败 A）**：`Stage02ImportUITests:155` 的 `prepareEditorGallery` 只把 `photoCount` 滚进窗口（y=852.3/874），其下方 lazy 图库尚未实例化，thumbnail 节点不存在。最小修改**既有共享 helper**（`UITestSupport.swift`）：保留唯一编辑器滚动/count==1/picker-preview 不在场/有限正 frame/nav 裁切，追加**有界慢速真实拖拽**（≤6 次，从 count 向下）直到图库网格出现；helper 本身不断言 thumbnail，Stage02 原存在/身份/完整视口可点/预览/删除断言全部保留，未加等候、未加生产测试开关。
2. **Stage04 搜索键盘遮挡（真实失败 B）**：搜索 `OFFSET` 后键盘仍活跃，`layout.choose.offset` 虽在 `layout.scroll` 内但被键盘覆盖不可点。产品侧最小修复：`CollageLayoutSheet` 增加 `.onSubmit(of: .search) { dismissSearch() }`，真实搜索提交即结束搜索交互收起键盘（过滤/已选/Apply 语义不变）。测试侧 `Stage04LayoutUITests.tapChoice` 改为按 **layout.scroll ∩ 窗口 − nav − 真实键盘** 的可用视口判定与有界拖拽，并在两次输入后用 `submitSearch`（键盘 Search 键）收键盘；搜索过滤、无结果、已选保留、清搜索、重复 Apply 层 ID/变换/重启断言全部保留，未做坐标穿透、未跳过 hittable、未盲滑。
3. **同名成员编译阻断**：`PhotoAnalysisSheet` 中两个同名 `isSheetCurrent` 计算属性 → 删除重复（保留基于 `presentedProjectID` 的那一个）；并新增**静态重复成员扫描**（tree-sitter 解析全部 57 个 Swift 文件，按“名称+完整参数列表”判定，合法重载不误报）：**0 处重复**。
4. **请求生命周期（token 不再复用）**：新增 `PhotoAnalysisRun.beginRequest(taskKey:currentTaskKey:isSheetCurrent:)`——**每个真实新 task** 在确认自身未被取消、捕获的任务键仍是当前键、sheet 仍当前之后，才**原子**产生新 token 并清空旧值；过期 task 的 `beginRequest` 返回 nil，既不能轮换/清空新 state，其 `defer` 也不能把新 `isRunning` 改回 false。`startRun` 校验 `run.projectID == projectID`；`Analyze again` 与 `.onDisappear` 仍先即时 `invalidate()`（关闭即失效）兜底，`analyze` 每次 await 后核对取消/token/当前 sheet/**捕获的任务键**。`Stage05AnalysisRunTests` 新增 3 项（`beginRequest` 当前键/当前 sheet、新 metadata 换新 token 且旧 token 拒写、过期任务不能清新 state）→ 该文件 11 项。

### FIX04（本轮，最终冻结前）

1. **搜索结束改为激活绑定**：删除外层 `@Environment(\.dismissSearch)`（`searchable` 在内层 ScrollView，该环境不向上传递；即便生效也会清空 `query`）。改为 iOS 17 的 `searchable(text:isPresented:placement:prompt:)` + `@State searchIsPresented`，`.onSubmit(of: .search)` 里置 `false`：同一视图内的状态写入结束搜索激活、收起键盘，**不清 query**，`OFFSET` 过滤与无结果状态保留。UI 测试在每次 submit 后新增断言：`layout.choose.offset` 仍在、`layout.choose.grid` 仍被过滤掉（提交没有清查询）；重进搜索仍可改关键词。
2. **Close 立即失效**：`dismissIfCurrent()` 在询问 route 之前同步 `run.invalidate()`（Close 当前 sheet 动作即时失效），`.onDisappear` 继续兜底；项目切换沿用既有 `SheetRoute.id`（同槽位不同 projectID 即新 sheet 视图），未加新抽象。
3. **Stage04 viewport 几何加固**：`usableViewport` 要求 **唯一** `layout.scroll` + 唯一 sheet nav，并对 scroll/app/nav/keyboard/目标 frame 全部做 finite-positive 校验（失败即 `XCTFail`，不猜）；可用视口按实际 nav/keyboard 交叠裁剪；`tapChoice` 的拖拽端点改为**真实视口点**（`app.coordinate(...).withOffset(...)`），目标已在视口内却不可点则显式失败并记录，不再按被遮挡 scroll 的百分比盲拖；共享 `scrollEditorToMakeHittable` 与 gallery 有界实例化修复保持，原断言全部保留。
4. **Stage05 设备工具链与阶段统一**：`stage05-device.yml` 由 `macos-15` 改标准 **`macos-26`**（免费标准 runner，不用 larger），新增与测试入口一致的 **Xcode 26+/iphoneos SDK 26+ 枚举/选择/记录**步骤（`xcode-candidates.txt`/`xcode-selection.txt` 入证据并写入 `DEVELOPER_DIR`/`SELECTED_XCODE_PATH`），清理 `Stage04DeviceDerivedData`/`Stage04DevicePayload`/`stage04_device_app` 等误留命名，补充证据允许清单；**6 分钟/2 天/手动/无签名不变**，不运行 XCTest。Stage04 两个冻结工作流未改。

### FIX05（2026-10-10 01:06 实施，冻结前小范围；只改 1 个测试文件）

范围来自 [交接 FIX05](../tasks/STAGE-04-05-DSH-CONTEXT-HANDOFF-2026-10-10.md) 及所有者补充口径：**不新增**未经原生验证的传播假设。

1. **导航精确 scope（不再数全 App）**：删除 FIX04 的 `app.navigationBars.count == 1` 门槛（该断言不在冻结 edeca4d 的 155 项内，且与 Editor 背后合法存在的 bar 冲突）。改为用该 sheet 已有的真实 `navigationTitle("Layouts")` 定位对应导航栏：`app.navigationBars.matching(identifier: "Layouts")`，要求恰 1 个，并核它的 `label == "Layouts"` 且自身拥有 `layout.cancel`/`layout.apply` 工具栏项。`app.navigationBars.count` 不再参与任何判定。
2. **不发明新 AX 标识**：曾试在 `CollageLayoutSheet` 的 `NavigationStack` 上加 `layout.navigationBar`，按所有者补充**已回退**——该传播未经原生验证，产品文件回到 FIX04 后字节（8955 bytes / `c0cc666f4dacd7e6`），本轮产品代码零改动，仅有既存的 `searchable(isPresented:)` 与 `.onSubmit` FIX04 改动。
3. **拖拽相对 `layout.scroll` 归一化**：不再用 `app.coordinate(...).withOffset(绝对屏幕几何)`（app 起点可能非原点）。视口端点先按 `(point − scrollFrame.min) / scrollFrame.size` 换算为 `layout.scroll` 的归一化坐标再 `scroll.coordinate(withNormalizedOffset:)` 拖拽；三个归一化值必须在 `0...1` 内，否则显式失败。保留慢速/最多 5 次/端点范围验证/目标已在视口却不可点即失败；`layout.scroll` 仍要求唯一，所有 finite-positive 校验保留。
4. **旧断言全部保留**：`testThreePreviewsSearchCancelApplyAndRestartKeepExactLayer` 仍为唯一测试方法；43 `XCTAssertTrue` / 3 `XCTAssertFalse` / 6 `XCTAssertEqual` / 2 `XCTUnwrap` / 10 `XCTFail`，含三预览存在、Apply 初始禁用、Cancel 后 0 层、OFFSET 过滤与提交不清 query、无结果、已选保留、清搜索、重复 Apply 层 ID 与 transform 不变、Done 重开恢复等原断言；未删/未跳过任何断言。

**FIX05 静态检查（本机实跑）**：`verify_project.py` **PASS**（166 objects、58 refs、Sources 33/18/6 = 57 Swift **13567 行**、17 个 UI 标识符解析、App 声明 **74**——已回到未加 `layout.navigationBar` 的数值）；tree-sitter 重解析 **57/57 文件 0 ERROR**；同父节点重复声明扫描 **0 处**；复算 stage05 清单 **unit=176 ui=10 total=186**，逐文件方法数与冻结期望表一致（Stage04LayoutUITests 仍为 1 个 UI 方法）。当前源聚合 SHA256（57 Swift 逐文件哈希按路径序再哈希）`5da07b10cf4e1e0d…f63c12c9`，被改文件 `Stage04LayoutUITests.swift` 15759 bytes / `376df73e50c3cc81…f72768922`。清单 SHA 会随改动的源码哈希变化，不作为通过依据。

### FIX06（2026-10-10 01:2x，首次 Stage05 原生运行后的编译冲突；只重命名 1 个本地 helper）

**首次 Stage05 原生运行实际结果**：[run 37964463618](https://github.com/Icatly/moments-studio/actions/runs/37964463618)（`Stage 05 Xcode 26 native test run`，source `bc166d4517b9bced0f10e01b0240fd6ad4695543`，completed / **failure**）：
- **设备 App Release 编译通过**：`xcodebuild-device.log` 有 `** BUILD SUCCEEDED **`（无新 IPA、未签名、无本人验收）。
- **XCTest target 在编译阶段失败，测试根本没开始执行**：`test-summary.json` 为 `result=unknown`、`totalTestCount=0`、passed/failed/skipped 全 0；这是 **0 项执行**，不是“0 失败通过”。
- 原始失败行（私密证据 `.ai/build/stage05-run-37964463618-20261010-012020/evidence/xcodebuild-test.log:696-709`）：
  - `Stage04LayoutUITests.swift:23:18: error: overriding instance method must be as accessible as the declaration it overrides`
  - `Stage04LayoutUITests.swift:23:18: error: overriding declaration requires an 'override' keyword`
  - note：`UITestSupport.swift:333:10: note: overridden declaration is here` → `func isFinitePositive(_ frame: CGRect) -> Bool`

**根因（按原始 note 更正）**：冲突来自**本仓库** `UITestSupport.swift:333` 的 `extension XCTestCase` 共享方法 `isFinitePositive(_:)`（internal），不是 SDK 新 API。`Stage04LayoutUITests` 内的 `private func isFinitePositive(_ rect: CGRect)` 因此被编译器当作对继承成员的非法 override（private 且无 `override`）。

**唯一改动**（允许范围内，`Stage04LayoutUITests.swift`）：把该**本地**私有 helper 重命名为 `layoutFrameIsFiniteAndPositive`，并更新全部 6 处调用（`:55`×2、`:62`、`:83`、`:92`、`:121`、`:138`）。**未**加 `override`、**未**改函数体、**未**改断言/viewport/导航/搜索/拖拽/计数，**未**改共享 `UITestSupport.swift`（仍 42130 bytes / `222f5f0092829230`），**未**改其他源码或任何工作流；方法总数仍 186。该文件 15871 bytes / `3e6c48616492887c…c62e55a`（FIX05 时为 15759）。

**证明“只是改名”**：基线为 Architect 已冻结推送的 `bc166d4`（`git show HEAD:…Stage04LayoutUITests.swift` = 15759 bytes / `376df73e50c3cc81…`，`isFinitePositive` 8 次、`layoutFrameIsFiniteAndPositive` 0 次）。把 HEAD 版的 `isFinitePositive` 与工作树的 `layoutFrameIsFiniteAndPositive` 都归一化为同一占位名后，两份文本**逐字节相同**（归一化 SHA256 均为 `d780fc2ca9725138…ec45e1b`，8 处对 8 处，272 行对 272 行）：除该标识符外**没有任何文本变化**。

**FIX06 本机核验（实跑）**：`verify_project.py` **PASS**（166 objects、58 refs、Sources 33/18/6 = 57 Swift **13567 行**、17 个 UI 标识符解析、App 声明 74）；tree-sitter 重解析 **57/57 文件 0 ERROR**；同父节点重复声明 **0 处**；**跨文件 helper 冲突扫描 0 处**（即 UI test 目录内已无与 `UITestSupport.swift` 扩展成员同名同签名的本地 helper —— 正是本次编译错误的那类冲突）；复算清单 **unit=176 + ui=10 = 186**、逐文件与冻结期望表一致；scheme 两个 testable 均不 skip。被改文件 `Stage04LayoutUITests.swift` 15871 bytes / `3e6c48616492887c…c62e55a`；共享 `UITestSupport.swift` 42130 bytes / `222f5f0092829230`、`CollageLayoutSheet.swift` 8955 bytes / `c0cc666f4dacd7e6` 均未变。当前源聚合 **`9c26ce92223c579a…f3a0295`**。**未执行**：任何原生 XCTest（本机无 Xcode/模拟器/`swift`），无新 IPA、无本人验收；新原生 run 由 Architect 组织。

**当前计数（FIX06 为准）**：Stage05 测试 4 个文件、31 个方法（11 + 8 + 11 unit + 1 UI）；全工程 **176 unit + 10 UI = 186**，其中 Stage01–04 的 155 项与断言不变。下方 §1/§4/§5 已按本轮实际值更新（FIX01 首版的 172 与旧哈希不再引用）。

---

## 1. 交付物（本轮实际改动）

新增：

| 文件 | bytes | SHA256(前16) | 作用 |
| --- | --- | --- | --- |
| `MomentsStudio/MomentsStudio/Services/PhotoAnalyzer.swift` | 11871 | `7ff5f4dcee8d7790` | 纯 CoreGraphics/Foundation 有界采样统计、严格 sRGB、`PhotoAnalysis`/失败类型/置信度/三档估计 |
| `MomentsStudio/MomentsStudio/Features/Editor/CollageLayoutSheet.swift` | 8955 | `c0cc666f4dacd7e6` | 三预设 sheet + `searchable(isPresented:)`/提交置 false（收键盘且不清 query） |
| `MomentsStudio/MomentsStudioUITests/UITestSupport.swift` | 42130 | `222f5f0092829230` | 既有共享 helper：`prepareEditorGallery` 有界慢拖实例化 lazy 图库（原断言不变） |
| `MomentsStudio/MomentsStudioUITests/Stage04LayoutUITests.swift` | 15871 | `3e6c48616492887c` | 可用视口有限/`layout.scroll` 与 `Layouts` sheet 各自唯一校验 + 视口端点换算为相对 `layout.scroll` 的归一化拖拽 + 搜索提交保留过滤（断言全保留；FIX05 视口/拖拽 + **FIX06 本地 helper 改名**后的字节/哈希） |
| `MomentsStudio/MomentsStudio/Features/PhotoImport/PhotoAnalysisSheet.swift` | 19360 | `6ccbedb2c6848c75` | Photo summary sheet + `PhotoAnalysisRun` 身份/请求 guard（currentProjectID、取消/关闭/重算即时失效、asset/尺寸核对）、用户语言提示 |
| `MomentsStudio/MomentsStudioTests/Stage05PhotoAnalysisTests.swift` | 12217 | `858a3787fa19afde` | 11 项纯统计测试（真实 CGImage，明确容差，含 alpha 12/13 边界） |
| `MomentsStudio/MomentsStudioTests/Stage05AnalysisStorageTests.swift` | 13158 | `9e58731314502fad` | 8 项真实文件/actor/桥接测试（含符号链接与越界路径守卫） |
| `MomentsStudio/MomentsStudioTests/Stage05AnalysisRunTests.swift` | 19035 | `f42280853869ff07` | 11 项身份/请求 guard 回归（错 asset/尺寸、currentProjectID、invalidate、metadata 变化、beginRequest 请求身份） |
| `MomentsStudio/MomentsStudioUITests/Stage05PhotoSummaryUITests.swift` | 7012 | `534f935d66686562` | 1 项真实导入→summary→结果→重算→关闭→重开 UI smoke（共享可见门槛 + 容器查询） |
| `.github/workflows/stage05-tests.yml` | 43761 | `5469b49688528b4c` | 手动原生测试入口（完整 186 项） |
| `.github/workflows/stage05-device.yml` | 9907 | `daf6e95ed9279b08` | 手动无签名设备包入口：macos-26 + Xcode 26+/SDK 26+ 选择记录，6 分钟/2 天，不跑 XCTest |

修改（沿用既有边界，未改公开契约）：

| 文件 | 改动 |
| --- | --- |
| `Services/PhotoLibrary.swift` | 新增只读 `analyzePhoto(projectID:assetID:)` + 分析专用取消检查（+66 行） |
| `Features/PhotoImport/PhotoImportModel.swift` | 新增只读异步桥接 `analyzePhoto(projectID:assetID:)`（+15 行） |
| `Features/Editor/EditorPlaceholderView.swift` | 新增 `Photo summary` 入口（与 Layouts 同样的禁用规则，+8 行） |
| `App/RootView.swift` | `.sheet` 路由新增 `.photoAnalysis` 分支（+2 行） |
| `Core/Navigation/AppRoute.swift` | `SheetRoute` 新增 `photoAnalysis(projectID:)`（+1 行） |
| `MomentsStudio.xcodeproj/project.pbxproj` | 由既有生成器重新生成，纳入 4 个新 Swift 文件（+60 行） |
| `MomentsStudio/README.md` | 新增 Stage05 构建/验收入口小节与算法/边界说明 |

未改动：`Project`/`CanvasDocument`/`Asset`/`Layer`/`ImportedPhoto`/`ProjectPackage` 全部字段、schema2 与 v1 兼容、原始照片、Stage01–03 工作流、Stage04 两个工作流、既有 155 项测试与全部旧断言。

## 2. 冻结的算法与采样决定

规格要求把阈值、缩图取整与插值策略冻结并由测试检验；`PhotoAnalyzer` 的文档注释与测试是同一份契约：

- **输入**：调用方传入已按 EXIF 纠正方向的 320px 缩略图 `CGImage` 与纠正后的显示尺寸；`PhotoAnalyzer` 本身不读文件、不读原图、不碰 SwiftUI。
- **采样尺寸**：`scale = min(1, 64 / max(w,h))`；`sampleW = max(1, floor(w·scale))`、`sampleH = max(1, floor(h·scale))`。**不放大**，比例保留到 1 像素取整以内（320×240→64×48；1000×500→64×32；40×30→40×30；0 边长→`invalidMetadata`）。
- **转换**：显式画入 8-bit sRGB RGBA 上下文，`bitmapInfo = byteOrder32Big | premultipliedLast`（内存 r,g,b,a），`interpolationQuality = .high`。不假设输入像素格式或色域（有 BGRA 输入测试）。
- **透明**：存储 alpha 字节 ≤ `Int(0.05×255)` 向下取整 = **12** 的像素不计入（即 alpha ≤ 0.05）；其余像素**先去预乘**（除以 alpha，四舍五入只做 ≤1 截断），透明边缘不会被当成黑色。有效像素为 0 → `noVisiblePixels`。
- **统计**（只在有效像素上等权）：`L = 0.2126r + 0.7152g + 0.0722b`（编码 sRGB 上的**相对亮度代理**，不是物理照度/EV/线性光）；`meanL`；`contrast = sqrt(mean(L²) − meanL²)`，仅对浮点负方差归零、上限 0.5（数学上界，仅吸收浮点误差）；饱和度 `S = (max−min)/max`，`max = 0` 时 `S = 0`；暗像素 `L ≤ 0.1`、亮像素 `L ≥ 0.9`；`coverage = 有效像素 / 采样总数`；均值/比例均裁剪到 `[0,1]` 且有限。
- **置信度只表达采样充分度**：有效像素 ≥ **256** 且 coverage ≥ **0.75** → `adequate`，否则 `limited`；不是 AI 概率、不评价照片好坏。`confidenceExplanation` 输出实际像素数与 coverage 供 UI 解释弱采样。
- **三档 UI 估计**：`meanL < 0.25 / ≤0.75 / >0.75` → darker/balanced/brighter；`meanS < 0.2 / ≤0.5 / >0.5` → muted/moderate/colorful。

## 3. 服务、导航与数据边界

- **`PhotoLibrary`（actor，非 MainActor）**：`analyzePhoto` 从当前包查元数据与缩略图引用，经既有 `loadDerivedImage` + `PhotoLibraryPathGuard` 加载派生图（不接受外部路径、不加载/修改原图），在读取前、解码后、计算前检查取消；**取消抛 `CancellationError`**，不转成成功也不转成普通坏图。失败按类型化原因返回：包/素材不可解析→`missing`，缩略图缺失或不可解码→`unreadable`，存储元数据非法→`invalidMetadata`（防守分支），全透明→`noVisiblePixels`。
- **`PhotoImportModel`（只读桥接）**：不占单一 mutation gate（有“持手势门槛时仍可分析”的测试）、不写 store/manifest/failedDraft，只把值结果交回 UI（`CGImage` 不跨 UI 边界）。
- **导航**：`SheetRoute.photoAnalysis(projectID:)` 由 `RootView` 统一呈现并显式注入原有三个环境对象；编辑器入口 `editor.photoSummary`，与 Layouts 入口同样在无照片/未就绪/忙时禁用（检查点 O1 的既定口径：复用编辑器既有导入说明，不新增页面/问卷）。
- **Sheet**：有限状态（running + `PhotoAnalysisRun` 内的结果/失败）；按导入顺序**一次一张**、最多项目上限 20；`.task(id:)` 的任务键包含 projectID、手动重算计数器与每张照片的身份+缩略图引用+像素尺寸+方向签名，因此素材集合或元数据变化会取消并重算。**写回与显示都经 `PhotoAnalysisRun`**：`accept`/`reject` 复核请求 token、当前呈现的 projectID 与照片当前 metadata 签名，`measurement(for:)`/`failure(for:)` 再按签名核对；`restart()` 清空并作废旧 token。因此上一轮/上一项目/已关闭/已删除/元数据变化后的旧成功与旧失败都不写 UI、也不显示；关闭即取消，重开重新计算（无缓存、无持久化）。
- **契约**：`PhotoAnalysis`/`PhotoAnalysisFailure`/`PhotoAnalysisConfidence`/两个估计枚举都是 `Equatable`/`Sendable` 值类型，**不 Codable**；无新增持久化字段、无第三方依赖、无网络/账号/GPU/模型下载、无生产测试开关。

## 4. 新增测试（编码，未运行）

| 文件 | 方法数 | 覆盖 |
| --- | --- | --- |
| `Stage05PhotoAnalysisTests` | **11** | 黑白灰固体精确值；纯 RGB 通道与亮度权重；320×320 双区图（均值/暗亮比/对比度，容差 0.05）；半透明去预乘（存 128 恢复为 1.0）；全透明→`noVisiblePixels`；coverage 与像素数分别驱动 `limited`/`adequate`；采样上限/不放大/比例/非正尺寸；BGRA 输入显式转换；非法显示尺寸；三档 UI 阈值与弱采样说明；**alpha 门槛 12 排除 / 13 计入**的边界数值 |
| `Stage05AnalysisStorageTests` | **8** | 真实缩略图统计 + **manifest/原图/派生图字节前后完全相同** + 无草稿/无 store 变化；EXIF 方向 6 的显示尺寸 240×320 与竖向采样；删除缩略图→`unreadable` 且另一张仍成功（逐图隔离）；未知 asset 与跨项目 asset→`missing` 且两项目 manifest 不变；取消传播为 `CancellationError`（非 `PhotoAnalysisFailure`）；持 canvas 手势门槛时仍可只读分析且门槛不被释放/消费；**真实 thumbnail 符号链接被拒且外部/项目文件字节不变**；**`PhotoLibraryPathGuard` 拒绝 `../`、绝对路径与反斜杠越界引用** |
| `Stage05AnalysisRunTests` | **11** | `PhotoAnalysisRun` 真实 guard：只有测量时 metadata 才显示（尺寸/缩略图/方向变化后旧值不显示）；**错 asset 或错 display 尺寸的结果被拒**；同一 run 换 `currentProjectID` 时成功与失败都拒、读取也为 nil；旧 token 不能写；`invalidate()`（关闭/重算）立即清空并使旧 token 失效；照片被删或项目不存在时不能写；旧尺寸结果不能作为新 metadata 结果读取；成功与失败在同一身份下互斥替换 |
| `Stage05PhotoSummaryUITests` | **1** | 真实系统 picker 导入 1 张 → `Photo summary` → 等待真实 `analysis.status` 到达 “Analyzed 1 of 1 photos” → **真实 `.contain` 容器行**（非 `staticTexts`）且 asset 身份与估计行一致 → `Analyze again` 后仍完成 → 关闭 → 编辑器仍是 “1 of 20 photos / 0 of 20 layers”（分析没写项目）→ 重开从空态重算；编辑器控件的 tap 走**共享** `scrollEditorToMakeHittable` 门槛 |

合计新增 **31** 项（11 + 8 + 11 unit + 1 UI）。既有 Stage01–04 的 **155** 项与之并存，全工程源码清单为 **176 unit + 10 UI = 186**（见 §5）。未改任何旧测试或断言；FIX03/FIX05 只改共享 helper 的图库实例化一段与 Stage04 的可用视口/拖拽，方法数与断言数不变。

## 5. 实际执行的本地检查与真实输出

| 检查 | 结果 |
| --- | --- |
| `tools/generate_xcodeproj.py` | 写入工程：MomentsStudio 34 / Tests 18 / UITests 6 文件引用，**166 objects** |
| `tools/verify_project.py` | **PASS**（FIX05 后复跑）：166 objects、58 文件引用、Sources 覆盖 **33/18/6 = 57 Swift（13567 行）**、17 个 UI 标识符解析、App 声明 74 个、asset catalog 有效。**不证明 Swift 类型检查** |
| `stage05-tests.yml` 自带清单步骤（本机实跑同一段内嵌逻辑，FIX05 后复算） | **PASS**：`unit=176 ui=10 total=186`；逐文件方法数与 workflow 内冻结期望表逐项一致；scheme 的 `TestAction` 两个 testable 均不 skip。清单 SHA 随源码内容变化（FIX05 后为 `6b94f7877960d4c5…cedfc65b`），**不作为通过依据**，只说明清单由真实源码生成 |
| tree-sitter（0.26.0 + tree_sitter_swift） | 全部 **57 个 Swift 文件解析 0 ERROR/missing**；FIX05 另按“同一父节点同名+同参数列表”扫描重复声明：**0 处** |
| 两个 Stage05 工作流 | PyYAML 解析：仅 `workflow_dispatch`、`contents: read`、超时 30/6 分钟、2 天产物；**7 + 4 段内嵌 Python 全部 `compile()` 通过**；无 `STAGE04_`/`stage04-` 残留、无 `-only-testing`/skip/retry；边界 176/10/186 与清单实算一致 |
| 既有工作流保护 | `git status --porcelain -- .github/workflows` 只有两个新增 `stage05-*`；`stage04-tests.yml` `1a0f19d05226ba27…5a425fef0e4e` 与 `stage04-device.yml` `957198157f7f277d…31ff073a77` **与冻结时逐字节相同**；Stage01/02/03 工作流未被修改 |
| 源基线（FIX06 后） | 57 个 Swift 文件逐文件 SHA256，按路径序再哈希的聚合 `9c26ce92223c579ac5bbfc0d4a22431261ecbc1103dda67187c957b18f3a0295`；本机无 Xcode，故这只是编码基线，不是构建产物哈希 |
| 跨文件 helper 冲突扫描（FIX06 新增） | UI test 目录内与 `UITestSupport.swift` 扩展成员**同名同签名**的本地 helper：**0 处**（`Stage04LayoutUITests.swift` 的本地几何判定已改名 `layoutFrameIsFiniteAndPositive`）。该扫描只是源码层防回归，不能替代原生编译 |
| 首次 Stage05 原生运行（真实，已失败） | [run 37964463618](https://github.com/Icatly/moments-studio/actions/runs/37964463618)：设备 `** BUILD SUCCEEDED **`；测试 target 编译失败 → `totalTestCount=0`。**不是**测试通过，也不是“0 失败通过”；修复后尚未重跑 |
| 私密证据 | `.ai/build/stage05-dsh-implementation-20261010/`：`test-manifest.txt`、`test-methods.txt`、`test-source-hashes.txt`、`test-method-counts.txt`、`env-values.txt`、`project-wiring.txt`、`swift-source-hashes.txt`、`BASELINE.txt`、`HOW-THESE-WERE-PRODUCED.txt`（明示是编码清单/源哈希，**不是** XCTest 结果；已按补正后源码重生成） |

逐文件方法数（实际源码，非猜测）：unit 176 = AppNavigation 6 + CanvasDocument 3 + LargePhotoBatch 2 + LayerModel 9 + PhotoImportModel 6 + PhotoLibrary 31 + ProjectModel 5 + ProjectPackage 8 + ProjectStore 11 + Stage03Contract 34 + Stage03StorageCoordinator 16 + Stage04Layout 11 + Stage04Storage 4 + **Stage05PhotoAnalysis 11** + **Stage05AnalysisStorage 8** + **Stage05AnalysisRun 11**（+2 个 0 方法支持文件）；UI 10 = Stage01Smoke 2 + Stage02Import 3 + Stage03Canvas 3 + Stage04Layout 1 + **Stage05PhotoSummary 1**（+1 个 0 方法 helper 文件）。

## 6. 未执行 / 不得冒充

- **本机没有任何原生结果**：本机 Windows 无 Xcode、无模拟器/真机，也没有 `swift`/`swiftc` → 修复后的 **186 项 XCTest 未运行**、无本机构建/`xcresult`/IPA/本人验收；手机仍是 Stage03 包。
- **已有一次真实但失败的原生运行**：Stage05 `37964463618`（source `bc166d45…`）设备 App 编译通过、UI test target **编译失败、0 项测试执行**（§FIX06）；该次结果**不是**通过，修复后**尚未重跑**。Stage04 `37957684567` 的真实结果（155 运行 / 153 通过 / 2 UI 失败）只对应冻结 commit `edeca4d`，其后的 FIX03/04/05/06 改动**均未原生重验**；两次运行都**不覆盖**本文档的当前工作树。
- 因此无法在本机验证：Swift 类型/actor 隔离错误、`CGContext` 实际像素行为、SwiftUI `searchable`/AX 合并/`.task(id:)` 时序、`analysis.*` 标识符在原生层级中的真实暴露、真实照片的视觉与弱采样提示观感。
- 静态检查（工程接线、语法树、YAML/内嵌 Python、清单门禁）**不等于** Xcode 通过；§5 的方法清单是编码清单。
- **工作流未推送、未触发**；本机无免费额度结论，未产生费用；未做过任何外部发布或账户动作。
- 已知的规格内防守分支：`invalidMetadata` 在 `PhotoLibrary` 路径上**不可达**——包契约（`ProjectPackage.validate`）已经保证像素尺寸为正、方向 1…8，因此该分支只在直接调用 `PhotoAnalyzer` 时可达（已由纯统计测试覆盖）；如未来包契约放宽需重新评估。

## 7. 待 Architect 复审与后续

1. 独立复审本报告、§1 差异与私有证据；确认算法冻结项（§2）与 O1–O4 口径。
2. 组织 Stage05 原生验证：`stage05-tests.yml` 按**完整 186 项**运行（Stage04 入口保持其冻结 155 边界，不互相冒充）；测试失败按明确根因修复后重验，不放宽断言、不跳过。
3. 原生通过后准备同源 Stage05 设备包（`stage05-device.yml`）并交本人在 iPhone 上看 Photo summary 的实际观感（含弱采样提示）、关闭/重开行为与真实照片估计是否合理；自动测试与本报告都不替代本人验收。
4. Stage05 实际验收前的状态即为 READY_FOR_ARCHITECT_REVIEW；Stage06 未授权、未开始。任何推送/派发/费用/账户动作由 Architect 组织与所有者授权，DSH 不自行执行。
