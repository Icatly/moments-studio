# STAGE-02-FIX-05-REPORT.md

Stage 02 — Architect Fix 05（第四次 macOS 运行：**已编译并执行** 78 单元 + 4 UI，4 个方法失败）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-05.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-09.md`、证据 `.ai/build/downloads/run-37135113445/evidence/xcodebuild.log`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过 Review、未交所有者验收；Stage03 未授权）

---

## 1. 第四次真实运行：EXECUTED AND FAILED

- 源码 `0c905a3f038b770169a930e8c16d27572fb639ca`，run [37135113445](https://github.com/Icatly/moments-studio/actions/runs/37135113445)。
- **全部 target 编译通过，测试真正执行**：`Executed 78 tests, with 5 failures`（单元）+ `Executed 4 tests, with 1 failure`（UI）。
- 3 个单元方法 + 1 个 UI 方法失败，共 **6 条断言失败**（5 单元 + 1 UI）：

| 文件:行 | 失败方法 | 断言消息 |
| --- | --- | --- |
| `PhotoLibraryTests.swift:882` | `testSymlinkAliasInsideTheLibraryCannotRedirectAnotherProjectsAssets` | `failed - writing through a within-library symlink alias must be refused`（导入竟然成功） |
| `PhotoLibraryTests.swift:889` | 同上 | `XCTAssertEqual failed: (["05304A3D…", "0A672AE8…"]) is not equal to (["0A672AE8…"])` —— B 项目目录列表被写入 |
| `PhotoLibraryTests.swift:230` | `testImportKeepsTransparencyAsPNGAndUsesJPEGOtherwise` | `the PNG fixture must contain semi-transparent pixels`（0 个半透明像素） |
| `PhotoLibraryTests.swift:243` | 同上 | `the thumbnail must keep semi-transparent pixels`（0 个） |
| `ProjectPackageTests.swift:260` | `testPathRulesAcceptOnlyGeneratedReferences` | `XCTAssertThrowsError failed: did not throw an error`（`original.gif` 被接受） |
| `Stage02ImportUITests.swift:62` | `testImportPickerCanBeDismissedBackToTheEditor` | `Cancel must dismiss the picker instead of leaving it on screen.` |

套件统计（执行方法 / 失败方法 / 失败断言）：PhotoLibraryTests 29 / 2 / 4；ProjectPackageTests 8 / 1 / 1；Stage02ImportUITests 2 / 1 / 1；其余套件全绿。

**本次日志中的其它真实结果（Architect Round 09 记录）**：合成 HEIC 导入 **PASS（未 skip）**；12 MP 批次取消用例 PASS；3×4000×3000 串行导入实测 **0.430 秒**（fixture 准备在计时之外）；导入前后内存快照 footprint `38,443,776 → 38,656,768` 字节、resident `214,761,472 → 214,958,080` 字节 —— **仅为模拟器上的两次快照，不是峰值内存，也不能推断真机吞吐**；3 条 AppIntents 元数据告警（缺少 AppIntents 依赖），未观察到 Swift actor 诊断。

## 2. 四项授权修正

### 2.1（HIGH，生产缺陷）生成路径的逐组件归属校验

**已证实的边界缺陷**：旧实现仅比较整条路径规范化后的结果，没有逐组件拒绝生成路径中的链接；实际 run37135113445 在新资产目标尚不存在、A/assets 指向 B/assets 的情况下放行并写入 B。具体 Foundation 解析/规范化机制尚未证明，不能据此断言已有路径的旧校验普遍有效。修正按逐组件归属不变量实现，不依赖该内部机制推测。

**修正**（仅 `Services/PhotoLibrary.swift`）：

- 新增本地 `enum PhotoLibraryPathGuard`（一个文件内的窄助手，未新增服务/协议/actor/公开 API/依赖）：
  - 逐组件在**已规范化根**之下检查；每个**已存在**组件用 `fileManager.attributesOfItem(atPath:)` 取属性并判断 `.typeSymbolicLink` → 一律拒绝（库外链接、库内别名、悬空链接都在内）。这正是**不跟随链接**的检查，`fileExists` 跟随链接看不到链接本身。
  - **允许真正缺失的尾部**（正常新建目录），并对 `ENOENT`/`NSFileNoSuchFileError` 与其它检查错误**分别处理**（前者视为缺失，后者抛 `fileOperationFailed`）。
  - 拒绝绝对路径、反斜杠以及空/`.`/`..` 组件，杜绝词法逃逸。
- `PhotoLibrary` 在 `init` 中**一次性**规范化可信根（`canonicalRootURL`），保留 `/var -> /private/var` 平台别名支持；生成组件在检查前**不做**规范化。
- `resolvedLibraryPath` 改为委托该助手，因此 create/read/write/copy/rollback/delete/cleanup **全部 17 处**生成路径解析走同一不变量。
- `PhotoLibraryLocation.canonicalStagingDirectory` / `canonicalStagedFile` 改用同一助手（暂存目录与自有暂存文件同样逐组件校验）；删除了已不再被使用、且**未校验**的重复 helper `stagingDirectoryURL`，避免出现第二个分歧实现。
- 保持：其它项目、original/来源文件、未知暂存条目、提交后 apply 与取消语义均未改。

**新增一个聚焦回归**（任务允许，且此前未覆盖）：`PhotoLibraryTests.testDanglingSymlinkAtAGeneratedPathIsRejected` —— 生成的 `assets/<assetID>` 是指向不存在目标的悬空链接时必须抛 `.invalidReference`，且**不得创建链接目标**。

### 2.2（MEDIUM）original 只接受受支持扩展名

- `PhotoLibraryPath` 新增 `supportedOriginalExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif"]`；`parse` 的 `.original` 分支改为要求命中该集合（此前只要求"非空且字母数字"），因此 `original.gif` 被拒。
- 扩展名仍先 `lowercased()`（`"HEIC"` 仍可用）；派生图规则 `derivativeExtensions` 未变；序列化字段名/raw 值/fixture 未变；`parse` 的既有拒绝测试保留。
- 与流水线一致：`PhotoDerivativeRenderer.metadata` 本就只接受 JPEG/PNG/HEIC/HEIF，`preferredFileExtension` 只会给出 jpeg/png/heic/heif。未新增 GIF 支持、未放宽任何校验。

