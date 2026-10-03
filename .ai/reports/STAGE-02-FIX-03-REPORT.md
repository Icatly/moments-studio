# STAGE-02-FIX-03-REPORT.md

Stage 02 — Architect Fix 03（第二次 macOS 运行：参数标签编译失败）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-03.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-05.md`、证据 `.ai/build/downloads/run-37132895287/evidence/xcodebuild.log`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过 Review、未交所有者验收；Stage03 未授权）

---

## 1. 本次真实失败证据

- 源码 `20e9d5f4b12be4010862a46d61b7e745aeccbd7e`，run [37132895287](https://github.com/Icatly/moments-studio/actions/runs/37132895287)，job 4m25s，**编译失败，0 个单元/UI 测试执行，无 Stage02 运行包**。
- **上一轮的 `PhotosPickerItem` / `@escaping` 诊断已消失**（FIX-02 的交叉导入生效），本次失败点前移到路径 helper 的调用标签。
- 日志（530 行）中全部 error（本地只读读取，共 5 条，全部在 App target）：

```text
:459  Models/PhotoLibraryPath.swift:109:35: error: extraneous argument label 'projectID:' in call
:463  Models/PhotoLibraryPath.swift:119:35: error: extraneous argument label 'projectID:' in call
:487  Services/PhotoLibrary.swift:206:70:   error: extraneous argument label 'projectID:' in call
:491  Services/PhotoLibrary.swift:246:71:   error: extraneous argument label 'projectID:' in call
:494  Services/PhotoLibrary.swift:337:70:   error: extraneous argument label 'projectID:' in call
```

**根因**：`assetDirectoryReference` 的声明是 `assetDirectoryReference(_ projectID: UUID, assetID: UUID)`（首参无标签），但调用处写成 `assetDirectoryReference(projectID: assetID:)`。`originalReference` 与 `derivativeReference` 内部都调用了它，因此同一错误在 `PhotoLibraryPath.swift:109/119` 各出现一次。

## 2. 修正（仅调用标签，保持声明与路径字符串）

按任务要求只改调用点，未改任何签名、持久化字段、路径结构或无关代码。共 **10 处**（App 5 处 + 测试 5 处），`git diff` 为 **10 行改动、10 行删除**：

| 文件 | 位置 | 改动 |
| --- | --- | --- |
| `Models/PhotoLibraryPath.swift` | :109（`originalReference` 体内） | `assetDirectoryReference(projectID, assetID: assetID)` |
| `Models/PhotoLibraryPath.swift` | :119（`derivativeReference` 体内） | 同上 |
| `Services/PhotoLibrary.swift` | :206 | `PhotoLibraryPath.assetDirectoryReference(projectID, assetID: assetID)` |
| `Services/PhotoLibrary.swift` | :246（多行调用） | `originalReference(projectID, assetID:…, fileExtension:…)` |
| `Services/PhotoLibrary.swift` | :337（多行调用） | `assetDirectoryReference(package.project.id, assetID: assetID)` |
| `MomentsStudioTests/PhotoLibraryTests.swift` | :53 | `assetDirectoryReference(projectID, assetID: assetID)` |
| `MomentsStudioTests/ProjectPackageTests.swift` | :18（多行）、:212、:240 | `originalReference(projectID, assetID:…, fileExtension:…)` |
| `MomentsStudioTests/ProjectStoreTests.swift` | :172（多行） | 同上 |

> 日志里的 5 条错误**全部**在 App target（编译在 App target 就失败，测试 target 未编译）。同一模式下测试 target 另有 **5 处**同类调用（上表 Test 行），按任务“修正每一个 App/测试调用方”的要求一并改正。

**审计结论**（一次性脚本，覆盖全部 `.swift` 调用点，含多行调用与括号配平扫描）：

- 5 个 helper 的**声明全部未变**：`projectReference(_ projectID:)`、`manifestReference(_ projectID:)`、`assetDirectoryReference(_ projectID:assetID:)`、`originalReference(_ projectID:assetID:fileExtension:)`、`derivativeReference(_ kind:projectID:assetID:fileExtension:)`。
- 现在**没有任何** App/测试调用把 `projectID:`（或 `assetID:`）当作首参传入这些 helper。
- `derivativeReference`（首参 `.thumbnail`/`.preview`）、`manifestReference(projectID)`、`projectReference(projectID)` 的调用原本就与声明一致，未改。
- 生成路径字符串**逐字符未变**：`projectReference`/`assetDirectoryReference`/`manifestReference` 函数体与两个插入表达式的文本已由脚本逐条核对，仅标签变化、输出不变。

## 3. 本机执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0，132 对象 / 41 文件引用（App 26 + 单元 11 + UI 3） |
| `python tools/verify_project.py` | **PASS**（40 Swift 文件 5991 行、Sources 覆盖无重无漏、构建设置/scheme/资源 JSON、6 个 UI identifier） |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-03 一致性脚本 | 11/11 通过（声明首参无标签、无调用方传首参标签、5 个函数体与路径字符串未变） |
| 回归：FIX-02 脚本 / 契约脚本 | `STAGE02_FIX02_CHECK` 20/20 PASS、`STAGE02_CONFORMANCE` PASS |
| **diff 空白检查** | `git diff --check` → 无空白错误；Python 扫描 5 个改动文件 → 无行尾空格、无 Tab、无 CRLF |
| 测试计数 | 78 单元 + 4 UI = 82 项，**全部未执行**（本机无 Xcode） |

按任务要求**未新增任何镜像式参数标签测试**：该问题只有真实 Xcode 编译能验证。

## 4. 剩余风险

1. 只有下一次云端编译能确认 5 条 error 消失；本机静态检查无法替代类型检查。
2. 测试 target 的 5 处同类调用同样待真实编译确认（本轮已按同一规则预先改正）。
3. 既有风险不变（见 `.ai/reports/STAGE-02-REPORT.md` §10 与 `.ai/reports/STAGE-02-FIX-02-REPORT.md` §7）：HEIC 用例可能 skip 且不证明 HEIC 支持；真实选择器多选/预览/移除/重启恢复/大字号未验证；12 MP 批次的耗时与内存数字仍需 macOS 实测。

## 5. 未做的动作

未运行云端构建/工作流，未操作账户或计费，未 push/上传，未改动 `.github/workflows/*`、Architect 的 Task/Review/证据文件、序列化字段与路径契约，未开始 Stage03。仅本地读取已下载日志与 fixtures。

## 6. 下一步

Architect 复审后对**当前源码**重跑 macOS 构建与 78 单元 + 4 UI 测试。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER`/`APPROVED`，所有者判断保持 PENDING，9 项验收清单未勾选。
