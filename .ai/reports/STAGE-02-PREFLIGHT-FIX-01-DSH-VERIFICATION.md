# STAGE-02-PREFLIGHT-FIX-01 — DSH 独立核验报告

Stage 02 预检工作流限定修复01：**DSH 侧独立核验与状态澄清**
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-PREFLIGHT-FIX-01.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-21.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-22.md`、`.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-01.md`、`bc3a15b`/`d4d4ee7`、`run-37216674264` 原始 `job.log`
状态：`READY_FOR_ARCHITECT_REVIEW`（DSH 未运行任何云端作业；Stage02 所有者 PENDING、Stage03 禁止）

> 本文件是 DSH 的核实记录，**不是** FIX-01 的交付报告：FIX-01 的实现报告是同目录的 `STAGE-02-PREFLIGHT-FIX-01.md`（Architect 侧）。本文件不覆盖它。

---

## 1. 传输失败与「未提交工作流更新」的作者澄清

- 21:34 的 FIX-01 任务与 21:52 的续执行要求**均以 Messages transport failed 结束**，DSH 修复未送达（与 Round21/Round22 记录一致）。
- 00:12 后续执行时，DSH 因未读到我方此前的失败回执，**基于同一份 FIX-01 任务自行重写了一份工作流草稿**（工作树内未提交）。`.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-01.md`「10月5日00:19:41 本地工作流出现未提交更新……其作者/交付状态尚待核对」所指的**就是这份 DSH 草稿**。
- **该草稿已作废并撤销**：`git checkout -- .github/workflows/stage02-testflight-preflight.yml` → 工作树工作流与 `d4d4ee7` **逐字节一致**（`git diff` 为空、308 行）。已核实草稿特征（`pure decision logic` 标记、414 行）不复存在，Architect 侧的已复审特征全部回归：`runner-architecture.txt`、`available-destinations.txt`、`id: evidence_guard`、`steps.evidence_guard.outcome == 'success'`、`Build version (\S+)`、凭据/照片守卫。
- 结论：**FIX-01 的实现由 Architect 侧在 `bc3a15b` 完成、`d4d4ee7` 记录并经 Round22 复审**；DSH 没有、也不应再重做它。DSH 本轮只做①撤销草稿②独立核验③如实报告。**DSH 未提交、未推送、未触发云端。**

## 2. FIX-01 四项要求在实际交付中的落点（DSH 只读核对）

| 要求 | 交付实现（`d4d4ee7`） |
| --- | --- |
| 1. build 号无冒号解析 | L72 `re.fullmatch(r"Xcode (\d+(?:\.\d+){0,2})")`；L74-76 `re.fullmatch(r"Build version (\S+)")`；L81-83 缺版本或缺 build → `(inspection failed)` 并排除；无合格者 L89-94 明确失败。**不含** `split(":", 1)[1]` |
| 2. 守卫阻断上传 | L301 `id: evidence_guard`；L329 `if: ${{ always() && steps.evidence_guard.outcome == 'success' }}`；守卫仍 `always()` 运行（失败运行的安全日志在守卫通过时可上传） |
| 3. runtime 按完整版本排序 + 真实 destination | L136-137 `re.search(r"iOS-(\d+(?:-\d+)*)$")` → 完整元组；L151-152 `sort` 后取 `[-1]`；L119-133 用 `xcodebuild -showdestinations` 过滤 `platform == iOS Simulator` 且 `arch == arm64` 的可达 id，L140-141 仅在该集合内选设备 |
| 4. 证据补强 | L46-47 记录并断言主机 `arm64`；L117 选定后记录 runtime 清单；L265-276 summary 守卫：恰好 1 个 device/configuration、`osVersion` 主版本 ≥26、`platform == iOS Simulator`、`architecture == arm64`、`deviceId == STAGE02_SIMULATOR_ID`；L266 落盘实际设备证据；L278-282 仍断言 85/85/0/0/0 |

## 3. DSH 在本机实际执行的核验（Windows，无 Xcode）

**全部使用 Python 标准库**（本轮未用 PyYAML，也没有新增依赖）；核验对象是上面那份已交付工作流本身：

1. **直接执行其内嵌脚本**（从工作流文本抽出、按原样运行，喂入模拟输入）——`STAGE02_PREFLIGHT_FIX01_REVIEWED_VERIFY: PASS`（**43/43**）：
   - **要求1**：以交付文件中的两条正则解析真实输出 `Xcode 26.6\nBuild version 17F113` → `('26.6', '17F113')` ✓；缺 build 行 → build 为空（走明确失败分支）✓；build 号为空 ✓；乱码 ✓；并且确认**不再**使用 `split(":", 1)[1]`。
   - **要求3**：打乱 `26.2/26.4/26.5 + 18.5` 的设备表与 destination 表，仍选中 **iOS 26.5 / iPhone 17 Pro (CCC)** ✓ 并导出 UDID ✓；「仅列在 Ineligible 的 26.5」不被选、改选可用的 26.4 ✓；只有 `arch:x86_64` 的 destination 被拒 ✓；仅 18.5 → 明确失败 ✓。
   - **要求4**：真实 `run9` summary 结构（`totalTestCount/passedTests/failedTests/skippedTests/expectedFailures` + `devicesAndConfigurations[0].device.{deviceId,deviceName,platform,architecture,osVersion,osBuildNumber}`，已逐字段实测存在）改为 iOS 26.5/Simulator/arm64/匹配 UDID → 通过并落盘设备证据 ✓；随后**逐一拒绝**：iOS 18.5 旧结果、非 Simulator、`x86_64`、外部 UDID、缺失选中 UDID、多于一个 device/configuration、无设备证据、1 个失败、1 个跳过、少于 85 项 ✓。
   - **要求2**：守卫脚本接受日志/报告并写清单 ✓、拒绝 `.p8` ✓、拒绝 `photo.jpg` ✓；对工作流里**真实的 `if:` 表达式**按成功/失败/跳过/取消四种 outcome 求值：`success → True`，其余**全部 False**（即守卫失败时上传被阻断）✓；确认守卫 `id` 与条件引用一致、仍只有一处 artifact 上传 ✓。
2. **策略与范围**：仅 `workflow_dispatch`、`contents: read`、`persist-credentials: false`、20 分钟、产物 2 天、无 `secrets`、无 skip/retry、`CODE_SIGNING_ALLOWED=NO` 两处、85 契约断言在位 ✓。
3. **工程静态核对**：`tools/verify_project.py` PASS（132 对象、41 文件引用、40 Swift 文件 **6567 行**、11 个 UI 标识符）；tree-sitter `TREE_SITTER_PARSED=40 WITH_ERRORS=0`；测试方法 **80 单元 + 5 UI = 85** 未增删；`git diff` 中**没有** Swift/测试/工程/生成器/旧工作流改动；`git diff --check` 无空白错误（Architect 自己未提交的文档改动保持原样，DSH 未触碰）。

> 说明：这些是**逻辑与证据层**核验。DSH 无 macOS，未做 Xcode 编译、未跑模拟器测试、未触发工作流。

## 4. 真实云端预检 `run-37216674264`（源码 `d4d4ee7`）——修复在真实环境中的表现

DSH 只读分析了 Architect 已下载的 `job.log`（741,647 字节），未运行任何云端作业：

- ✅ **工具链选择成功**：`selected_xcode_path=/Applications/Xcode_26.6.app`、`selected_xcode_version=26.6`、`selected_iphoneos_sdk=26.5`。这直接证明「无冒号 build 号解析」修复在真实 runner 上工作（旧版会 IndexError 直接崩），且**未凭 runner 标签推断**。
- ✅ **模拟器/destination 选择成功**：`selected com.apple.CoreSimulator.SimRuntime.iOS-26-5: iPhone 17 Pro (22452A91-4697-4369-8812-53ADB77EB73B)`——证明 iOS 26 的真实 `-showdestinations` 输出确实带 `arch:arm64`，完整版本排序与可达 destination 过滤按预期工作。
- ✅ **无签名 iphoneos Release 构建成功**：`** BUILD SUCCEEDED **`，随后设备产物校验步骤通过（`device-Info.plist` 落盘）。
- ✅ **单元测试在 iOS 26.5 上全通过**：`Executed 80 tests, with 0 failures`（各测试套件 `passed`）。
- ❌ **1 个 UI 用例失败**：`Stage02ImportUITests.swift:124`，断言消息即现有诊断——`No native photo-grid cell could be selected: picker scroll view 'content_scroll_view' not found`；UI 汇总 `Executed 5 tests, with 1 failure`，`** TEST FAILED **`，`##[error]Process completed with exit code 65`。
- ✅ **守卫按要求 fail-closed**：summary 断言输出 `total=85 passed=84 failed=1 skipped=0 expectedFailures=0` 后以 exit code 1 失败；**没有生成成功模拟器包**。这正是 FIX-01 要求的行为——不假装通过、不以重试/跳过掩盖。

