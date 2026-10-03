# STAGE-02-FIX-06-REPORT.md

Stage 02 — Architect Fix 06（真实运行发现：点开预览即退出应用）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-06.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-12.md`、`.ai/build/downloads/stage02-appetize-preview-crash/debug-log.txt`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过 Review、未交所有者验收；Stage02 CHANGES_REQUESTED、Stage03 禁止）

---

## 1. 真实证据与根因

- 源码 `012126165c0a00203a71b491fb7f632f4875d84c`，run 37138644682：**80 单元 + 4 UI 在真实 macOS 上全部通过、0 失败/0 skip**，ZIP 已上传到既有授权 Appetize 应用（SHA256 `97396cf2d0a4680c259eb377590a9ae06f4ef191f9c7d92a768b2a81a3b0ce7c`），iPhone 14 Pro / iOS 17.2。
- 真实操作：选择器导入 3 张（顺序正确、count 3/20、Saved Yes）后，**点缩略图即退出到 iOS SpringBoard**；另一会话导入预设照片后同样在点缩略图时退出。
- 实际致命日志（02:56:46.643083+0800，已下载原文）：

```text
SwiftUI/Environment+Objects.swift:32: Fatal error: No Observable object of type PhotoImportModel found.
A View.environmentObject(_:) for PhotoImportModel may be missing as an ancestor of this view.
```

**根因**：`RootView` 把 `.environment(navigation/projectStore/photoImport)` 挂在 `.sheet` **之前**；`PhotoPreviewSheet` 通过 `@Environment(PhotoImportModel.self)` / `@Environment(ProjectStore.self)` 读取模型，而在该 iOS 17.2 路径上被呈现的内容没有拿到这些实例 → 预览一打开即崩溃。这是**模态依赖注入缺陷**，与图片解码/素材存储无关（未改动解码或存储逻辑）。既有 **4 个 UI 测试（2 个 Stage 01 smoke + 2 个 Stage 02 选择器/入口用例）**只打开或取消选择器，**从未导入照片、也从未打开预览**，所以 84 项 PASS 并不能覆盖该路径。OS 内部的精确传播机制本报告不作断言。

**Appetize 额度（Architect 于 03:03 更新的事实）**：**27/30 已用、剩余 3 分钟，所有会话均已关闭**；下一次真实运行检查前需重新确认余额。DSH 未消耗任何额度（未访问 Appetize、未运行云端构建）。

## 2. 授权修正一：模态获得同一批实例

仅改 `MomentsStudio/App/RootView.swift` 的既有 `.sheet` 闭包（+16 行）：

```swift
.sheet(item: $navigation.sheet) { route in
    sheet(for: route)
        .environment(navigation)
        .environment(projectStore)
        .environment(photoImport)
}
```

- 传入的是 **同一批根实例**（`navigation` / `projectStore` / `photoImport`，均由 `RootView` 持有），没有新建 state/store/coordinator。
- 未使用 `environmentObject`、未迁移 Observation、未改导航契约、未加可选 fallback 或协议/服务/包。
- 保留既有 `NavigationStack(path:)`、`navigationDestination` 与 `.task { await photoImport.restoreProjects() }` 启动恢复生命周期；屏幕层级不变（仍是 `sheet(for:)` 的 switch）。

## 3. 授权修正二：一个真实选择器 → 导入 → 预览 回归

新增 **1 个** UI 测试（`MomentsStudioUITests/Stage02ImportUITests.swift`）：

`testImportPreviewShowsTheImageAndRemovalConfirmationKeepsOrRemovesTheCopy`

单一场景，全部使用真实系统 UI 与云端工作流已预置的合成照片（未加生产测试按钮、未注入 launch arguments、未伪造 provider 的 photo id）：

1. Home 就绪 → Create Project → Editor 初始为空（`editor.galleryEmpty`）。
2. 打开 **真实 PhotosPicker**（`editor.importPhotos`）→ 断言选择器真的出现（`Cancel` 或 `Photos` 导航栏）→ 在**原生网格单元**上选择一张预置照片 → 点 **Add** 确认。
3. 断言导入已提交：`editor.photo.` 前缀的缩略图出现且可点、计数为 `1 of 20 photos`。
4. **点缩略图打开预览**（即崩溃路径）：断言 `preview.info` 出现、`preview.missingPhoto` 不存在、`preview.image` 可交互、`photo.unavailable`（加载失败占位）**不存在**。
5. `preview.done` 返回，Editor 恢复可用且计数仍为 1。
6. 再次打开预览 → 点 `preview.remove` → 断言出现**真实系统确认**且文案含"photo library is not changed"（不修改相册原图）→ 点确认框 **Cancel** → 回到预览、Done 后计数仍为 1，控件可用。
7. 再次 Remove 并**确认** → 断言回到空画廊（`editor.galleryEmpty`）且计数 `0 of 20 photos`（移除更新计数）。
8. 再次打开选择器并**重新选择同一张预置照片**导入成功、计数回到 1（证明移除的是本项目副本、相册来源未被改动、可再次选择）。

约定与假设（**需真实运行确认**，已在测试注释中写明）：

- 选择器为系统 UI；`Cancel` 与 `Photos` 导航栏此前真实运行已验证可匹配。
- 网格单元按 `app.collectionViews.cells` → `app.collectionViews.images` → `app.images` 的**原生查询**顺序取第一个可点元素；确认控件为 `Add`（系统标签）。
- 确认框按 action sheet 优先（`app.sheets.buttons[...]`，回退 `app.alerts.buttons[...]`），避免匹配到工具栏自身的 "Remove"。
- 缩略图 id 含运行时 UUID，故用 `identifier BEGINSWITH "editor.photo."` 前缀匹配，不猜测 UUID。
- 全部等待均为有界 `waitForExistence` / `XCTNSPredicateExpectation`（新增 `XCUIElement.waitUntilHittable`），**无任意 sleep**、无 skip、无删除既有断言。

若某条系统 UI 假设不成立，测试会**显式失败并给出消息**，不会静默通过。此测试可能比既有 UI 用例耗时更长（两次选择器往返），请在云端工作流确认超时设置（工作流本身未改动）。

## 4. 本轮改动文件

| 文件 | 改动 |
| --- | --- |
| `App/RootView.swift` | `.sheet` 内容显式注入同一批 `navigation`/`projectStore`/`photoImport`（+说明注释）；其余不动 |
| `MomentsStudioUITests/Stage02ImportUITests.swift` | 新增 1 个预览/移除回归与选择器/网格/确认框辅助方法；类注释更新；既有 2 个用例未改 |
| `MomentsStudioUITests/UITestSupport.swift` | 新增 `waitUntilHittable(timeout:)`（有界等待可点） |
| `tools/verify_project.py` | 系统控件标签豁免表新增 `Add`（系统选择器的确认控件；与既有 `Cancel`/`Photos` 同一机制），并写明理由 |

`git diff --stat`：**3 个 Swift 文件 + 1 个工具脚本，Swift 侧 276 insertions(+), 4 deletions(-)**（`RootView.swift` +16、`Stage02ImportUITests.swift` +246、`UITestSupport.swift` +18）；`git status` 确认未触碰任何模型/服务/存储/资源/工程设置/工作流文件，序列化契约与全部既有测试保持原样。

## 5. 本机执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用；UI 测试仍 3 个文件） |
| `python tools/verify_project.py` | **PASS**：40 Swift 文件 **6398 行**、Sources 覆盖、构建设置/scheme/资源 JSON；**7 个 UI 查询标识符**解析通过（`Add`/`Cancel`/`Photos` 为系统标签并显式列出豁免） |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0`（40 Swift 文件 **6493 行**） |
| FIX-06 一致性脚本 | **16/16 PASS**（§2 模态注入 + §3 回归全项；"来源可再次选择"子检查的期望字符串已随 03:03 澄清后的消息文本更新） |
| FIX-06 同范围澄清脚本 | **11/11 PASS**（见 §8：Add 等待 enabled+hittable、无未限定 `app.images`、网格查询限定、加载指示器有界消失后才断言 unavailable、加载后可见性/信息断言、≥15 处 `app.debugDescription`、诊断含试过的查询与 Add 三态、生产视图未改、无 sleep/skip） |
| 回归脚本 | FIX-02 / FIX-03 / FIX-04 / FIX-05 / FIX-05 澄清 / `STAGE02_ALL_CORRECTIONS_CHECK` / `STAGE02_CONFORMANCE` 全部 **PASS** |
| **diff / 空白检查** | `git diff --check` → 无空白错误；全仓 markdown 仍为有效 UTF-8 |
| 测试计数 | **80 单元 + 5 UI = 85 项**（新增 1 个 UI 用例），本机全部**未执行** |

