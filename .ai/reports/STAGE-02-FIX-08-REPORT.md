# STAGE-02-FIX-08-REPORT.md

Stage 02 — Fix 08：修正只读预览图像的"已加载"判据，并保留一张完整预览截图
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-08.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-16.md`、原生失败附件 `.ai/build/downloads/run-37148549701/failure-attachments/BBA7314A-FB29-4E7F-B227-35532026428D.txt`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过复审、未交所有者验收；Stage02 CHANGES_REQUESTED、Stage03 禁止）

---

## 1. 真实证据（Round 16）

- 云端 run [37148549701](https://github.com/Icatly/moments-studio/actions/runs/37148549701)（job 111277399157），源码 `e84b834740ea52c477c0f57080e36cc0baa7b1d7`；workflow 8m26 / job 8m14；下载 ZIP 84,100,743 字节、SHA256 `814bbb59422ddb78a6f43df549f30d5f95fc18e2b57e8e4876a3b3082b7e082b`；Xcode 16.4 / iOS 18.5。
- 原生汇总 **85 项、84 通过、1 失败、0 跳过、0 预期失败**：80 单元 + 4 既有 UI 通过。
- **本轮全流程已真正走到预览**：精确选择器查询 → 真实照片 → `Add` → 导入 1 张 → 点缩略图 → `preview.info` 出现、`preview.missingPhoto` 不存在、加载指示器消失、`photo.unavailable` 不存在——**这些检查全部通过**。
- **只在 `Stage02ImportUITests.swift:158` 失败**，失败消息即我上轮的断言：`XCTAssertTrue failed - The preview image area is not visible after loading.`
- 原生层级（同附件）：

| 行 | 内容 |
| --- | --- |
| 70 | `Image … {{16.0, 166.3}, {370.0, 555.0}}, identifier: 'preview.image'`（在 402×874 窗口内） |
| 71 | `StaticText … identifier: 'preview.info', label: '360 × 540 · PNG'` |
| 63 / 65 | `Other` **与** `Button` 同带 `identifier: 'preview.done'`（重复包装层） |
| 76 / 78 | `Other` **与** `Button` 同带 `identifier: 'preview.remove'`（重复包装层） |
| — | 无 `preview.missingPhoto`、无 `photo.unavailable`，无 fatal |

**判据错误**：`isHittable` 报告的是"是否存在可计算的交互命中点"（[Apple 文档](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)），而这里的图片是只读装饰性 `Image`，不是点击动作。因此该断言与产品要求不符。**Apple 内部为何返回 false 本轮不作断言**，也不因 `exists`/`frame` 就宣称像素可见——**没有像素证据之前不宣称视觉通过**。

## 2. 授权修正（只改 UI 测试）

全部改动位于 `MomentsStudioUITests/Stage02ImportUITests.swift`。

1. **正向的已加载证据**：`DerivedImageView` 只在 `loaded(CGImage)` 分支才生成 `Image(decorative:)`（loading 是 `ProgressView`，failed 是 unavailable 控件），因此改用**有类型的** `app.images["preview.image"]` 查询：
   - 有界等待该 Image 出现（30 秒）；
   - 校验 frame **有限、非空、宽高 > 0**（逐分量 `isFinite`，不依赖不确定的 `CGRect.isFinite`），且**完全落在 `app.frame` 内**（`app.frame.contains(imageFrame)`）。
   - **不再对图片使用 `isHittable`**。
2. **保留原有全部检查**：加载指示器有界消失、`preview.missingPhoto` 不存在、`photo.unavailable` 不存在、`preview.info` 存在——均**未被** `exists` 化替代。
3. **一张保留的完整截图**：图片就绪后立即 `XCTAttachment(screenshot: app.screenshot())`，名称 `Stage02 imported photo preview`，`lifetime = .keepAlways`（成功也保留）；**无** golden 对比、**无** 伪造截图、**无** 额外快照框架。像素是否真可见由 Architect 看图判定。
4. **操作控件用已观测的类型查询**：`app.buttons["preview.done"]` / `app.buttons["preview.remove"]`（避开同标识的 `Other` 包装层），每次点击前都要求**有界 enabled 且 hittable**；**Cancel 确认后**重新等待 Remove 与 Done 可用再点击。确认框文案与 Cancel/Remove 仍为真实交互。
5. **保留**：完整流程（选择器 → Add → 缩略图/计数 → 预览 → Done → Cancel 移除 → 确认移除 → 空画廊/计数 0 → 再次导入同一来源）、FIX-07 的观测选择器查询与诊断、85 个方法。
6. **未改任何生产 Swift**、公开序列化字段、存储、渲染、导航、依赖、工程设置或工作流；**未**给 Image 添加交互、**无** sleep/skip/坐标回退/注入 id/测试按钮。

## 3. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | 只读预览图像的判据改为类型化 Image + 有限非空且全在屏内的 frame；新增 1 张 keepAlways 完整预览截图；Done/Remove 改为类型化 Button + 有界 enabled+hittable 点击；其余断言与流程不动 |

`git diff --stat`：**本请求轮次只改这 1 个文件（56 insertions / 14 deletions）**；`git status` 无其他 Swift 改动（FIX-06/07 的改动已随源码 `e84b834` 提交）。

## 4. 本机实际执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用） |
| `python tools/verify_project.py` | **PASS**：40 Swift 文件 **6554 行**；**11 个 UI 查询标识符**解析通过（新增 `preview.done`/`preview.image`/`preview.remove` 三个 App 标识符；`Add`/`Cancel`/`Photos`/`content_scroll_view` 为系统项并显式列出豁免）——本轮**无需**修改该工具 |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-08 一致性脚本 | **21/21 PASS**：类型化 Image 查询、无 Any 包装层查询、图片不用 `isHittable`、有界等待、有限非空 frame、全在 `app.frame` 内、加载/缺失/不可用/info 检查保留、恰好 1 张截图且名称与 `.keepAlways` 正确、截图紧随图像证据、无 golden/快照框架、类型化 done/remove、通用包装层查询已移除、每次点击前有界 enabled+hittable（≥5 处）、Cancel 后重新要求可用、确认文案/Cancel/Remove 保留、空画廊与重导保留、FIX-07 选择器查询与诊断保留、无 sleep/skip/坐标/注入、**85 个方法齐备（80 单元 + 5 UI）**、生产源码未被触碰 |
| 既有回归脚本 | FIX-02…FIX-07（含两轮澄清）与 `STAGE02_ALL_CORRECTIONS_CHECK`、`STAGE02_CONFORMANCE` 全部 **PASS** |
| **diff / 空白检查** | `git diff --check` → 无空白错误；全仓 markdown 仍为有效 UTF-8 |

**未执行**：任何 Xcode 构建、单元/UI 测试与运行期交互。**不声称 macOS 构建或测试通过。**

> 一次性检查脚本更新（诚实披露，全部因 FIX-08 授权的判据替换而同步，非放宽校验）：
> 1. 三个 FIX-06/07 脚本中"禁止任何 `app.images`"的子检查，改为**仍禁止无范围通配用法**（正则 `app\.images(?!\[)`），同时允许 FIX-08 要求的**带标识的类型化查询** `app.images["preview.image"]`。
> 2. FIX-06 主检查中 `element("preview.image"/"preview.done")` 的期望改为类型化查询与 frame 判据。
> 3. FIX-06 澄清检查里"图像区可见"的期望由已删除的旧消息改为 FIX-08 的有限 frame + 全屏内判据。
> 更新后四个脚本分别 21/15/16/11 项全 PASS，其余脚本未受影响。

## 5. 未验证的门（交 Architect）

1. **像素是否真的可见**：本机与云端均未做像素比对；测试源码已加入一张 `keepAlways` 完整预览截图的保留逻辑；尚未执行产生新截图，待 macOS 实际生成后由 Architect 看图判定（其工作流改动会把保留附件一并导出）。
2. **FIX-08 修改后源码的 macOS 构建/测试**：**UNVERIFIED**；当前实测结论仍是**旧源码 `e84b834` 的 85/84/1/0**。
3. **iOS 17.2 崩溃是否消失**：本轮跑在 iOS 18.5 且未出现 `PhotoImportModel` fatal，但**不能**据此宣称 17.2 已修复。
4. 同会话重启恢复、深色/大字号、真机与 iPad/VoiceOver、精确 iOS 17.0/Xcode 15.4 仍待完成。

## 6. 未做的动作

未运行云端构建/工作流、未 push/upload、未改账户、**未消耗 Appetize**（仍 3 分钟暂停）、未改工作流、未改生产 Swift/模型/存储/序列化/依赖/工程设置、未删除或跳过测试、未开始 Stage03。原始失败证据与既有 review 决定均未改写。

## 7. 下一步

Architect 复审本报告 → macOS 重跑 85 项（本轮应能在保留附件中拿到完整预览截图）→ 人工审图确认像素可见 → 再决定 iOS 17.2/重启/深色大字号等必要运行复查 → 所有者验收。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER` 或 `APPROVED`，9 项验收清单未勾选。
