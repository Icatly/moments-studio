# STAGE-02-LARGE-TEXT-PREFLIGHT-01 报告

Stage02 最大辅助字号配置（仅实施 + 本地验证，**尚未运行**）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-LARGE-TEXT-PREFLIGHT-01.md`、`run-37225749574` 本地已取回的 `simctl-ui-help.txt` / `content-size-current.txt`、Round30
状态：`READY_FOR_ARCHITECT_REVIEW`（**DSH 未做任何 macOS/Xcode/云端执行**；Apple/付费/Stage03 禁止）

---

## 1. 范围与交付

| 项 | 内容 |
| --- | --- |
| 允许改动 | 仅 `.github/workflows/stage02-testflight-preflight.yml` + 本报告 + 交接日志 |
| 实际改动 | 该 workflow：新增一个 `workflow_dispatch` 布尔输入 + 两个条件步骤（应用 / 还原） |
| 未改 | 产品 Swift、UI 测试、工程与 `tools/`、公开契约、依赖、**85 方法/门禁**、`timeout-minutes: 20`、证据保留 2 天、无 cache、guard 与其上传条件 |

**默认行为不变**：与 HEAD `01bc584` 最终逐行 diff 为 **+96 / −0**（纯新增，无任何既有行被删改；Architect已核对）；`large_text` 默认 `false`，两个新步骤都不会运行，`content_size` 不被触碰。

## 2. 新增内容

### 2.1 输入

```yaml
on:
  workflow_dispatch:
    inputs:
      large_text:
        description: "Run Stage 02 at the maximum accessibility text size (one-off simulator content size; default off)"
        type: boolean
        default: false
