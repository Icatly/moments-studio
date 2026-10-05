# STAGE-02-PREFLIGHT-FIX-07 报告

Stage02 FIX07 — 实际导入后的屏下图库准备与主按钮标题最小替代（**仅本地实施与验证，未 native 执行**）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-07.md`、`run-37248700016` 本地原始证据
状态：`READY_FOR_ARCHITECT_REVIEW`

日期：2026-10-05（本机无可信时钟，按任务要求只写日期）

---

## 1. 第七轮真实证据（run37248700016 / source `590ccf3`）

- 08:44:58–08:57:56 实际 12:58，结果 **85 / 84 / 1 / 0 / 0**；唯一失败在测试**第 154 行**（初次 thumbnail `waitForExistence` 90 秒，耗时 145.660 秒）。完整 artifact 124,915,141 B、SHA `043b42a3…8113d` 已匹配 GitHub；原 `job.log` 808,551 B；失败层级 `failure-attachments/DF6EF151-B5E7-4308-891D-130A61823132.txt`。
- **原日志与 dump 共同证明**：FIX06 的**唯一 Close 一次成功**（photo count 0 → 9）；元素相对中心点击选中了真实照片、`Done` 启用并返回 Editor ✓。失败时 Editor 确实为 `editor.photoCount` = `1 of 20 photos`，项目状态 `Photos, 1` / `Saved on device, Yes` —— **不是导入未完成或原图丢失**。
- 实见几何：窗口高 874、真实 `NavigationBar {{0,62},{402,54}} identifier 'Untitled Project'`；`ScrollView {{0,0},{402,874}}`；`StaticText identifier 'editor.photoCount' {{16,920},{268,52.7}} label '1 of 20 photos'`（**y=920 在屏下**）；`Photos, 1` 在 y=1811.3、`Saved on device, Yes` 在 y=1891.7；**没有任何 `editor.photo.<assetID>` 缩略图 AX 节点**。
- 措辞边界（按任务）：以上由原 dump 直接证明；**结合产品 `LazyVGrid` 源代码推断**「惰性布局尚未创建/暴露缩略图 AX」是当前原因，**不宣称**已验证 Apple 内部节点创建机制。因此「先等 target 存在再滚动」的旧顺序**无法**处理这一实见状态。
- Architect 实际目视：原生 Home PNG `DDC2A057-…` 仍为 `Cre- / ate Proj…`（FIX06 仅在**外** Label 上加的纵向修饰符未解决截断）；Photos 关闭前后、选中 1 张的 PNG 亦为真实深色 + 最大字号。本轮 85 项未通过，预览/Popover/移除/再导入/重启/后段深色**尚未执行到**，故不改尚未失败的 Popover 逻辑。

## 2. 改动（仅 2 个文件）

### 2.1 `MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`：最小 Editor 图库准备

新增小函数 `prepareEditorGallery(expectingThumbnail:in:session:)`：

- **只在当前 thumbnail 尚不 `exists` 时**才动作（默认已存在→不加任何手势）；
- **先严格校验 Editor 归属**：真实 `editor.placeholder` 存在、无系统 `Photos` 选择器导航、无预览 Sheet（用 app 已声明的 `preview.*` 标识判定）、Editor ScrollView 与导航栏均唯一；
- 再要求**唯一**的计数锚点：`app.staticTexts.matching(identifier: "editor.photoCount")` 的 `count == 1`（不用 `firstMatch` 掩盖唯一性）；
- 然后对该唯一锚点使用**既有 `XCTNSPredicateExpectation` + `XCTWaiter`** 等待 `exists == true AND label == "1 of 20 photos"`，**最多 90 秒**：真实计数节点常以 `0 of 20 photos` **先存在**，故仅凭 `waitForExistence` 会**在异步导入完成前提前返回**（09:07 复审指出的缺陷，已修正为等待「已提交的标签」）；无 sleep、无重复点击；
- **等待提交完成后**才调用 FIX06 已复审的 Editor 有界滚动 helper，让该锚点进入真实可用 viewport（锚点实见 y=920，**存在但在屏下**）；**不把不存在 thumbnail 的 frame 当有效、不猜坐标、不盲滚**；
- 保存**准备前/后**两张 `keepAlways` 截图与诊断（前缀 `INTERACTION-VERIFY[gallery]`，含锚点 frame、app frame、thumbnailExists）；
- **guard 失败只打印具体诊断并返回**（`XCTFail`/`XCTAssert` 均不出现于该 helper），失败的判定**仍由原存在/ID 断言**给出；锚点已提交而 thumbnail 仍缺失时不继续滚动。

调用点（均在对应查询之前）：初次 thumbnail 存在等待、再导入存在等待、重启恢复后的资产 ID 枚举、深色资产 ID 枚举、移除 thumbnail 查询、确认移除 thumbnail 查询。

**注释与措辞**：该 helper 的文档注释已从「anchor stays on screen」改为**「exists but sits below the screen」**（与实见 y=920 一致）；「惰性网格尚未创建/暴露缩略图 AX」明确写为**结合产品源码与 dump 的推断**，**不宣称**已验证 Apple 内部创建机制。

**保留**：全部 **99** 条现有完整断言**原文与顺序**（新增调用不改变任何既有断言表达式）、**80 + 5 = 85** 方法；**未改**产品 `LazyVGrid`、素材标识/去重、`photoCount` 与 ID 断言。**`photoCount` 为 1 不是预览完成的证据**——原缩略图/typed preview 等断言仍决定通过。

### 2.2 `MomentsStudio/MomentsStudio/Features/Home/HomeView.swift`：主按钮标题最小替代

按 FIX06 报告已提的最小替代方案，把 `createProjectButton` 的 Label title 写成**显式 `Text`**：

```swift
Label {
    Text("Create Project")
        .multilineTextAlignment(.center)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
} icon: {
    Image(systemName: "plus")
}
.font(Typography.body.weight(.semibold))
.foregroundStyle(createProjectLabelColor)
.frame(maxWidth: .infinity, minHeight: Layout.minimumTapTarget)
```

- icon 仍是原 `plus`；**原系统字体、动态颜色、44 最小点击区、`.buttonStyle(.borderedProminent)`、创建动作、`accessibilityIdentifier("home.createProject")`、`.disabled(!photoImport.isReady)` 与 ready 行为全保留**；
- 移除已证明**无效**的外层两修饰符以避免重复，保持最小差异（HomeView 与 HEAD 的 diff 共 30 行变化，**全部落在该 Label 表达式内**）；
- **无其他 Home 布局重设计、无文案/导航改动**；
- **无 native 环境，不能声称已消除截断**。

### 2.3 明确未改

workflow（与 HEAD **逐字相同**）、Photos 唯一 Close、照片元素相对中心点击、Popover 相对中心取消逻辑，以及所有其他产品/契约/依赖/工程/`tools` **全部未改**。

## 3. 本机（Windows）实际执行的检查

`STAGE02_PREFLIGHT_FIX07_CHECK: PASS`（**27/27**）：

- **断言保留**：与 HEAD `590ccf3` 逐条抽取比对——**123 条既有长字符串全部按原顺序保留**（有序子序列）；**断言数 99 → 99**（本轮只新增调用与截图，不新增断言）；**80 + 5 = 85** 方法不变。
- **图库准备（含 09:07 复审修正）**：仅 thumbnail 不存在时动作；先证明 Editor 归属（placeholder/无 picker/无 preview/scroll 与 nav 唯一）；要求**唯一**计数锚点（`matching(identifier:)` + `count == 1`）；用 `XCTNSPredicateExpectation` + `XCTWaiter` 等待 `exists == true AND label == "1 of 20 photos"` 最多 90 秒（**不再**用 `waitForExistence` 后立即比较标签），且滚动发生在**等待提交之后**；helper 内只有诊断、无 `XCTFail`/`XCTAssert`（失败由原断言决定）；函数内无 `CGPoint(`/`coordinate(`；6 个调用点齐全且都在对应存在/ID/移除查询**之前**；原存在/ID 断言原文在位。
- **注释措辞**：`prepareEditorGallery` 注释已改为「anchor **exists but sits below the screen**」（与实见 y=920 一致），并把惰性 AX 说明标为**源码+dump 推断**、非已验证 Apple 机制；Home 注释改为「**intended** to let the label wrap … still awaits verification on a real run」，不再写「is what actually wraps」。
- **Home**：显式 `Text("Create Project")` + `.multilineTextAlignment(.center)` + `.lineLimit(nil)` + `.fixedSize(horizontal: false, vertical: true)` 各恰一处；`Label { … } icon: { Image(systemName: "plus") }` 在位；字体/动态颜色/44 仍在 Label 上；action/identifier/disabled/buttonStyle 行**未被改动**；diff 全部落在该 Label 表达式内；`MomentsStudio/MomentsStudio` 下**无其他产品文件改动**。
- **未改校验**：workflow 与 HEAD **逐字相同**；测试文件相对 HEAD 的**所有删除行**均不涉及 Close/Popover/`popovers`/`sheets.matching`/`coordinate(withNormalizedOffset` 等区域；授权的两次元素相对中心点击与一次 `close.tap()` 仍各恰一处。
- **工程**：`tools/verify_project.py` **exit 0**（40 Swift **7464 行**）、tree-sitter `40 WITH_ERRORS=0`、`git diff --check` 干净；代码改动恰好 2 个文件（UI 测试 + HomeView）。

## 4. 未执行 / 预算 / 边界（如实声明）

1. **没有 macOS、没有 Xcode、没有云端执行**：图库准备与 Home 标题替代**均未 native 验证**；本报告的27项是 Windows 静态/差异校验。第七轮**未执行到**预览/Popover/移除/再导入/重启/后段深色，故对这些部分**不作任何通过声明**；也**不声称** Home 截断已解决。
2. 云预算（任务给出）：上一轮 13 整分估 **$0.806**，七轮合计约 **$6.076**，旧截图推算**剩约 $0.464**，**不足 18+2 分钟完整下一轮** → 本任务**仅本地实施/复审**，**未触发任何云任务**、未绕过 85 门禁。
3. 未 commit/push/query/付费/改账户；Appetize 31/30（0 分钟）；今天是所有者授予的**Stage02 免逐项审批**，但**本人亲自操作与验收均未发生**（两者分别记录）；Stage03 禁止。
4. `UIKitToolbar` 运行告警根因仍未确立，记录为已知限制（未改纯 SwiftUI toolbar）。

## 5. 下一步

Architect 复审本报告与两文件 diff → 待核实可用免费预算/环境后按今天既有授权**单次**真实运行，核对：`INTERACTION-VERIFY[gallery]` 日志与前后截图、缩略图 AX 是否真正出现（仍由原断言判定）、以及 Home 主按钮标题在最大字号下的原始 PNG 是否完整；在拿到该证据前不宣称任何修复通过。

Architect 终审补记：09:13实际DSH最终答复并停止（09:15截图实见）；09:07意见实际09:09送达。报告残留7429/22旧数按独立最终7464/27校正。独立比对99完整断言全等/80+5、40Swift/7464、workflow与旧scroll/Close/Popover逐字未改，本地复审接受，新native未执行。
