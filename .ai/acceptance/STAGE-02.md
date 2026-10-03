# Stage 02 验收

Stage: 02

Name: Photo Import and Asset Pipeline

Status: READY_FOR_ARCHITECT_REVIEW

User Decision: PENDING

Stage01于2026-10-03由所有者明确批准，并授权继续下一阶段。Stage02 需求、架构与执行任务已定义；DSH 已完成实现，处理完 Architect 实现中检查 `.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md` 的**全部 13 项**（该记录最初为 10 项，随后扩展），并完成 Round 01 Review 授权的 `.ai/tasks/STAGE-02-ARCHITECT-FIX-01.md` **6 项**修正（第 6 项为追加；见 `.ai/reports/STAGE-02-FIX-01-REPORT.md`），以及首个 macOS 运行编译失败后的 `.ai/tasks/STAGE-02-ARCHITECT-FIX-02.md` **3 项**修正（见 `.ai/reports/STAGE-02-FIX-02-REPORT.md`）。交付总览见 `.ai/reports/STAGE-02-REPORT.md`。**本机（Windows）无 Xcode：78 个单元测试 + 4 个 UI 测试从未执行，也没有 Stage 02 可运行版本。** 真实 macOS 运行证据（run 37131111464）显示**编译失败、测试未执行**。本文件不表示 Stage02 已获验收批准。

## 所有者验收清单

- [ ] 系统照片选择器一次选择多张照片，导入顺序和数量正确。
- [ ] 不申请完整图库权限；原图仅复制，系统相册中的照片不被修改。
- [ ] 原始文件、缩略图与预览图正确保存，方向、比例与透明图显示正确。
- [ ] 追加导入、只读预览、移除本项目照片正常，未影响其他项目。
- [ ] 导入进度、取消和失败提示明确，旧素材不因失败丢失。
- [ ] 导入后的项目在应用重新启动后可恢复；未保存的空项目限制明确。
- [ ] 导入时可操作导航，无明显UI阻塞；浅/深色与大字号基本可用。
- [ ] 当前源码的自动测试与macOS构建实际执行，Architect完成架构/Bug/性能/警告/视觉Review。
- [ ] 所有者已亲自检查Stage02可运行版本，并明确作出验收决定。

## 验收方法

用至少3张合成照片（竖/横/EXIF旋转或镜像、不同格式）一次导入，再追加、预览、移除。返回Home、重开对应项目，terminate/relaunch后核对照片和项目；取消新一批导入，确认已完成项保留而剩余项停止；受控失败不损坏旧数据。容量、大图、文件摘要、方向和回滚由自动测试及Architect证据补充。

需求/完成标准：[Stage02架构](../../docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md)。执行任务：[IMPLEMENT01](../tasks/STAGE-02-IMPLEMENT-01.md)。当前没有Stage02运行包；Stage01 Appetize链接不能冒充新阶段版本。用户操作说明在真实构建与Review完成后提供。

## 每项当前证据（DSH 交付，未验收）

