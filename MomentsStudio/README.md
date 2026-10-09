# Moments Studio — 构建、运行与测试

Swift/SwiftUI、iPhone优先。Stage04已冻结（commit edeca4dd）并交原生验证（run37957684567 只对应该冻结commit，不覆盖当前工作树），其本地确定性布局、三照片预览/内置搜索/Apply保存代码已在工作区，完整155项Xcode测试与新IPA仍由Architect组织。当前Stage05已按所有者指令实现并完成 Review 补正01：逐图只读光色分析（`Photo summary`），本地READY_FOR_ARCHITECT_REVIEW，源码清单为176单元＋10 UI＝186项，**未运行**。手机仍是Stage03 source68864c2；历史138/138及首组三项本人正常不证明Stage04/05。

完整产品为“导入及可改建议 → 三方向参考图/预设＋可选搜索 → 选定后AI生成整组 → 微调 → 保存相册”，见[产品基线](../docs/产品与架构基线.md)。Stage04当前仅是单画布构图基础；AI自适应、多页图组及相册导出仍未实现。

## Stage04构建和验收入口

- 规格：[确定性布局与三预览](../docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)；验收：[Stage04清单](../.ai/acceptance/STAGE-04.md)。
- 新测试入口：`.github/workflows/stage04-tests.yml`，手动触发、标准macos-26、30分钟上限、146单元＋9 UI＝155项完整scheme，原始清单/xcresult/结果门禁和2天产物守卫。当前只做本地脚本解析与合成门禁检查，没有实际运行。
- 新设备入口：`.github/workflows/stage04-device.yml`，手动触发、标准macos-15、6分钟上限、无签名IPA、产物2天/100MiB上限；不运行XCTest。完整原生成功后再准备同源码设备包。
- Stage03工作流保留旧138项冻结边界，不能在新增Stage04源码上派发旧入口并假称通过。下方Stage01/02/03记录均是各自历史边界。
- 新运行包中从编辑器Layouts入口浏览Grid/Focus/Offset；空画布用已导入照片建层，已有画布仅排列可见未锁定层。取消不写盘，Apply成功才关闭，失败保留可重试意图；不新增序列化字段或依赖。

## Stage05构建和验收入口