> 工具说明（诚实披露，两处均为脚本期望更新，非放宽校验）：
> 1. `verify_project.py` 的**系统控件标签豁免**新增 `Add`：它是系统选择器的确认按钮标签，App 源码中不存在该字符串，与既有 `Cancel`/`Photos` 同机制、同样在输出中显式列出。
> 2. FIX-05 一致性脚本中"不得用 `waitForExistence` 断言消失"的子检查原以整文件禁止 `XCTAssertFalse` 代理实现；FIX-06 新用例出于**存在性**判断合法使用了 `XCTAssertFalse(... .exists)`，故把该检查收窄为"任何地方都不得用 `XCTAssertFalse(...waitForExistence...)` 断言消失"，并保留"picker 用例仍必须用 `waitForDisappearance`"，**比原代理更精确**。

## 6. 未验证的门（必须由 Architect 在 macOS/真机侧完成）

1. **构建与自动测试**：80 单元 + 5 UI 全部未在本机执行；新增 UI 回归与 RootView 改动都只经过静态检查。
2. **新的 UI 回归本身**：系统选择器网格/`Add`/确认框定位均为假设，需真实模拟器运行确认；若定位不成立将显式失败，需按实际 UI 层级调整。
3. **崩溃是否真的修复**：需重新打包并在 Appetize/模拟器实测 "导入 → 点缩略图 → 预览"（这正是本轮缺陷点）；本报告不声称已修复，只声称按授权做了最小注入。
4. 其余运行闸门仍不完整：移除后计数、追加导入、重启恢复、浅/深色与大字号、真机与 iPad/VoiceOver、精确 iOS 17.0/Xcode 15.4。
5. Appetize 免费额度：**27/30 已用、剩余 3 分钟，所有会话均已关闭**（见 §1；Architect 03:03 更新）。下一会话前需重新确认余额；DSH 未消耗任何额度、未访问任何云服务。
6. 既有二进制仍被阻止进入验收；Stage01 所有者批准保持不变，Stage02 所有者判断仍为 PENDING。

