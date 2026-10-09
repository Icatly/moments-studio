# Stage03 当前修正技术复审与交付

结论：当前修改通过技术复审，交付本人真机复测。Stage03 为 **WAITING_FOR_USER**，不是 APPROVED；Stage04 未授权。

## 真实结果

- 验证源码：`68864c2bc2109abaf8d8b9b45bec0777ae1700ec`。[完整原生运行](https://github.com/Icatly/moments-studio/actions/runs/37885854102)真实 success，130 unit + 8 UI = 138，138 passed / 0 failed / 0 skipped / 0 expected failures。Xcode26.6（17F113）、iphoneos SDK26.5、iPhone17 Pro arm64 / iOS26.5（23F77）。清单、计数门禁、模拟器包、启动截图及证据上传全部通过。
- 原始 xcresult/附件归档已下载并核验 GitHub digest：artifact11596802912，149818502 bytes，SHA256 `903069f4878d6270aeca77d12f7ce028eaebb2d5e2d7cb9a31831e904e2e98b4`。保存在本机私密 `.ai/build`；未把原始本机材料加入提交。
- [设备构建](https://github.com/Icatly/moments-studio/actions/runs/37885964541)真实 success、同源码。无签名 IPA535429 bytes，SHA256 `f622ab1cd728466272c7ffe02146ca0b4212cc43edca5fcaedc0c2a9fcf6927c`；ZIP无损、iPhoneOS/arm64/Mach-O IOS、最低iOS17.0、bundle `com.example.MomentsStudio`、无xctest。Xcode16.4/SDK18.5；本机英文临时路径安装副本逐字SHA相同。
- 第四轮原生138/138已通过但整体workflow因旧7项UI计数残留而failure，保留真实历史，不回写成绿。门禁修正实际以成功证据和9项反例运行10/10；第五轮完整GitHub流程随后真实通过。未手动改GitHub状态、未skip/only-testing/删旧断言或同版本自动重试。

## 修正与评审边界

列表所选可见下层优先接收其范围内的拖动，锁层拒绝变换；Tap仍按顶层命中。触控边界限制于按钮和实际工具viewport，plain添加按钮恢复label触摸；每行独立AX容器保留子按钮身份。原生回归确认锁上层后下层可拖、上层不动、两层UUID/count不增，并核完整变换/调序/隐藏锁定及强制结束重启恢复、删层保留素材。Done沿用原保存协调器，保存成功后才回首页；空项目保存/重启和保存失败不改旧包均有真实测试。

未修改公开序列化字段、导航契约、模块边界或运行期依赖。临时原生样式延续已批准外壳；正常竖屏Home启动截图已目视核对，无遮挡或裁切。全部原133方法和旧断言保留；共享测试helper按真实overflow做最多3次原生慢速相对拖动，保留完整可见/可点击门槛。30分钟上限来自实际完整链耗时，标准公开macOS运行器，不改付款或预算。

Swift编译没有编译器warning。App/device/test target有无AppIntents依赖而跳过元数据提取的工具warning，原日志保留；没有通过删除依赖、系统框架或压制日志处理。设备包不运行XCTest，不能把device build success单独当成测试通过。

## 本人待验收

当前新包未签名/未安装，USB未检测到iPhone；本人手机仍为6bd2fbf旧版。保留现有App与项目，用既有AltServer在本机由本人完成Apple签名登录，不卸载或删除照片。

旧版偶发新增持久化副本由本人明确报告，旧版精确触发尚未原生复现；新版两轮自动完整链不增层通过，仍须本人用原重叠场景多次拖动核对计数和重开结果。新版组合双指、照片保留、深色/最大字/VoiceOver及20层性能仍待本人实际检查，旧包第一组正常不外推新包。验收清单见 `.ai/acceptance/STAGE-03-PHYSICAL-DEVICE.md`；只有本人明确通过，才可能批准Stage03。
