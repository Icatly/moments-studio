# Stage03 公开仓库原生测试

## 当前结果与限定修正（2026-10-09 11:33）

第一轮结束为 failure，非超时：138 实际执行，136 passed / 2 failed / 0 skipped / 0 expected failures。全部130 unit和6 UI通过；Done空项目保存、回首页和重启恢复通过。iPhone17 Pro arm64模拟器，iOS26.5（23F77），macOS26.6.2。设备Release编译成功。

两项原始失败及修正：

- Stage03完整编辑链在首次添加图层失败（line216）；新plain按钮的整张图片label仍带allowsHitTesting(false)，可见可用按钮的真实点击未提交。删除该modifier，保留56点frame、显式contentShape和plain style，避免恢复图片绘制区域超出按钮的命中问题。此修改尚待下一轮原生证实。
- Stage02预览链在line171失败。原始AX证明gallery按钮y860.3、高96，ScrollView底874，仅顶部14点可见；XCTest仍认为isHittable，旧helper提前返回后中心点击未打开预览。共享helper改为先检查完整frame位于真实ScrollView/window/nav裁剪后的viewport，再接受isHittable；仍最多3次原生方向明确的滑动，超界或不可点击即失败。Stage03工具也走此检查，导航栏Done保留正常点击。

所有138方法及旧断言保留，无skip/only-testing/同版本自动重跑。Windows结构、46 Swift语法树、16 Bash/7 Python片段和实际138清单校验通过；当前本地manifest SHA256为9bf9443f24bafd692e8cb2f7dd4e454770a4dcf1f8f0afdf589531878081cecb。原始结果及附件归档已校验GitHub digest，artifact11593282854、SHA256 50f54df618feb2a524c43891c5c91b5f470a9de687af9a0ba0e5747ed93edf96。原始xcresult保存在本机私密.ai/build，不发布用户材料。

锁层重叠拖动/不增层回归位于首次添加之后，本轮尚未执行到；不能宣称副本缺陷修复。下一轮使用修正后的新提交运行同一完整scheme，公开标准macos-26，无付费预算变化。手机仍旧6bd2fbf，新IPA及本人回归未发生，Stage03 CHANGES_REQUESTED。

## 第一轮启动记录

所有者恢复指令：“那继续测试吧 现在应该不用额度了”。既有仓库已公开、标准GitHub-hosted macos-26，未改付款或付费预算。

来源：`bb7a78df86deec5706b707f064fbfe1499ef7439`，完整130 unit+8 UI=138方法。2026-10-09 11:08:55（Asia/Shanghai）只派发一次stage03-tests，HTTP204；[run37877928826](https://github.com/Icatly/moments-studio/actions/runs/37877928826)，attempt1、job113650677789。

已从真实jobs API观察：Xcode26+选择、接线与清单、iOS26+模拟器选择、iphoneos Release编译与设备产物校验均success。具体版本与完整日志待运行结束下载，不臆测。当前运行进行中、合成测试素材/模拟器准备中，完整138测试结果尚未产生；不等于测试通过。测试失败时保留真实诊断，继续限定修正后才运行新版本，不删断言、不跳方法、不自动重跑同版本。

手机仍为6bd2fbf旧包，新版IPA与真机复测、Final Review未发生。Stage03保持CHANGES_REQUESTED，Stage04未授权。原生测试完成后的结果和证据追加于本报告。
