# Moments Studio — 构建、运行与测试

Stage 01 基础工程及 Stage 02 照片管线的 iOS 应用工程（Swift / SwiftUI，iPhone 优先，可扩展到 iPad）。

## 环境要求

| 项 | 要求 |
| --- | --- |
| macOS | 必需（Xcode 只能在 macOS 上运行） |
| Xcode | 最低设计基线15.4（使用iOS17 API）；实际验证16.4与26.6；15.4尚未验证 |
| iOS Deployment Target | 17.0（依据见下表） |
| 第三方依赖 | 无（只使用 Apple 原生框架） |
| 设备 | iPhone 模拟器或真机；UI 测试需要模拟器 |

Deployment Target 取 17.0 的依据：`NavigationStack` 需要 iOS 16；`@Observable`（Observation 框架）与 `@Environment(Type.self)` 需要 iOS 17；17.0 是同时满足这些能力的最低版本。若要降低到 iOS 16，需要把状态对象改回 `ObservableObject`，属于契约改动，需 Architect 决定。

## 打开工程

```bash
cd MomentsStudio
open MomentsStudio.xcodeproj
```

在 Xcode 中选择 scheme `MomentsStudio`，选择任意 iPhone 模拟器，按 ⌘R 运行。

## 命令行构建

```bash
cd MomentsStudio

# 查看 scheme 与可用模拟器
xcodebuild -list -project MomentsStudio.xcodeproj
xcrun simctl list devices available

# 构建（模拟器）
xcodebuild build \
  -project MomentsStudio.xcodeproj \
  -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# 若本机没有 iPhone 16 模拟器，请把 name 换成上面列出的任一 iPhone 机型
```

## 命令行测试

```bash
cd MomentsStudio

# 单元测试 + UI smoke test（使用 scheme 的 Test Action）
xcodebuild test \
  -project MomentsStudio.xcodeproj \
  -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# 只跑单元测试（更快）
xcodebuild test \
  -project MomentsStudio.xcodeproj \
  -scheme MomentsStudio \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:MomentsStudioTests
```

UI 测试会启动一次真实 App，因此比单元测试慢；若模拟器环境异常，UI 测试可能失败，请先确认 `xcrun simctl` 能正常启动模拟器。

## 无凭据的 Xcode 26+ 工具链预检（云工作流）