## 7. 未做的动作

未 push/upload、未改账户、未运行云端构建、未使用 Appetize、未改 `.github/workflows/*`、未改 SDK/编译器/actor/部署/设计 token/序列化字段/模型不变量/素材处理；未新增依赖、服务、协议或公开接口；未删除或跳过任何测试；未开始 Stage03。证据日志仅本地只读读取。

## 8. 03:03 同范围复审澄清（四项，已实现）

Architect 在同一 FIX-06 范围内追加澄清，DSH 全部落实（**生产 UI 未改动，未新增加载状态 API**）：

1. **Add 必须 enabled 且 hittable**：新增 `XCUIElement.waitUntilEnabledAndHittable(timeout:)`（`exists == true AND isEnabled == true AND isHittable == true`）；`tapPickerAddButton` 用它等待——选择状态是异步更新的，"存在"甚至"可点"都不代表已启用。失败时诊断串给出 `exists/enabled/hittable` 三个值。
2. **移除未限定范围的 `app.images` 回退**：照片单元只在 `app.collectionViews.cells` 与 `app.collectionViews.images` 内查找（原生网格范围），不再回退到全应用 `app.images`（可能匹配到无关图标）。失败时记录**试过哪些限定查询及其 exists/hittable 结果**。
3. **预览"已加载"的判定**：`preview.image` 包装层在加载期间同样存在，不能作为已加载证据。现在改为：有界（60 秒）等待其**加载进度指示器消失**（`ProgressView` → XCTest 的 activity indicator；先查 `app.sheets` 内、再回退全应用，属已披露假设），**之后**才断言 `photo.unavailable` 不存在，并断言图像区域可交互、`preview.info` 存在。
4. **定位失败保留原生证据**：所有选择器/缩略图/预览/移除定位断言的消息都带上 `app.debugDescription`（XCTest 的 `@autoclosure` 消息，仅失败时求值），失败即失败，不扩大盲回退、不 skip。

本机追加验证：`STAGE02_FIX06_CLARIFICATION_CHECK` **11/11 PASS**（Add 同时等待 enabled+hittable、无未限定 `app.images`、网格查询限定在 collection view、加载等待先于 unavailable 断言、加载后有可见性/信息断言、≥15 处保留 `app.debugDescription`、诊断包含试过的查询与 Add 三态、生产视图未被改动、无 sleep/skip、UI 方法数仍为 3）。FIX-06 主检查 15/15 仍 PASS（其"来源可再次选择"子检查的字符串期望已随澄清后的消息文本更新）。

## 9. 下一步

Architect 复审本报告 → 重跑 macOS 构建与 80 单元 + 5 UI → 重新打包并完成真实预览/移除/追加/重启/大字号闸门 → 所有者亲自验收。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER` 或 `APPROVED`，9 项验收清单未勾选。
