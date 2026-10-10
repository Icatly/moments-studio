# Stage06 本地实现报告 — 2026-10-10

角色：DSH（Implementation Engineer，实施/工程/测试）；Architect 负责规格与独立 Review，不代写实现。授权：所有者 2026-10-10“进行stage06”；Stage04/05 已按本人新版真机三组“正常”收尾（[收尾记录](../reviews/STAGE-04-05-OWNER-CLOSEOUT-2026-10-10.md)）。范围：[STAGE-06-PHOTO-ROLES](../../docs/architecture/STAGE-06-PHOTO-ROLES.md)、[实施任务01](../tasks/STAGE-06-IMPLEMENT-01.md)，并按实现中独立 Review 补正 01–04 全部修复。基线：`fe17ac0d00db53629228f3ff972b5b83d563b551`（完整186/186）。

**状态：READY_FOR_ARCHITECT_REVIEW。** 本报告覆盖首版本地实现与 Review FIX01–FIX08。多轮独立 Review 退回后已按 [FIX05](../tasks/STAGE-06-FIX-05.md)、[FIX05 补充](../tasks/STAGE-06-FIX-05-SUPPLEMENT.md)、[FIX06](../tasks/STAGE-06-FIX-06.md)、[FIX07](../tasks/STAGE-06-FIX-07.md) 与 [FIX08](../tasks/STAGE-06-FIX-08-NATIVE.md) 全部修复。**首轮 Stage06 原生运行已真实发生并失败**：`run 38024488499` / source `198c755145e818bc9f2c7945c896fa72c21d3b48` 的 iphoneos Release 编译失败（XCTest 未执行、无 IPA），FIX08 已修根因但**尚未重新原生运行**（见 §0.0b）。本轮只做本地修复、测试编码与静态检查：**没有** 成功编译、**没有** XCTest 运行、**没有** Stage06 IPA/真机/本人验收，也**没有** git 提交/推送、工作流派发、付费或账户设置更改。Stage07 未开始。

## 0.0 FIX06（FIX05 交付后的剩余缺口，2026-10-10 12:0x）

| FIX06 | 缺口 | 实际修复 |
| --- | --- | --- |
| 1 | 报告称有 IO 失败回滚，实际没有 | 新增真实写失败测试：把项目目录设为不可写（POSIX 目录权限），**读取仍合法**、原子写无法创建临时文件 → `saveRoleChoices` 返回 `.saveFailed`；随后断言 manifest 字节、store、`roleSnapshot` 与包内角色**全部未变**、不产生画布草稿；恢复权限后**同一草稿 retry 成功**并写盘。**探测证明权限无法生效时直接抛出错误使测试失败（不是 `XCTSkip`、不是静默 no-op）**；未改生产 API 或错误分类，也未加隐藏测试开关 |
| 2 | 直接 arrange 覆盖不足 | 新增 5 个真实 `CollageLayout.arrange` 测试：nil 角色网格/错落与 Stage04 完全相同、Focus 主位真实 transform；空画布只为 primary/supporting 建层；collage/excluded 完整 transform/顺序/z/opacity 不动、locked/hidden 层不动；同 asset 多层只首层占主位；重复 Apply 字节稳定 |
| 3 | 全部 collage/excluded 仍提示 Import | 新增 `CollageLayoutError.noEligiblePhotos`：有照片但全部非参与时抛它，文案指向 **Photo roles 改角色**且不含“Import photos”；无照片仍 `.noPhotos`；sheets 侧同时按该判定提示，空画布/照片不删除不假加层 |
| 4 | UI 只有 IDs/count | UI test 增加**真实 geometry**：空画布层身份=photo id，故按保存主图的层 ID 选中行并读 `editor.layerTransform` 文本（`x .., y .., ..%`）解析 x/y/scale，断言第二导入主图 y 更小（主位）且 scale 不同；重复 Apply 后两层 y 值在 0.5 容差内不变 |
| 5 | 报告真实性 | 全报告/README/根交接改为当前真实清单 **245 unit + 11 UI = 256**；修正“手机仍 Stage03 包”为 Stage04/05 已验收 source `fe17ac0d` 的同一设备包（无 Stage06 IPA）；无 244/235 混写 |