### 2.3（测试缺陷）真正含半透明像素的 fixture

- 原实现先在**不透明**背景上以 source-over 填 alpha 0.5 → 结果 alpha 仍为 1（这正是失败原因）。
- 现在先 `context.clear(band)` 再以 alpha 0.5 填充，同时保留**alpha 0 的透明方块**与不透明区域。
- 断言未动、未降级为只看扩展名、未跳过：源 fixture、thumbnail、preview 的逐像素 alpha 断言全部保留。
- **未改任何渲染生产代码**（该缺陷不构成渲染器 alpha 问题）。

### 2.4（测试等待缺陷）真正的"等待消失"

- 原来用 `XCTAssertFalse(pickerCancel.waitForExistence(timeout: 5))` 断言消失 —— 元素仍在时它立即返回，无法证明消失。
- 新增 `XCUIElement.waitForDisappearance(timeout:)`（`UITestSupport.swift`）：`NSPredicate(format: "exists == false")` + `XCTNSPredicateExpectation` + `XCTWaiter` 的**有界等待**。
- picker 测试改为：真实出现断言 + 真实 Cancel 点击（保留）→ `waitForDisappearance()` → 导入入口**同时**要求 `waitUntilEnabled()` **与** `isHittable`。
- 无任意 sleep、无 mock picker、无空断言、未做生产绕过。

## 3. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `Services/PhotoLibrary.swift` | 新增 `PhotoLibraryPathGuard`（逐组件属主校验）；`init` 一次性规范化根；`resolvedLibraryPath` 委托助手；`PhotoLibraryLocation` 暂存检查改用助手；删除未使用的未校验 helper |
| `Models/PhotoLibraryPath.swift` | 新增 `supportedOriginalExtensions`；`.original` 解析改用白名单 |
| `MomentsStudioTests/SyntheticImageFactory.swift` | 半透明带先 clear 再填 |
| `MomentsStudioTests/PhotoLibraryTests.swift` | 新增悬空链接回归测试（其余测试与断言未改） |
| `MomentsStudioUITests/UITestSupport.swift` | 新增 `waitForDisappearance(timeout:)` |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | 改为有界消失等待 + enabled 且 hittable |

`git diff --stat`：**6 文件，287 insertions(+), 67 deletions(-)**；`git status` 确认未触碰生产/UI 之外的文件（无工程设置、无依赖、无 workflow、无序列化契约）。

## 4. 本机执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用） |
| `python tools/verify_project.py` | **PASS**（40 Swift 文件 6221 行，含 §7 澄清；改动前该次为 6157 行；Sources 覆盖、构建设置/scheme/资源、6 个 UI identifier） |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-05 一致性脚本 | **27/27 PASS**（逐组件检查用 `attributesOfItem`+`.typeSymbolicLink`、ENOENT 区分、缺失尾部放行、拒绝 `.`/`..`/绝对/反斜杠、根只规范化一次、暂存同样走助手、白名单精确为 jpg/jpeg/png/heic/heif、派生规则未变、band 先 clear、断言未弱化、消失等待用 `exists == false`+`XCTWaiter`、enabled 且 hittable、无 sleep、保留全部既有测试、B 项目保留断言仍在、悬空回归恰好 1 个、无 skip） |
| 回归脚本 | `STAGE02_FIX02_CHECK` PASS、`STAGE02_FIX03_CHECK` PASS、`STAGE02_FIX04_CHECK` PASS、`STAGE02_CONFORMANCE` PASS、`STAGE02_ALL_CORRECTIONS_CHECK` PASS |
| **diff / 空白检查** | `git diff --check` → 无空白错误；Python 扫描 6 个改动文件 → 无行尾空格、无 Tab、无 CRLF |
| 测试计数 | **80 单元 + 4 UI = 84 项**（新增 2 个聚焦回归），本机**未执行** |

