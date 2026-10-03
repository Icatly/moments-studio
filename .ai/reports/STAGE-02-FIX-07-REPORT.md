# STAGE-02-FIX-07-REPORT.md

Stage 02 — Fix 07：按**实际观测到的**系统选择器层级修正测试定位
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-07.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-14.md`、原生失败附件 `.ai/build/downloads/run-37147120379/failure-attachments/ABA75FF7-80B3-414D-B25C-8591AC245D1C.txt`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过复审、未交所有者验收；Stage02 CHANGES_REQUESTED、Stage03 禁止）

---

## 1. 真实证据（Round 14）

- 云端 run [37147120379](https://github.com/Icatly/moments-studio/actions/runs/37147120379)（job 111273262286），源码 `96dece596be8eee0d8a0ec06eb10e40d894c5c1f`；下载 ZIP 71,958,044 字节、SHA256 `3261f050b19922619b64a06cd4ccc8c2a2a4f2d5d48f01178b97982a609bf280`；环境 macOS 15.7.9 / Xcode 16.4 / arm64 iPhone 16 Pro / iOS 18.5。
- **编译成功**；原生汇总 **85 项、84 通过、1 失败、0 跳过、0 预期失败**：80 单元全 PASS、4 个既有 UI PASS、**新增第 5 个 UI 用例在导入之前失败**（`Stage02ImportUITests.swift:111`，即选照片那一步）。
- 本地只读读取原生附件，失败消息正是我上轮加入的诊断：

```text
XCTAssertTrue failed - No native photo-grid cell could be selected:
collectionViews.cells: exists=false hittable=n/a; collectionViews.images: exists=false hittable=n/a
```

原生层级（同一附件）证明：

| 行 | 内容 |
| --- | --- |
| 95 | `ScrollView … identifier: 'content_scroll_view'`（选择器网格的滚动容器） |
| 96–110 | `photos_layout` → `photos_sectioned_layout` → `PXAssetsSectionLayout-Group` → … → `PXGGridLayout-Group` |
| 111–117 | `Image … identifier: 'PXGGridLayout-Info'`，label 如 `Photo, October 03, 7:14 PM`（**9 张真实照片**，前三张即工作流种入的合成图） |
| 77 | `Button … label: 'Add', Disabled`（未选中任何照片时禁用） |
| 98–105 | 选择器显示 "Private Access to Photos" 提示条（限权访问），不影响单元格存在 |

**结论**：本层是**测试定位假设错误**——iOS 18.5 的选择器里没有 collection view；不是"没有照片"、不是用户取消，而且该次运行**从未到达导入或预览**。因此"预览修复已被验证"或"Appetize 崩溃已消失"都**不能**由本轮得出。

## 2. 授权修正（只改测试 helper）

只修改 `MomentsStudioUITests/Stage02ImportUITests.swift` 的 `selectFirstPhotoCell` 及其直接相关文档：

```swift
let scope = app.scrollViews["content_scroll_view"]
guard scope.waitForExistence(timeout: 20) else { /* 诊断 */ }

let photos = scope.images.matching(identifier: "PXGGridLayout-Info")
let photo = photos.element(boundBy: 0)
guard photo.waitUntilHittable(timeout: 20) else { /* 诊断：exists/hittable/count */ }