| 清单项 | 当前状态与证据 |
| --- | --- |
| 多选导入、顺序与数量 | **代码已实现，未运行**：`PhotoImportSection` 使用 ordered `PhotosPicker`；`PhotoImportModel` 串行逐项导入、`photos` 数组即顺序；单元测试覆盖顺序与追加（未执行） |
| 不申请完整图库权限、原图不被修改 | **代码符合，未运行**：Info.plist 未声明任何照片权限键；导入为字节复制（单测断言 original 与源文件字节相等、源文件未被改动；未执行） |
| 原始文件、缩略图与预览图正确保存，方向、比例与透明图显示正确 | **代码已实现，未运行**：ImageIO 派生 320/2048（与源长边取 min，不上采样）、两个派生图重绘为 8-bit sRGB、EXIF 1...8（含镜像半图取色断言）、透明 PNG 保留 alpha、original 字节不变；JPEG/PNG/HEIC 合成导入测试已写（未执行） |
| 追加、只读预览、移除、跨项目隔离 | **代码已实现，未运行**：`SheetRoute.photoPreview` 只读预览（人类可读格式名）、确认移除；单测覆盖“移除只删本项目文件”“移除失败不改盘”（未执行） |
| 进度、取消、失败提示 | **代码已实现，未运行**：进度+取消按钮、错误摘要、取消回滚与 manifest 失败回滚单测；并发 mutation 被串行化；每项成功/失败/取消都清理应用自有 staging 副本（均未执行） |
| 重启恢复、未保存空项目限制明确 | **代码已实现，未运行**：启动异步恢复 + Home loading/重试/警告；文案区分未保存空项目与已保存项目；恢复测试已写（未执行） |
| 导入时导航可操作、浅深色与大字号 | **未验证**：需模拟器实查 |
| 自动测试与 macOS 构建实际执行、Architect Review | **未执行**：需 Architect 云端构建/测试；Windows 侧只完成结构、语法与契约静态校验 |
| 所有者亲自检查并决定 | **未开始** |

## 已披露限制（详见 `.ai/reports/STAGE-02-REPORT.md` 第 7、10 节）

- 未编译、未运行任何测试；首次 Xcode 构建可能出现 API 标签类修正（不影响语义）。
- 未验证真实选择器多选、真实照片、terminate/relaunch 恢复、相册原图不变、大图批次耗时/内存与取消反应、iPad/VoiceOver。
- 仅静态图（JPEG/PNG/HEIC/HEIF）；拒绝 RAW、动画 GIF、视频；不承诺 HDR 保真。
- 上限 20 张/项目、100 MiB/图、80 MP/图、320/2048 为本阶段工程策略，未做真机测量；无内容去重。
- 恢复时文件缺失的照片仍列出并给出 warning；清理失败只告警、后续启动重试。

## 状态记录

| 日期 | 状态 | 触发 |
| --- | --- | --- |
| 2026-10-03 | SPEC_READY | 所有者批准Stage01并要求继续；Architect完成Stage02需求、架构与执行任务 |
| 2026-10-03 | IMPLEMENTING | 执行任务已实际发送，DSH回复“Stage 01 approved — starting Stage 02”并开始读取/实现 |
| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW | DSH 完成实现与 Windows 侧校验（工程 126 对象/37 Swift 文件语法 0 错误/契约一致性 PASS），交付 `.ai/reports/STAGE-02-REPORT.md` 与 `.ai/reviews/STAGE-02-REVIEW-PACKET.md`；**测试与构建仍未执行** |
| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（含实现中修正） | 处理 Architect `.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md` 的实现中检查（该记录当时 10 项）：派生图遮蔽/8-bit sRGB/受限解码/路径与 symlink 校验/单 mutation 串行/提交后仍 apply/staging 清理/图片三态/HEIC 测试/ordered 选择与 ready 门控，新增 8 个单元测试；本机静态校验通过，仍未编译未运行 |
| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（13 项完成） | Architect 将同一记录扩展为 **13 项**；DSH 补做第 11–13 项（picker smoke 非空洞 + 等待 enabled；`nonisolated async` staging 且字节/取消前置、失败只清自有副本；库根可创建 + 解析结果必须等于 canonical root+生成式相对路径、UUID 命名普通文件不被清理）并新增 3 个回归测试。本机：128 对象/38 Swift 文件 5120 行语法 0 错误/`verify_project.py` PASS/`INFLIGHT_NOTE_01_CHECK_13`（item-12 子检查由纯文本匹配修正为类型声明统计后通过）/`STAGE02_CONFORMANCE` PASS；合计 **70 单元 + 4 UI**。**仍未编译未运行**，DSH 已停止开发 |

| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（FIX-01 六项完成） | Architect Round 01 Review 判 CHANGES_REQUIRED 并授权 `STAGE-02-ARCHITECT-FIX-01.md`：**6 项**（第 6 项为报告生成前追加）全部完成 —— 1) Transferable 返回自身类型；2) canonical staging 边界与精确归属；3) 清理 warnings 回传协调器；4) import/remove/writeManifest 入口校验且无 schema 降级；5) 像素上限溢出防护；6) 合成 fixture 真实透明/半透明像素 + 派生图像素 alpha 断言 + 协调器 import-vs-removal/双批次覆盖 + 窄注入 loader + 关键 fixture/PNG/JPEG 失败不用 XCTSkip（仅 HEIC 编码不可用可 skip 且不证明 HEIC 支持）；另按附加要求给新 UI 类型加显式 `@MainActor`。本机：130 对象/40 文件引用/39 Swift 文件 5714 行语法 0 错误/`verify_project.py` PASS/`STAGE02_ALL_CORRECTIONS_CHECK` 19/19/`STAGE02_CONFORMANCE` PASS；合计 **76 单元 + 4 UI**。**仍未编译未运行** |

| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（FIX-02 完成） | 首个真实 macOS 运行（source `dcfacd0`，run 37131111464，Xcode 16.4，3m50s）**编译失败、0 个测试执行**：日志 4 条 error 均为 `PhotoImportModel` 缺公开 `SwiftUI` 导入导致 `PhotosPickerItem` 不在作用域（`@escaping` 一条为级联）。Architect Round 03 判 CHANGES_REQUIRED 并授权 `STAGE-02-ARCHITECT-FIX-02.md` **3 项**；DSH 完成：1) 4 个引用文件全部同时导入 PhotosUI+SwiftUI（未用下划线模块、未改 picker 流程与 loader 类型）；2) 弱引用批次任务显式 `Task<Void, Never>` + `guard let self` + 非可选 await，取消转发/token 生命周期/提交后 apply 保留，`importSelection` 契约不变；3) 新增 3×4000×3000 JPEG 串行导入用例（断言顺序/字节/320-2048 边界、记录真实耗时与**字节**单位内存快照，无阈值、生成先于计时）与 `TestGate` 确定性取消用例（已提交保留、剩余不提交、staging 清空）。本机：132 对象/41 文件引用/40 Swift 文件 5989 行语法 0 错误/`verify_project.py` PASS/`STAGE02_FIX02_CHECK` 通过；合计 **78 单元 + 4 UI**。**仍未编译未运行** |

| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（FIX-03 完成） | 第二次真实 macOS 运行（source `20e9d5f4b12be4010862a46d61b7e745aeccbd7e`，run 37132895287，4m25s）**编译失败、0 个测试执行、无运行包**：首轮 `PhotosPickerItem`/`@escaping` 诊断已消失，改为 5 处 `extraneous argument label 'projectID:'`（`assetDirectoryReference(_ projectID:assetID:)` 首参无标签，调用处误用 `projectID:`）。Architect Round 05 判 CHANGES_REQUIRED 并授权 `STAGE-02-ARCHITECT-FIX-03.md`；DSH 仅改调用标签、共 **10 处**（App 5 + 测试 5，含多行调用），声明与生成路径字符串未变，未加镜像测试。本机：`git diff` 10 行改动、`git diff --check` 无空白错误、`verify_project.py` PASS（132 对象/41 文件引用/40 Swift 文件 5991 行）、tree-sitter `WITH_ERRORS=0`、FIX-03 一致性 11/11；合计 **78 单元 + 4 UI**。**仍未编译未运行** |

