# STAGE-02-PREFLIGHT-FIX-05 报告

Stage02 FIX05 — 实见系统 Popover 取消路径
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-05.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-29.md`、本地 `run-37225749574` 原始日志与 `failure-attachments/9EC5723E-3844-4E91-AE25-8D24E01DC74D.txt`
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 Xcode/云端执行**；Apple/付费/Stage03 仍禁止）

---

## 1. 第四轮真实证据（run37225749574 / source `8d1f954`）

- Xcode 26.6 / build 17F113 / iphoneos SDK 26.5 / iOS 26.5 iPhone 17 Pro arm64；设备 Release、产品 guard、诊断导出/上传均成功；包装 skipped、无新 ZIP；`total=85 passed=84 failed=1 skipped=0`（job 13:15）。
- **本轮新通过**（真实执行）：首张照片的**元素相对中心点击成功**、真实导入 `count=1`、typed loaded preview、`Done` 返回可用 Editor；PNG `47BB9075…` 目视选中 1 张，PNG `AB73206E…` 目视圆形透明 PNG 比例正常、完整在屏内。
- **唯一失败在 `Stage02ImportUITests.swift:243`（Cancel）**：原 helper 先找 Sheet 的 Cancel（15 秒）再无条件返回 Alert 的 Cancel，而实见层级中**根本没有 Cancel**。
- 原始层级（`9EC5723E-….txt`，DSH 已实际读取）关键事实：
  - `Popover, {{81.0, 72.0}, {240.0, 247.3}}`；
  - 其内 `Sheet, label: 'Remove this photo from the project?'`，含该标题 StaticText、`Only this project's copy is deleted. The photo in your photo library is not changed…` 说明，以及唯一 `Button, {{97.0, 242.3}, {208.0, 48.0}}, label: 'Remove'`；**没有 Cancel**；
  - 外层：`Other, identifier: 'PopoverDismissRegion', label: 'dismiss popup', {{0.0, 0.0}, {402.0, 874.0}}`（在本 dump 中唯一）。
  - 因此取消只能通过该实见关闭区域；其相对中心 (201, 437) 落在 Popover y 区间 72–319.3 **之外**（x 在 81–321 内），即**严格位于 Popover 外**。
- Apple 文档（confirmationDialog）说明 popover 可点外部关闭，但**没有**证明本机 iOS 26 的内部成因或 size class，故报告不作推断。

## 2. 改动（仅 `MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`）

新增窄 helper 与两个共用检查，并把原 Cancel `.tap()` 调用改为该 helper（任务第 2 条明确允许；Architect按最终源码纠正报告中的拆分描述）：

- `usesModernSystemUI`（系统版本分支）、`isFinitePositive(_:)`（finite + 非空 + 正宽高，空 frame 永不当作可见）。
- `cancelRemovalConfirmation(in:)`：
  - **旧系统分支**：`confirmationButton(named: "Cancel")` → `waitUntilEnabledAndHittable()` → 一次点击；**完全保留**原真实 Sheet/Alert Cancel 路径。
  - **iOS 26 分支**：在同一 `cancelRemovalConfirmation(in:)` 内执行以下检查，没有另建 `dismissPopoverConfirmation` 函数。
