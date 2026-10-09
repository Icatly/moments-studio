# 最终冻结前补正04 — 最小搜索结束与同工具链交付

FIX03源码独立核176unit+10UI=186、旧18个测试文件/公开6模型/Stage04冻结工作流保持；未原生运行。仅以下补正，由DSH实施：

1. **dismissSearch环境层级与清空查询**：新CollageLayoutSheet在外层读取dismissSearch，但searchable在内层ScrollView，Apple明确该环境不向上传递；即使挪到有效子view，dismissSearch会清空query，破坏OFFSET筛选与无结果断言。请用最小原生方式结束键盘/搜索激活而保留过滤查询（可优先考虑iOS17可用searchable isPresented binding），不堆服务或UIKit私有调用。保留旧所有行为断言，并在每次submit后显式核过滤仍有效/查询不误丢；重进搜索能按实际内容改关键词。官方：[dismissSearch](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisssearch)、[搜索激活管理](https://developer.apple.com/documentation/swiftui/managing-search-interface-activation)。原录屏140秒截帧`.ai/build/stage04-run-37957684567-20261010-003618/offset-frame.png`已看，确认按钮在键盘下。
2. **PhotoAnalysisSheet.Close立即失效**：dismissIfCurrent目前只改navigation，invalidate在onDisappear兜底；把同步invalidate放在Close当前sheet动作、仍保留onDisappear。项目切换的view生命周期用最小现有route.id保证run对应当前project，无需新抽象。当前captured key在startRun读取前有!cancel guard并无await，主actor原子性可接受；无需额外复杂调度器。
3. **Stage04新viewport几何**：所有scroll/app/nav/keyboard/target实际参与值验证finite positive；目标已在viewport却不hittable应失败并记录，不猜方向拖动。严格唯一layout.scroll/对应sheet nav，扣键盘与实际导航覆盖。新drag端点在真实viewport而非被遮挡的scroll百分比。共享旧scrollEditorToMakeHittable保持，gallery有界实例化修复可接受，原assertions保留。
4. **Architect批准Stage05设备构建工具链统一**：Stage03历史IPA实际Xcode16.4/SDK18.5，当前Stage05 device照抄macos15可能仍旧SDK，呈现不同于Xcode26云测试。Stage05设备workflow改标准macos-26（免费标准，不larger），6分钟/2天/手动/无签名不变；复用实际Xcode26+与iphoneos26+选择/记录校验，不再默认老SDK。清理本workflow里Stage04DeviceDerivedData/变量等误命名，报告与README按实际修正。Stage04两冻结workflow不改。零新增依赖/付费/账号设置。

无需新增无逻辑常量测试；实际新增仅在必要回归下如实计数。交付READY_FOR_ARCHITECT_REVIEW，Architect复审后精确公开提交/完整186项原生测试/同源设备包；Stage06禁止。当前DSH68%，此轮若达70%先完整落盘接续任务、明确未完项并停，Architect在本DSH工作区续开会话，保留旧对话。