| 2026-10-03 | READY_FOR_ARCHITECT_REVIEW（FIX-04 完成） | 第三次真实 macOS 运行（source `70721cf13362475bfea5648b26241b4ea1df2c66`，run 37133937308）**编译失败、0 个测试执行、无运行包**，但**不是普通诊断**：日志中无 `error:`，而是 Swift 6.1.2 前端崩溃 —— `TypeCheckFunctionBodyRequest(... ProjectPackageTests.testDecodingRejectsInvalidDimensionsOrientationAndContentType())` + `ActorIsolationChecker::walkToExprPre`（只发生 1 次），结尾 `** TEST FAILED **`（2 failures）；App target 已 `Ld .../MomentsStudio.debug.dylib`，仅说明 App target 编译链接完成，**不声称整体构建成功**。Architect Round 07 判 CHANGES_REQUIRED 并授权 `STAGE-02-ARCHITECT-FIX-04.md`；DSH 把 :168 的内联混合 Int/String 元组字面量改为显式 `let cases: [(key: String, value: Any)]` 后遍历，四个损坏值（pixelWidth 0、pixelHeight −5、orientation 9、contentType ""）与逐例断言原样保留；审计确认这是全测试唯一未类型化异质元组。本机：1 文件 12+/1−、`git diff --check` 无空白错误、`verify_project.py` PASS（40 Swift 文件 6002 行）、tree-sitter `WITH_ERRORS=0`、FIX-04 一致性 6/6、FIX-03 回归 PASS；合计 **78 单元 + 4 UI**。**仍未编译未运行**；该修复为推断候选，待云端判定 |

只有所有者亲自检查并明确通过后可APPROVED。提出修改意见即CHANGES_REQUESTED，仅修当前阶段。DSH交付只到READY_FOR_ARCHITECT_REVIEW；Stage03–15未批准。

2026-10-03 22:16 当前更新：初版交付文档生成后，Architect继续发现并记录13项范围内缺陷/风险，DSH正在修正，尚未停止开发。状态回到IMPLEMENTING，最终Review仍未完成；所有者判断保持全部未勾选。依据 `.ai/reviews/STAGE-02-INFLIGHT-NOTE-01.md`。

2026-10-03 续（13 项完成）：上一条已被本轮完成取代——13 项实现中检查全部处理完毕（含扩展后的第 11–13 项），本机静态校验重跑通过，DSH 已停止开发并把本文件状态交回 `READY_FOR_ARCHITECT_REVIEW`。**测试与构建仍未执行**，最终 Review、可运行版本与所有者判断仍未完成。

2026-10-03 续（FIX-01 六项完成）：Round 01 Review 的 **6 项**发现也已全部修正（`.ai/reports/STAGE-02-FIX-01-REPORT.md`），测试合计 **76 单元 + 4 UI**，仍未执行。DSH 停止开发，等待 Architect 复审与当前 commit 的 macOS 构建。

2026-10-03 22:35：FIX01第6项必要行为测试仍在补充，5项报告不是全部6项完成；当前状态IMPLEMENTING，所有者决定仍PENDING。

2026-10-03 续（回应上一条，FIX-01 第 6 项完成）：第 6 项已补齐并复核——`SyntheticImageFactory` 现在真的画出 alpha 0 的透明区与 alpha 0.5 的半透明带，PNG 派生图断言逐像素 alpha（JPEG 断言无 alpha）；协调器新增“注入 loader 的完整批次”“导入进行中移除被拒”“第二批次被拒”三个用例（合成标识符从不交给真实照片库）；`XCTSkip` 只保留在 HEIC/HEIF 编码不可用分支，且明确不证明 HEIC 支持。故上一条 IMPLEMENTING 的理由已消失，本文件状态交回 `READY_FOR_ARCHITECT_REVIEW`；**测试与构建仍未执行**，所有者判断保持全部未勾选。