## 0.0a FIX07（最后一处用户行为缺陷，2026-10-10 12:2x）

| 项 | 缺陷 | 实际修复 |
| --- | --- | --- |
| 1 | saved **automatic** primary 的 Picker 仍显示 Primary | 新增纯规则 `PhotoRolesSheet.pickerSelection`：**只有 manual**（本次草稿或 captured manual）才作为具体角色显示；captured automatic、未保存默认与 explicit Automatic 一律显示 **Automatic**。复现场景（A automatic primary + 选 B manual primary）现在 A 显示 Automatic、B 显示 Primary，界面与将保存的 `A=automatic supporting` 一致 |
| 2 | 自动建议变化/失败时仍显示旧 auto，失败被说成“Kept your choice” | 新增纯规则 `PhotoRolesSheet.advice` + `Advice` 值（`none`/`suggestion`/`keptManualChoice`/`noEvidence(keepingManualChoice:)`），UI 文案只由它决定：真实建议才叫 suggestion、已存 manual 永不称 device suggestion、失败明确说“这次读不到”并说明旧 manual 是否保留 |
| 3 | 回归与报告 | 新增 5 个**走真实 UI 取值函数**的测试：captured automatic primary+manual primary 只后者显示角色且保存恰一个 primary、untouched captured manual 保留、explicit Automatic/manual、同角色 auto→manual 可保存、advice 四种分支（含“manual 强制出的 policy 角色不得称 suggestion”）；报告 §0.0 第 1 项的 XCTSkip 措辞更正为**探测失败即 throw 使测试失败**（代码如此，未改测试去配报告） |

## 0.0b FIX08（首轮原生真编译失败后的最小修复，2026-10-10 12:4x）