- iOS 26 分支依次硬校验：
  1. **唯一 Popover**：`app.popovers` 的 `count == 1` 后取 `.element`（不使用任何 `firstMatch`）；捕获 `popoverFrame`。
  2. **该唯一 Popover 内、精确标题的唯一 Sheet**：`popover.sheets.matching(NSPredicate(format: "label == %@", "Remove this photo from the project?"))` 的 `count == 1` 后取 `.element`。
  3. **问题与说明限定在该 Sheet 内**：`sheet.staticTexts` 中精确等于该标题的问题、以及包含 `photo library is not changed` 的说明都必须存在；**不使用**全 app 相似文本（确认归属不可由 app 内任意同名文本代替）。
  4. **唯一关闭区域**：`app.otherElements.matching(identifier: "PopoverDismissRegion")` 的 `count == 1`（整 identifier 匹配，**不是** first 任意节点）且有界就绪。
  5. **帧校验（同一处同时验两个 frame）**：`isFinitePositive(regionFrame)`、`isFinitePositive(popoverFrame)`、`app.frame.contains(regionFrame)`、`app.frame.contains(popoverFrame)` 全部成立。
  6. 计算相对中心 `CGPoint(x: midX, y: midY)`，要求**在屏内**且 `!popoverFrame.contains(centre)`（严格在 Popover 外）——该点**只用于校验**，不作为点击目标。
  7. 打印真实窗口层级（`app.debugDescription`）、popover/dismissRegion/centre 与动作策略，保存**取消前**原生全 app 截图。
  8. 仅执行**一次** `dismissRegion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()`；随后保存**取消后**全 app 截图。
  - 任一前置不满足即返回失败并硬失败；**不**换点、不换候选、不做坐标循环、无 sleep/重试/skip/forceTap/私有 API。
- 日志与截图统一前缀 `INTERACTION-VERIFY[confirmation]`（本次 7 处使用）。
- **未改**：原 48 条行为断言原文、FIX-04 追加的全部 `INTERACTION-VERIFY[picker]/[restart]/[dark]` 检查、`Remove` 路径（仍限定真实 Sheet/Alert：`app.sheets.buttons[label]` → `app.alerts.buttons[label]`，无全 app 同名按钮任取）、取消后的 `removeButton`/`Done`/count1 与后续 Remove→empty→再导入→重启→深色全部保留。
- **未改**产品 Swift、工程、契约、依赖、**workflow**。

## 3. 工程校验与「豁免」结论（按要求先报告、未擅改）

- `python tools/verify_project.py` → **PASS（exit 0）**：132 对象、41 引用、40 Swift 文件 **7148 行**、11 个 UI 标识符可解析（含 `BackButton`/`home.libraryError`）；Architect独立重新执行确认该最终行数。
- `tools/verify_project.py` 与本轮 HEAD **逐字未改**（本机 harness 断言 `tool_now == tool_head`）。
- **因此本轮不需要任何新豁免**。原因如实说明：该工具目前只扫描 `app.<type>["identifier"]` 形式的查询，而本轮的 `PopoverDismissRegion` 是用 `app.otherElements.matching(identifier:)` 查询的，**不在其扫描范围内**——这属于工具既有的覆盖局限，不是本次引入的问题；我在 harness 中对字面量做了显式断言，并人工核对了 dump 中的 identifier。若 Architect 希望把 `matching(identifier:)` 也纳入静态校验，那是**单独的工具任务**，本任务不擅自扩大。

## 4. 本机（Windows，无 Xcode）实际执行的检查

Python 标准库；`STAGE02_PREFLIGHT_FIX05_CHECK: PASS`（**31/31**，含 Architect 实现中复审的精准性补充）：

- **归属精准性（补充要求）**：popover 为 `count == 1` + `.element`（文件内不存在 `app.popovers.firstMatch`）；Sheet 在**该 popover 内**按精确 `label ==` 匹配且 `count == 1` + `.element`；question/explanation 均限定在 `sheet.staticTexts` 内，且全文件仅原断言那一处使用 app 级 `staticText(containing:)`（确认 helper 内不再使用）；`popoverFrame` 捕获后与 `regionFrame` 在**同一处**同时通过 `isFinitePositive` 与 `app.frame.contains`；中心仍在屏内且严格在 Popover 外。