2026-10-03 23:14（实测时间，FIX-02 交付）：收到真实 macOS 证据——run 37131111464（source `dcfacd0`）在**编译阶段失败**，4 条 error 全为 `PhotoImportModel.swift` 缺公开 `SwiftUI` 导入致 `PhotosPickerItem` 不在作用域（第 345 行 `@escaping` 为级联），**0 个测试执行、无运行包**。Architect Round 03 判 CHANGES_REQUIRED 并授权 `STAGE-02-ARCHITECT-FIX-02.md` 三项，DSH 已完成（交叉导入审计 4 处、显式 `Task<Void, Never>`+`guard let self`、3×12MP 串行批次与 `TestGate` 确定性取消验证）。本机静态校验：132 对象/41 文件引用/40 Swift 文件 5989 行语法 0 错误、`verify_project.py` PASS、FIX-02 一致性通过；测试合计 **78 单元 + 4 UI，仍全部未执行**。DSH 已停止开发，状态保持 `READY_FOR_ARCHITECT_REVIEW`，等待对当前源码的云端重跑；未运行任何云端服务、未推送/上传。

2026-10-03 23:33（实测时间，FIX-03 交付）：第二次 macOS 运行 run 37132895287（source `20e9d5f`，4m25s）**编译失败、0 测试执行**：首轮诊断消失，改为 5 处 `extraneous argument label 'projectID:'`。DSH 只改调用标签：`PhotoLibraryPath.swift` :109/:119、`PhotoLibrary.swift` :206/:246/:337（App target）+ `PhotoLibraryTests.swift` :53、`ProjectPackageTests.swift` :18/:212/:240、`ProjectStoreTests.swift` :172（测试 target，编译未到达但同模式）= **10 处**；5 个 helper 声明、路径字符串、序列化字段与既有测试全部不变，未新增镜像测试。检查：`git diff` 仅 10 行标签改动、`git diff --check` 无空白错误、Python 空白扫描干净、`verify_project.py` PASS（40 Swift 文件 5991 行）、tree-sitter 40/40 0 错误、FIX-03 一致性 11/11、FIX-02 回归 20/20、`STAGE02_CONFORMANCE` PASS；**78 单元 + 4 UI 仍全部未执行**。停止在 `READY_FOR_ARCHITECT_REVIEW`，等云端重跑；未运行云端服务、未推送/上传、未开始 Stage03。

2026-10-03 23:51（实测时间，FIX-04 交付）：第三次 macOS 运行 run 37133937308（source `70721cf`）**不是普通编译错误**：日志 705 行中无 `error:`，失败形式是 Swift 6.1.2 前端崩溃 —— `TypeCheckSourceFileRequest` → `TypeCheckFunctionBodyRequest(ProjectPackageTests.testDecodingRejectsInvalidDimensionsOrientationAndContentType())` → `ActorIsolationChecker::walkToExprPre`（崩溃 1 次，`** TEST FAILED **`/2 failures，`Command SwiftCompile failed with a nonzero exit code`），**0 个测试执行、无运行包**；App target 已 `Ld .../MomentsStudio.debug.dylib`，只说明 App target 编译链接完成，**不构成整体构建成功**。DSH 按 FIX04 只改 `ProjectPackageTests.swift:168`：内联混合 Int/String 元组字面量 → 显式 `let cases: [(key: String, value: Any)]` 后逐项遍历，四个值（pixelWidth 0、pixelHeight −5、orientation 9、contentType ""）与逐例 JSON 改写 + `assertInvalidPackage` 断言全部保留；审计确认修正前全测试仅此一处未类型化异质元组，另一处 `[(field: String, value: String)]` 已有标注未改。检查：`git diff --stat` 1 文件 12+/1−、`git diff --check` 无空白错误、`verify_project.py` PASS（132 对象/41 文件引用/40 Swift 文件 6002 行）、tree-sitter 40/40 0 错误、FIX-04 一致性 6/6、FIX-03 回归 PASS、`STAGE02_CONFORMANCE` PASS；**78 单元 + 4 UI 仍全部未执行**。未改生产代码/SDK/编译器/部署/工作流，未新增或跳过测试，未运行云端服务、未推送/上传。**该修复是推断候选，是否有效只能由下一次云端编译判定。** 停止在 `READY_FOR_ARCHITECT_REVIEW`。
