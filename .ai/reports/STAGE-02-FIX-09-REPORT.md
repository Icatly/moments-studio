# STAGE-02-FIX-09-REPORT.md

Stage 02 — Fix 09：既有 Cancel smoke 改为等待**真正的原生选择器就绪**
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-09.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-18.md`、run8 原始证据 `.ai/build/downloads/run-37149876593/`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过复审、未交所有者验收；Stage02 CHANGES_REQUESTED、Stage03 禁止）

---

## 1. 真实结果（Round 18，第 8 次运行）

- 源码 `b9cf5a7fff593a9b7ed55660f0ab21fdbb4afe3d`，run [37149876593](https://github.com/Icatly/moments-studio/actions/runs/37149876593)（job 111281259985）；下载 ZIP 86,201,221 字节、SHA256 `2da71fb8a95570f4db7ebed2bb6fb043b5a022c91d1aefb5e6a1758fbc2bd2a`。
- macOS **编译成功**：80 单元 + 4 个既有 UI 通过；**总 85 / 84 通过 / 1 失败 / 0 跳过**。
- **新的完整真实用例通过（54.357 秒）**：真实选择器 → 精确选照片 → `Add` → 导入 1 张 → 点缩略图 → 预览（`preview.info`、`preview.image` 加载证据、无 missing/unavailable）→ Done → 取消移除 → 确认移除 → 空画廊/计数 0 → 再次导入同一来源。
- 其**实际截图已由 Architect 目视审查**（`6BA9E4EB-EDE1-4B17-B345-563367F66A26.png`，1206×2622，素材 360×540 PNG；附件 SHA256 `2577e72fff2dfd31a32cba9b27050e1f414c32e3491225c304e06a45997027c1`）：照片正向、2:3、aspect-fit 留白、无裁断，Preview/Done/Remove 与信息可辨，无 loading/missing/unavailable。
- **唯一失败**：既有 `testImportPickerCanBeDismissedBackToTheEditor`，`Stage02ImportUITests.swift:65` —— Cancel 点击后的 20 秒有界消失等待超时。

## 2. 根因与限度（只依据原生证据）

- 旧代码在**任意** `app.buttons["Cancel"]` 一出现就点击，既未等原生 Photos 导航就绪，也未等该控件 enabled+hittable。
- 原生录屏（`6250FC7B-A343-4B87-B0DF-6F3779389425.mp4`）：约 6 秒画面仍是初始化 Loading、**可见 Cancel 但没有 Photos 导航**，约 13 秒才是完整 Photos/Collections/网格。即存在"先出现 Cancel、后完成选择器呈现"的窗口，早期点击未生效。
- run8 的失败附件显示残留控件为 `Button identifier: 'Cancel'`，同层还有 `Button label: 'Photos', Selected`；更早的完整原生树（run 37147120379，iOS 18.5）给出确切层级：

```text
72: NavigationBar  {{0, 72}, {402, 109}}  identifier: 'Photos'
73:   Button       {{8, 78}, {63.7, 44}}  identifier: 'Cancel', label: 'Cancel'   ← 真正的 Cancel
74:   SegmentedControl label: 'Photos'
75:     Button label: 'Photos', Selected
76:     Button label: 'Collections'
77:   Button {{354, 78}, {40, 44}} label: 'Add', Disabled
```

**就绪判据因此是 Photos 导航栏，而不是早期 Cancel。** Apple 内部为何该次早期点击未生效、以及当时按钮的 enabled 取值，**原始 dump 并未证明**——本报告**不**声称生产应用的 Cancel 回调有缺陷，也不改生产代码。

## 3. 授权修正（只改这一个 smoke 用例）

仅 `MomentsStudioUITests/Stage02ImportUITests.swift` 的 `testImportPickerCanBeDismissedBackToTheEditor`：

1. **正向等待原生 Photos 导航**：`app.navigationBars["Photos"].waitForExistence(timeout: 20)`；**没有**"早期 Cancel 即视为就绪"的兜底。
2. **在观测到的原生作用域内查询 Cancel**：`photosNavigationBar.buttons["Cancel"]`（有类型的 Button，位于该 NavigationBar 之下）。
3. **一次点击前要求有界 enabled+hittable**：复用既有 `UITestSupport.waitUntilEnabledAndHittable()`（即任务所说的 waitUntilEnabled 与 waitUntilHittable 组合，已存在，无需新增 helper）。
4. **消失判据双重要求**：Cancel 控件与 Photos 导航**都**要有界消失（`waitForDisappearance()`），随后仍要求 Editor 的导入入口 enabled **且** hittable——这是同步修正，不是单纯加长超时。
5. **原生诊断**：全部失败消息附 `app.debugDescription`（6 处），保留真实原生状态。
6. **未做**：sleep、重试点击、坐标、跳过、relaunch、为了取消而选择照片、要求非空图库、注入控件；**未改**全流程用例、其选择器 helper、保留截图逻辑与任何生产字节。

## 4. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | 仅 `testImportPickerCanBeDismissedBackToTheEditor`：改为"正向等待 Photos 导航 → 该作用域内类型化 Cancel → 有界 enabled+hittable → 单次点击 → Cancel 与 Photos 导航双双有界消失 → Editor enabled+hittable"，失败附原生层级 |

`git diff --stat`：**本请求轮次只改这 1 个文件（28 insertions / 15 deletions）**；`git status` 无其他 Swift 改动（生产代码、全流程测试、截图逻辑均未触碰）。

## 5. 本机实际执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用） |
| `python tools/verify_project.py` | **PASS**：40 Swift 文件 **6567 行**；**11 个 UI 查询标识符**解析（`Add`/`Cancel`/`Photos`/`content_scroll_view` 为系统项并显式列出豁免）——本轮无需改该工具 |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-09 一致性脚本 | **13/13 PASS**：先等 Photos 导航再查 Cancel、无早期 Cancel 兜底、Cancel 在观测作用域内、点击前有界 enabled+hittable、点击恰好 1 次、Cancel 与 Photos 导航均有界消失、Editor enabled+hittable 保留、≥6 处原生诊断、无 sleep/重试/坐标/跳过/relaunch、全流程用例与其选择器 helper 未变、保留截图逻辑未变、85 个方法（80 单元 + 5 UI）齐备、生产文件未被触碰 |
| 既有回归脚本 | FIX-02…FIX-08（含两轮澄清）与 `STAGE02_ALL_CORRECTIONS_CHECK`、`STAGE02_CONFORMANCE` 全部 **PASS** |
| **diff / 空白检查** | `git diff --check` → 无空白错误；全仓 markdown 仍为有效 UTF-8 |

**未执行**：任何 Xcode 构建、单元/UI 测试与运行期交互。**FIX-09 的 macOS 结果在 Windows 上 UNVERIFIED。**

> 一次性检查脚本更新（诚实披露）：13 项实现中检查脚本的 item 11 原本断言旧的 smoke 内部写法（`pickerAppeared`、`XCTAssertTrue(pickerCancel.exists`），已按 FIX-09 授权替换为**更强**的就绪判据（正向 Photos 导航 + 作用域内 Cancel + enabled/hittable + 双重消失 + Editor 可操作），并断言不再存在 `pickerAppeared` 兜底。更新后 12 个脚本全部 PASS。

## 6. 未验证的门（交 Architect）

1. **FIX-09 之后源码的 macOS 重跑**：UNVERIFIED；当前 85/84/1/0 是**旧源码 `b9cf5a7`** 的结果。
2. **iOS 17.2 真实运行复查**：18.5 全流程已通过且截图已审，但 17.2 之前的 fatal 需**新的有效包**实测确认。
3. 同会话重启恢复、深色/大字号、真机与 iPad/VoiceOver、精确 iOS 17.0/Xcode 15.4 仍未完成。
4. **尚无通过构建门禁的新交付包**；Appetize 仍是旧包，额度 27/30、剩 3 分钟、暂停未消耗；所有者 9 项验收未勾选。

## 7. 未做的动作

未 push/dispatch/upload、未改账户、未运行云端构建、未消耗 Appetize、未改工作流/工程/工具、未改生产 Swift/模型/序列化/依赖、未删除或跳过测试、未开始 Stage03。此前原始证据与历史 review 决定均未改写。

## 8. 下一步

Architect 复审本报告 → 重跑 macOS 全 85 项（期望 Cancel smoke 与完整流程同时通过）→ 生成有效新包并做 17.2/重启/深色大字号必要复查 → 所有者验收。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER` 或 `APPROVED`。
