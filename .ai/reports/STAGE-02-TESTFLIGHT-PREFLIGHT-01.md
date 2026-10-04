# STAGE-02-TESTFLIGHT-PREFLIGHT-01 报告

> 2026-10-04 Architect复核更正：本报告为DSH原始交付记录。Round21实际复现Xcode build号解析异常、major排序不可靠及失败守卫无法阻断always上传；下文原“最高runtime”“拒绝上传”不能代表原工作流整体正确。DSH后续两次TRANSPORT失败，修复由Codex限定补完，证据见 `.ai/reports/STAGE-02-PREFLIGHT-FIX-01.md`。当前Appetize最新31/30、0可用分钟；云端尚未执行。

Stage 02 — 无凭据的 Xcode 26+ 工具链预检（TestFlight 前置检查）
执行者：DeepSeek Harness（Implementation Engineer）
依据：`.ai/tasks/STAGE-02-TESTFLIGHT-PREFLIGHT-01.md`（Architect 授权）、根交接 `项目要求与上下文交接.md`、`AGENTS.md`、`docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md`、`.ai/reviews/STAGE-02-ARCHITECT-ROUND-20.md`、既有 `.github/workflows/stage02-macos.yml`
状态：`READY_FOR_ARCHITECT_REVIEW`（**云端工作流未由 DSH 运行**；Stage02 仍所有者 PENDING、Stage03 禁止）

---

## 1. 背景与边界

