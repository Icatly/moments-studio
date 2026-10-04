# STAGE-02-INTERACTION-VERIFY-PLAN-01 — Stage02 剩余交互补验方案（**仅方案，未执行**）

依据：`.ai/tasks/STAGE-02-INTERACTION-VERIFY-PLAN-01.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-25.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-26.md`、当前 UI 测试与产品源码（只读）
状态：**PLAN ONLY / NOT EXECUTED**。DSH 本轮未改 Swift、未改工程、未改 workflow、未触发云端、未修改根交接文件、未重复 FIX-01/02/03。

---

## 0. 摘要

| 剩余交互证据 | 需要改测试？ | 需要改 workflow？ | 预计额外 CI 轮次 | 预计测试时长 |
| --- | --- | --- | --- | --- |
| ① 同进程终止再启动恢复 | 是（在既有完整导入测试**末尾追加**） | **否** | 0（并入下一次授权的 UI 运行） | +20–40 秒 |
| ② 深色可操作性 | 是（同上，`XCUIDevice.shared.appearance`，`defer` 还原） | **否** | 0（同一轮） | +30–60 秒 |
| ③ 大字号可操作性 | 是（同上） | **是**（唯一需要 workflow 的项） | Phase A 可并入下一轮；**Phase B 单独一轮**（按 Round26 口径约 $1.364/轮，剩余约 $4.866） | 设置/还原 <10 秒；整轮 ≈16–20 分钟 |

要点：三项全部复用**既有完整导入测试**（现 `Stage02ImportUITests.swift` 第 288–289 行之间，即 `XCTAssertEqual(photoCount(in: app), "1 of 20 photos")` 之后、方法结束 `}` 之前**追加**），不新增测试方法 → **80 单元 + 5 UI = 85 方法不变**、旧断言一条不删。

## 1. 严格区分：已执行证据 vs 本方案

**已执行（既有真实证据，勿混算）**

- run9/source `728f435`：Xcode 16.4 / iOS 18.5 上 **85/85 全通过**（含取消 smoke 与完整导入路径），预览截图已目视审查。
- run37216674264 / `d4d4ee7` 与 run37220074605 / `d5e3152`：Xcode 26.6 / SDK 26.5 / iOS 26.5 上设备 Release 与产品校验 success，测试 **84/85（1 失败、0 skip）**；两轮唯一失败均在系统 picker 定位/点击环节，**尚未到过产品导入或预览的成功断言**。
- FIX-02 的 guard 规则已在真实运行中生效（`Allowed 1 XCTest diagnostic recording(s)…`，并保留 manifest + 原 xcresult）。
- 17.2 单张预置照片的真实预览目视通过（不复现旧 fatal）；同会话重启、深色、大字号**未执行**。
- FIX-03 已复审、推送 `1d103fb`；第三轮 run37222556297 **正在真实测试**，DSH 本轮**未读取、未查询、未触发**。

**本方案（未执行）**：下列 ①②③ 的步骤、断言、截图与 workflow 插入点全部是**待批准方案**，没有任何一项已运行。

## 2. 方案可复用的真实标识符与就绪信号（只读核对）

