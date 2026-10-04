# Stage02 — iPhone 16 Pro Max 真机安装与验收

日期：2026-10-04。所有者授权：“走真机路线 现在需要我做什么”。

## 当前状态

- Stage02 尚未获所有者批准；原 run9/source728f435 的85项测试通过记录保持有效，不能算真机测试。
- 改走真机路线，只增加交付/验收步骤，应用源码、公开数据契约和Stage03权限不变。
- 手机：所有者提供 iPhone 16 Pro Max，当前iOS26.5.2（所有者报告，尚未直接核实）。
- 新工作流 `.github/workflows/stage02-device.yml` 使用既有私有GitHub macOS环境，仅编译Release iphoneos设备包。设备包为**未签名IPA**，不是可直接安装或已在手机运行的产物。
- Windows侧计划使用AltStore Classic/AltServer本地签名安装；需先核实依赖与实际兼容性。Apple账户登录、信任电脑、开发者信任、开发者模式均由所有者亲自操作。不得上传Apple账户密码或签名凭据到GitHub。
- 当前没有可供Architect直接操作这台iPhone的通道。先由所有者操作手机，Architect根据录屏/截图/诊断记录Review；不声称USB连接即可自动化真机测试。

## 所有者现在准备

1. 在“设置→通用→关于本机”查看iOS版本并告知Architect。
2. 用支持数据传输的USB线连接这台Windows电脑，解锁手机；出现“信任此电脑”时由本人确认并输入手机密码。
3. 保留手机连接。安装器与IPA由Architect准备，Apple账户信息不要发到聊天。

## 安装顺序（待实际执行）

1. 只读核对现有iTunes/iCloud/Apple设备驱动/AltServer，避免覆盖已有工具或数据。
2. 按AltStore官方Windows步骤准备桌面版iTunes/iCloud与AltServer；如已有不兼容版本，先提出明确方案，不擅自卸载。
3. 在AltServer由所有者登录Apple账户，为本机手机安装AltStore Classic。
4. 按手机实际提示，由所有者在“通用→VPN与设备管理”信任本人开发者、在“隐私与安全性”开启开发者模式（iOS16+；可能要求重启）。这些改变须本人确认。
5. 对GitHub产物核对源码提交、原生构建日志、iphoneos平台与SHA256，然后由AltStore签名并安装本项目IPA。未签名IPA安装成功前，不标记可运行。
6. 首次真实启动后再提交运行截图/录屏；免费签名通常7天到期，续签需AltServer。安装和续签不是项目验收。

## 本轮真机验收范围

- 基础导航、新建项目、多图导入、顺序/数量、预览加载、Done返回、取消、移除确认、空项目行为。
- 同一台设备上关闭App再从图标重开，检查项目/照片恢复；不通过卸载/重装验证恢复。
- 深色与大字号基本可用性。照片可选不敏感样本；避免上传个人照片到GitHub。
- 记录实际手机型号/iOS、设备构建提交、签名后安装时间、实际执行/未执行项、错误与已知限制。
- 真机新增版本不能自动补齐17.2最低版本的未完成证据；最低系统覆盖与所有者真机验收分别如实记录。
- 完成Review且真机安装可运行后才可转WAITING_FOR_USER；最终仍由所有者亲自明确批准。Stage03未授权。

## 官方参考

- [AltStore Classic Windows安装](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltStore签名到期与应用数量限制](https://faq.altstore.io/altstore-classic/your-altstore)
- [Apple免费Personal Team限制](https://developer.apple.com/help/account/basics/about-your-developer-account)

## 执行记录

- 2026-10-04：确认本项目最低iOS17.0；只读Windows卸载登记目前仅发现Apple Mobile Device Support 18.0.0.32，尚未据此排除Store版应用或便携版工具。
- 2026-10-04：设备构建工作流与安装指南准备；设备构建/签名/安装/真机操作均尚未执行。
