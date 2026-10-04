# STAGE-02-PREFLIGHT-FIX-03 报告

Stage02 预检限定修复03：iOS 26 原生照片点击与诊断
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-03.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-25.md`、原始 `job.log`（`.ai/build/downloads/run-37220074605/job.log`，735,683 字节）
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 Xcode/云端执行**；Stage02 所有者 PENDING、Stage03 禁止）

> 本报告只覆盖 FIX-03。FIX-01 实现报告与 FIX-02 报告均未被覆盖；DSH 未重复 FIX-01/02 已完成实现。

---

## 1. 授权范围与改动

| 授权范围 | 实际改动 |
| --- | --- |
| `MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift` | iOS 26 分支：以「存在 + 有限非空 frame」为前置、记录原生诊断、对该真实元素**一次**原生 `tap()`；两张点击前/后 keepAlways 全 app 截图；旧分支等待逻辑不变 |
| 独立报告/交接 | 本文件 + 交接日志 |

**未改**：产品 Swift、公开契约、依赖、工程布局、**工作流**（`git status` 中工作流无改动）、85 项测试数量与断言集合。

## 2. 驱动本轮的真实证据（run 37220074605 / 源码 `d5e3152`）

- Xcode 26.6 build 17F113 / iphoneos SDK 26.5 / iOS 26.5 iPhone 17 Pro arm64；无签名 iphoneos Release 构建与设备产物校验 **success**。
- 80 单元 0 失败；5 UI 1 失败；控制台 `total=85 passed=84 failed=1 skipped=0 expectedFailures=0`。
- 唯一失败发生在**真正点击之前**：FIX-02 确定的正确 scope 已找到 **9 个** `PXGGridLayout-Info` 真实照片，但第一个 `exists=true` / `hittable=false`（frame `{{0.0, 346.0}, {132.9, 133.0}}`）；`Photos` 导航内 `Done` 仍 disabled，即**尚未发生真实选择**，因此不能断言导入/预览在产品层失败或成功。
- 原始日志里可见 FIX-02 代码路径：反复检查 `Expect predicate 'exists == 1 AND isHittable == 1' for object "PXGGridLayout-Info" Image` 直至 20 秒有界等待耗尽 —— 与本轮「补齐点击」的修复点一致。
- **FIX-02 的 guard 修复已在生产中生效**：同一份 artifact 中出现 `failure-attachments/EF2A2BB0-1AE6-4476-866D-DB328330DBE3.mp4`（5,901,341 B）与 `failure-attachments/manifest.json`（7,038 B），日志明确打印 `Allowed 1 XCTest diagnostic recording(s) exported from the xcresult: [...]`，随后上传成功；即「丢证据」问题已解决（原 xcresult 亦随 artifact 上传，下载由 Architect 进行）。
- 4 条 AppIntents 无依赖元数据 warning；性能数字仅两时点、不代表真机。

## 3. 修复内容（仅测试定位与诊断）

### 3.1 iOS 26 分支：把「能否命中」从**前置条件**改为**诊断记录**

- 保留：`Photos` 导航就绪、`photosView_content_scroll_view` scope、scope 内 `PXGGridLayout-Info`、首个 photo **有界存在**（20 秒）。
- 新增前置：首个 photo 必须 **有限、非空、宽高 > 0** 的 frame（逐分量 `isFinite`），否则带诊断失败。
- **不再**以 `isHittable == false` 阻止操作：App 文档说明 `isHittable` 表示「当前是否可计算命中点」，而 `tap()` 会尝试把滚动容器内的目标滚到可点击位置后再点击（[isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)、[tap()](https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap())）。因此本分支调用**一次** `photo.tap()`，由 XCTest 自行计算命中点/滚动。
- **不猜系统原因**：为何该元素回报 `hittable=false` 尚无画面证实，本报告不作根因断言，也不声称已绕过系统限制。

### 3.2 诊断（仅诊断，不参与选路）

- 记录并 `print` 到运行日志：scope frame、`count`、**前 3 个** photo 的 `exists/isHittable/frame/label`（两次 picker 交互各记录一次，带 `initial import` / `reimport` 标签）。该记录循环**从不点击**任何候选，也不用于挑选元素；点击对象始终是 `boundBy: 0`。
- 两张 `XCTAttachment(screenshot:)`、`lifetime = .keepAlways`：`Stage02 iOS 26 picker before first photo tap (<session>)` 与 `... after first photo tap (<session>)`，分别位于 `tap()` 之前与之后。原有的预览截图 `Stage02 imported photo preview` 保留。
- 全部为测试诊断，**未**加入产品测试控件、launch 参数或环境注入。

### 3.3 成功判据仍是真实路径，`tap()` 本身不算成功

- 两分支点击后都仍要求 `Photos` 真实确认控件（iOS 26 为导航内 `Done`，旧版为 `Add`）**enabled + hittable** 后才确认一次。
- 之后继续断言：真实 thumbnail/计数、预览 loaded Image 与屏内 frame、Done、取消移除、确认移除、空计数、同源再次导入 —— 任一环节失败即 XCTest 失败。
- 旧 iOS 分支**保持**既有 `waitUntilHittable(timeout: 20)` 前置，不改其等待行为。

## 4. 本机（Windows，无 Xcode）实际执行的检查

Python 标准库；`STAGE02_PREFLIGHT_FIX03_CHECK: PASS`（**32/32**）：

- **iOS 26 前进路径**：`Photos` 导航就绪保留；scope 标识符保留；首个 photo 有界存在；`waitUntilHittable` 仍**仅**存在于旧分支且 iOS 26 分支内不含它；有限非空 frame 前置在位；诊断含 scope frame 与前 3 个 photo 的 exists/isHittable/frame/label 并打印；每分支恰好一次 `photo.tap()`；无 `coordinate(`/`tap(at:`/`normalizedOffset`/`forceTap`；诊断循环不含点击；点击前只有 `boundBy: 0`；无 skip/sleep/launch 注入；代码中无无范围 `app.images`。
- **旧分支与真实判据**：旧分支保留有界 hittable 等待与一次真实点击；确认控件仍要求 enabled+hittable；四处 `succeeded` 断言仍在；thumbnail×90、屏内 frame、空画廊×60、keepAlways 预览截图、确认移除等全路径断言保留。
- **截图**：恰好 2 处 `XCTAttachment(screenshot:)` + `.keepAlways`；before/after 名称清楚且顺序为「before → tap → after」（在同一 iOS 26 分支内核对）；既有预览截图未删；两个交互带不同 session 标签。
- **断言集合未删**：与已提交 `d5e3152` 对比——断言调用数 **48 → 48**，24 条既有长字符串全部仍存在（新增诊断文本除外）。
- **85 项不变**：80 单元 + 5 UI。
- **工程静态核对**：`tools/verify_project.py` **exit 0**（132 对象、41 文件引用、40 Swift 文件 **6669 行**、9 个 UI 标识符可解析）；tree-sitter `40 WITH_ERRORS=0`；`git diff --check` 无空白错误。
- **范围**：本轮 DSH 只改 1 个文件（上述测试文件）；工作流与产品代码无改动。

## 5. 未验证 / 未做（如实声明）

1. **没有任何 Xcode 编译、模拟器运行或云端触发**。本次修改**尚未实跑**：原生 `tap()` 能否真正选中照片、XCTest 是否会滚动定位、`Done` 是否转为 enabled、后续真实路径是否通过，均需真实 macOS 运行判定；本轮 iOS 26 分支不设 hittable 前置属**有依据的尝试**，不保证成功。
2. **不猜根因**：`hittable=false` 的确切系统原因尚未由画面或 Apple 文档证实；本报告不作断言，也不以任何形式声称已绕过系统行为。
3. 未取得：新模拟器 ZIP/SHA、新 SDK 预览截图、本轮两张新截图的像素（须待FIX03真实执行、上传并下载新artifact；当前正在下载的FIX02失败artifact不含尚未执行的FIX03截图）、警告完整清单。
4. 若真实重跑仍在点击或后续路径失败：**保留新诊断与两张截图**后另行定位，**不得**改用坐标、盲重试、skip 或宽带兜底。
5. 依旧未验证：同会话重启恢复、深色模式、大字号、真机/iPad/VoiceOver、最低 iOS 17 覆盖、新 SDK 控件外观视觉检查。
6. 未推送、未提交、未触发云端、未付费、未改账户；Appetize 仍 31/30（0 分钟）；Apple 账户暂停；Stage02 所有者 PENDING；Stage03 不启动。今天所有者的免逐项审批授权不代表可越过上述边界，也不代表所有者已亲自验收。

## 6. 交 Architect 的下一步

1. 复审本报告与测试文件 diff；在已确认的包含额度内做**单次**云端预检（源码推送需 Architect 授权），核对：iOS 26.5 上是否 85/85、两张新截图内容、日志中的 picker 诊断行（scope frame + 前 3 个 photo 状态）、以及 guard 是否继续放行诊断录屏。
2. 若原生 `tap()` 后确认控件仍未 enabled/hittable，则依据新诊断定位（例如元素被覆盖或层级变化），另开限定任务；不通过坐标/skip/无限重试换取通过。
3. 本报告不代替所有者交互验收，也不把任何单轮结果当作 Stage02 批准。
