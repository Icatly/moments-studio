# STAGE-02-PREFLIGHT-FIX-02 报告

Stage02 预检限定修复02：真实 iOS 26 picker 定位与失败证据（诊断录屏）规则
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-02.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-23.md`、原始 `job.log`（`.ai/build/downloads/run-37216674264/job.log`，741,647 字节）
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 Xcode/云端执行**；Stage02 所有者 PENDING、Stage03 禁止）

> 本报告只覆盖 FIX-02。FIX-01 的实现报告是 `.ai/reports/STAGE-02-PREFLIGHT-FIX-01.md`（Architect 侧，未被本报告替换或覆盖）；DSH 对 FIX-01 交付的独立核验见 `.ai/reports/STAGE-02-PREFLIGHT-FIX-01-DSH-VERIFICATION.md`。

---

## 1. 授权范围与改动文件

| 授权范围 | 实际改动 |
| --- | --- |
| `MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift` | 系统 picker 定位按运行系统版本分支为两套**已观测**scope；确认控件 iOS 26 用 Photos 导航内 `Done`、旧版保留 `Add`；picker 就绪判据改为 `Photos` 导航栏 |
| `.github/workflows/stage02-testflight-preflight.yml` | 证据守卫仅放行 xcresult 导出的 UUID 命名 XCTest 诊断录屏，并强制要求导出 manifest 与原 result bundle 同时存在；其余媒体/凭据规则不变 |
| 报告/交接 | 本文件 + 交接日志 |

**未改**：产品 Swift、公开契约、依赖、工程布局/生成器、旧工作流、85 项测试的数量与断言集合。

## 2. 驱动本轮修复的真实证据（run 37216674264 / 源码 `d4d4ee7`）

1. 工具链与设备：`Xcode_26.6.app` / Xcode 26.6 build 17F113 / iphoneos SDK 26.5 / iOS 26.5 模拟器；无签名 iphoneos Release 构建 `** BUILD SUCCEEDED **` 且设备产物校验通过。
2. 测试：单元 80/80 通过（`Executed 80 tests, with 0 failures`）；UI 5 项 1 失败；`total=85 passed=84 failed=1 skipped=0`，守卫 fail-closed 拒绝，无新 ZIP。
3. 唯一失败：`testImportPreviewShowsTheImageAndRemovalConfirmationKeepsOrRemovesTheCopy`，`Stage02ImportUITests.swift:124`——`picker scroll view 'content_scroll_view' not found`。
4. iOS 26.5 原生层级（同一 `job.log`）：`NavigationBar id='Photos'` 内含 `Button id='Cancel'`、`SegmentedControl`（Photos/Collections）与 **`Done`（选择前 Disabled）**；网格容器为 **`ScrollView id='photosView_content_scroll_view'`**；照片仍是 **`Image id='PXGGridLayout-Info'`**（label 形如 `Photo, October 04, 4:26 PM`）。对照 iOS 18.5 的 `content_scroll_view` + `Add`。
5. 守卫误拦：`Refusing to upload photo-like files: ['failure-attachments/D42D3FF6-041C-4A4E-8FB3-3A6F668359F9.mp4']`；而同一份 artifact 清单里确实同时存在 `failure-attachments/manifest.json`（12,406 B）与 `Stage02-Preflight.xcresult/`——这正是新规则要求的两个前提。

## 3. 修复一：按系统版本分支的 picker 定位

- 新增 `usesModernPickerLayout`（`ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26`）——**按系统版本分支**，不是先后探测两套 scope，因此不存在盲猜兜底。
- 网格 scope：iOS 26 → `photosView_content_scroll_view`；旧版 → `content_scroll_view`；照片仍限定为 scope 内 `matching(identifier: "PXGGridLayout-Info")`。
- 确认控件：iOS 26 → `app.navigationBars["Photos"].buttons["Done"]`；旧版 → `app.buttons["Add"]`；两者都要求**有界 enabled+hittable** 后才点击一次。
- 就绪判据：`waitForPickerToOpen` 改为等待 `app.navigationBars["Photos"]`（两套层级都观测到该导航栏），不再把初始化屏上的早期 `Cancel` 当作就绪（延续 FIX-09 结论）。
- 诊断信息带版本与所用 scope（例如 `picker scroll view 'photosView_content_scroll_view' not found on iOS 26`），失败时保留原生 `app.debugDescription`。
- 断言集合完全保留：真实导入 → 缩略图/计数 → 预览（加载完成、`preview.image` 有限且全在屏内、info、无 missing/unavailable）→ Done → Cancel 保留副本 → 确认移除 → 空画廊/0 计数 → 同源再次导入；picker smoke 仍把 `Cancel` 限定在 `Photos` 导航栏内。
- **未**新增 sleep / skip / 坐标 / 无限重试 / launch 注入；**未**改产品 API 或加测试用按钮。

## 4. 修复二：诊断录屏规则

守卫（`id: evidence_guard`，`if: always()`）新增规则：

- **只放行**路径严格匹配 `^failure-attachments/<8-4-4-4-12 UUID>\.mp4$` 的文件，**且必须**同时满足 `failure-attachments/manifest.json` 是文件、`Stage02-Preflight.xcresult` 是目录（把该录屏钉死为「本次 xcresult 导出的诊断产物」）。
- 放行时在日志打印来源说明：录屏由 runner 的**合成 fixture 与系统默认媒体**产生，产物中不含所有者相册、桌面截图或设备媒体。
- 仍然 fail：其他目录的视频（如 `screenshots/x.mp4`）、`failure-attachments/` 下非 UUID 命名的视频、缺 manifest、缺 result bundle、任何照片（`.jpg/.jpeg/.heic`，无论是否有 manifest+bundle）、凭据类文件（`.p8/.p12/.pem/.key/.cer/.env/.mobileprovision`/`id_rsa`/`credentials`）。
- `if: ${{ always() && steps.evidence_guard.outcome == 'success' }}` **未改**：守卫失败仍然阻断上传；构建/测试失败但守卫通过时，安全日志照常上传。
- `.mov` 未纳入放行（授权只允许 `<UUID>.mp4`）；若未来 XCTest 改扩展名需另开任务。
- **规则边界（Round24 澄清，务必按此理解）**：这是**明确的文件名 + 导出上下文检查**，**不是** manifest 成员关系校验，也**不是**媒体内容来源认证。它只说明「本次固定工作流在全新 runner 上、以脚本合成图与 Apple 系统默认媒体运行」这一前提出货；**不得**据此复用于上传所有者相册、桌面录制或任何私人媒体的产物。
- Architect 侧独立执行同一守卫脚本 **12/12 通过**（另含 `.mov`、`.jpg`、`.p8`、UUID 后带额外后缀、子目录视频、未知大写扩展等用例），结论与本机 9 分支一致。

## 5. 本机（Windows，无 Xcode）实际执行的检查

**全部 Python 标准库**（本轮未使用 PyYAML，未新增依赖）；`STAGE02_PREFLIGHT_FIX02_CHECK: PASS`：

1. **直接执行工作流里真实的守卫脚本**（从 `id: evidence_guard` 步骤抽出、原样运行），按模拟 artifact 目录逐一验证 9 个分支：
   - 放行：`failure-attachments/<UUID>.mp4` + `manifest.json` + `Stage02-Preflight.xcresult/` ✓，并打印来源说明 ✓；
   - 拒绝：视频位于未知目录 ✓、`failure-attachments/recording.mp4`（非 UUID）✓、缺 manifest ✓（诊断含 `manifest=False`）、缺 bundle ✓（`bundle=False`）、`.p8` ✓、`photo.jpg`（即使有 manifest+bundle）✓；
   - 普通文本诊断（`.txt` 附件 + 日志）通过并写清单 ✓。
2. **UI 测试静态核对**：系统版本分支存在 ✓；两套 scope 标识符与观测一致 ✓；`PXGGridLayout-Info` 仅一处、限定在 scope 内 ✓；iOS 26 的 `Done` 限定在 `Photos` 导航栏内 ✓；旧版保留 `app.buttons["Add"]` ✓；就绪等待 `Photos` 导航 ✓；确认控件 enabled+hittable 后单次点击 ✓；无 `XCTSkip`/`sleep(`/`coordinate(`/`launchArguments` ✓；代码中无无范围 `app.images` ✓；八条既有端到端断言消息与 `app.frame.contains(imageFrame)` 全部在位 ✓；**85 个方法（80 单元 + 5 UI）保留** ✓。
3. **FIX-01 修复回归**（工作流被改动后再全量核对一次）：`STAGE02_PREFLIGHT_FIX01_REVIEWED_VERIFY: PASS`——build 号无冒号解析、完整 runtime 版本排序、arm64 destination 过滤与失败路径、summary 设备/系统/UDID 守卫的 9 种拒绝、上传条件在 guard 失败/跳过/取消时为假、策略项（手动触发/contents:read/persist-credentials:false/20 分钟/2 天/无 secrets/无 skip-retry）全部仍然成立。
4. **工程静态核对**：`tools/verify_project.py` PASS（exit 0；132 对象、41 文件引用、40 Swift 文件 **6595 行**、**9 个 UI 测试标识符可解析**）；tree-sitter `TREE_SITTER_PARSED=40 WITH_ERRORS=0`；`80 + 5 = 85` 方法。
   - 更正：本报告初稿沿用了旧轮次的「11 个 UI 标识符」，与实际输出不符（Round24 已指出，以实际 **9** 为准）。原因是本轮把网格标识符改为经版本分支 helper 选择（`app.scrollViews[identifier]`），字面量不再是内联下标，因此该静态检查的计数下降；被查询的标识符本身没有被删除或放宽。
5. **范围与卫生**：`git status` 中本轮仅上述 2 个授权文件被改（其余为用户/Architect 未提交的文档改动，DSH 未触碰）；`git diff --check` 无空白错误；工作流文件恢复为**纯 ASCII**（我先前引入的一个 em-dash 已改回 ASCII 连字符）。

## 6. 未验证 / 未做（必须如实声明）

1. **没有任何 Xcode 编译、模拟器运行或云端触发**。新定位只在**结构上**与 run37216674264 记录的原生层级一致，**尚未在 iOS 26 上实际通过**；`Done` 在选择后的 enabled 状态、`photosView_content_scroll_view` 在真实运行中的出现时机均需真实重跑确认。
2. 守卫的放行分支只在本机用**模拟 artifact 目录**执行；其文件/目录名取自真实 run 的 artifact 清单，但不等于云端导出流程已被端到端验证。
3. 未取得：新模拟器 ZIP/新 SHA、新 SDK 预览截图、编译警告完整清单（Round23 记录 4 条 AppIntents 元数据告警，未声称零告警）、xcresult/附件原始文件。
4. 依旧未验证：同会话重启恢复、深色模式、大字号、真机/iPad/VoiceOver、最低 iOS 17 覆盖、新 SDK 系统控件外观（须实际视觉检查）。
5. **未推送、未提交、未触发云端、未改账户、未付费**；Appetize 仍 31/30（0 分钟）暂停；Apple 账户问题搁置；Stage02 保持 CHANGES_REQUESTED/所有者 PENDING，Stage03 不启动。

## 7. 交 Architect 的下一步

1. 复审本报告与两个文件的实际 diff；若接受，在**额度核对后**做**单次**云端预检重跑（源码推送需另行授权），核对：iOS 26.5 上 85/85、新包 SHA、以及守卫是否按预期放行 `failure-attachments/<UUID>.mp4` 并打印来源说明。
2. 若 iOS 26 上出现新的原生层级差异，保留原始 dump 后按证据限定修正；**不得**通过 skip、无限重试、坐标点击或宽泛兜底换取通过。
3. 本报告不代替所有者交互验收，也不把「Xcode 26 通过」当作 Stage02 批准。
