# Stage03 公开仓库原生测试

## 最终结果（2026-10-09 13:29，覆盖下方历史）

完整[run37885854102](https://github.com/Icatly/moments-studio/actions/runs/37885854102)真实success，source68864c2bc2109abaf8d8b9b45bec0777ae1700ec。130 unit+8 UI=138，138 passed/0 failed/0 skipped/0 expected failures；结果门禁、模拟器包/启动截图与上传均success。Xcode26.6/SDK26.5，arm64 iPhone17 Pro/iOS26.5。artifact11596802912、149818502 bytes，SHA256 903069f4878d6270aeca77d12f7ce028eaebb2d5e2d7cb9a31831e904e2e98b4，与GitHub digest一致；完整原始xcresult/附件已私密留存。Home启动截图已目视核对。

设备run37885964541 success，source同68864c2，IPA验证与英文安装副本复核完成（535429 bytes、SHA f622ab1cd728466272c7ffe02146ca0b4212cc43edca5fcaedc0c2a9fcf6927c）。元数据提取无AppIntents依赖warning保留；编译器warning为0，未压日志。当前签名/安装/本人新版复测仍未执行，USB未检测iPhone、手机仍旧6bd2fbf。最终技术Review完成，Stage03 WAITING_FOR_USER，不是APPROVED；Stage04未授权。公开标准runner、未改付费预算/付款，前四轮真实结果保持历史，不伪造绿状态。

## 第四轮原生通过与门禁修正记录（2026-10-09 12:49）

第四轮原生XCTest已全部通过：138执行/138 passed/0 failed/0 skipped/0 expected failures，130 unit+8 UI；锁层重叠下层拖动、不增层、完整编辑/调序/强制结束重启恢复/删除保留素材及Done保存回首页均真实通过。source b436590b560da378687fbae1f2b4290a5f465224，run37883613668；整体workflow仍failure，原因是结果门禁残留旧“frozen-7 / 7”拆分，与真实130/8不符，不能把红workflow写success。

原始summary/xcresult及附件已核验：artifact11596436195，141276170 bytes，SHA256 f9b1dff674d4eeb4853bf14f2660944e97916d27dbc76c001b5f9e02fe740f65，匹配GitHub digest；清单14份含测试方法的源码逐字SHA匹配Git commit。修正门禁从EXPECTED_UNIT_TEST_COUNT/EXPECTED_UI_TEST_COUNT读取130/8，并检查拆分和总数一致；保留清单、设备、138全通过、0失败/跳过/expected failure等严格条件。已对真实成功证据及9项失败反例执行实际门禁，10/10符合预期，没有修改原证据。

下一步仅推workflow门禁/真实报告；App和所有测试源码保持。再运行完整GitHub入口验证后续流程；设备IPA允许同步准备，前提是新head的MomentsStudio树与已138通过的b436590完全相同。新版手机安装、偶发复制真机多次复测、组合双指/显示与可访问性仍未完成；不宣称所有者Stage03批准或进入Stage04。

## 首轮结果与限定修正（2026-10-09 11:33）

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

## 第三轮实际启动（2026-10-09 12:02）

精确4文件正常推送46be2a74a693646cf501e1612dcfec5793d7e1ac，单次派发[run37881959932](https://github.com/Icatly/moments-studio/actions/runs/37881959932)，attempt1，in_progress；完整138/标准macos-26/30分钟上限。当前尚无第三轮结果，新IPA未构建/安装。

## 第三轮结束与滚动修正（2026-10-09 12:20）

第三轮run37881959932真实failure，138执行/137 passed/1 failed/0 skipped/0 expected failures，未超时。artifact11594519856、153958530 bytes、SHA256 aefc99d718f1f19c3fc4d2a9c6975e07b774f630df378db215ea002fbbf52dcf，与GitHub digest匹配；原始xcresult/附件已私密留存。两层真实UUID/顺序label和上层锁定均已通过，拖锁层后transform及UUID集合/count=2保持，说明行AX容器修正有效。下层拖动尚未执行。

唯一失败line279为select lower photo beneath locked upper photo never became hittable。实际操作日志为上滑→下滑→上滑，同一个目标反复被全幅惯性滑动越过。仅修改共享UI测试滚动helper：按实测超出viewport的距离加16点余量移动，单次24至viewport高度45%，两个端点均从真实scrollView/viewport几何换算为element-relative位置；原生slow拖动并停留0.2秒再松手，仍最多3次且必须整个按钮可见和hittable后才点击。每次记录真实frame/viewport/distance，便于下轮定位。App和所有旧断言/138方法不变，不增retry、不skip、不伪造UUID。原生API核对：[Apple XCUICoordinate文档](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/press%28forduration%3Athendragto%3Awithvelocity%3Athenholdforduration%3A%29)。

第四轮准备只推helper及本报告，完整30分钟macos-26入口保持；下层拖动/持久化完整链、新IPA和本人复测仍待，Stage03 CHANGES_REQUESTED。

## 第四轮实际启动（2026-10-09 12:23）

精确2文件正常推送b436590b560da378687fbae1f2b4290a5f465224，单次[run37883613668](https://github.com/Icatly/moments-studio/actions/runs/37883613668)，attempt1，in_progress；完整138/标准macos-26/30分钟上限，尚无第四轮结果。App与第三轮一致，无新IPA或本人修后验收。

## 最终流程与设备包实际启动（2026-10-09 12:54）

门禁/报告精确2文件推送68864c2bc2109abaf8d8b9b45bec0777ae1700ec；完整[run37885854102](https://github.com/Icatly/moments-studio/actions/runs/37885854102)与设备包[run37885964541](https://github.com/Icatly/moments-studio/actions/runs/37885964541)各单次派发，attempt1，均in_progress。设备包在138/138真实证据、公开标准macos-15、原生测试源码树完全一致的核验后准备；MomentsStudio树8dbb142284d4cd9ac0f7b28342a9f3af1e51e97f相同，未改付款/预算。尚无新IPA/签名/安装，不计整个native workflow通过。

## 新版设备包验证（2026-10-09 12:58）

run37885964541 success，source68864c2；有效unsigned IPA535429 bytes、SHA256 f622ab1cd728466272c7ffe02146ca0b4212cc43edca5fcaedc0c2a9fcf6927c。平台iPhoneOS/arm64/Mach-O IOS/min17，bundle com.example.MomentsStudio、无xctest、ZIP无损；Xcode16.4/SDK18.5，一项AppIntents无依赖的元数据提取warning，不隐藏。设备workflow不运行XCTest，但整个MomentsStudio树与138/138通过b436590一致。安装副本C:/Users/27411/AppData/Local/Temp/MomentsStudio-Stage03-37885964541/MomentsStudio.ipa已逐字SHA复核。签名/安装/本人新版复测均未执行；最终native入口仍运行，Stage03未批准。