**首轮 Stage06 原生运行真实结果**：[run 38024488499](https://github.com/Icatly/moments-studio/actions/runs/38024488499)，source `198c755145e818bc9f2c7945c896fa72c21d3b48`，attempt1，Xcode 26.6 build 17F113 / iphoneos SDK 26.5：**`iphoneos` Release 编译失败（exit 65），XCTest 未执行**，无 Stage06 IPA/本人验收。原始私密证据 `.ai/build/stage06-run-38024488499-20261010-123735/evidence/xcodebuild-device.log`（artifact 34697 bytes / SHA256 `7b8626b5…7422`）。本机语法树检查**不覆盖**这类类型错误。

| 项 | 真实诊断 | 修复 |
| --- | --- | --- |
| 1 | `PhotoRolesSheet.swift:383` 与 `:535`：`suggestions[photo.id].role` —— 字典下标是 `Optional<Suggestion>`，未解包 | 改可选链 `suggestions[photo.id]?.role`；**缺结果就是没有建议**，不伪造建议、不把缺失当 Primary |
| 2 | `PhotoRolePolicy.swift:124`：`suggestions[id] = .none` 被解释为 `Optional<Suggestion>.none`（删键）而非 `Suggestion.none` | 明确写 `suggestions[candidate.assetID] = Suggestion.none`；测试里的 `?? .none` 改为 `?? PhotoRolePolicy.Suggestion.none`，`Advice.none` 断言写全 `PhotoRolesSheet.Advice.none`，不再用 nil 假证明 |
| 3 | 新 warnings：`PhotoImportModel.swift:583` 未使用的 `project`；`PhotoRolesSheet` 四处 `invalidate()` 返回值未用；`PhotoRoleAnalyzer.swift:240/243` 恒成功的条件 cast | 583 改为存在性判断；`PhotoRolesRun.invalidate()` 标 `@discardableResult`（只动 Stage06 自己的 run，**未动冻结的 Stage05 `PhotoAnalysisRun`/`PhotoAnalysisSheet` 三处已有 invalidate warning**）；分析结果类型已确定，删除恒成功 cast |
| 4 | workflow Step 标题仍写 `176 + 10 = 186` | 仅改标题为 `245 + 11 = 256`；**未改** 256 完整 scheme/清单/SHA/0-skip/证据 guard 逻辑、timeouts 或冻结旧 workflow |
| 5 | 报告状态 | 本报告与根交接按真实 source/hash 记录“已执行真编译失败、XCTest 未执行”，保留全部 256 测试及意图，不把修复编码等同原生通过 |

**FIX08 本机核验**：`verify_project.py` PASS（192 objects、70 Swift **18050 行**）；tree-sitter 70/70 文件 0 ERROR；重复测试方法名 none；`suggestions[...].role` 未解包模式 0 处；Stage06 测试 `XCTSkip` 0；**workflow 内嵌真实清单 rc=0**：`unit=245 ui=11 total=256`，`manifest_sha256=13ef38db970ba7c7…537efd4`；stage06 两个 workflow 内嵌 Python 全部 compile 通过；Stage01–05 四个冻结 workflow SHA 逐字节未变；源聚合 `2243954a9dac9020…1c1c0ce`。

## 0.1 FIX05（第一轮 Review 退回全部阻断）逐项回应

| FIX05 | 阻断 | 实际修复 |
| --- | --- | --- |
| A1 | 真实 workflow manifest 独立执行失败：新旧 `testBeginRequestOnlyStartsForTheCurrentKeyAndSheet` 重名 | 新方法改名 `testRolesBeginRequestOnlyStartsForTheCurrentKeyAndSheet`；**实际执行 workflow 内嵌的真实清单代码**（提取 `stage06-tests.yml` 的 heredoc、注入真实 env 后运行）：rc=0、**无重名**、`unit=245 ui=11 total=256`；报告旧“235 清单已通过”的说法已更正 |
| A2 | 新 UI test 调用其他 class 的 `private` helper | `Stage06PhotoRolesUITests` 只在本 class 定义最小局部 `waitForLabel`/`tapEditor`，`tapEditor` 复用**公开共享** `scrollEditorToMakeHittable`；不再引用任何其他 class 的私有成员 |
| A3 | `Stage06RolesSheetModelTests` 无 `@MainActor` 却同步调用 `@MainActor` 静态函数 | `PhotoRolesSheet.choices`/`hasChanges` 明确 `nonisolated`，全部纯值模型（`PhotoRoleDraft`/`PhotoRolePolicy`/`PhotoRolesRun`/`PhotoRoleLayoutPlan`）本身 `nonisolated`；测试不再有 actor 语义漏项 |
| B3 | 完整批量“缺键清 nil”与 `Set(keys)==Set(current)` 自相矛盾，清空/部分失败全被拒 | 库改为**只要求 choices 的 key ⊆ 当前照片集**；未出现的当前照片**明确清 nil**；外来 asset 仍拒绝；真实存储测试覆盖全清、部分清、混合失败 |
| B4 | 真实 Automatic setter 仍删 key、旧 automatic 被当 manual 冻结 | 草稿改为**真实三态枚举** `PhotoRoleDraft`（`absent`/`automatic`/`role`）；setter 写 `.automatic`；`effectiveManualRole` 只在 captured 为 **manual** 时保留；`choices` 对 captured `automatic` 走重算刷新；测试全部改走这一真实 setter |
| B5 | 新主图不降已保存的 manual primary | `demotingOtherPrimaries` 按“本页照片＋原捕获角色＋本次草稿”求有效人工角色后降级；测试覆盖“保存 A primary → 重开选 B → Save → 只剩 B” |
| C6 | Vision 失败丢掉已成功的光色测量 | `PhotoRoleAnalyzer.observationAfterVisionFailure`（库真实错误路径调用）保留成功 `PhotoAnalysis`、`classificationRan=false`、分数/人脸/rev 全 0，不伪造；取消继续传播；已测该生产函数两条路径与“非 Vision 错误不吞” |
| C7 | UI 仅存在性断言，未证明取消/保存/重启/Apply | UI test 增加**真实值**断言：重开显示已保存角色、改动→Cancel→重开仍旧值、manual→Automatic→Save 清除、换主图、重启后仍保存、真实 Focus 预览＋Apply 后 layer 集合恰为 2（不复制）；导入后先在编辑器取真实 assetID，不依赖 sheet 打开后才查背后控件 |
| C8 | 缺布局直接 arrange 与保存回滚/后续编辑覆盖 | 新增 `CollageLayout.arrange` 直接测试（nil 旧行为、Focus 主位、Grid/Offset 原序、collage/excluded 空画布不加层、多层/隐藏/存储顺序+z-order 保持、重复 Apply 稳定）与真实 IO 回滚保持测试（全清、部分清、后续 canvas 保存保留、删除照片保留其他） |
| 补1 | `hasChanges` 只比 role，漏 source 变化 | `hasChanges` 改为比较**实际将保存的完整 role/source**（直接与 captured 比较），`automatic supporting → manual supporting`、重算新 automatic、清 nil 都能 Save；由同一 `choices` 派生，非 `nonisolated` 也一致 |
| 补2 | `Use suggested roles` 只清 draft，已存 manual 仍 fallback | 按钮把**当前全部照片**置为本轮 `.automatic` 草稿（按钮名与行为一致），仅 Save 持久化，Cancel 不写 |
| 补3 | 白名单测试误期待 `mountain range` | 测试期望改为白名单真实结果（排除 `mountain_range`），保留“不做子串猜测”断言；白名单未放宽 |
| 补4 | 新 workflow 复制了 Stage04/photo-analysis 的不准注释 | 只在新 `stage06-tests.yml`/`stage06-device.yml` 头部改成“Stage01–05 全部回归 + Stage06 角色测试”；Stage01–05 工作流未动 |
| 补5 | `RootView` 仍用旧 `PhotoRolesSheet(projectID:)` | `RootView` 传**同实例** `store:`/`photoImport:`，与 sheet 的 `init(projectID:store:photoImport:)` 一致；无其他旧调用点 |
| 补6 | `PhotoRolesRun.signature` 不含 `roleChoice` | 签名加入 `role/source` 或 `none`，并成为**唯一**签名：`PhotoLibrary.roleSnapshot` 直接委派给它；测试覆盖“仅角色改变→旧结果拒绝”与两者相等 |

## 0.2 补正 01–04 的逐项回应

| 补正 | 问题（Architect 原文要点） | 实际处理 |
| --- | --- | --- |
| 01.1 | 未实际用 `supportedIdentifiers` 筛选；face 框未检 `0...1` | 分类词表改为**该 request 实例真实** `supportedIdentifiers()` 与本项目白名单的精确交集（`supportedNaturalSceneVocabulary()`/`naturalSceneVocabulary(fromSupported:)`），测试注入集合；人脸只计有限且 `x,y≥0`、`width,height>0`、`maxX,maxY≤1` 的框 |
| 01.2 | 把 limited 成功误报失败；NaN/Inf/超界当证据；clip clamp | `Candidate` 分离 `analysisSucceeded` 与 `adequateSample`：**limited 成功仍是有效候选**，只有像素测量与语义两路都失败才无建议；`sceneScore` 只接受有限且 `0...1`，**越界/非有限舍弃**（测试覆盖 `.nan`/`.infinity`/`4.2`） |
| 01.3 | Grid/Offset 也调主位；误拼接 case 行 | 仅 `preset == .focus` 调整计算序列（`arrangementOrder`），同资产多层只把**原顺序首个**层提主位，其余保持相对顺序，输出 layers 存储顺序/z-order/IDs/baseSize/opacity/保护层不变；恢复 `noEditableLayers`/`tooManyLayers` 同行误拼接 |
| 补01原生 | `VNRequest.revision` 是 `Int`、`supportedRevisions` 是 class var/`IndexSet`；Vision 忽略 alpha | 观测字段 `classifyRevision`/`faceRevision` 用 `Int`；revision 用**具体 request 类型**的 class `supportedRevisions` 选最新支持值；`noVisiblePixels` 时**跳过 Vision** 并保留真实失败（含专项测试） |
| 02.1 | `roleSnapshot` 漏 `roleChoice` | 签名加入 `role/source` 或 `none`；补“同 asset 元数据不变但角色已变 → 拒绝”真实文件测试 |
| 02.2 | `[UUID: PhotoRoleChoice?]` 下标赋 nil 删键 + 库 `continue`，无法清除旧选择 | 改为**完整批量**语义：`[UUID: PhotoRoleChoice]`，当前照片必须全部出现在请求中，**未出现即清除**；库端校验 `Set(choices.keys) == Set(current.keys)`，缺键是拒绝而不是“保持不变”。补“旧 collage → Automatic → 新分析失败 → Save 清 nil”与“部分失败混合批量存储”测试 |
| 02.3 | 非法组合/多 primary 被当 IO `saveFailed` 让用户 Retry | 库把 `ProjectPackage.validate` 的非法组合映射为 typed `PhotoRoleSaveError.impossible` → `.rejected`（不可重试），IO 写失败仍为 `.saveFailed` + 草稿 Retry |
| 03.1 | Automatic 无法清除已保存 role；source automatic 被当 manual 冻结 | 草稿改为**可区分三态**：`[UUID: PhotoRole?]`，缺键=未改、`.some(nil)`=明确 Automatic、`.some(role)`=人工；getter 直接返回草稿（不再 fallback 保存角色），candidates/choices 同源；`Use suggested roles` 明确清当前人工草稿；改主图时先前 manual primary 自动降为 manual supporting |
| 03.2 | Save 用点击瞬间 fresh snapshot，stale 保护失效 | `expectedSnapshot`/`capturedRoles` 在**初次加载与 Reload**捕获，Save 只提交该快照；`Analyze again` 保留人工草稿与预期快照，只有 `Reload` 重新读取当前保存选择与快照；store 已变即拒绝并提示 Reload |
| 03.3 | 保存中可上划关闭；成功用旧 bool 关别的 sheet | 新增 `.interactiveDismissDisabled(isSaving)`；成功后核**当前** `navigation.sheet == .photoRoles(projectID:)` 才关闭；Cancel 即时 `invalidate()` |
| 03.4 | 宽高 `Int` 直接相乘可溢出 | `PhotoRolesRun.pixelArea(of:)` 用 `multipliedReportingOverflow` + 正值校验，溢出/非法即 **nil（不是候选）**，不 clamp 成最大面积冒充主图 |
| 03.5 | 只有 Reload，无 Analyze again；保存同状态反复成功 | 恢复可理解的 `Analyze again`（重算、保留人工草稿）与 `Reload`（解决过期并重载）；IO 失败保留草稿 + `Retry saving`；Save 按钮在没有任何实际变化时 `disabled` |
| 04.1 | `VNClassifyImageRequest.supportedIdentifiers` 当成 class 属性 | 改为实例 `func supportedIdentifiers() throws -> [String]`；抛错时返回空词表（**不伪造**），纯降减函数接收真实/注入集合 |
| 04.2 | `request.supportedRevisions` 当成实例属性 | 改为 `type(of: request).supportedRevisions`（具体 request 类型的 class var），仍以 `Int`/`IndexSet` 使用 |
| 04.3 | 新测试 `XCTAssertEqual(await …)` 与 `guard let` 字典 | 所有 async 结果先 await 到局部变量再断言；`roleSnapshot(for:)` 返回非可选字典，调用点不再 `guard let`；并检查无与既有 `XCTestCase` 扩展冲突的新私有 helper |

## 1. 交付物

新增（App）：

| 文件 | bytes | SHA256(前16) | 作用 |
| --- | --- | --- | --- |
| `MomentsStudio/Models/PhotoRoleChoice.swift` | 4860 | `71e17b7eb7c59986` | `PhotoRole`/`PhotoRoleSource`/`PhotoRoleChoice`（Codable/Equatable/Hashable/Sendable，严格解码） |
| `MomentsStudio/Models/PhotoRolePolicy.swift` | 11123 | `44ed6078a8c3a80b` | 确定性策略（manual优先/唯一primary/稳定排序/Automatic清除）+ 布局参与与 Focus 计算顺序 |
| `MomentsStudio/Models/PhotoRolesRun.swift` | 8023 | `9e21a4efcde31863` | sheet 的真实身份/请求 guard（含 roleChoice 签名）+ 溢出安全候选面积 |
| `MomentsStudio/Services/PhotoRoleAnalyzer.swift` | 12779 | `de62d625332fedb0` | 真实 Vision 词表/Vision 观测（revision、sceneScore 舍弃越界、face 0...1 边界、透明跳过） |
| `MomentsStudio/Services/PhotoRoleSaveError.swift` | 824 | `4f8c2571d9f2db0c` | typed 保存失败（projectMissing/photosChanged/impossible/busy） |
| `MomentsStudio/Features/PhotoImport/PhotoRolesSheet.swift` | 33041 | `67d787b8a4254108` | 可选 Photo roles sheet（真实三态草稿/Analyze again/Reload/Save/Retry、真实来源行、保存中禁止关闭） |
| `.github/workflows/stage06-tests.yml` | 44314 | `dca0d656d0c76a3e` | 手动原生测试入口（完整256项/40分钟/2天/门禁） |
| `.github/workflows/stage06-device.yml` | 9988 | `6702d9b0b5b0fea8` | 手动无签名设备包入口（macos-26/Xcode26+/SDK26+/6分钟/2天） |

新增（测试，70项；FIX07 后）：

| 文件 | 方法数 | 覆盖 |
| --- | --- | --- |
| `MomentsStudioTests/Stage06RoleChoiceTests.swift` | 7 | 契约与兼容：`nil` 不新增键、缺键/`null` 读作 nil、全 role/source 往返、未知 role/source/类型/自动collage拒绝、单 primary 校验、schema1 读回 |
| `MomentsStudioTests/Stage06RolePolicyTests.swift` | 14 | manual 优先、唯一 primary、非参与角色不自动分配、limited 成功是真候选、仅两路都失败才无建议、NaN/Inf/超界舍弃、面积/导入顺序 tie、captured manual 保留 vs automatic 刷新、**焦点只首个同 asset 层 + 直接 arrange（多层/隐藏/顺序/z-order/重复 Apply）**、参与集合与“全部不可参与”提示 |
| `MomentsStudioTests/Stage06RolesRunTests.swift` | 10 | 签名含 roleChoice 且与 `PhotoLibrary.roleSnapshot` 一致、仅角色变化即拒绝、旧 token/跨项目/换 sheet/删除照片拒绝、错 asset 与错 display 尺寸拒绝、`beginRequest` 边界、候选面积与溢出/非法尺寸、损坏元数据不成为候选 |
| `MomentsStudioTests/Stage06RolesSheetModelTests.swift` | 12 | **实际 UI 值模型**：人工草稿物化为 manual、未触碰 manual 保留、captured automatic 参与重算、明确 Automatic 清除/刷新、**role+source 变化可保存**、新主图降已存 manual primary（不误降 automatic）、`Use suggested roles` 语义 |
| `MomentsStudioTests/Stage06RoleStorageTests.swift` | 14 | 真实文件：保存+重开、原图/派生图字节不变、**全清/部分清**、部分失败混合、同 asset 角色变化拒绝、加照片后 stale 拒绝、跨项目拒绝、非法组合不写盘、**Vision 失败保留成功测量且不伪造**、全透明跳过 Vision、注入词表降减与打分、后续 canvas 保存与删除照片保留其他选择 |
| `MomentsStudioUITests/Stage06PhotoRolesUITests.swift` | 1 | 真实导入2张 → Roles 完成检查 → 人工选 Primary → Save → **重开显示真实值** → 改动+Cancel 仍旧值 → Automatic 清除 → 换主图 → 重启保留 → Focus 预览+Apply 后 layer 恰 2 不复制 → 角色仍保存 |

修改（App）：

| 文件 | 改动 |
| --- | --- |
| `Models/ImportedPhoto.swift` | 新增可选 `roleChoice` + 自定义 Codable（`nil` 不编码，未知值抛错） |
| `Models/ProjectPackage.swift` | `validate` 新增角色合法性 + 最多一个 saved primary |
| `Models/CollageLayout.swift` | 只对参与照片建层/排版、仅 Focus 调主位计算顺序；恢复误拼接 case 行 |
| `Services/PhotoLibrary.swift` | 新增 `observeRole`/`roleSnapshots`/`saveRoleChoices`/`roleSnapshot(of:)`；抽出共享 `loadThumbnail`（`analyzePhoto` 改用它，语义不变） |
| `Features/PhotoImport/PhotoImportModel.swift` | 新增 `observeRole` 只读桥接、`roleSnapshot(for:)`、`saveRoleChoices`（复用同一 mutation gate/token/原子写） |
| `Features/Editor/EditorPlaceholderView.swift` | 导航栏新增 `editor.photoRoles`（保留 Done 名称/标识/行为，导入工具区几何不变） |
| `App/RootView.swift` | `.photoRoles(projectID:)` sheet 分支 + 同实例环境注入 |
| `Core/Navigation/AppRoute.swift` | `SheetRoute` 新增 `photoRoles(projectID:)` |
| `MomentsStudio.xcodeproj/project.pbxproj` | 由既有生成器重新生成（190 objects） |
| `MomentsStudio/README.md` | 新增 Stage06 构建/验收入口与算法/边界说明 |

未改动：`Project`/`CanvasDocument`/`Asset`/`Layer` 字段、`schemaVersion`（仍 2，兼容 1）、原照片/派生图、Stage01–05 全部旧测试与断言、Stage04/05 四个冻结工作流（SHA 见 §4）。

## 2. 公开契约（唯一附加）

- 仅 `ImportedPhoto.roleChoice: PhotoRoleChoice?`；`role ∈ {primary, supporting, collageMaterial, excluded}`，`source ∈ {automatic, manual}`。
- `nil` = 没有保存选择；`automatic` = 用户 Save 接受了系统建议；`manual` = 用户指定。
- 解码：缺键与 `null` → `nil`；未知 role/source、错误类型、`automatic`+collageMaterial/excluded → **抛错**。
- 编码：`nil` 不写键 → 未使用角色的包保持原 schema2 字节。
- 校验（解码与写盘前）：至多一个 saved primary；非法组合拒绝。
- 不持久化：分析观测、sceneScore、人脸框、revision 均不入包；不是照片身份识别；无新增缓存/服务协议/Swift Package。

## 3. 算法与冻结决定（工程策略，非 Apple 推荐算法）

- 词表：`supportedIdentifiers()`（实例、throws）× 白名单精确匹配（大小写与 `_`/`-` 归一，不做子串猜测）；抛错/不支持即无证据。
- `sceneScore`：白名单标签中**有限且 0...1** 的最高 confidence；越界/非有限舍弃；`>= 0.5` 视为可能自然场景（阈值是工程策略）。
- 人脸：只计有限、`x,y≥0`、`width,height>0`、`maxX,maxY≤1` 的框；仅用于“Face detected; original photo kept.”，不推断身份/性别/美颜；`0` 不是“没有人”。
- 策略：manual primary 冻结主位；否则在非 manual collage/excluded/supporting 的候选中按 sceneScore（<0.5 记 0）→ adequate 采样 → 纠正尺寸面积降序 → 导入顺序选一个 primary；其余有证据者 supporting；**两路都失败**才 `.failed`。
- 布局：`nil` 严格保持 Stage04；primary/supporting 参与；collage/excluded 不自动加层/移动/隐藏；**仅 Focus** 把主图提计算序列首位（同资产首个层），Grid/Offset 原序；输出层顺序/z-order/IDs/baseSize/opacity/保护层不变；预览与 Apply 同源。
- 保存：完整批量 `[UUID: PhotoRoleChoice]`（缺键=清除）+ 完整快照校验；只改 `roleChoice`/`updatedAt`；复用同一 gate 与原子写；非法草稿 typed rejection。
- 透明：`noVisiblePixels` 跳过 Vision，保留真实失败与人工选择，不用透明像素的 RGB 标签伪造角色。

## 4. 本机实际执行与真实输出

| 检查 | 结果 |
| --- | --- |
| `tools/generate_xcodeproj.py` | 写入工程：MomentsStudio 40 / Tests 23 / UITests 7 文件引用，**192 objects** |
| `tools/verify_project.py` | **PASS**：192 objects、70 Swift（**17809 行**）、19 个 UI 标识符解析、App 声明 **101**、asset catalog 有效。**不证明 Swift 类型检查** |
| tree-sitter（0.26.0 + tree_sitter_swift） | 全部 **70 个 Swift 文件解析 0 ERROR** |
| **workflow 内嵌真实清单代码**（提取 `stage06-tests.yml` 的 heredoc 并注入真实 env 后执行） | **rc=0**：无重复方法名、`stage06 manifest: unit=245 ui=11 total=256`、`manifest_sha256=13ef38db970ba7c7…537efd4`；逐文件与冻结期望表一致；scheme 两个 testable 均不 skip。旧 **186 项一个未删** |
| `stage06-tests.yml` | PyYAML 可解析；**6 段内嵌 Python 全部 `compile()` 通过**；40 分钟上限；无 `-only-testing`/skip/retry |
| `stage06-device.yml` | PyYAML 可解析；**5 段内嵌 Python 全部 `compile()` 通过**；macos-26、6分钟、无签名、Xcode26+/SDK26+ 选择记录 |
| 冻结工作流保护 | `stage04-tests.yml` `1a0f19d05226ba27…`、`stage04-device.yml` `957198157f7f277d…`、`stage05-tests.yml` `1145ce48703a306c…`、`stage05-device.yml` `daf6e95ed9279b08…` **逐字节未变** |
| 源基线 | 70 Swift 逐文件 SHA256，按路径序聚合 `2243954a9dac9020959b70d8aa2f2d8f1f53a8f4a470ae6d0351b1df91c1c0ce` |
| 私密证据 | `.ai/build/stage06-dsh-implementation-20261010/`：`test-manifest.txt`、`test-methods.txt`、`test-method-counts.txt`、`test-source-hashes.txt`、`swift-source-hashes.txt`、`project-wiring.txt`、`BASELINE.txt`（明示是编码清单/源哈希，**不是** XCTest 结果） |

## 5. 未执行 / 不得冒充

- **本机没有任何原生结果，且首轮真实原生编译已失败**：本机 Windows 无 Xcode/模拟器/真机，也没有 `swift`/`swiftc`；已执行的云端 `run 38024488499` 是 **iphoneos Release 编译失败（exit 65、XCTest 未执行）**，FIX08 修复后**尚未重跑** → **256 项 XCTest 仍未运行**、无成功编译、无 Stage06 xcresult/IPA、无本人验收。手机上的已验收版本是 **Stage04/05 的 source `fe17ac0d`**（所有者三组“正常”＋同源设备包）；本轮没有新的 Stage06 IPA，也没有把 Stage06 装到手机上。项目结构由 Architect 独立通过，**Swift 语法树通过不等于类型编译**（首轮真编译失败正是本机检查覆盖不到的类型错误）；本机沙箱的 Bash 初始化失败只是本机权限问题，不是源码结论。**不得把 256 这个数量当成通过。**
- 因此**未在本机验证**：Swift 类型/actor 隔离、Vision 真实词表与 revision 行为、`CGContext` 透明行为、SwiftUI `Picker`/`.searchable`/AX 合并与 `.task(id:)` 时序、`roles.*`/`editor.photoRoles` 在原生层级的真实暴露、真实照片的建议观感与文案。
- 静态检查（工程接线、语法树、YAML/内嵌 Python、清单门禁）**不等于** Xcode 通过；§4 的清单是编码清单。
- **本次FIX08修复源码尚未推送或触发**（交付时）；首轮198c755源码工作流已由Architect实际派发且编译失败，见§0.0b。DSH本轮未做费用或账户动作；Stage04/05四个工作流保持冻结边界，不在新源码上派发旧入口。
- 已知限制（如实）：① `sceneScore` 阈值 0.5 是工程策略，不是准确率；② 建议只做 primary/supporting，`collageMaterial`/`excluded` 完全靠用户；③ 全透明照片无自动建议（保留真实失败与人工选择）；④ 旧版 App 读附加键可以，但旧版再写可能丢角色选择，**不宣称降级写入保留**；⑤ `invalidMetadata` 在包契约下不可达（`ProjectPackage.validate` 已保证为正尺寸/合法方向），只在直接调用 analyzer 时可达。
- 布局/存储的既有实现（Stage04 排版、Stage05 分析）在 `analyzePhoto` 上只做了等价重构（共用 `loadThumbnail`），Stage05 的 31 项与断言未改。

## 6. 待 Architect 复审与后续

1. 独立复审本报告、§1 差异与私密证据；确认契约（§2）、策略/阈值（§3）与四项补正的落地方式。
2. 冻结本源码后单次运行 `stage06-tests.yml` 的完整 256 项；失败按明确根因修复后重验，不放宽断言、不跳过。
3. 原生通过后准备同源设备包（`stage06-device.yml`）交本人在 iPhone 上看 Photo roles 的实际观感（建议依据、Automatic、Save/Cancel）与 Focus 预览；自动测试与本报告都不替代本人验收。
4. Stage07 未授权、未开始；任何提交/推送/派发/费用/账户动作由 Architect 组织与所有者授权，DSH 不自行执行。
