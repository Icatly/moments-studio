# STAGE-02-PREFLIGHT-FIX-04 报告

Stage02 FIX04 — 证据限定元素相对中心点击 + 同轮恢复/深色补验
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-04.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-27.md`、原始 `run-37222556297/job.log`（712,845 B）与 selected-members
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 Xcode/云端执行**；Stage03/Apple/付费仍禁止）

> 本报告只覆盖 FIX-04；未覆盖历史 FIX-01/02/03 报告与只读方案文件。

---

## 1. 第三轮真实证据（run37222556297 / source `1d103fb`）

- Xcode 26.6 build 17F113 / iphoneos SDK 26.5 / iOS 26.5 iPhone 17 Pro arm64；设备 Release 与产品校验 success；`total=85 passed=84 failed=1 skipped=0 expectedFailures=0`；5 UI 执行 122.106 秒、1 失败。
- 失败：`Stage02ImportUITests.swift:418`。原生 `Tap "PXGGridLayout-Info" Image` 内部三次尝试均报 `Computed hit point {-1, -1} after scrolling to visible` —— 即 XCTest 无法为该元素算出命中点，**不是**产品导入/预览失败。
- Architect 已目视 manifest 所列原生 PNG `D556472C-B271-4F30-8077-3BAC01313B44.png`（1,857,480 B，1206×2622）：首张合成照片完整可见、隐私说明位于网格上方、**未覆盖该照片**；前 3 个元素 frame 在屏内但 `isHittable` 全为 false；`PXGGridLayout-Group` 直接包含 9 个 `Image`，没有可单独查询的 Button/Cell。
- FIX-02 守卫继续生效：日志中 `Allowed 1 XCTest diagnostic recording(s) exported from the xcresult`。
- Round27 据此**明确放宽唯一一项**：仅对已记录的 iOS 26 布局，允许一次元素**相对中心**点击（`photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()`），并同轮允许追加恢复/深色补验；DSH 不得再自行放宽。

## 2. 实际改动（3 个文件 + 文档）

| 文件 | 改动 |
| --- | --- |
| `MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift` | iOS 26 picker 分支：一次元素相对中心点击；新增 scope/app frame 包含性前置；保留原诊断与点击前后截图；**追加**重启恢复与深色两段补验 |
| `.github/workflows/stage02-testflight-preflight.yml` | 仅新增**只读**能力探测：`xcrun simctl help ui` 与 `xcrun simctl ui "$ID" content_size`（记录输出与**退出状态**，不改变字号） |
| `tools/verify_project.py` | **一行豁免**：把系统自带的 `BackButton` 加入 `SYSTEM_CONTROL_LABELS`（附两次真实 dump 依据）——见 §3.4 披露 |
| 报告/交接 | 本文件 + 交接日志 |

未改：产品 Swift、公开契约、依赖、工程文件、既有 85 方法、既有 48 条行为断言原文。

### 2.1 picker：仅一次元素相对中心点击

```swift
photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
```

- 该 API 为 Apple 公开 XCTest API，偏移相对**目标元素**，不使用任何绝对屏幕坐标；现代分支**不再**调用 `photo.tap()`。
- 前置：`waitForExistence(timeout: 20)` + 有限非空 frame + **`scope.frame.contains(frame)` 与 `app.frame.contains(frame)` 同时成立**；任一不满足即带诊断失败。
- 保留原 `pickerElementDiagnostics`（scope frame、count、前 3 个元素 exists/isHittable/frame/label）与点击前/后两张 `keepAlways` 截图；日志策略写进注释并统一前缀 `INTERACTION-VERIFY[picker]`，两次交互以 `initial import` / `reimport` 区分。
- 旧 iOS 分支**完全不变**（有界 `waitUntilHittable` + 原生 `photo.tap()`）。
- 禁止项已核对不存在：绝对坐标、`tap(at:)`、`forceTap`、scope 整体盲点、候选循环/重试、skip、产品 launch 注入。
- 点击后原有真实 `Done` enabled+hittable 与整条导入/预览/移除/再导入断言全部保留 —— **相对中心点击本身不是通过证明**。

### 2.2 重启恢复（INTERACTION-VERIFY[restart]，置于原路径全部通过之后）

1. 创建项目**之前**记录 Home 上 `home.project.` 完整 identifier 集合；
2. 原完整路径结束后取真实唯一 thumbnail 的**完整 identifier**（`editor.photo.<assetID>`），且必须按**唯一完整 asset identifier 去重**后计数（同一个 SwiftUI Button 的重复 AX 节点不得当两张照片），使用已实见的原生 `Button` 类型查询（`PhotoImportSection` 的缩略图就是 Button），并断言恰好 1 张；
3. 经 `BackButton`/导航返回 Home，Home ready 且无 `home.libraryError`，集合差**恰好 1 个完整项目 ID**（不猜首行/名称；0 或多个即失败并 dump 两个集合）；
4. `app.terminate()` → `app.launch()`；等 `home.createProject` enabled 且 `libraryError` 不存在；
5. 精确打开该 ID → `1 of 20 photos`、同一 assetID 且仅 1 张 → 缩略图 → 预览：无 loading/`photo.unavailable`/`preview.missingPhoto`，`preview.image` 为有限非空且在 `app.frame` 内的 Image → `preview.done` enabled+hittable → 返回可操作 Editor；
6. 3 张 keepAlways 截图（返回前 Home、重启后 Home、恢复后预览）+ 日志（集合、新 ID、assetID）。

不使用 reset、数据注入或产品钩子。

### 2.3 深色可操作性（INTERACTION-VERIFY[dark]）

- 保存 `XCUIDevice.shared.appearance` 并以 `defer` 还原（只影响测试模拟器），设 `.dark`（Apple 官方 API）。
- 在同一已恢复项目上核对：Editor 导入入口 enabled+hittable、`1 of 20 photos`、同一 assetID、缩略图可点、预览已加载 Image **finite、非空、宽高 > 0 且完全在屏内**（三重判据，不再只用 `contains`）、无 unavailable/missing、`preview.done` 可用并返回可操作 Editor；再经返回键到 Home 并精确重开同一项目。
- 3 张 keepAlways 截图：`INTERACTION-VERIFY[dark] Editor` / `loaded preview` / `Home`。
- 不加入产品样式或测试钩子；**截图须由 Architect 实际查看后才可判视觉通过**。

### 2.4 字号（只读，未改字号）

工作流 fixture 步骤 `bootstatus` 之后新增只读探测：输出 `simctl help ui` 与当前 `content_size` 到 `$ARTIFACTS/simctl-ui-help.txt`、`content-size-current.txt`，并各自追加 `exit_status=`；用 `set +e`/`set -e` 包裹，**命令不支持只记录非零状态、绝不中止运行**，也不把不支持冒称成功。字号未改变、未传未知参数、原测试与门禁条件未变。

### 2.5 02:32 追加复审要求（交付前已一并处理）

1. **thumbnail 计数按唯一完整 asset identifier**：`importedThumbnailIdentifiers` 改为已实见的原生 **`Button`** 类型查询（`app.buttons.matching(identifier BEGINSWITH "editor.photo.")`）并用 `Set<String>` 去重、`sorted()` 稳定输出；计数是**不同素材数**，不是 AX 节点数；仍保留「恰 1 张」与「同一 assetID」断言。两处新增缩略图点击也改为 typed `app.buttons[assetIdentifier].firstMatch`。
   - 未改动项（刻意）：原路径既有的 `importedThumbnail(in:)`（`descendants(matching: .any)` + `firstMatch`）**保持不变**——它只用于点击真实缩略图、在历次真实运行中可用；本补充只约束新增的计数与点击路径，避免改动原 48 条路径的行为。
2. **深色 preview frame 三重判据**：新增 `finite`、`非空且宽高 > 0`，再叠加 `app.frame.contains`；不再以 `contains` 单独判定可见（空/零尺寸 frame 无法再蒙过）。
3. **18.5 返回按钮改为实见 label 分支**：由原先的「导航栏内第一个按钮」改为**已观测到的 label** `app.navigationBars.buttons["Moments Studio"]`（`ABA75FF7-…` 第 13 行实见 `Button … label: 'Moments Studio'`，无 identifier）；不猜其他标签、不降低原断言。
4. **`verify_project.py` 仅添加实见系统 `BackButton` 的精确豁免**：diff 对比确认**只新增**一行 `"BackButton",`（外加说明注释），无删除、无其他豁免；若将来需要其他豁免，先报告再改（见 §3.2）。

## 3. 必须披露的两项决策（均有真实证据）

### 3.1 返回键按系统版本分支（否则会在 iOS 18.5 上新增失败）

- iOS 26.5（`run-37222556297/selected-members/…/0BFEE17B-….txt`）：`Button … identifier: 'BackButton', label: 'Moments Studio'`。
- iOS 18.5（`run-37147120379/…/ABA75FF7-….txt` 第 13 行）：同一个导航栏前导按钮**没有任何 identifier**，只有 `label: 'Moments Studio'`。
- 因此无条件 `app.buttons["BackButton"]` 会让本套件在 18.5 上失败。新增 helper（18.5 分支按 02:32 追加要求改为**实见 label**）：

```swift
private func editorBackButton(in app: XCUIApplication) -> XCUIElement {
    if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 {
        return app.buttons["BackButton"]
    }
    return app.navigationBars.buttons["Moments Studio"]
}
```

iOS 18.5 分支限定在**导航栏内**、且只用 dump 中实见的 label，不猜标签；两处调用都走该 helper，无其它整体兜底。

### 3.2 `tools/verify_project.py` 一行豁免 `BackButton`

未加该豁免时工程校验会失败：`FAIL: UI tests query identifiers the app never declares: BackButton`。`BackButton` 属**系统**标识符（与既有 `Add`/`Cancel`/`Photos`/`content_scroll_view` 同类），故按既有惯例加入 `SYSTEM_CONTROL_LABELS` 并附两次 dump 依据。**02:32 追加要求已明确允许这一项精确豁免**；本机以 `git show HEAD:tools/verify_project.py` 与当前文件逐行 diff 核对：**只新增一行 `"BackButton",` 与说明注释，无删除、无其他豁免**；将来若需其他豁免先报告。该文件只是 Windows 侧工程校验脚本（AGENTS §3：`tools/*.py` 仅标准库、不进 App 产物）；若 Architect 仍认为不该改，可回退该行并改用其他证据形式。

## 4. 本机（Windows，无 Xcode）实际执行的检查

Python 标准库 + 本机诊断用 PyYAML（既有安装，未新增依赖）：`STAGE02_PREFLIGHT_FIX04_CHECK: PASS`（**45/45**），要点：

- **断言原文**：与 `1d103fb` 逐条抽取比对，48 条既有断言的 53 条长字符串**全部按原顺序保留**（有序子序列判定，非数量相等）；补充深色frame后当前断言调用 48 → 86（新增均带 `INTERACTION-VERIFY` 前缀；此前85为补充前稿的计数，Architect独立核对86）。
- **picker**：相对中心点击恰 1 次且只在现代分支；现代分支无 `photo.tap()`；旧分支保留原生 tap + 有界 hittable 等待；有限非空 frame 与 scope/app 包含性前置在位；诊断、前后截图、日志策略、`INTERACTION-VERIFY[picker]` 在位；无绝对坐标/forceTap/盲点/重试/skip/注入。
- **重启**：基线集合、集合差恰 1、terminate+launch、createProject enabled + 无 libraryError、精确 ID 打开、同一 assetID 且仅 1 张、预览 loaded/finite/屏内、Done → Editor、3 张 `INTERACTION-VERIFY[restart]` 截图，且整段位于原路径最后一条 count 断言之后。
- **深色**：保存 + `defer` 还原、`.dark` 恰 1 次、3 张 `INTERACTION-VERIFY[dark]` 截图、计数/素材/图片/Done→Editor 断言在位；新增交互截图共 6 张全部经 `keepAlways` helper。
- **工作流**：YAML 可解析、**6 段内嵌 Python 全部编译通过**、只读探测与退出状态记录在位、**未设置任何字号**、`set +e`/`set -e` 保护、85 契约/guard id 与上传条件/20 分钟/2 天均未变、文件仍为纯 ASCII 且无 CRLF。
- **02:32 追加项**：thumbnail 计数为 typed `Button` 查询 + `Set` 去重 + `sorted()`；两处新增缩略图点击为 typed `app.buttons[assetIdentifier]`；深色 preview 具备 finite/非空/正宽高 + 屏内包含性，且不再存在「仅 contains」判定；18.5 返回分支为 `navigationBars.buttons["Moments Studio"]` 且全文只出现这一处观测标签、无位置分支残留；`tools/verify_project.py` 相对 HEAD 仅新增该一行豁免、无删除。
- **工程**：`tools/verify_project.py` **PASS**（exit 0；132 对象/41 引用/40 Swift 文件 **7000 行**；11 个 UI 标识符可解析，含 `BackButton`/`home.libraryError`；系统项豁免 `Add`/`BackButton`/`Photos`）；tree-sitter `TREE_SITTER_PARSED=40 WITH_ERRORS=0`；`80 单元 + 5 UI = 85` 方法不变；`git diff --check` 干净。6988行属追加Review前稿，当前计数已由Architect实际复核。
- **回归脚本更新（诚实披露）**：因 Round27 授权变化，三个一次性校验脚本的 4 处期望同步更新——FIX-02 的「禁止 coordinate」改为「允许 1 次授权的元素相对调用，仍禁绝对坐标/forceTap」；FIX-03 的日志前缀改为 `INTERACTION-VERIFY[picker]`、tap 计数改为「旧分支 1 次原生 + 现代分支 1 次相对中心」、坐标禁令同前。更新后 FIX-01/02/03/04 四个脚本全部 PASS。

## 5. 未执行 / 未验证（如实声明）

1. **未编译、未运行模拟器、未触发云端**：相对中心点击**能否真正选中照片未经验证**；`Done` 是否转为 enabled、恢复与深色是否通过、字号帮助/当前值的实际内容，全部**尚未执行**。
2. 6 张新截图尚未产生、未查看；视觉通过只能由 Architect 看图后判定。
3. 相对中心点击是**有证据的限定尝试**，不是通过证明；若真实重跑仍失败，保留新截图与原生层级后另行定位，**不得**再自行放宽（如改用绝对坐标、scope 盲点、重试或 skip）。
4. 新增检查只在原 48 条路径全部通过后执行，失败消息一律带 `INTERACTION-VERIFY[…]` 前缀，报告可据此区分「旧路径回归」与「新增交互失败」。
5. 预算影响：测试时长预计 +60–120 秒（UI 段此前 122 秒；job 上限 20 分钟、前两轮 10:41–15:58）；附件增加 6 张全屏截图（每张约 1.8 MB，合计约 10 MB），在 2 天保留与既有存储估算内，但应按轮核验。
6. 未推送、未提交、未触发云端、未付费、未改账户；Appetize 31/30（0 分钟）；Apple 暂停；Stage02 所有者 PENDING；Stage03 不启动；自动交互不构成所有者本人操作或验收。

## 6. 交 Architect 的下一步

1. 复审本报告与三个文件的实际 diff（含 §3.1/§3.2 两项披露）。
2. 若接受，在已确认包含额度内授权**单次**云端预检（源码推送需 Architect 授权），核对：iOS 26.5 上是否 85/85、相对中心点击后真实 `Done`/导入/预览断言、6 张交互截图与 `INTERACTION-VERIFY` 日志行、`simctl-ui-help.txt`/`content-size-current.txt` 的实际内容与退出状态、新包 SHA。
3. 若失败，按新诊断定位；本轮的授权放宽不得被继续扩展。
