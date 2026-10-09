# Stage04/05 同源设备交付 — 2026-10-10

源码`fe17ac0d00db53629228f3ff972b5b83d563b551`；[完整186项测试](https://github.com/Icatly/moments-studio/actions/runs/37969910797)真实通过；[设备构建](https://github.com/Icatly/moments-studio/actions/runs/37973412193)成功。工具链Xcode 26.6 / Build version 17F113、SDK26.5，标准macos26。

IPA `692381` bytes，SHA256 `20954ef7839acd83d9c1203f06dbff63dde002e420359bff356c20bb4de65732`。独立核Payload、arm64 Mach-O IOS、最低iOS17、bundle `com.example.MomentsStudio`、Info.plist与云端digest一致，内不含测试包；测试和设备source完全相同，工具链/SDK相同。

本地安装副本已在私密验证记录`.ai/build/stage05-verified-ipa-37973412193.json`的`english_install_path`指明，复制后再次核hash。云产物`stage05-device-package-and-evidence`保留2天，本机原始证据已留存。

签名、安装、本人Stage04/05验收：**NOT_EXECUTED**。安装需本人在本机填写同一Apple账户，不发送凭据、不卸载App或删除旧项目。手机尚为Stage03。完整限制与警告见[技术复审](../reviews/STAGE-04-05-NATIVE-FINAL-2026-10-10.md)。
