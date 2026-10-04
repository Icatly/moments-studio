# STAGE-02-DARK-ENV-PREFLIGHT-01 报告

Stage02 真实深色环境预检补充（仅实施 + 本地验证，**尚未在 native 执行**）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-DARK-ENV-PREFLIGHT-01.md`、Round31、`run-37227995563` 本地已取回的 `simctl-ui-help.txt`（`exit_status=0`）
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 macOS/Xcode/云端执行**；账户/付费/Stage03 禁止）

---

## 1. 问题与依据

- 第五轮 run37227995563 / source `01bc584` 实际 **85/85/0/0/0 成功**（原生取消保留、确认移除、再导入、同 project/asset 重启均真实通过，artifact SHA 已匹配）。
- 但 Architect 实际查看三张标记 `dark` 的 PNG，**全部仍为浅色**：测试内 `XCUIDevice.shared.appearance = .dark` 的调用不能作为**渲染**证据。产品本身**没有** `preferredColorScheme` / `UIUserInterfaceStyle` / `overrideUserInterfaceStyle`；**不断言** Apple regression 或产品 bug。
- 改用**原生环境控制** `xcrun simctl ui <device> appearance dark`：本地 `run-37227995563/simctl-ui-help.txt` 明确列出 `appearance` 与 `appearance [light | dark]`（`exit_status=0`），Apple Xcode 11.4 release notes 亦公开该命令（https://developer.apple.com/documentation/xcode-release-notes/xcode-11_4-release-notes ）。与本轮已复审的**最大辅助字号**配置合并为单次运行使用；本机 Windows **不冒称** native 执行。

## 2. 改动（仅 `.github/workflows/stage02-testflight-preflight.yml`）

| 新增 | 内容 |
| --- | --- |
| 输入 | `dark_appearance`：`type: boolean`、`default: false`、描述写明是**一次性模拟器环境**；默认 false 完全不改 appearance |
| 应用步骤（`if: inputs.dark_appearance`，fixture 之后 / tests 之前） | ① 能力门槛：捕获的 help 必须含**整行** `exit_status=0`，且必须列出 `appearance [light | dark]`；② 只读当前值并保存完整命令/exit/value 到 `appearance-original.txt`；③ **只接受精确 `light` 或 `dark`**（整值匹配，拒绝 `unknown`/`unsupported`/`light dark` 等）；④ 保存 `STAGE02_ORIGINAL_APPEARANCE` 到 `GITHUB_ENV`；⑤ 设 `dark` 并**精确读回 `dark`**、两个 exit 均须 0，否则硬失败；⑥ `appearance-applied.txt` 记录原值/目标/命令/各 exit/读回。**不改 App 或 launch 参数、不改系统安全设置**，只作用于一次性 runner 模拟器 |
| 持续核验步骤（`if: always() && (inputs.large_text \|\| inputs.dark_appearance)`，tests/85 门禁之后、app 打包之前） | **只核实际被请求的值**：`large_text` → `content_size` 精确 `accessibility-extra-extra-extra-large`；`dark_appearance` → `appearance` 精确 `dark`；全部 exit 0，不成立即硬失败；记录 `environment-after-tests.txt`。**环境读回仍不能替代 PNG 审查** |
| 还原步骤（`if: always() && inputs.dark_appearance && env.STAGE02_ORIGINAL_APPEARANCE != ''`，guard/upload 之前） | 还原原 appearance，**精确读回**须等于原值、两个 exit 均 0，保存 `appearance-restored.txt`；失败保留诊断并如实 failure（不忽略错误、不自动重试）。既有最大字号还原步骤**原样保留** |

**未改**：产品 Swift、UI 测试（`Stage02ImportUITests.swift` 与 HEAD **逐字相同** → 87 条 body 断言 / 85 方法不变）、工程与 `tools/`、guard 与其上传条件、`timeout-minutes: 20`、证据保留 2 天、无 cache；与 HEAD `01bc584` 逐行 diff **+228 / −0**（纯新增，**所有旧步骤原文不变**，含已复审的最大字号两步）。

## 3. 本机（Windows）实际执行的检查

### 3.1 直接执行三段真实脚本（Git Bash + `xcrun` stub）——`STAGE02_DARK_ENV_BASH_CHECK: PASS`（**26/26**）

本机 Git Bash（`C:\Program Files\Git\bin\bash.exe`）执行**从 workflow 抽出、未经改写**的三段脚本；stub 同时支持 `content_size` 与 `appearance` 的读/设/读回与失败注入；help 取自 `run-37227995563/simctl-ui-help.txt`（确认含 `appearance [light | dark]` 与 `exit_status=0`）。

| 场景 | 结果 |
| --- | --- |
| 正常 `light` → 设 `dark` → 精确读回 | rc=0，写 applied/original 证据并导出 `STAGE02_ORIGINAL_APPEARANCE=light` |
| **非法组合 `light dark`** / `unknown` / `unsupported` / 空值 | 全部 rc≠0，且**不写** `GITHUB_ENV` |
| 读取当前值失败 / 设置失败 / 读回失败 / 读回不是 `dark` | 全部 rc≠0（设置失败时原值已先保存，便于还原） |
| help 无 `exit_status=0`（=1）/ help 未列出 `appearance [light \| dark]` | 全部 rc≠0 |
| 还原：成功 / 还原失败 / 还原读回不一致 | rc=0 / rc≠0 / rc≠0，成功时写 `appearance-restored.txt` |
| 持续核验：仅 large（max）→ 通过；仅 large（被改回）→ 失败；仅 dark（dark）→ 通过；仅 dark（light）→ 失败；两者都请求且都在效 → 通过；两者都请求但 appearance 错 → 失败；读取失败 → 失败 | 与预期一致，并写 `environment-after-tests.txt` |

> stub 是本机模拟：证明的是**脚本逻辑与失败分支**，不是 native `simctl` 行为。

### 3.2 静态校验——`STAGE02_DARK_ENV_CHECK: PASS`（**41/41**）

- YAML 可解析；6 段内嵌 Python 全部编译；与 HEAD diff **+228/−0**（无删改）；**UI 测试未被改动**。
- 输入与触发：`large_text` 仍在且默认 false；`dark_appearance` boolean 默认 false；描述写明一次性模拟器环境；仍仅 `workflow_dispatch`。
- 位置：dark 应用步骤在 fixture 之后、tests 之前，且与最大字号应用步骤相邻；持续核验在 85 门禁之后、打包之前；两个还原步骤都在 guard/upload 之前。
- 条件语义：dark 应用 = `inputs.dark_appearance`；持续核验在 (large,dark) = (F,F)/(T,F)/(F,T)/(T,T) 四种组合下为 跳过/运行/运行/运行；dark 还原在 (dark=False,"")/(True,"")/(True,"dark")/(True,"light") 下为 跳过/跳过/运行/运行。
- appearance 取值：`case "$original" in` 为**整值** `light|dark`（无 substring 形式），非法值硬失败；help 门槛为 `grep -qx 'exit_status=0'` 与 `grep -qF 'appearance [light | dark]'`。
- 失败控制：三段均 `set -euo pipefail`、无 `|| true`、无重试；应用/还原/持续核验都要求精确读回。
- 边界：85 契约、`timeout-minutes: 20`、2 天保留、guard 与上传条件、`uses:` 数量均未变；工作流纯 ASCII、无 CRLF。
- 工程：`tools/verify_project.py` **PASS**；tree-sitter `40 WITH_ERRORS=0`；本任务只改该 workflow（`MomentsStudio/`、`tools/` 未改动）；`git diff --check` 干净。

## 4. 未执行 / 未验证（如实声明）

1. **没有 macOS、没有 Xcode、没有云端执行**：三段新脚本**从未在真实 runner 运行**；3.1 是本机 Git Bash + stub 的模拟执行。
2. **深色视觉仍未验证**：本改动只能证明「环境被设为 dark 且读回 dark」。**PNG 像素/可操作性必须由 Architect 在新的真实运行中对原始证据判定**——本报告**不声明深色通过**，也不把 setter 日志当渲染证据。
3. 最大字号 + 深色合并运行、原始 PNG、源码与包 SHA 由 Architect 对新原始证据判断；本轮不重复旧的默认 85 检查结论。
4. 已知限制（记录，不擅自处理）：`UIKitToolbar` 运行告警根因尚未确立，**未**修改纯 SwiftUI toolbar。
5. 未提交/推送/触发/查询云端、未付费、未改账户；Appetize 31/30（0 分钟）；Apple 暂停；Stage02 今天免逐项审批；本人亲自操作未发生；Stage03 不启动。
6. 预算：默认模式三段全部跳过 → **不增加运行时间**；深色/最大字号模式新增 <10 秒仅为DSH估计（未native计时），实际耗时/额度待真实运行核对。

## 5. 下一步

Architect 复审本报告与 workflow diff → 单次 `large_text=true` + `dark_appearance=true` 真实运行（今天Stage02推送/运行已授权，无需重复请求）→ 核对 `appearance-applied/original/restored`、`environment-after-tests.txt`、85/85、以及**原始 PNG 的深色像素**与最大字号下的可操作性。
