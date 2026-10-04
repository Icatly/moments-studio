# Stage02 — TestFlight无凭据工具链预检

角色：DSH Implementation Engineer。Architect授权本文件列出的Stage02交付准备；是否已发送/执行以根交接日志为准。2026-10-04所有者要求暂时搁置Apple账户问题，继续项目。本任务不依赖开发者会员或签名；文件名保留以便追溯原任务。

## 目标与边界

验证现有原生工程可以在Xcode26+编译并运行原有测试，为无需Apple账户的模拟器交付准备证据。保留SwiftUI、最低iOS17、现有序列化字段和全部85项测试；不进入Stage03。

本任务不包括：新增产品功能、最终品牌设计、改模型/导航公开契约、重写图像管线、引入Expo/EAS/第三方依赖、注册外部App ID、改Apple/GitHub账户、配置签名密钥、执行Apple上传或付款。

## 实现要求

1. 先读根交接、AGENTS、Stage02架构、Round20 Review和现有 `.github/workflows/stage02-macos.yml`。复用现有测试/fixture/证据提取方法；不要复制一套新的工程生成器或测试系统。
2. 新增单个手动触发、无凭据的 `.github/workflows/stage02-testflight-preflight.yml`。只用既有GitHub macOS runner；contents:read、persist-credentials:false、最长20分钟、证据保留2天。不得自动Apple上传或读取不存在的账户凭据。
3. 核对runner实际安装的Xcode正式版本，显式选择一个Xcode26+且iphoneos SDK26+的版本，记录路径与完整版本。不用beta，不凭runner标签推断工具链版本；无符合条件版本即明确失败报告，不自行安装大型软件或购买runner。
4. 对现有scheme实际进行无签名iphoneos Release构建，并在该工具链实际可用的iOS26+模拟器上运行原有80单元/5 UI测试。保持生成器/工程文件与产品代码不变。目标设备选择须依据实际可用destination；缺少runtime明确失败，不用跳过测试冒充成功。
5. 记录源码提交、Xcode/SDK/运行时/设备、完整构建与测试结果、xcresult或现有提取的测试报告。保持85项契约与smoke覆盖，不删除/禁用失败测试，不以多次重试掩盖确定失败。失败只先定位并报告；产品修复另交Architect决定。
6. 批量上传测试证据前检查只有必要日志/测试产物；该任务无密钥、无本人照片、无手机标识。不输出整个环境变量，不在日志中记录账户资料。
7. 更新README中预检执行方法，并交付 `.ai/reports/STAGE-02-TESTFLIGHT-PREFLIGHT-01.md`，区分Windows静态核对和实际macOS执行；未运行必须写未运行。DSH交付停在READY_FOR_ARCHITECT_REVIEW，云端运行由Architect按既有授权执行/核验。
8. 成功运行测试后，按现有工作流打包模拟器App并附源码SHA和包SHA256，供后续交互验收使用。若原有85项测试没有覆盖重启恢复、深色模式和大字号，先在报告中说明缺口，不在本任务中自行增加产品功能或扩展测试体系。自动测试/截图不能替代所有者交互验收。

## 完成与验收

- Windows检查工作流、参数、权限、证据路径与现有工程静态校验；不声称Xcode通过。
- Architect Review工作流后实际运行云端预检，核对源码与80+5结果；这是上传工具链兼容性证据，不能代替最低系统覆盖或真机验收。
- 新SDK可能改变系统控件外观，标为待实际视觉检查；不通过无依据的兼容开关隐藏差异。
- 后续临时图标、正式ID、签名与上传分别待账户事实与Architect具体任务，不扩大本文件范围。

官方要求：https://developer.apple.com/news/upcoming-requirements/ （2026-04-28起，上传App Store Connect需Xcode26+及对应iOS26+ SDK）。