- 规格：[照片分析基础](../docs/architecture/STAGE-05-PHOTO-ANALYSIS.md)；验收：[Stage05清单](../.ai/acceptance/STAGE-05.md)；报告：[实现报告](../.ai/reports/STAGE-05-IMPLEMENTATION.md)。
- 新测试入口：`.github/workflows/stage05-tests.yml`，手动触发、标准macos-26、30分钟上限、**176单元＋10 UI＝186项**完整scheme，原始清单/源哈希/xcresult/结果门禁与2天产物守卫；与Stage04入口一样只在部署时运行完整scheme（无`-only-testing`、不跳过、不重试）。当前未推送、未触发，只做本地YAML/内嵌Python与清单步骤检查。
- 新设备入口：`.github/workflows/stage05-device.yml`，手动触发、标准**macos-26**（免费标准runner）、6分钟上限、无签名IPA、产物2天/≤100MiB；构建前枚举并记录**Xcode 26+/iphoneos SDK 26+**（与测试入口同一工具链，Stage03 历史设备包实为 Xcode16.4/SDK18.5，不再默认老 SDK）；不运行XCTest。
- Stage04两个工作流按其冻结commit保持原样（155项边界），不在Stage05新源码上派发旧入口假称通过；Stage01/02/03工作流同样各自保留历史边界。
- 功能：编辑器可选“Photo summary”入口（`editor.photoSummary`）→ sheet 顺序分析最多20张已导入照片，每张显示纠正后尺寸与三档光/色估计（`Estimated darker/balanced/brighter`、`Estimated muted/moderate/colorful`）；弱采样只给用户语言的“Not much visible detail to measure here — treat this as a rough estimate.”，不展示像素数/coverage/阈值。单张读取失败只影响该张，可“Analyze again”重算，关闭即取消，重开重新计算。
- 结果只在**当前项目、当前照片身份与当前metadata**下写回和显示（`PhotoAnalysisRun` guard），并核对测量结果的asset与display尺寸：照片被删/元数据变化、换项目（currentProjectID）、关闭或重算（`invalidate()` 即时生效）后，旧的估计与旧的失败都不会再出现。
- 算法冻结（工程决定，非Apple推荐算法）：既有320px缩略图再等比缩到最长边≤64px（不放大、不拉伸）；显式画入8-bit sRGB RGBA（`premultipliedLast｜byteOrder32Big`，`.high`插值；**sRGB 颜色空间创建失败即抛类型化错误，不静默回退 DeviceRGB**）；alpha≤0.05（字节≤12）不计入、字节13起计入，其余先去预乘；`L=0.2126r+0.7152g+0.0722b`（编码sRGB相对亮度代理），对比度为总体标准差（仅对浮点误差归零/上限0.5），饱和度为HSV的S；暗像素L≤0.1、亮像素L≥0.9；`coverage=有效/采样`；`adequate`需有效像素≥256且coverage≥0.75，否则`limited`。
- 边界：分析只读——不改manifest/原图/派生图、不占mutation gate、不写草稿、不写store；不新增Codable字段或schema（仍schema2、兼容v1）、无第三方运行依赖、无网络/账号/模型/GPU；不自动选模板或改照片。
- 新增测试（31项，全部**未运行**）：`Stage05PhotoAnalysisTests`（11，纯统计：黑白灰/RGB/双区、非RGBA输入、半透明去预乘、全透明失败、覆盖与置信度、采样上限与不放大、非法元数据、UI分档、alpha 12/13边界）、`Stage05AnalysisStorageTests`（8，真实文件：统计与字节不变、EXIF显示尺寸、缺失缩略图与逐图隔离、未知/跨项目asset、取消传播、持手势门槛仍只读、**符号链接缩略图被拒且字节不变**、**越界路径守卫**）、`Stage05AnalysisRunTests`（11，身份/请求guard：错asset或错display尺寸被拒、切currentProjectID拒绝成功与失败、关闭/重算invalidate即时失效、旧尺寸结果不得作为新metadata结果读取、`beginRequest` 只允许当前任务键起新请求并原子换新token清旧值）、`Stage05PhotoSummaryUITests`（1，真实导入→summary→结果→重算→关闭→层数/照片不变→重开重算，tap走严格完整视口门槛、行用真实容器查询）。**本轮另按 Stage04/02 真实原生证据最小修复**：共享 `prepareEditorGallery` 增加有界慢拖实例化 lazy 图库；布局搜索激活绑定（`searchable(isPresented:)` + 提交置 false）收起键盘且**不清查询**，使筛选结果可点；`tapChoice` 以扣除 nav/键盘的可用视口为准（唯一 scope + finite/正 frame 校验 + 真实视口拖拽端点，视口内不可点即失败不盲拖）；`PhotoAnalysisRun.beginRequest` 让每个真实新 task 原子换新 token 清旧值。Stage02/04 旧断言与 Stage04 冻结工作流未改。**本轮另按 Stage04/02 真实原生证据最小修复**：共享 `prepareEditorGallery` 增加有界慢拖实例化 lazy 图库；布局搜索激活绑定（`searchable(isPresented:)` + 提交置 false）收起键盘且**不清查询**，使筛选结果可点；`tapChoice` 以扣除 nav/键盘的可用视口为准（唯一 scope + finite/正 frame 校验 + 真实视口拖拽端点，视口内不可点即失败不盲拖）；`PhotoAnalysisRun.beginRequest` 让每个真实新 task 原子换新 token 清旧值。Stage02/04 旧断言与 Stage04 冻结工作流未改。

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

以下固定85项工作流保留Stage02历史验证边界，不能直接用于当前Stage03。Stage03使用两个手动工作流：`.github/workflows/stage03-device.yml`（6分钟超时、产物保留2天、合计≤100MiB，仅构建无签名设备IPA，**不运行XCTest**）与`.github/workflows/stage03-tests.yml`（30分钟超时，完整130单元＋8 UI＝138项）。source68864c2的原生run37885854102与设备run37885964541均已真实success，见[测试报告](../.ai/reports/STAGE-03-NATIVE-TEST-2026-10-09.md)。仓库已按所有者授权公开；历史私有仓库/Appetize余额不代表当前资源，后续运行仍按实际授权和资源核验。

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

