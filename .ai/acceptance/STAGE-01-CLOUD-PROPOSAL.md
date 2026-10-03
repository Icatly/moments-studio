# Stage 01 可运行版本方案（待所有者授权）

日期：2026-10-03。**所有者已授权此路径，登录由所有者处理；尚未上传代码或运行云构建。**

## 当前条件

所有者没有 Mac，也未加入 Apple Developer Program；当前 Windows 无法运行 Xcode。需要补充真正的编译/测试环境，以及所有者能操作的 iOS 运行环境。

## 建议：GitHub 私有仓库构建 + Appetize 浏览器验收

1. 所有者授权后，使用其 GitHub 私有仓库存放本项目源码与测试，不公开项目。
2. 已将构建配置放到 `.github/workflows/stage01-macos.yml`，仅手动触发标准 macOS runner，30 分钟超时，产物只保留2天。运行前核实账户免费额度与费用限制；不足就停止，不购买额度。
3. 执行真实 Xcode build 与所有 XCTest/UI smoke tests。保留源码 commit、Xcode版本、模拟器信息、完整日志与 xcresult；我 Review 编译错误、警告和失败，然后让 DSH 只修本阶段。
4. 测试成功后产出 ARM iOS Simulator `.app` 压缩包与校验值。该包用于模拟器，不能直接装到 iPhone。
5. 所有者授权后，将该构建上传至其 Appetize 账户，不上传个人照片。所有者在 Windows 浏览器里亲自操作真实 iOS 模拟器，按 `.ai/acceptance/STAGE-01.md` 验收。
6. 我完成代码/构建/视觉 Review 且可运行版本可用后才转 WAITING_FOR_USER。只有所有者明确批准 Stage 01 后才 APPROVED。

## 费用与限制

- GitHub 私有仓库提供按账户方案计的免费分钟和存储，超出可能收费；不承诺此账户一定有剩余额度。[官方计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- Appetize 免费方案目前每月30分钟、单次会话3分钟；不足就等额度或另选路径，不自动付费。[官方价格页](https://site.appetize.io/pricing)
- Appetize 支持模拟器 `.app`，不支持把 App Store 的 `.ipa` 当作模拟器构建运行。[官方上传说明](https://docs.appetize.io/platform/app-management/uploading-apps/ios)
- 默认持有 Appetize 构建链接的人可运行应用；免费方案不能假定具有登录保护。链接只交所有者，不公开发布。[官方共享说明](https://docs.appetize.io/platform/sharing-apps)
- 云模拟器可以验收 Stage 01 的导航/项目状态/占位页面；网络延迟影响手感，截图不能充分证明真实设备性能。真机性能、照片处理、签名与 App Store 上架门槛仍待对应阶段。
- 本地 workflow 是待执行草案，不是已验证 CI；首次云执行可能发现编译或工程问题。Mac runner 是工程工具，不进入 App，也不增加 App 运行依赖。

## 所需授权与账户

所有者已明确同意：源码上传至其 GitHub **私有仓库**，模拟器构建上传 Appetize，以及仅使用核实过的免费额度。账户登录/注册由所有者处理；不在聊天中索要密码或密钥。此授权不代表 Stage 01 通过，也不授权购买额度。

若不同意第三方托管，可借用/提供一台 Mac 并运行原生模拟器；有真实设备验收需求时再决定个人签名或开发者分发路径。