- Home：`home.createProject`（HomeView:82）、项目行 `home.project.<project.id.uuidString>`（HomeView:168）、空态 `home.recentProjects.empty`（159）、恢复中 `home.libraryLoading`（117）、失败 `home.libraryError`/`home.libraryRetry`（124/131）、告警 `home.libraryWarning`（140）。
- Editor：`editor.importPhotos`（PhotoImportSection:99）、`editor.photoCount`（105，文本 `N of 20 photos`）、缩略图 `editor.photo.<asset.id.uuidString>`（164）、`editor.galleryEmpty`（63）、`editor.importProgress`/`editor.cancelImport`/`editor.importError`（121/132/176）。
- 预览：`preview.image`（PhotoPreviewSheet:95）、`preview.info`（100）、`preview.done`（50）、`preview.remove`（59）、`preview.missingPhoto`（40）；加载失败 `photo.unavailable`（DerivedImageView:70）。
- 恢复链路：`RootView.swift:63` 启动即 `await photoImport.restoreProjects()`；`PhotoImportModel.restoreState` = `.idle/.loading/.ready/.failed`（46/122/137/140）、`isRestoring`（95）。
- 现有 helper：`UITestSupport.swift` 的 `waitUntilEnabled`(9)/`waitUntilEnabledAndHittable`(20)/`waitUntilHittable`(27)/`waitForDisappearance`(39)；测试内 `element(_:in:)`、`importedThumbnail(in:)`、`photoCount(in:)`、`staticText(containing:in:)`、`confirmationButton(named:in:)`、FIX-03 新增的 `attachFullAppScreenshot(_:named:)`。

## 3. 补验项 ①：同进程 `terminate()` → `launch()` 恢复（无 workflow 改动）

**插入点**：完整导入测试末尾（现 L288 断言之后）。

1. **创建前基线**：进入创建项目前，收集 Home 上所有 `identifier` 以 `home.project.` 开头的元素标识符集合 `before`（`app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home.project."))` 逐个读 `.identifier`）——**不使用**首行/名称/相似文本。
2. **创建并导入**（沿用现有真实路径）。
3. **精确识别同一项目**：再次收集集合 `after`；要求 `after \ before` **恰好 1 个** ID，记为 `newProjectID`（0 个或多个 → 失败并把两个集合写入日志，不做猜测）。记录 `newProjectID` 的**完整 identifier 字符串**。
4. **保留 assetID**：读取第一个 `editor.photo.<assetID>` 元素的完整 identifier，保留后缀 `assetID` 供重启后比对（同样不使用位置/名称猜测）。
5. **真实重启**：`app.terminate()`；`app.launch()`。
6. **等待恢复就绪（有界，不用固定等待）**：等待 `home.libraryLoading` **有界消失**（`waitForDisappearance(timeout: 60)`），并断言 `home.libraryError` **不存在**（存在则把其文本写入失败消息）；允许 `home.libraryWarning` 存在（按产品语义是告警而非失败，需在报告中注明）。
7. **断言同一项目**：`home.project.<newProjectID>` 存在且 `waitUntilEnabledAndHittable()`；**不**用项目名或首行。
8. **打开并断言恢复的内容**：点击该项目 → Editor：`editor.photoCount` == `1 of 20 photos`；`app.descendants` 中 `editor.photo.<assetID>` 存在且 `waitUntilHittable()`；缩略图数量为 1（按前缀查询计数）。
9. **断言恢复的预览可操作**：点缩略图 → 加载指示器有界消失、`photo.unavailable` 不存在、`preview.image` 为**有限非空 frame 且完全落在 `app.frame` 内**、`preview.info` 存在；`preview.done` enabled+hittable 后点击返回 Editor，Editor 导入入口 enabled+hittable。
10. **证据**：3 张 `keepAlways` 全 app 截图（重启后的 Home、恢复后的 Editor、恢复后的已加载预览），命名 `Stage02 restart …`；日志打印 `before/after` 集合、`newProjectID`、`assetID`、恢复耗时。

**失败点与归属**：Home 无该项目 = 恢复失败；项目在但缩略图/计数不符 = 恢复不完整；`home.libraryError` 出现 = 恢复报错（需其文本）。三种都是产品行为证据，**不得**用 reset / 数据注入 / 产品钩子绕过。

## 4. 补验项 ②：深色可操作性（无 workflow 改动）

