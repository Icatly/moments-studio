# STAGE-02-FIX-04-REPORT.md

Stage 02 — Architect Fix 04（第三次 macOS 运行：Swift 前端崩溃）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-ARCHITECT-FIX-04.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-07.md`、证据 `.ai/build/downloads/run-37133937308/evidence/xcodebuild.log`
状态：`READY_FOR_ARCHITECT_REVIEW`（未通过 Review、未交所有者验收；Stage03 未授权）

---

## 1. 本次真实结果（不是普通诊断）

- 源码 `70721cf13362475bfea5648b26241b4ea1df2c66`，run [37133937308](https://github.com/Icatly/moments-studio/actions/runs/37133937308)，**编译失败、0 个测试执行、无运行包**。
- 日志（705 行）中**没有任何 `error:` 行**；失败形式是 Swift 前端崩溃：

```text
:617  SwiftCompile normal arm64 Compiling PhotoImportModelTests.swift, PhotoLibraryTests.swift, ProjectModelTests.swift, ProjectPackageTests.swift (in target 'MomentsStudioTests')
:618  Please submit a bug report ... and include the crash backtrace.
:623  3. While evaluating request TypeCheckSourceFileRequest(source_file ".../ProjectPackageTests.swift")
:624  4. While evaluating request TypeCheckFunctionBodyRequest(... ProjectPackageTests.testDecodingRejectsInvalidDimensionsOrientationAndContentType() ...)
:630  4  swift-frontend ... (anonymous namespace)::ActorIsolationChecker::walkToExprPre(swift::Expr*) + 2684
:695  Testing failed:
:696  Command SwiftCompile failed with a nonzero exit code
:699  ** TEST FAILED **
:705  (2 failures)
```

- 崩溃只发生 **1 次**（`Please submit a bug report` 出现 1 次），失败命令为该测试编译批次；日志尾部为 `** TEST FAILED **`，**没有** `** BUILD FAILED **`。
- **App target 已走到链接**：`:687 Ld .../MomentsStudio.app/MomentsStudio.debug.dylib normal (in target 'MomentsStudio')`。这只能说明 App target 本轮完成了编译与链接，**不能**据此宣称整体构建成功（测试 target 编译失败、测试 0 执行、无运行包）。

## 2. 触发点与修正（仅测试数据表达式的显式类型）

原代码 `ProjectPackageTests.swift:168`（内联、无显式类型、`value` 混合 Int 与 String）：

```swift
for (key, value) in [("pixelWidth", 0), ("pixelHeight", -5), ("orientation", 9), ("contentType", "")] {
```

修正后（同一文件 :168–186）：

```swift
// Explicitly typed on purpose: these four values mix Int and String
// (`Any`), and an untyped heterogeneous tuple literal in this loop sent
// the Swift 6.1.2 frontend's ActorIsolationChecker into a crash during
// TypeCheckFunctionBodyRequest (run 37133937308).
let cases: [(key: String, value: Any)] = [
    ("pixelWidth", 0),
    ("pixelHeight", -5),
    ("orientation", 9),
    ("contentType", ""),
]

for (key, value) in cases {
    ...
}
```

- **四个值原样保留**：`pixelWidth 0`、`pixelHeight -5`、`orientation 9`、`contentType ""`（顺序不变）。
- **每个用例的断言完全不变**：仍构造 `root`/`photos`、`photos[0][key] = value`，仍调用 `assertInvalidPackage { try self.decode(root) }`。
- 循环改为遍历显式类型的本地 `cases`，元组字段名明确（`key`/`value`）。

**变更规模**：1 个文件、`12 insertions(+), 1 deletion(-)`（改动仅为该函数的数据表达式与其说明注释）。

**触发点是推断结论**：由崩溃堆栈的函数指针与源码定位得出，未在本机构造最小复现、也未证明编译器根因；**该候选修复是否有效只能由下一次真实云端运行判定**。

## 3. 同类混合字面量审计

一次性脚本扫描全部 `MomentsStudioTests/*.swift`：

- 内联（无类型标注）异质元组字面量：修正前 **仅 1 处**（即上述 :168），修正后 **0 处**。
- 其余元组数组仅 1 处：`ProjectPackageTests.swift:195 let cases: [(field: String, value: String)] = [` —— 已有显式标注且值类型同质，按任务要求**未改**。
- 生产代码未扫描到同类模式改动需求；按任务授权范围**未改任何生产代码**。

## 4. 本机执行的检查（Windows，无 Xcode）

| 检查 | 结果 |
| --- | --- |
| `python tools/generate_xcodeproj.py` | exit 0（132 对象 / 41 文件引用，App 26 + 单元 11 + UI 3） |
| `python tools/verify_project.py` | **PASS**（40 Swift 文件 6002 行；Sources 覆盖、构建设置/scheme/资源 JSON、6 个 UI identifier） |
| tree-sitter 语法 | `TREE_SITTER_PARSED=40 WITH_ERRORS=0` |
| FIX-04 一致性脚本 | 6/6：显式类型、四值齐备且有序、遍历本地数组、断言不变、无残留未类型化内联元组、函数仍唯一 |
| 回归：FIX-03 脚本 / 契约脚本 | `STAGE02_FIX03_CHECK` PASS（标签修正未被破坏）、`STAGE02_CONFORMANCE` PASS |
| **diff / 空白检查** | `git diff --check` → 无空白错误；`git diff --stat` → 1 文件 12+/1− |
| 测试计数 | 78 单元 + 4 UI = 82 项，**全部未执行**（本机无 Xcode，且前端崩溃类问题本机无法复现） |

未新增测试、未删除或跳过任何既有测试（计数仍为 78 + 4）。

## 5. 剩余风险

1. 该修复未经验证；若前端崩溃另有触发因素，下一次云端运行仍可能失败——只改类型标注不会改变测试语义，故即使无效也不会引入新的行为风险。
2. 测试 target 其余文件（`PhotoLibraryTests`、`PhotoImportModelTests`、`LargePhotoBatchTests`、`UI tests`）本轮只部分编译，是否存在同类前端崩溃触发点需真实编译逐批确认。
3. App target 本轮编译并链接成功是进展，但**不等于**构建通过或测试通过。
4. 既有风险不变（见 `.ai/reports/STAGE-02-REPORT.md` §10、FIX-02 报告 §7）。

## 6. 未做的动作

未改生产代码/actor 隔离/SDK/编译器/语言版本/部署目标/构建设置/工作流；未新增或删除测试；未使用 actor 抑制或 unsafe 逃逸；未运行云端构建或工作流、未操作账户、未 push/上传；未开始 Stage03。仅本地只读读取已下载日志与 fixtures。

## 7. 下一步

Architect 复审后对**当前源码**重跑 macOS 构建与 78 单元 + 4 UI 测试。DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`；未标记 `WAITING_FOR_USER`/`APPROVED`，所有者判断保持 PENDING，9 项验收清单未勾选。