### 4.1 iOS 26 原生选择器实测层级（供后续定位任务使用；本任务不修改测试）

`job.log` 中原生 dump（iOS 26.5，窗口 402×874）显示与 iOS 18.5 的差异：

```text
NavigationBar            id='Photos'
  Button                 id='Cancel'                 label='Cancel'
  SegmentedControl       (Button 'Photos' / Button 'Collections')
ScrollView               id='photosView_content_scroll_view'     <-- iOS 18.5 时是 'content_scroll_view'
  Other                  id='photos_layout'
  Other                  id='PXGSingleViewLayout-Group'
  Other                  id='PXGSingleViewContainerView_AX'      label='Private Access to Photos…'
  Other                  id='photos_sectioned_layout'
  Other                  id='PXAssetsSectionLayout-Group'
  Other                  id='PXZoomablePhotosLayout-Group'
  Other                  id='PXGZoomLayout-Group'
  ...
  Other                  id='PXGGridLayout-Group'
  Image                  id='PXGGridLayout-Info'   label='Photo, October 04, 4:26 PM'   (多张)
```

要点：**网格照片仍是 `PXGGridLayout-Info`**，但 **scroll view 标识符由 `content_scroll_view` 变为 `photosView_content_scroll_view`**；`Cancel`、`Photos` 导航栏、`Photos/Collections` 分段控件仍在。因此 FIX-07/09 的定位 helper 在 iOS 26 上会（且确实）**带诊断明确失败**——这是我此前预检报告中登记的 D1 风险，现已成事实。
**这是测试定位与新 SDK 的兼容问题，不代表产品导入/预览功能在 iOS 26 上失败**（本轮 UI 用例在选照片步骤即终止，预览路径未执行）。按 FIX-01 授权范围（不改 Swift/85 测试/契约），DSH **未**修改任何测试；是否把该定位扩展为同时接受 iOS 26 标识符（或按后缀匹配）需 Architect 另开限定任务决定。