> 追加澄清后重跑：`STAGE02_FIX05_CLARIFICATION_CHECK` 12/12 PASS；`verify_project.py` 仍 PASS（40 Swift 文件 **6221 行**）；tree-sitter `40 WITH_ERRORS=0`；`git diff --check` 仍无空白错误。

> 诚实说明：`STAGE02_ALL_CORRECTIONS_CHECK` 中 item 13 的旧断言检查的是 FIX-05 **已按授权替换掉**的"整路径相等"实现，属脚本过期期望；已把该子检查改为核验新机制（逐组件属主检查），并重跑 PASS。这是脚本期望更新，不是放宽校验——新机制在"目标尚不存在"时比旧机制严格。

## 5. 剩余风险与未验证项

1. **本次四项修正均未经运行验证**：Windows 静态检查无法证明任何运行时行为；必须由 Architect 的 macOS 重跑判定，尤其是：
   - 逐组件属主校验是否真的拦住"尚不存在的目标目录"（本次修复的核心）；
   - 悬空链接回归与既有 symlink/清理测试是否全绿；
   - fixture 现在是否真的产生半透明像素并穿透到 thumbnail/preview；
   - `waitForDisappearance` 在有界时间内是否真的观察到 Cancel 消失（若仍失败，Architect 将检查实际 UI 证据）。
2. `attributesOfItem(atPath:)` 的 `lstat` 语义与 `ENOENT` 错误码映射仅按 Apple 文档与既有经验实现，本机无法编译验证；若平台返回不同错误域，缺失尾部分支可能需按真实错误调整（仅影响本地助手，不影响契约）。
3. 既有未验证项不变：真机/iPad/VoiceOver、精确 iOS 17.0/Xcode 15.4、真实照片与真实选择器多选、terminate/relaunch 恢复；大图 0.430 秒与两次内存快照仅代表模拟器与平坦合成 JPEG，**不代表真机性能或峰值内存**。
4. Stage01 的云端/Appetize 证据不属于 Stage02；Stage02 仍无运行包。

## 6. 未做的动作

未运行云端/工作流，未操作账户，未 push/上传，未改 `.github/workflows/*`、SDK/编译器/语言版本/部署目标/工程设置、actor 隔离、公开契约或序列化字段；未新增依赖、服务、协议或 actor；未删除/跳过/弱化任何既有测试；未开始 Stage03。仅本地只读读取已下载日志与 fixtures。

## 7. FIX-05 追加澄清（同一范围内的三项，2026-10-04 00:45）

Architect 在复审中追加了同一范围的三点澄清，DSH 已实现：

1. **"文件不存在"的错误判定**：`PhotoLibraryPathGuard.isMissing` 原来只认 Cocoa `NSFileNoSuchFileError`(4)。现在同时接受文档化的 **`NSFileReadNoSuchFileError`(260)** 与 POSIX **`ENOENT`**，且**不放宽其它错误**：只有这三个码被当作"该生成路径尚不存在"（首次启动、全新素材目录的正常状态），其余仍抛 `fileOperationFailed`。首次空根场景由既有 `testRestoreCreatesTheLibraryOnFirstLaunchWithAMissingRoot` 覆盖。
2. **暂存文件归属不再解析任意外来父路径**：`canonicalStagedFile` 此前对传入 URL 的父目录做 `resolvingSymlinksInPath()`，于是一个**外部目录里名为 `Temporary` 的链接**会被解析到库内真实暂存目录而被当成"自有文件"。现在改为**纯粹按词法**比较父路径，且只接受两种可信形式 —— 调用方提供的根（可带平台别名）与其规范化形式；不再对外来路径做符号链接解析。**只有可信根**会被规范化，生成组件一律先检查再使用（guard 内部同样如此）。新增聚焦回归 `testExternalAliasToTheOwnedStagingFolderIsNotAcceptedAsOwnership`：外部 `…/OutsideStagingAlias/Temporary/<owned file>` 必须**不删除**库内自有暂存副本。
3. **注释只描述已观察到的边界失败**：`PhotoLibraryPathGuard` 的文档改为写明"run 37135113445 中整路径比较接受了库内别名、导入写进了项目 B"，并明确"**其确切的 Foundation 机制在此并未确立**"，不再断言未经证明的内部行为。

本机追加验证：`STAGE02_FIX05_CLARIFICATION_CHECK` **12/12 PASS**（三类缺失错误齐全且不放宽其它错误、`canonicalStagedFile` 内不含 `resolvingSymlinksInPath`、只接受两种可信父形式、仅可信根被规范化、注释含观察证据且不含未证机制断言、外部别名回归存在且既有暂存归属测试保留），FIX-05 主检查 27/27 与既有回归脚本仍全部 PASS。

## 8. 下一步

Architect 复审本报告后对**当前源码**重跑 macOS 构建与 80 单元 + 4 UI 测试并判定四项修正。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER`/`APPROVED`，所有者判断保持 PENDING，9 项验收清单未勾选。