```

描述明确这是**一次性模拟器环境核验**，不是给产品加开关（产品侧无任何 flag）。

### 2.2 应用步骤（`if: inputs.large_text`，位于 fixture seed 之后、测试之前）

1. 帮助必须精确整行`exit_status=0`，目标值`accessibility-extra-extra-extra-large`须用`grep -qF`在本次实见帮助中检索到，否则硬失败，不设置没有被证据支持的类别。
2. 只读当前类别，记录 `previous_content_size` / `previous_exit`，保存到 `$ARTIFACTS/content-size-original.txt` 并导出 `STAGE02_ORIGINAL_CONTENT_SIZE` 到 `GITHUB_ENV` 供还原使用。
3. **拒绝非法值**：当前类别必须落在**实见合法集合**内（12 个类别，见 §3），`unknown`/`unsupported` 被明确拒绝——非法值不设置、直接失败。
4. 设置目标类别 → **实际读回** → 要求**精确同值**，不匹配即硬失败。
5. 记录 `command` / `set_exit` / `readback` / `readback_exit` 到 `content-size-applied.txt`；`set -euo pipefail`，**任何失败不冒称已应用**（无 `|| true` 之类掩盖）。

### 2.3 还原步骤（`if: always() && inputs.large_text && env.STAGE02_ORIGINAL_CONTENT_SIZE != ''`）

- 位置：测试、85 断言步骤与打包步骤**之后**、**证据 guard 与上传之前**。
- 行为：用保存的原值还原 → **实际读回** → 要求**精确同值**；记录到 `content-size-restored.txt`；未成功即如实失败。
- 还原失败/测试失败不改变原85门禁与诊断导出；guard为`if: always()`，上传仍精确条件`always() && steps.evidence_guard.outcome == 'success'`，不得把guard失败的证据自动上传。

## 3. 证据基础（本地实读，非猜测）

- `.ai/build/downloads/run-37225749574/simctl-ui-help.txt`（1,790 B）明确列出：
  - `Standard sizes: extra-small, small, medium, large, extra-large, extra-extra-large, extra-extra-extra-large.`
  - `Extended range sizes: accessibility-medium, accessibility-large, accessibility-extra-large, accessibility-extra-extra-large, accessibility-extra-extra-extra-large.`
  - `Other values: unknown, unsupported.`；设置形式为 `content_size [increment | decrement | desired_size]`。
- `.ai/build/downloads/run-37225749574/content-size-current.txt`（20 B）：`large`，`exit_status=0`。
- 因此 workflow 的合法集合**取自该帮助文本**（12 个值），本机 harness 已核对「workflow 集合 == 帮助解析集合」、`unknown`/`unsupported` 不在可设置集合、`accessibility-extra-extra-extra-large` 为列出的最大类别、当前值 `large` 合法。

## 4. 本机（Windows）实际执行的检查

### 4.1 直接执行两段真实脚本（Git Bash + `xcrun` stub）——`STAGE02_LARGE_TEXT_BASH_CHECK: PASS`（**18/18**）

本机 Git Bash 位于 `C:\Program Files\Git\bin\bash.exe`（不在 PATH 上，先前"无 bash"的初判已更正）。用它执行**从 workflow 抽出、未经改写**的两段脚本，`xcrun` 用 stub 替代：

| 场景 | 结果 |
| --- | --- |
| 正常 `large` → 设最大值 → 精确读回 | rc=0，写入 `content-size-applied.txt` 与 `STAGE02_ORIGINAL_CONTENT_SIZE=large` |
| **Architect 实测发现的缺陷：`original='small medium'`** | **现在 rc≠0 且不写 GITHUB_ENV**（旧的 substring `case` 会误接纳） |
| `unknown` / `unsupported` / 空值 | 全部 rc≠0 |
| 初始读取失败 / 设置失败 / 读回失败 / 读回值不一致 | 全部 rc≠0（设置失败时**原值已先保存**，故意保留以便还原） |
| help 无 `exit_status=0`（缺失或为 1） | 全部 rc≠0（**非零采集不得当能力证据**） |
| help 不含合法最大值 | rc≠0 |
| 还原：成功 / 还原设置失败 / 还原读回不一致 | rc=0 / rc≠0 / rc≠0，成功时写出 `content-size-restored.txt` |

### 4.2 静态与差异校验——`STAGE02_LARGE_TEXT_CHECK: PASS`（**39/39**）

- **结构与差异**：YAML 可解析；**6 段内嵌 Python 全部编译通过**；与 HEAD `01bc584` diff **+96/−0**（纯新增，无删改）。
- **输入与触发**：`large_text` 为 boolean、默认 `false`、描述含"one-off simulator content size"；仍为仅 `workflow_dispatch`。
- **位置**：应用步骤在 fixture seed 之后、测试之前；还原步骤在证据 guard/上传之前。
- **条件语义**：应用 `inputs.large_text`（true→运行 / false→跳过）；还原在 (false,"")、(true,"")、(true,"large")、(false,"large") 下为 跳过/跳过/运行/跳过。
- **精确类别匹配**：`case "$original" in` 为 **12 值精确 alternation**，不含 `*" $original "*` 之类的 substring 形式。
- **help 能力门槛**：要求 `grep -qx 'exit_status=0'` 整行命中，且用 `grep -qF` 固定字符串检索合法最大值。
- **默认路径不触碰字号**：全文件恰好 2 处「设置」调用，且都在两个条件步骤内；既有**只读**探测行未改。
- **失败控制**：两个新步骤均以 `set -euo pipefail` 开头；无 `|| true`；应用与还原都要求精确读回，失败如实非零。
- **证据与边界**：记录 `content-size-applied.txt`/`content-size-restored.txt`/`content-size-original.txt`；85 契约、`timeout-minutes: 20`、2 天保留、guard 与上传条件未变；`uses:` 数量未增；文件恢复**纯 ASCII** 且无 CRLF。
- **工程范围**：`tools/verify_project.py` **PASS**；tree-sitter `40 WITH_ERRORS=0`；本任务只改该 workflow（`MomentsStudio/`、`tools/` 未改动）；`git diff --check` 干净。

### 4.3 本轮修正（Architect 实测复审）

1. **类别校验改为精确单一类别**：原 `case " $LEGAL_CATEGORIES " in *" $original "*)` 是 substring 匹配，`original='small medium'` 会被误接纳并写入 `GITHUB_ENV`（Architect 用 Git Bash + stub 实测复现）。现改为 `case "$original" in extra-small|small|medium|large|extra-large|extra-extra-large|extra-extra-extra-large|accessibility-medium|accessibility-large|accessibility-extra-large|accessibility-extra-extra-large|accessibility-extra-extra-extra-large) ;;`，整值匹配，`LEGAL_CATEGORIES` 变量随之移除。
2. **help 能力门槛**：设置前要求捕获的 help 文件含**精确整行** `exit_status=0`（非零或缺失即失败、不当作能力证据），并以固定字符串精确检索合法最大值。
3. 顺带修正：新增注释中曾出现 Unicode 省略号/破折号，已改回 ASCII，工作流恢复纯 ASCII。

## 5. 未执行 / 限制（如实声明）

1. **没有 macOS、没有 Xcode、也没有云端执行**：两个新步骤**从未在真实 runner 运行**，**最大字号配置尚未执行**，本报告不声明任何大字号通过；4.1 是本机 Git Bash + stub 的模拟执行（验证脚本逻辑与失败分支），不是 macOS 验证。
2. 本机初判"无 bash"已更正：Git Bash 可用且已用于 4.1；但 `xcrun` 是 stub，**真实 `simctl` 语义仍只在 macOS 上验证**。
3. 环境证明方式：真实运行时的证据是 CLI「设置命令 + 精确读回」日志，**不是测试内部的字号断言**；最大字号下界面是否可操作、视觉是否符合预期，仍待云端原日志与 PNG 审查。
4. 第五轮 run37227995563（默认配置）正在真实执行；**DSH 未查询、未触发、未取消**该运行，也未修改已复审推送（`01bc584`）的 FIX-05 内容。
5. 本任务未改字号默认值、未新增测试方法/断言、未改 source 契约、未只跑选定 UI；最大模式仍是同一套 **80 单元 + 5 UI（87 条 body 断言）** 在真实最大字号下完整运行，既有 `keepAlways` 截图与 `INTERACTION-VERIFY` 保留。
6. 预算：默认模式两个步骤均跳过 → **不增加运行时间**；大字号模式新增 <10 秒，但**需要单独一轮授权运行**；具体额度按 Round30 与第五轮结果核算，本轮不预判。

## 6. 条件写法说明（供 Architect 确认）

- 本轮按任务给定写法：应用步骤 `if: inputs.large_text`；还原步骤 `if: always() && inputs.large_text && env.STAGE02_ORIGINAL_CONTENT_SIZE != ''`。
- 依据：`type: boolean` 的 dispatch 输入在 `inputs` 上下文是真布尔值；`env.*` 可引用前序步骤写入 `GITHUB_ENV` 的变量。
- 若你希望更显式，最小改动是 `inputs.large_text == true`（或对字符串输入用 `github.event.inputs.large_text == 'true'`）；同样是一行、无需新依赖。**未擅自改动**，等你确认。

## 7. 下一步

Architect 复审本报告与 workflow diff → 待第五轮结果与费用核算后决定是否授权**单次** `large_text=true` 运行（源码推送需授权）→ 核对 `content-size-applied/restored` 日志、85/85 与最大字号下的截图/日志；最大字号的视觉与可操作性仍由你审查。

Architect最终核对：DSH03:36交付并停止。独立13项完整shell本地stub检查通过，全部原workflow step内容逐字保留、6个内嵌Python/YAML解析、默认false与20min不变，工程diff仅workflow，+96/0。报告中初稿+87、grep及upload条件已纠正，未改运行行为。当前最大字号仍未native执行；待第五轮结果及费用核验后由Architect按今天已授权范围执行，无需再次请求所有者Stage02逐项审批。