## 5. 未验证 / 未做 / 剩余限制

1. **DSH 未运行任何云端作业、未触发 workflow_dispatch、未消费 Actions 额度、未上传 Apple、未改账户**；本轮云端结果全部来自 Architect 已下载的 `job.log`，DSH 未独立下载产物（`run-37216674264` 本地目录当前仅有 `job.log`，无 `xcode-selection.txt`/`test-summary.json`/包）。
2. **上表 §4 的结论只针对该次运行**：`85/84/1/0`、`** TEST FAILED **`、无新包。Xcode 26 下 **iOS 26 全部 UI 路径尚未验证**（选择器定位修正前无法完成）；新包、SDK 警告清单、启动截图尚未取得。
3. 仍有未验证项：同会话重启恢复、深色模式、大字号、真机/iPad/VoiceOver、最低 iOS 17 覆盖、精确 Xcode 15.4；新 SDK 系统控件外观差异须实际视觉检查。
4. **Appetize：31/30、0 免费分钟**，未启动新会话；下次重置按历史记录为 11 月 1 日 08:00（北京时间），未重新读取当期页面。**本任务不涉付费**；Actions 额度由所有者提供明细、Architect 事前折算（单次 20 分钟上限约 $1.24，未声称已扣费）。
5. Swift/85 测试/工程/生成器/旧工作流/公开契约本轮**零改动**；工作树只多出本报告；Architect 的未提交文档改动未被触碰。

## 6. 建议的下一步（交 Architect 决定，DSH 不自行推进）

1. 若要继续 iOS 26 预检，需另开**限定测试定位任务**：按 §4.1 实测层级让选择器 helper 同时接受 iOS 18.5 的 `content_scroll_view` 与 iOS 26 的 `photosView_content_scroll_view`（或按 `*content_scroll_view` 后缀 + 有界等待，失败保留原生 dump），不得用无范围回退或跳过；随后重跑该预检并核对 85/85。
2. 复核 `run-37216674264` 产物（工具链详情、警告、失败附件）并把 Xcode 26 结果登记进验收证据；原 `run9` 的 85/85 仍只属于 Xcode 16.4/iOS 18.5。
3. 保持 Stage02 所有者 PENDING、Appetize 暂停、Stage03 不执行；推送/提交由 Architect 决定（本报告与草稿撤销均未提交、未推送）。