### Stage03原生测试入口（已有真实成功结果）

Stage03 的自动测试使用独立入口 `.github/workflows/stage03-tests.yml`，它由上面这个**已实际运行的 Stage02 预检工作流最小适配**而来，不能沿用 Stage02 的固定门禁：

- 仅 `workflow_dispatch`、`permissions: contents: read`、`persist-credentials: false`、`timeout-minutes: 30`、产物保留2天；输入 `large_text`/`dark_appearance` 均默认关闭。
- **测试前**用Python标准库从两个测试目录生成**方法清单与逐文件SHA256**（当前冻结边界130 unit + 8 UI = **138**），并核对scheme的`TestAction`只跑两个测试target且逐文件方法数与冻结值一致；名单/哈希写进本轮产物，计数写入`GITHUB_ENV`供原生结果门禁。
- 运行**完整scheme**（不加`-only-testing`、不跳过、不重试），保留真实退出码、完整log、`Stage03-Tests.xcresult`与附件导出，并断言原生summary恰为 **138 total / 138 passed / 0 failed / 0 skipped / 0 expected failures**，且实际设备匹配所选arm64 iOS26+模拟器UDID。
- 保留 Xcode 26+/SDK 26+ 枚举、合成 Photos 种图、内容字号与外观的设置-读回-测试后读回-还原，以及上传前的证据守卫（拒绝凭据类文件与非 xcresult 导出的媒体）。
- 该入口只产出**模拟器**自动测试证据：它做一次无签名 iphoneos Release 设备构建校验，但**不产出 iPhone 安装包**；设备 IPA 由 `stage03-device.yml` 单独准备。自动测试不替代所有者在本人 iPhone 上的双指/视觉验收。
- 已执行的run37885854102对应source68864c2，全流程success。未来派发仍须核对检出源码、具体授权及资源；清单步骤在源码不符时以**真实计数直接失败**，不会把旧的较小方法集当成Stage03结果。早期Xcode/工程接线失败即使缺manifest仍可保留安全诊断日志，并附`SOURCE_MANIFEST_MISSING/NOT_VERIFIED`；原生结果门禁仍拒绝缺清单/summary，日志上传不能把失败变成通过。

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

