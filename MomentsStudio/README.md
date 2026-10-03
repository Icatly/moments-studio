# Moments Studio — 构建、运行与测试

Stage 01 基础工程及 Stage 02 照片管线的 iOS 应用工程（Swift / SwiftUI，iPhone 优先，可扩展到 iPad）。

## 环境要求

| 项 | 要求 |
| --- | --- |
| macOS | 必需（Xcode 只能在 macOS 上运行） |
| Xcode | 最低设计基线15.4（使用iOS17 API）；实际验证16.4；15.4与26尚未验证 |
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

- **Stage02真实编译测试门禁通过**：run9/source728f435在macOS15.7.9/Xcode16.4/arm64 iPhone16Pro18.5实际80单元+5UI全85通过，0失败0skip，取消选择器及完整照片流程同时通过，原生预览PNG已审。有效新ZIP已核SHA且04:39上传既有Appetize；17.2真实预置4032×3024 HEIC预览成功，不复现旧缺模型fatal。Done返回/同会话重启/深色大字号尚未完成；free30/30、0分钟，按所有者指令暂停等重置。Windows仅结构/语法检查，真机/iPad/VoiceOver/精确17.0/Xcode15.4/26未测，Stage02所有者PENDING。最新事实见[Round20](../.ai/reviews/STAGE-02-ARCHITECT-ROUND-20.md)和[验收证据](../.ai/acceptance/STAGE-02.md)。
- Stage 01 外壳曾有真实构建证据：Architect 在 macOS 云端对源码 `6e8f449` 编译并执行 31 项测试（零失败），运行入口与警告见 [Round04](../.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md)。**该结果只对应 Stage 01 源码，不是 Stage 02 的构建证据。**
- 未保存的空项目只在内存中，退出即丢失；导入过照片的项目写入 `Application Support/MomentsStudio/`，重启后恢复（界面已标注两者区别）。
- Stage 02 暂定上限：每项目 20 张、每文件 100 MiB、每图 80 MP、thumbnail 320 / preview 2048、串行处理；未做真机性能测量。
- 仅接受 JPEG/PNG/HEIC/HEIF 静态图；拒绝 RAW、动画 GIF、视频。无内容去重。
- 工程内所有界面文案为英文占位，显示语言待定。
- 未实现：画布、图层、裁剪、拼贴、抠图、贴纸、AI、滤镜、动画、导出、云、账户、付费。