- **API**：`XCUIDevice.shared.appearance`（Apple 官方：[appearance](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/appearance-swift.property)）。只影响测试用模拟器。
- **写法**：`let originalAppearance = XCUIDevice.shared.appearance`；`defer { XCUIDevice.shared.appearance = originalAppearance }`；设 `.dark`。
- **稳定判据**：不用固定等待；以关键元素出现且 `enabled/hittable` 为界（外观切换后的重绘以查询结果为准）。
- **断言（只判可操作性与文本，不判美观、不重定义样式）**：Home `home.createProject` enabled+hittable 且项目行存在；导入后 Editor `editor.importPhotos` enabled+hittable、`editor.photoCount` 文本正确；预览 `preview.image` 有限非空且屏内、`preview.info` 文本非空且含尺寸与格式、`preview.done`/`preview.remove` enabled+hittable。
- **证据**：Home / 导入后 Editor / 已加载预览各 1 张 `keepAlways` 截图，命名 `Stage02 dark …`。
- **失败点与归属**：深色下控件不可用或文本被截断 → 先报告并附原生 dump/截图，由 Architect 判定是产品缺陷还是临时样式问题；**不允许**为让测试通过而改产品颜色或放宽断言。

## 5. 补验项 ③：大字号可操作性（唯一需要 workflow 改动）

**限制（先说明）**：测试进程无法设置设备级 `content_size`——它不是 `XCUIDevice` API；也**不猜**私有 launch 参数或未核实的 JSON testplan 字段；**不给产品加环境注入**。

### Phase A — 先取得 runner 上的实见证据（可与下一次授权运行合并，0 额外轮次）

在最少量插入点（现有 workflow「Select an available iOS 26+ iPhone simulator」步骤之后、测试步骤之前）新增**只读**步骤：

```bash
xcrun simctl help ui                            | tee "$ARTIFACTS/simctl-ui-help.txt"
xcrun simctl ui "$STAGE02_SIMULATOR_ID" content_size | tee "$ARTIFACTS/content-size-before.txt"
```

目的：确认该 runner 上**合法的子命令与可选值**、当前默认值。**在拿到这份证据之前，方案不写死任何字号字符串**（当前 Windows 无法声称这些 CLI 已执行）。

### Phase B — 设最大 accessibility 字号并单独一轮验证

- 在测试步骤**之前**插入设置步骤：`xcrun simctl ui "$STAGE02_SIMULATOR_ID" content_size <Phase A 实见的最大 accessibility 值>`，并把命令与实际**读回值**写入 `$ARTIFACTS/content-size-applied.txt`。
- 新增 `if: always()` 还原步骤：`xcrun simctl ui "$STAGE02_SIMULATOR_ID" content_size <Phase A 记录的默认值>`，同样写日志（模拟器一次性，仍写回以保持幂等与可追溯）。
- 测试侧（仍在同一完整导入测试末尾）：重复关键交互断言——`editor.importPhotos` enabled+hittable、`editor.photoCount` 文本正确、缩略图 hittable、`preview.image` 有限非空且屏内、`preview.done`/`preview.remove` enabled+hittable、确认框按钮可点；并把关键元素 `frame` 打印到日志作为几何证据（只记录，不断言像素）。
- **环境证明方式**：由 CI 日志的「已应用 + 读回值」与截图证明运行在最大 accessibility 字号下；**测试内部不断言字号数值**（无产品钩子/无私有 API）。这一条在报告中明确标注为「环境由 CI 日志证明，非测试断言」。
- **最小插入点/还原/预算**：2 个新步骤（设置 + always 还原）；新增运行时间 <10 秒；**额外一轮 20 分钟 timeout + 收尾余量，按 Round26 的同一口径估算约 $1.364**（Round26 记录：Actions 额度约 $12、已抵 $5.46、剩余约 $4.866；前两轮 15:58/10:41 分别约 $0.992/$0.682；实际账单未核）。存储：每轮 artifact 约 +84 MB（Round26：14 份未过期共 415,586,018 B），2 天保留、无 cache，仍在 0.5 GB 包含额度内但需按轮核验；不新增包/依赖，不改产品与工程文件。