photo.tap()
```

- 使用**已观测**的原生范围与照片标识（`content_scroll_view`、`PXGGridLayout-Info`），Swift 实参用双引号；有界等待（范围 20 秒存在、照片 20 秒存在且可点）后选择第一张真实照片。
- 失败诊断保留关键证据（范围缺失 / 无可用照片且给出 exists、hittable、count）；调用处仍保留原生 `app.debugDescription`（≥15 处）。
- **无**未限定 `app.images`、**无**屏幕坐标、**无** sleep、**无** skip、**无**盲回退链（只有这一条精确查询）、**无** launch 注入/夹具替换/生产测试按钮；`Add` 仍等待 enabled 且 hittable。
- 旧的 `collectionViews` 假设只作为"为何失败"的说明保留在注释里，代码中已无该查询。

**OS 特异性披露**：以上标识来自 **iOS 18.5** 的 PhotosPicker 原生层级（自动回归运行的工作流模拟器）。若其它系统版本的层级不同，该查询会**带诊断显式失败**（这是刻意的：不扩大盲回退）；iOS 17.2 的手工 Appetize 会话尚未重新检查。

## 3. 保持不变（任务要求）

- **85 个方法全部保留**：80 单元 + 5 UI（本轮未新增/删除/改名）。
- **每一个端到端断言保留**：真实选择器打开、真实网格选择、`Add`、缩略图与 `1 of 20 photos`、预览 `preview.info`/图像加载指示器有界消失/`photo.unavailable` 不存在/图像区可点、Done 回可用 Editor、Remove 真实确认（含 "photo library is not changed"）、Cancel 保留副本、确认移除后空画廊 `0 of 20 photos`、再次导入同一来源成功。
- `RootView` 的**同实例 sheet 依赖注入**（FIX-06）原样保留。
- **未改任何生产 Swift**、模型、序列化字段、存储、渲染逻辑、导航契约、依赖、工作流或工程设置。

## 4. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | `selectFirstPhotoCell` 改用观测到的 `content_scroll_view` / `PXGGridLayout-Info` 定位；注释更新为原生证据；其余断言不动 |
| `tools/verify_project.py` | 系统豁免表把 **`content_scroll_view`** 记为系统（选择器）标识符并写明来源（run 37147120379 的原生层级）；同时把该表的说明改为"系统标识符与控件标签" |

`git diff --stat`：**本请求轮次只改 1 个 Swift 文件（34 insertions / 15 deletions）**；Architect于03:35核对：FIX-06的 `RootView.swift` / `UITestSupport.swift` 已包含在提交96dece5中，并非未提交改动；FIX07相对该提交只修改1个UI测试Swift文件，生产代码未改。

## 5. 本机实际执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用） |
| `python tools/verify_project.py` | **PASS**：40 Swift 文件 **6512 行**；Sources 覆盖、构建设置/scheme/资源 JSON；**8 个 UI 查询标识符**解析通过（`Add`/`Cancel`/`Photos`/`content_scroll_view` 为系统项并显式列出豁免） |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-07 一致性脚本 | **15/15 PASS**：使用观测范围与标识符、代码中无 `collectionViews`、无未限定 `app.images`、无坐标/ sleep / skip、范围与照片均有界等待、失败诊断含范围与照片证据、`app.debugDescription` 保留、`Add` 仍等 enabled+hittable、只有一条精确查询、**85 个方法齐备（80 单元 + 5 UI）**、端到端断言齐全、RootView 注入未变、生产文件未被本轮触碰 |
| 回归脚本 | FIX-02 / FIX-03 / FIX-04 / FIX-05（含澄清）/ FIX-06（含澄清）/ `STAGE02_ALL_CORRECTIONS_CHECK` / `STAGE02_CONFORMANCE` 全部 **PASS** |
| **diff / 空白检查** | `git diff --check` → 无空白错误；全仓 markdown 仍为有效 UTF-8 |

**未执行**：任何 Xcode 构建、单元/UI 测试、真实选择器交互与运行期测量。本报告**不**声称 macOS 构建或测试通过——那由 Architect 执行。

> 工具期望更新（诚实披露，均为**随 FIX-07 授权变更的定位**同步，不是放宽校验）：
> 1. `verify_project.py` 系统豁免表新增 `content_scroll_view`（系统选择器标识符，非 App 标识符），并在输出中显式列出。
> 2. FIX-06 的两个一次性检查脚本中"必须使用 collectionViews 查询 / 报告试过哪些 collectionViews 查询"的子检查，已改为核验 FIX-07 的观测定位与诊断文本；FIX-06 主检查 16/16、澄清检查 11/11 仍全部通过。

## 6. 未验证的门（交 Architect）

1. **新定位能否在真实 iOS 18.5 选择器上选中照片**——只能由下一次 macOS 运行判定；若失败，诊断会给出范围/照片的 exists、hittable、count。
2. **导入→预览是否真的不再崩溃**（FIX-06 的模态注入是否有效）——本轮仍未到达该路径，**不能声称已验证**。
3. 移除计数、追加导入、重启恢复、浅/深色与大字号、iOS 17.2 手工复查、真机与 iPad/VoiceOver、精确 iOS 17.0/Xcode 15.4。
4. Appetize：额度 **27/30 已用、剩 3 分钟、无活跃会话**；DSH **未消耗**任何额度、未上传、未改账户。

## 7. 未做的动作

未运行云端构建/工作流，未 push/upload，未改账户或额度，未改生产代码/模型/存储/序列化/依赖/工程设置/工作流，未删除或跳过测试，未开始 Stage03。已完成的历史证据与既有 review 决定均未改写。

## 8. 下一步

Architect 复审本报告 → 重跑 macOS（80 单元 + 5 UI）→ 若通过再决定必要的运行期复查（预览/移除/重启等）→ 所有者验收。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER` 或 `APPROVED`，9 项验收清单未勾选。
