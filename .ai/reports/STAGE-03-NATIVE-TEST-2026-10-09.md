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

## 第二轮实际启动（2026-10-09 11:35）

限定4文件正常推送75b68a7bd5ea5e51321b491ae244e52399d1a370；无强推、未纳入其他未提交文件。单次派发[run37879961931](https://github.com/Icatly/moments-studio/actions/runs/37879961931)，job113657139239，attempt1；完整138方法与标准macos-26/18分钟均不变。当前in_progress，尚无第二轮测试结果。

## 第二轮结束与再次限定修正（2026-10-09 12:00）

第二轮真实summary为138执行、137 passed / 1 failed / 0 skipped / 0 expected failures；job最终cancelled（18分钟上限），不记整轮success。原始xcresult和附件已保留并下载：artifact11594402110、145225871 bytes、SHA256 53f487fb120a438674d7c118e5c471a405e8ffb3f492ad4260059c077b006955，匹配GitHub digest。Stage02预览/取消与确认移除/重新导入/重启链240.281秒通过，130 unit及Done UI均通过。

唯一失败为Stage03编辑链line217：first layer's select button did not appear。上一行layerCount=1已成功，说明添加按钮修正生效；尚未进入重叠/锁定回归。现有导出没有该失败时完整AX，不能认定最终根因。行VStack带identifier但未建立独立AX容器，可能覆盖子按钮标识；添加原生accessibilityElement(children: .contain)，保留原行/按钮标识和真实完整label。测试继续只按真实app.buttons和完整UUID查找，不换查询、放宽断言或用序号替代身份；失败时补充完整AX及截图，下一轮用于确认。

实际耗时证明18分钟无法容纳完整成功链及诊断收集，job上限改30分钟；仍标准macos-26、完整138、无only-testing/skip/retry。无接口/序列化/导航/依赖变化，无付款或预算改动。下一轮须真实跑完后再形成新包，手机仍旧6bd2fbf、Stage03 CHANGES_REQUESTED。