所有者要求**暂时搁置 Apple 账户排查**、继续项目。本任务因此不依赖开发者会员、签名或任何凭据：验证现有原生工程能否在 **Xcode 26+ / iOS 26+ SDK** 下编译并运行**原有 80 单元 + 5 UI 测试**，并准备无账户的模拟器交付证据（[Apple 上传要求](https://developer.apple.com/news/upcoming-requirements/)，2026-04-28 起）。文件名保留原任务名以便追溯。

**不包含**（按任务）：新增产品功能、最终品牌设计、公开契约/模型/导航改动、图像管线重写、Expo/EAS/第三方依赖、注册 App ID、改 Apple/GitHub 账户、签名密钥、Apple 上传或付款。**DSH 不运行云端工作流**——按任务第 7 条，云端由 Architect 按既有授权执行与核验。

## 2. 交付内容

| 文件 | 内容 |
| --- | --- |
| `.github/workflows/stage02-testflight-preflight.yml`（新增，唯一一个新工作流） | 手动触发、无凭据的预检：运行时选定 Xcode 26+ / iphoneos SDK 26+ → 无签名 iphoneos Release 构建并校验设备产物 → 在 iOS 26+ 模拟器跑既有 85 项测试 → 断言 85/85/0 失败/0 跳过 → 打包模拟器 App（源码 SHA + 包 SHA256 + 启动截图）→ 证据清单检查 → 上传产物（保留 2 天） |
| `MomentsStudio/README.md` | 新增「无凭据的 Xcode 26+ 工具链预检」小节：如何触发、它验证什么、权限与配额、以及**不**证明什么 |
| `.ai/reports/STAGE-02-TESTFLIGHT-PREFLIGHT-01.md`（本文件） | 实际执行的 Windows 检查、未验证项、缺口与风险 |
| `项目要求与上下文交接.md` | 追加本次交付与状态的真实日志 |

**未改**：任何 Swift 源码、测试、fixture、工程文件、生成器、`tools/verify_project.py`、既有三个工作流；85 个测试方法（80 单元 + 5 UI）与全部断言保持不变。

工作流关键参数（任务第 2 条）：`on: workflow_dispatch`（仅手动）、`permissions: contents: read`、checkout `persist-credentials: false`、`timeout-minutes: 20`、`retention-days: 2`、`if-no-files-found: error`；不使用 `secrets`，不读账户密钥，不做 Apple 上传。

## 3. 实际执行的 Windows 检查

### 3.1 YAML 与工作流静态校验

本机无 Xcode，安装 PyYAML 6.0.3（纯 Python 小包，与此前装 tree-sitter 同一 pip 流程）以做**真实 YAML 解析**：

- `YAML parses`：`stage01-macos.yml`、`stage02-device.yml`、`stage02-macos.yml`、**`stage02-testflight-preflight.yml`** 全部通过。
- `STAGE02_PREFLIGHT_WORKFLOW_CHECK: **PASS**`（44 项），覆盖：仅 `workflow_dispatch`；`permissions == {contents: read}`；`timeout-minutes ≤ 20`；恰好一个 artifact 上传且 `retention-days == 2`、`path == stage02-preflight-artifacts/`、`if-no-files-found: error`；checkout `persist-credentials: false`；**代码中不存在**任何签名/账户/密钥机制（`secrets.`、`xcrun altool`、`notarytool`、`app-store-connect`、`fastlane`、`security import`、`PROVISIONING_PROFILE`、`CODE_SIGN_IDENTITY=`、`-exportArchive`…），且 `CODE_SIGNING_ALLOWED=NO` 恰在两处（设备构建与测试）；**运行时**校验 Xcode 主版本≥26 且 iphoneos SDK 主版本≥26、排除 beta、无合格版本时明确失败；iOS 26+ 模拟器缺失时明确失败；断言 `(85, 85, 0, 0, 0)`；无 skip/retry 机制；复用既有 project/scheme/fixture 生成器而非第二套测试系统；设备产物校验 `iPhoneOS`/`iphoneos`/arm64/`platform IOS` 而非 `IOSSIMULATOR`；证据文件齐备（source-commit / xcode-selection / xcode-candidates / devices.json / destination / 构建与测试日志 / xcresult / test-summary / 附件 / 清单 / 包 SHA）；无环境变量转储；上传前拒绝凭据类与照片类文件；合成 fixture 只写 runner 临时目录、不进产物。

### 3.2 直接运行工作流内嵌的 Python 逻辑（真实脚本，模拟输入）

把工作流里 4 段内嵌脚本**原样抽出**在本机执行，喂入模拟数据，验证分支行为（`STAGE02_PREFLIGHT_LOGIC_CHECK: **PASS**`，13/13）：

| 场景 | 结果 |
| --- | --- |
| 设备列表含 iOS 17.2/18.5/26.2/26.5 | 选中**最高 iOS 26.5** 的 iPhone（CCC）并写入 `destination.txt` 与 `GITHUB_ENV` |
| 只有 iOS 18.5 | **明确失败**，消息含 "iOS 26+"（不跳过、不伪造） |
| 真实 run9 `test-summary.json`（85/85/0/0） | 通过，并写出实际设备 `iPhone 16 Pro / iOS Simulator / iOS 18.5` |
| 篡改为 1 个失败 / 1 个跳过 / 缺 summary / 只有 84 项 | **四种情况全部拒绝**（不掩盖失败、不放过静默丢测试） |
| 证据只含日志与报告 | 通过并生成 `artifact-inventory.txt` |
| 含 `AuthKey.p8` / `photo.jpg` | **两种都拒绝上传** |
| 工具链选择脚本在本机（无 Xcode） | **明确失败**（"refusing to fake the preflight"）且已先写出 `xcode-candidates.txt` |

> **本次检查真实发现并修复了一个工作流缺陷**：证据守卫原先对“文件名+字节数”的清单行做 `endswith(".jpg")` 判断，永远无法命中照片类文件；已改为对**文件路径列表**判断，重跑后通过。这条缺陷只有实际执行该脚本才会暴露，故在此如实记录。

### 3.3 既有工程静态核对（未改动的部分）

- `python tools/verify_project.py` → **PASS**（exit 0）：132 对象、41 文件引用、**40 Swift 文件 6567 行**、Sources 覆盖无重无漏、构建设置/scheme/资源、**11 个 UI 查询标识符**解析（系统项显式豁免）。
- tree-sitter：`TREE_SITTER_PARSED=40 WITH_ERRORS=0`。
- 测试契约：**80 单元 + 5 UI = 85 方法**，未增删改名；工作流断言正是 85/85/0/0/0。
- `git status`：本轮仅新增工作流、改 README 与文档；Swift/工程/工作流（既有三个）均未触碰；`git diff --check` 无空白错误；全仓 markdown 有效 UTF-8。

## 4. 外部事实核对（runner 镜像，非标签推断）

为让工作流有可用的起点，核对了 GitHub 官方 runner 镜像说明（[macos-26 镜像说明](https://github.com/actions/runner-images)）：`macos-26`（image 20260824.0517.1）安装 **Xcode 26.0.1 / 26.1.1 / 26.2 / 26.3 / 26.4.1 / 26.5 / 26.6（默认 26.6）**，提供 **iphoneos 26.0–26.5 SDK** 与 **iOS 26.2 / 26.4 / 26.5** 模拟器（iPhone 17 系列等）。因此工作流选择 `runs-on: macos-26`。

**但按任务要求，工作流不据此断言通过**：它在运行时枚举 `/Applications/Xcode*.app`、逐个取 `xcodebuild -version` 与 `xcrun --sdk iphoneos --show-sdk-version`，把候选与最终选择写进证据，缺条件即失败。镜像内容会随时间变化，这份外部核对只是预期依据，不是证据。

## 5. 未验证项与缺口（必须如实声明）

1. **工作流未运行**：DSH 未触发任何云端运行、未下载新产物。**没有任何 Xcode 26/macOS 执行结果**；本报告不含构建或测试通过结论。
2. **D1 风险 — iOS 26 上的系统选择器可能改变层级**：现有完整流程 UI 测试的定位来自 **iOS 18.5** 的原生层级（`ScrollView "content_scroll_view"`、`Image "PXGGridLayout-Info"`、`NavigationBar "Photos"`、`Button "Add"`）。iOS 26 若改变这些标识符，测试会**带诊断显式失败**（这是刻意设计），需要 Architect 依据新原生 dump 限定修正——不得用无范围回退或跳过掩盖。
3. **D2 风险 — 新工具链新告警/弃用**：Xcode 26 首次编译可能产生新的警告或弃用提示；本任务不预先掩盖，失败/告警交由 Architect 定位决定。
4. **D3 风险 — 时间预算**：macos-15 上完整一轮为 8m26–9m20；本次增加一次设备 Release 构建，`timeout-minutes: 20` 应有余量但未实测。
5. **测试覆盖缺口（按任务第 8 条如实列出，本任务不扩充测试体系）**：现有 85 项**不覆盖** ① 同会话重启恢复（terminate/relaunch 后项目与照片恢复）、② 深色模式、③ 大字号/辅助功能字号。这些仍需真实交互验收。
6. **仍未验证**：真机、iPad、VoiceOver、精确最低 iOS 17.0 覆盖、最终品牌视觉；**新 SDK 下系统控件外观差异须实际视觉检查**（不得用兼容开关隐藏）。
7. Appetize 免费额度 **30/30、0 分钟**（按所有者指令暂停等重置）；本任务**未消费**、未上传、未改账户。

## 6. 交付与下一步

- 交付物见 §2；DSH 已停止开发，停在 `READY_FOR_ARCHITECT_REVIEW`。
- 期望的云端证据（Architect 手动触发后）：`source-commit.txt`、`xcode-selection.txt`（所选 Xcode 路径/完整版本/iphoneos SDK 版本）、`xcode-candidates.txt`、`devices.json`/`destination.txt`、`xcodebuild-device.log` 与 `macho-build-version.txt`、`xcodebuild-test.log`、`Stage02-Preflight.xcresult`、`test-summary.json`、`test-device.txt`、`MomentsStudio-simulator.zip` + `app-sha256.txt` + `app-source-sha.txt` + `launch.png`、`artifact-inventory.txt`。
- 判定标准：作业成功 ⇔ 找到合格工具链、设备 Release 构建通过、既有 85 项测试在 iOS 26+ 模拟器上 **85/85、0 失败、0 跳过**。
- 本预检**替代不了**：最低系统覆盖、真机/iPad/VoiceOver、深色与大字号、所有者交互验收；Stage02 所有者判断仍 PENDING，Stage03 未授权。
