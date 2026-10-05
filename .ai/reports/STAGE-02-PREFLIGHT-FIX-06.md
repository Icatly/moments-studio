# STAGE-02-PREFLIGHT-FIX-06 报告

Stage02 FIX06 — 最大字号下真实用户操作补齐（仅实施 + 本地验证，**尚未 native 执行**）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-06.md`、Round32、`run-37230253288` 本地 `job.log`（756,332 B）与 `failure-attachments/2E070560-7350-4C4F-801B-0644D838AEA2.txt`
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 macOS/Xcode/云端执行**）

---

## 1. 第六轮真实证据（run37230253288 / source `64fb192`）

- 实际 04:12:17 failure：**85 / 84 / 1 / 0 / 0**；80 单元与其余 4 个 UI 通过。
- 唯一失败：**测试第 133 行**（照片选择）——scope 存在但 `PXGGridLayout-Info` **count 0**。Architect 已用 Windows 原生 WPF 抽帧审阅 40 秒录屏：真实深色 + 最大字号下，系统的 **Private Access 说明占满可视区**，关闭 X 实际可见，照片在下面（**仅抽帧，未完整播放**）。
- 实见层级（本次已读原文件）：`ScrollView photosView_content_scroll_view frame(0,72,402,802)`；`Other identifier 'PXGSingleViewContainerView_AX' frame(0,184,402,896.7)`（label `Private Access…`）内含 `Button label 'Close' frame(350,192,30,22)`；**外部重复 banner 也有自己的 Close**，故不能用 `app.buttons["Close"]` 或 `firstMatch` 掩盖归属；网格 `photos_sectioned_layout`/`PXGGridLayout-Group` 从 **y=1080.7** 起，位于 874 高的屏幕**之下**。
- Editor 实见：真实 ScrollView 内容高 2256.3（4 pages），正文 559.3；Import 高 125.3 从 **y=786.7** 起；count 920 / empty 988.7 —— 最大字号路径**需要真实用户滚动**，不能把「屏外元素存在」当作可操作。
- 环境控制正确：最大 `content_size` 与 `dark` 设置、测试后持续读回、还原均双 exit 0、精确值；完整 artifact 76,876,546 B、SHA `951fd7c4…3acf` 已匹配 GitHub。**不声称**产品坏/权限失效/无照片，也不换 scope。

## 2. 改动（范围：UI 测试 + workflow 一行 + 04:22 授权的最小 Home 布局修复）

### 2.1 唯一 AX 容器内**一次** Close（仅现代分支，原 photo 等待之前）

新增 `closeOverflowingPhotoAccessOnboarding(in:scope:photos:session:)`：

1. 以**完整 identifier** 查询 `app.otherElements.matching(identifier: "PXGSingleViewContainerView_AX")`，要求 `count == 1`；
2. overflow 条件：container 与 scope 的 frame 均 finite/正，且 **container 高度 > scope 高度** 且 **当前 photo count == 0**；**不满足即走旧默认路径**（返回成功、不做手势）；
3. Close **只在该容器内**按精确 `label == "Close"` 查询且要求 `count == 1`（不使用 `app.buttons["Close"]`、不使用 `firstMatch`）；
4. Close 须 enabled + hittable，frame 有限正且**同时落在 scope 与 app 内**；
5. 记录实际层级（`app.debugDescription`）与计数，保存**关闭前/后**两张 `keepAlways` 截图（前缀 `INTERACTION-VERIFY[onboarding]`）；
6. 仅执行**一次** `close.tap()`；无私有 API、无绝对坐标、无重复点击；失败硬报具体证据。
   关闭后照旧进入原「photo 存在 → 有效 frame → 相对元素中心单次选择 → Done 启用 → 真实导入」全部断言。

### 2.2 Editor 内最小有界用户滚动（按 04:26 初稿复审修正）

新增 `scrollEditorToMakeHittable(_:in:)`：

- 目标**已 hittable** → 直接返回、不做任何手势（默认路径不做手势）；
- **Editor 归属证明**（不再只用 `navigationBars.count == 1`）：真实 `editor.placeholder` 存在 **且** 无系统 `Photos` 选择器导航 **且** 无预览 Sheet（用 app **已声明**的 `preview.image`/`preview.done` 判定，避免查询未声明的标题字符串）**且** Editor ScrollView 唯一（`app.scrollViews.count == 1`）；
- **可视 viewport**：`scrollView.frame` 与 `app.frame` 的**交集**，再按实际 Editor `navigationBar.frame` 覆盖区做垂直修正；viewport 必须 finite/正，否则返回 false；
- **每次循环**重新读取 `target.frame` 与 viewport：目标任意部分越过可视底边（`targetFrame.maxY > viewport.maxY`）才 `swipeUp()`；目标任意部分越过可视顶边（`targetFrame.minY < viewport.minY`）才 `swipeDown()`；**在可视区内却不可 hit** 或 frame 非法 → **直接返回 false/诊断，不按 app 中心猜方向**；
- 原生 swipe **至多 3 次**；**不是点击重试**；picker/preview/banner 场景因归属证明不成立而直接拒绝。
- 应用点（**实际 12 处**，均保留原 wait/assert **原文**）：首次 import 入口、首个 thumbnail、移除/确认移除 thumbnail、再次 import 入口、重启恢复后的 import 入口与 thumbnail、**`restoredDone` 之后**、**`darkDone` 之后**、**`darkProjectRow` 重新打开之后**、深色下的 import 入口与 thumbnail；导航仍用既有精确 project/asset 标识。
- **04:26 补齐**：`editorAfterRestore`、`restoredDone` 后、`darkDone` 后、`darkProjectRow` 重开后这 4 个旧可操作断言前各补一次 helper 调用，**这 4 条旧断言原文逐字未改**（新增断言数按实际统计，不是初稿的 8）。

### 2.3 保留

FIX-05 的 Popover 取消逻辑（唯一 Popover→精确 Sheet→唯一 `PopoverDismissRegion`→中心在 Popover 外→一次相对中心点击）、照片**元素相对中心单次点击**、旧系统分支（hittable 等待 + 原生 `photo.tap()`）全部保留；**未加**测试方法、**未删**断言、未改契约/依赖/工程/tools。

### 2.5 04:22 补充：唯一授权的最小 Home 布局修复（**产品改动**）

- **实际缺陷依据**：Architect 用同一原始录屏解码查看请求 6 秒（Home）/9 秒（Editor）帧，确认真实深色 + 最大字号；Home 原生导航大标题截断属系统表现，但主操作 **Create Project 实际显示为 `Cre- / ate Proj…`**，主操作词无法完整阅读 —— 属 Stage02 真实视觉缺陷，**不能**用测试通过掩盖。
- **改动**：仅 `MomentsStudio/MomentsStudio/Features/Home/HomeView.swift` 中既有 `createProjectButton` 的 **Label** 增加两行修饰符：
  ```swift
  .multilineTextAlignment(.center)
  .fixedSize(horizontal: false, vertical: true)
  ```
  并附说明注释。**保留原文**：`Label("Create Project", systemImage: "plus")` 完整字符串、`Typography.body.weight(.semibold)` 系统语义字体、`createProjectLabelColor` 动态颜色、`minHeight: Layout.minimumTapTarget`（44）、创建动作 `navigation.push(.editor(projectID: project.id))`、`.accessibilityIdentifier("home.createProject")`、`.disabled(!photoImport.isReady)` 与 ready 行为。
- **未改**：导航、模型、copy、品牌、依赖、其他任何 product 文件；未重设计 Home。
- **若 native 仍不能保证完整**：按任务要求**先报告**最小替代方案（保留 `Label` 但把 title 换成显式 `Text("Create Project").multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)`），**本轮未预先实施**该替代，待真实证据决定。
- **新版 Home 视觉尚未 native 验证**（我无 macOS）。

### 2.6 04:22 补充：创建前的初始 Home keepAlways 截图

在原完整 UI 路径中，**记录 Home 项目 ID 基线之后、`createProject.tap()` 之前**新增一张 `keepAlways` 全 app 截图，命名为 `INTERACTION-VERIFY[home] initial Home before creating`，供下一轮真实最大字号下核对主操作文案是否完整（**不**添加镜像常量测试；**现有 87 条断言全部保留**）。

### 2.4 workflow：仅 `timeout-minutes: 20 → 18`

逐行 diff 核对为**恰好一行**（见 §3）。预算依据（任务给出）：第六轮 14:18 按 15min 估 $0.930，前 6 轮合计约 $5.270，所有者截图 $12 included 已抵 $5.46 推算余约 $1.270；下一轮 18+2min 预算约 $1.240 在估余内，**不是新账单**。**不压缩测试、不忽略失败**；若 18 分钟超时也如实 failure、不自动重跑。

## 3. 本机（Windows）实际执行的检查

`STAGE02_PREFLIGHT_FIX06_CHECK: PASS`（**42/42**；含 04:22、04:26、08:36 三次补充）：

- **断言保留**：与 HEAD `64fb192` 逐条抽取比对——**111 条既有长字符串全部按原顺序保留**（有序子序列）；断言数**当前实际 87 → 99**（新增均为 `INTERACTION-VERIFY[onboarding]/[editor-scroll]` 前缀），**80 + 5 = 85** 方法不变。*（历史记录：08:36 修正前分别为 87 → 95 与 35/35、40/40 等中途统计，保留于此仅作历史，非当前值。）*
- **workflow**：diff 恰好一行（`-    timeout-minutes: 20` / `+    timeout-minutes: 18`）；85 契约、2 天保留、guard 与上传条件未变；纯 ASCII、无 CRLF。
- **Close 路径**：唯一 container 整 identifier + `count == 1`；overflow 双条件（高于 scope + count 0）；非 overflow 走旧路径；Close 仅容器内、精确 label、唯一；enabled+hittable 且 frame 在 scope/app 内；**恰一次** `close.tap()`；前后 `keepAlways` 截图与层级打印；无 `app.buttons["Close"]`/`firstMatch`/私有 API/绝对坐标；确实挂在**现代分支原 photo 等待之前**；旧分支未被触碰。
- **Editor 滚动**：已 hittable 不手势；Editor 唯一上下文 + 有限 frame 前置；方向来自真实 frame；≤3 次原生 swipe；非点击重试、无绝对坐标；调用点覆盖任务列出的全部目标且**未出现在 picker/preview helper 内**；原 `waitUntilHittable` 断言仍在。
- **保留行为**：照片相对中心单次点击（2 处授权调用：picker + popover 关闭）、FIX-05 Popover 取消（唯一 Popover/Sheet/DismissRegion 与中心在外）均在位；无 skip/sleep/launch 注入。
- **范围**：代码改动**恰好** `Stage02ImportUITests.swift`、`stage02-testflight-preflight.yml`、`MomentsStudio/.../HomeView.swift`（04:22 授权）；`tools/verify_project.py` PASS（40 Swift 7378 行）、tree-sitter `40 WITH_ERRORS=0`、`git diff --check` 干净。
- **04:26 补充项（初稿复审修正）**：Editor 归属证明改为 `editor.placeholder` + 无 `Photos` 选择器导航 + 无预览 Sheet（用已声明的 `preview.*` 标识判定）+ 唯一 Editor ScrollView；viewport = scrollView ∩ app 再减去 nav bar 覆盖区，且必须 finite/正；**实际 helper 调用点 12 处**；`editorAfterRestore`、`restoredDone` 后、`darkDone` 后、`darkProjectRow` 重开后这 4 条旧断言的 helper 已补齐，且**这 4 条断言表达式与文本逐字未改**。（其中「方向判定」一项已由下方 08:36 补充进一步修正。）
- **08:36 补充项（部分溢出边界复审）**：方向判定改为**任意部分溢出**即手势——`targetFrame.maxY > viewport.maxY` ⇒ `swipeUp()`、`targetFrame.minY < viewport.minY` ⇒ `swipeDown()`；**完全在可用 viewport 内部却不可 hit** 才返回 false（不再只处理完全屏外，第六轮实见 Import `y=786.7` + 高 `125.3` 的部分溢出因此可被处理）。**每次循环重新读取** `target.frame`、`app.frame`、`scrollView.frame` 与导航栏 frame；Editor 侧要求 `app.navigationBars.count == 1` 后才取 `.element.frame`（不再用 `firstMatch` 掩盖唯一性），导航 frame 无效即硬返回 false；仍至多 3 次原生 swipe、已可 hit 不手势、非点击重试、无绝对坐标。
- **工具豁免**：`tools/verify_project.py` **仍 PASS（exit 0）且未改动**——预览判定改用 app 已声明的 `preview.image`/`preview.done` 标识，而不查询 app 自身的 `NavigationBar` 标题字符串，因此**不需要任何新豁免**（沿用「若需豁免先报告、不擅改工具」的既有约定）。
- **04:22 补充项**：HomeView 与 HEAD 的 diff **仅 8 行新增**（注释 + 两行修饰符），无任何删除或改写；`multilineTextAlignment(.center)` 与 `fixedSize(horizontal: false, vertical: true)` 各恰一处；完整字符串/系统字体/动态颜色/44 最小点击区/创建动作/identifier/disabled-ready 行为逐项仍在；`accessibilityIdentifier(` 与 `Text(` 计数与 HEAD 相同（未增删文案或标识）；`MomentsStudio/MomentsStudio` 下**除 HomeView 外无其他产品文件改动**；新增的初始 Home 截图恰一处、命名清楚、且在 `createProject.tap()` **之前**。
- **披露**：工作树另有 `MomentsStudio/README.md` 的未提交改动（mtime **04:03:56**，早于本轮），内容为 `large_text`/`dark_appearance` 环境输入与第五轮证据的文档说明——那是 Architect 早前的文档更新，**本轮未触碰**，故未计入本轮范围。

## 4. 未执行 / 未验证（如实声明）

1. **没有 macOS、没有 Xcode、没有云端执行**：两个新 helper 与 **04:22 的 Home 布局修复**都**从未 native 运行**；本报告的42项是静态与差异校验（Swift/SwiftUI 逻辑与渲染无法在 Windows 执行）。
2. **不声称**新 Close、Editor 滚动或完整路径通过。最大字号下真实可操作性/像素仍需下一次真实运行的**原日志 + 原始 PNG**判定；若 Close 后网格仍不可达、或滚动方向/次数不足，按新证据另行定位（不猜、不换 scope、不加坐标）。
3. 第六轮的失败**不是**产品坏、权限失效或「没有照片」——本轮不改系统权限、不隐藏实际照片（沿用任务定性）。
4. `UIKitToolbar` 运行告警根因仍未确立，记录为已知限制，**未**修改纯 SwiftUI toolbar。
5. 未 commit/push/cloud、未触发/查询运行、未付费、未改账户；Appetize 31/30（0 分钟）；**今天所有者授予 Stage02 免逐项审批**，但**本人亲自操作未执行、本人验收未发生**；Stage03 不启动。
6. **产品范围变化如实列出**：本轮在 Architect 04:22 明确授权下修改了 `HomeView.swift` 的一处 Label 修饰符（多行居中 + 纵向自适应），**不再是「产品零改动」**；该改动**未 native 验证**，是否会真正消除 `Cre- / ate Proj…` 截断须由下一轮原始 PNG 判定；若仍截断，按 §2.5 报告最小替代方案后再改。
7. 预算：新增三张 keepAlways 截图（onboarding 前/后 + 初始 Home）与层级日志（约数 MB / 数十 KB），测试时长预计 +10–30 秒；18 分钟上限下若超时如实 failure，不自动重跑。

## 5. 下一步

Architect 复审本报告与 diff → 单次真实运行（最大字号 + 深色）→ 核对第 133 行路径是否走通、`INTERACTION-VERIFY[onboarding]/[editor-scroll]` 日志与前后截图、85/85、以及原始 PNG 的深色与最大字号可操作性。

Architect 08:41终审校正：DSH最终答复界面实际08:41已停止；报告剩余旧方向/行数/检查数文字按最终源码修正。DSH交接所写08:50属于未经时钟核实的时间，实际完成证据是08:41截图，不作08:50事件证据。独立87条完整断言原文有序比对PASS，99现有/80+5，40 Swift/7378行；新native未执行。