- **Stage02历史证据快照（2026-10-05，不代表当前源码状态）**：第五轮run37227995563/source01bc584，macOS26.6.2/Xcode26.6/SDK26.5/iPhone17Pro iOS26.5 arm64实际85/85、0失败0跳过；原生导入/预览/Done/取消保留/确认移除/再导入及同project与asset terminate/launch恢复通过。有效模拟器ZIP与源码/SHA已核。dark标签截图仍浅色，深色视觉未通过；第六轮run37230253288/source64fb192实际84/85失败；最大辅助字号+真实深色设置/持续读回/还原通过，原始录屏抽帧确认实际环境。系统照片Private Access说明溢出遮住网格，Home主按钮文本截断；FIX06第七轮run37248700016/source590ccf3实测84/85；关闭说明/选图/导入计数1成功，屏下图库thumbnail AX未出现，Home原生PNG仍截断。FIX07仅本地修图库准备与Home显式Text，新版未native验证；旧账单推余$0.464不足完整下一轮，未付费。详见[第五轮Review](../.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-05.md)、[第六轮记录](../.ai/reviews/STAGE-02-CLOUD-PREFLIGHT-06.md)与[当前验收事实](../.ai/acceptance/STAGE-02.md)。
- Stage02历史证据：旧Xcode16.4/iOS18.5原85通过和Appetize17.2 HEIC加载预览仍有效；17.2 Done/重启未完成。所有者随后在iPhone旧版f185738确认导入两张、预览、删除一张、重开保留均正常，并提供录屏；明确批准进入Stage03。Stage02最新代码的native缺口保留，旧版体验不能证明Stage03。Appetize免费分钟已耗尽，Apple账户问题继续搁置；iPad/VoiceOver/精确17.0/Xcode15.4未验证。
- 构建有无AppIntents依赖的元数据提取告警；第五轮xcresult另记录UIKitToolbar/UIHostingController运行告警，根因未确立，不能宣称零警告。当前路径未出现因该告警导致的测试失败，仍需后续原证据核对。
- Stage 01 外壳曾有真实构建证据：Architect 在 macOS 云端对源码 `6e8f449` 编译并执行 31 项测试（零失败），运行入口与警告见 [Round04](../.ai/reviews/STAGE-01-ARCHITECT-ROUND-04.md)。**该结果只对应 Stage 01 源码，不是 Stage 02 的构建证据。**
- 尚未保存的空项目仅在内存中；Stage03点Done保存成功后可持久化空项目并返回首页。导入或编辑保存的项目写入`Application Support/MomentsStudio/`并支持重开恢复；Done空项目保存与重启路径已纳入138项原生测试。
- Stage 02 暂定上限：每项目 20 张、每文件 100 MiB、每图 80 MP、thumbnail 320 / preview 2048、串行处理；未做真机性能测量。
- 仅接受 JPEG/PNG/HEIC/HEIF 静态图；拒绝 RAW、动画 GIF、视频。无内容去重。
- 工程内所有界面文案为英文占位，显示语言待定。
- Stage03画布/图层有历史原生验证和首组本人反馈，其他真机缺口保留。Stage04本地已有三构图预览/内置搜索，尚待原生运行；未实现智能风格推荐/远端模板库、裁剪、多页图组、抠图、贴纸、AI、自适应滤镜、动画、导出、云、账户、付费。Stage05未批准。


## Stage03 — 可编辑画布与图层（历史验证基线）

- 已实现（本地编码）：从项目素材**手动添加**照片图层（同一素材可重复添加，上限 20 层）；点选、单指拖动、双指缩放/旋转（一次连续组合手势结束只提交一次完整 transform）；图层前后调序、隐藏/显示、锁定/解锁、重置与删除；**手势替代按钮**（移动/缩放/旋转/前移/后移/重置）供 VoiceOver 与不方便双指操作时使用；编辑后可保存并在重开/terminate 后恢复；删除**图层**保留照片素材，删除**素材照片**在同一 manifest 事务内级联移除引用它的图层。
- 数据契约：`Layer` 新增可选 `assetID`/`baseSize`，`ProjectPackage` 写 **schemaVersion 2**；真实 schemaVersion 1 文档仍可读取（内存升级，**读取不重写文件**，下次成功写入才升级）。旧版 App 无法读取 schema 2 文档，需要更新到 Stage03 运行包。
- 构建与测试命令仍与上文一致。source68864c2已在Xcode26.6/SDK26.5、iPhone17Pro arm64/iOS26.5模拟器完整通过130单元＋8 UI；原始结果、工具链与警告见[最终技术复审](../.ai/reviews/STAGE-03-NATIVE-FINAL-2026-10-09.md)。本次仅改文档，没有重新运行Xcode。
- 已运行覆盖：`Stage03ContractTests`（契约/几何/文档操作）、`Stage03StorageCoordinatorTests`（冻结schema1真实磁盘restore、saveEdit schema2、删层保留原图、删素材级联、真实写入失败/重试与手势门槛）、`Stage03CanvasUITests`（两层变换/隐藏锁定/调序/terminate恢复/删层）、新增锁层重叠下层拖动与不增层、Done保存返首页及原有Stage01/02回归。精确清单以该运行证据为准。
- 所有者已确认source68864c2对应的新IPA安装成功，且旧照片、Done保存返首页、重开位置三项正常；锁层重叠、偶发复制反复计数及其余双指/状态恢复/视觉和无障碍检查待反馈。见[真机验收](../.ai/acceptance/STAGE-03-PHYSICAL-DEVICE.md)，不能把自动测试通过写成本人全项验收。iPad完整适配与裁剪/自动布局/AI/导出不在本阶段。