- **断言原文**：与 HEAD `8d1f954` 逐条抽取比对——97 条既有长字符串**全部按原顺序保留**（有序子序列，97 → 106），断言调用 86 → 87（仅新增那 1 条 `INTERACTION-VERIFY[confirmation]` 取消断言）。
- **iOS 26 路径**：系统版本分支、精确问题文案、原件不变说明、popover finite、**唯一** dismiss region（`count == 1` + `.element`，非 firstMatch）、双 frame finite/屏内、相对中心「屏内且严格在 Popover 外」、**恰一次**元素相对中心点击、所算绝对点**从不**作为点击目标、取消前/后 keepAlways 截图、层级打印、`INTERACTION-VERIFY[confirmation]` 前缀、前置不满足即硬失败、无 sleep/重试/skip/forceTap/私有 API/launch 注入。
- **旧路径与后续断言**：旧系统保留真实 Sheet/Alert Cancel（enabled+hittable 后单次点击）；`Remove` 仍限定 Sheet/Alert；未把 Cancel 换成 Remove；`"Cancel must return to a usable preview."`、原件不变说明、`INTERACTION-VERIFY[restart]/[dark]/[picker]` 全部保留；取消后仍走到 Remove → 空态 → 再导入 → 重启 → 深色（按段落标记核对顺序）。
- **契约**：`80 单元 + 5 UI = 85` 方法不变；tree-sitter `TREE_SITTER_PARSED=40 WITH_ERRORS=0`；`git diff --check` 干净；本轮仅改 1 个文件。
- **回归**：FIX-01 **44/44**、FIX-02 **38/38**、FIX-03 **32/32**、FIX-04 **45/45** 全部 PASS（其中 6 处既有期望按本次授权同步更新：文件内出现第 2 处授权的元素相对点击、`CGPoint` 仅用于校验、工具已与 HEAD 一致、交互截图数量，已在各脚本内注明）。

## 5. 未执行 / 未验证（如实声明）

1. **未编译、未运行模拟器、未触发云端**：新的取消路径（唯一关闭区域 + 中心在 Popover 外 + 一次相对中心点击）**尚未在真实 iOS 26 上执行**。
2. 取消前后两张新截图尚未产生、未查看；恢复（terminate/launch）与深色两段本轮**没有到达**；大字号仅取得**只读能力证据**（`simctl help ui`/`content_size` 均 exit 0，当前 `large`，合法最大值 `accessibility-extra-extra-extra-large`）——这**不等于**大字号已设置或已通过，本任务也未改字号或 workflow。
3. 若下一次真实运行中几何/层级与本次 dump 不同，helper 会**带层级与截图硬失败**，不换点、不重试；失败后按新 dump 另行定位。
4. 预算影响：新增前/后两张截图（约 3.6 MB）与一次层级打印（约 20 KB 日志）；测试时长预计 +10–20 秒；仍应每轮核验 artifact 体积与剩余包含额度。
5. DSH未推送/未提交、未触发云端、未付费、未改账户；Appetize 31/30（0 分钟）；Apple 暂停；Stage02本人操作未执行，今天免逐项审批由Architect据真实证据技术验收，当前技术尚未通过；Stage03不启动。

Architect核对备注：上轮PNG目视结论由Architect实际view_image检查取得，DSH引用该已记录结论。DSH及补充03:16最终交付并停止；Round30独立保留86旧body断言原文（87现有）、80+5方法及Swift语法/结构检查通过。文档与代码注释中的函数拆分/两frame/最终7148行已按实际源码纠正，运行行为未变；新取消仍未真实执行。

## 6. 交 Architect 的下一步

1. 复审本报告与实际 diff（唯一文件：`Stage02ImportUITests.swift`）。
2. 若接受，在已确认包含额度内授权**单次**云端预检（源码推送需 Architect 授权），核对：iOS 26.5 上是否 85/85、`INTERACTION-VERIFY[confirmation]` 的 popover/dismissRegion/centre 日志与两张新截图、取消后 `removeButton`/Done 断言、以及后续移除/再导入/重启/深色是否到达。
3. §3 的工具覆盖局限（`matching(identifier:)` 不在扫描范围）如需补强，请另开限定工具任务。