## 6. 与既有 85 项的关系（避免混淆新结果）

- **追加不新增方法**：80 单元 + 5 UI = **85 方法不变**；实现时沿用 FIX-03 的比对法（与 HEAD 对比断言调用数与既有长字符串集合），确保**旧断言一条不删**。
- **归属标记**：新增断言消息统一前缀 `INTERACTION-VERIFY[restart|dark|large-text]`；附件统一命名 `Stage02 restart/dark/large-text …`；日志打印 `INTERACTION-VERIFY` 行 → 报告可按前缀把「既有 85 门禁」与「新增交互证据」分开列。
- **风险与读法**：追加检查位于同一测试方法内，其失败会使该方法失败 → 报告必须指明**是新增前缀断言**还是**旧断言**失败，禁止把新增交互失败读成旧路径回归，反之亦然。
- **配置轨道分离**：默认配置轮次是 85/85 门禁；**大字号轮单独作为证据轨道**；深色与重启在同一轮内完成，深色用 `defer` 还原、重启只影响该测试自身。

## 7. 方案自带的新增失败点清单

1. 重启恢复本身依赖磁盘包完整性：这是产品属性，失败即产品证据。
2. `launch()` 后必须等 `home.libraryLoading` 消失：否则新增检查会不稳定（故引入有界等待，不用 sleep）。
3. 集合差值要求「恰好 1 个新增项目」：若前置 Home 残留项目会使判断失真 → 前置处先记录并断言 `before` 状态已知（空集或已记录），严格比较。
4. 深色切换后界面重绘有时间差 → 以元素可操作性为界。
5. 大字号改变布局与命中区域：可能暴露与产品逻辑无关的测试假设 → 单独轨道 + 原始 dump 定位，先报告后决定。
6. 截图增多使产物体积略增（预计 +1–3 MB/轮，保留 2 天，计入存储额度）。
7. 测试时长增加使 20 分钟作业上限更紧（当前实际约 11–16 分钟）：若接近上限，需 Architect 决定调整 timeout 或拆分轨道——**不接受**静默放弃检查。

## 8. 明确未执行 / 不可执行

- **本方案 ①②③ 全部未执行**；本轮未改 Swift/工程/workflow，未运行 Xcode，未触发或查询云端，未读取第三轮结果，未修改根交接文件。
- **不属本方案、也不得由本方案推出的**：所有者本人亲手交互验收（自动交互不构成「所有者已亲自操作」）；Appetize 验证（免费分钟 31/30、0 分钟、暂停）；真机 / iPad / VoiceOver / 最低 iOS 17 精确覆盖 / Xcode 15.4；最终品牌视觉判定。
- 未取得的新证据：第三轮 run37222556297 的结论（正在跑，由 Architect 核验）。

## 9. 依赖与建议顺序（待 Architect 结论）

1. **先判定当前阻塞**：若第三轮 FIX-03 失败，先按新的真实诊断修复阻塞——**不得**用新增交互覆盖或掩盖当前失败。
2. **与 Round26 的下一轮门禁对齐**：下一轮需核 `实际 source`、`device/toolchain`、`85/85/0/0/0`、`截图像素`、`完整交互日志`、`新包 SHA`；本方案新增的截图与 `INTERACTION-VERIFY` 日志行应并入同一证据清单，且**截图像素只能由 Architect 目视判定**（自动化不构成视觉通过）。
3. 获批后按最小改动实施：测试侧追加（重启 + 深色）→ 与下一轮授权运行合并；Phase A 的 `simctl help ui`/当前值证据同轮取得。
4. Phase B（大字号）单独一轮，按剩余包含额度决定；结果作为独立证据轨道登记，不与默认门禁混算。**若超过预估的产物增长或费用，先核验、不无限堆产物。**
5. 全程保留：产品代码、公开契约、依赖、工程文件、既有 85 项与全部断言不变；不改产品视觉。