从 2026-04-28 起，向 App Store Connect 上传需要 **Xcode 26+ 与对应的 iOS 26+ SDK**（[Apple 要求](https://developer.apple.com/news/upcoming-requirements/)）。本工程用一个**手动触发、完全不需要 Apple 账户或签名凭据**的 GitHub Actions 工作流提前验证工具链兼容性：

- 工作流文件：`.github/workflows/stage02-testflight-preflight.yml`
- 触发方式：GitHub → Actions → **Stage 02 Xcode 26 toolchain preflight** → Run workflow（仅 `workflow_dispatch`）
- 可选环境输入：`large_text` 和 `dark_appearance` 均默认关闭。开启时只改变此次模拟器的最大辅助字号或深色外观，记录原值、设置/读回、测试后的持续读回与还原。仍运行全部85项；设置日志和测试通过须结合原始截图判断，不能单独证明实际主题或大字号可用。
- 它做什么：
  1. 在 runner 上**实际枚举**已安装的 Xcode，选择一个正式版 **Xcode 26+ 且 iphoneos SDK 26+** 的安装，记录路径与完整版本（排除 beta；不从 runner 标签推断版本；找不到就**明确失败**）。
  2. 用该工具链对现有 scheme 做**无签名 iphoneos Release 构建**，并校验产物确实是设备构建（`iPhoneOS`/`iphoneos`/arm64、`platform IOS` 而非 `IOSSIMULATOR`）。
  3. 核对主机 arm64，按完整系统版本选择该 scheme 实际可用的 **arm64 iOS 26+ 模拟器**，运行**现有 80 单元 + 5 UI = 85 项测试**（找不到符合条件的 destination 就明确失败，不跳过、不重试、不改测试）。
  4. 从原生 `test-summary.json` **断言 85/85 通过、0 失败、0 跳过、0 预期失败**；同时核对实际 iOS 26+、Simulator、arm64 和选中设备 UDID，保留实际设备证据。
  5. 测试通过后打包模拟器 App（`MomentsStudio-simulator.zip`），附源码 SHA（`app-source-sha.txt`）与包 SHA256（`app-sha256.txt`），并抓一张启动截图。
  6. 上传前检查证据清单，上传明确依赖守卫成功；遇到凭据类文件或照片类文件拒绝上传，安全的失败构建/测试日志仍可保留。产物目录只放日志、xcresult、报告与包。
- 权限与配额：`permissions: contents: read`、`persist-credentials: false`、`timeout-minutes: 18`、产物保留 2 天；**不上传 Apple、不读取任何账户密钥、不消费 Appetize**。
- 它会证明什么、不会证明什么：证明“现有工程在该 Xcode/SDK 与 iOS 26 模拟器上仍能编译并通过原有 85 项测试”。**不**证明真机、iPad、VoiceOver、最低 iOS 17 覆盖、最终视觉，也不替代所有者的交互验收。新 SDK 可能改变系统控件外观，须另做实际视觉检查。

## 真机运行

1. Xcode → 选中 `MomentsStudio` target → Signing & Capabilities → 选择你的 Team。
2. 若 Bundle ID `com.example.MomentsStudio` 已被占用，改成你自己的反写域名。
3. 连接 iPhone，选择该设备后 ⌘R。
4. 当前 `AppIcon.appiconset` 为空占位，真机与提审前需要替换（见根目录 `APP_STORE_REQUIREMENTS.md`）。

## 工程文件（.xcodeproj）如何维护

本工程最初在 Windows 上编写（无 Xcode），因此 `MomentsStudio.xcodeproj` 由脚本确定性生成：

```bash
# 仓库根目录执行
python tools/generate_xcodeproj.py   # 依据源码目录重新生成工程文件
python tools/verify_project.py       # 校验工程引用完整性、构建设置、scheme、源码静态语法
```

维护规则：

- **在用 Xcode 添加文件之前**：在磁盘上增删 Swift 文件后重新运行生成脚本即可。
- **一旦开始在 Xcode 里管理工程**（增删文件、改签名）：不要再运行生成脚本，否则会覆盖 Xcode 的改动；此时可以删除 `tools/`。
- `verify_project.py` 随时可运行，不会修改任何文件；它只能做结构校验，**不能替代 `xcodebuild build` / `xcodebuild test`**。

## 当前限制

- **Stage02当前真实证据（2026-10-05）**：第五轮run37227995563/source01bc584，macOS26.6.2/Xcode26.6/SDK26.5/iPhone17Pro iOS26.5 arm64实际85/85、0失败0跳过；原生导入/预览/Done/取消保留/确认移除/再导入及同project与asset terminate/launch恢复通过。有效模拟器ZIP与源码/SHA已核。dark标签截图仍浅色，深色视觉未通过；第六轮run37230253288/source64fb192实际84/85失败；最大辅助字号+真实深色设置/持续读回/还原通过，原始录屏抽帧确认实际环境。系统照片Private Access说明溢出遮住网格，Home主按钮文本截断；FIX06第七轮run37248700016/source590ccf3实测84/85；关闭说明/选图/导入计数1成功，屏下图库thumbnail AX未出现，Home原生PNG仍截断。FIX07仅本地修图库准备与Home显式Text，新版未native验证；旧账单推余$0.464不足完整下一轮，未付费。详见[第五轮Review](../.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-05.md)、[第六轮记录](../.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-06.md)与[当前验收事实](../.ai/acceptance/STAGE-02.md)。
- 旧Xcode16.4/iOS18.5原85通过和Appetize17.2 HEIC加载预览证据仍有效；17.2 Done/重启未完成。Appetize31/30、0免费分钟；Apple账户暂停，不支付。真机/iPad/VoiceOver/精确17.0/Xcode15.4尚未验证。今天所有者委托Stage02免逐项审批技术验收，本人亲自操作未发生；技术验收尚未完成，Stage03禁止。
- 构建有无AppIntents依赖的元数据提取告警；第五轮xcresult另记录UIKitToolbar/UIHostingController运行告警，根因未确立，不能宣称零警告。当前路径未出现因该告警导致的测试失败，仍需后续原证据核对。
- Stage 01 外壳曾有真实构建证据：Architect 在 macOS 云端对源码 `6e8f449` 编译并执行 31 项测试（零失败），运行入口与警告见 [Round04](../.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md)。**该结果只对应 Stage 01 源码，不是 Stage 02 的构建证据。**
- 未保存的空项目只在内存中，退出即丢失；导入过照片的项目写入 `Application Support/MomentsStudio/`，重启后恢复（界面已标注两者区别）。
- Stage 02 暂定上限：每项目 20 张、每文件 100 MiB、每图 80 MP、thumbnail 320 / preview 2048、串行处理；未做真机性能测量。
- 仅接受 JPEG/PNG/HEIC/HEIF 静态图；拒绝 RAW、动画 GIF、视频。无内容去重。
- 工程内所有界面文案为英文占位，显示语言待定。
- 未实现：画布、图层、裁剪、拼贴、抠图、贴纸、AI、滤镜、动画、导出、云、账户、付费。
