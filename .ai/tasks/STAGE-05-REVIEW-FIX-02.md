# Stage05补正02：保留真实门槛，完成请求身份检查

Architect独立读FIX01实际代码发现以下问题；由DSH修复，禁止Architect代写。此文件准备不等于已发送。

1. **编译阻断**：Stage05PhotoSummaryUITests同一个test方法先`let row = element(projectID...)`，后又`let row = rows(in: app).firstMatch`，同作用域重复声明。明确分别命名projectRow/analysisRow，所有断言保留。
2. **重复滚动且掩盖门槛失败**：新tapFullyVisible用`_ = scrollEditorToMakeHittable`丢掉结果，然后追加最多4次全屏swipe和自定义isFullyVisible；这重新引入Stage03真实惯性越过问题，还弱化了共享helper的nav裁切/有限正frame门槛。两个调用都是编辑器非nav按钮，直接要求既有helper返回true，再等enabled/hittable并tap；删掉第二个滚动循环/镜像viewport helper。不改旧UITestSupport，也不删任何既有smoke行为断言。
3. **取消与项目身份仍未完整接线**：PhotoAnalysisRun.projectID当前没有参与mayWrite或measurement/failure；“两个空字典互不共享”测试不证明同一个run拒绝另一个project。最小修正：在实际guard传入并核当前projectID，读取也核；照片测量assetID和显示尺寸也须与测量快照一致，不接受错asset结果。sheet在新项目初始化/重算/关闭时即失效旧请求，不依赖新task开始才invalidate；startRun与await后明确检查取消/当前sheet。过期任务在newtask之前不得清空/写回新state。实际采用的guard/state补回归：同run/currentToken/同asset，换currentProjectID拒绝成功/失败；取消/关闭/新请求不得写回，旧尺寸结果不得作为新metadata结果显示。避免新空服务、额外调度器或生产测试按钮。
4. **测试原始值一致**：现testValueIsShown...“resized640x480”的新analysis仍helper硬填displayWidth320/displayHeight240。修fixture符合被测新metadata，另加明确拒绝错result身份/尺寸回归，不能靠固定helper误造正确性。

按实际新增数量更新Stage05工作流清单/工程/报告；旧155项/原断言/Stage04两个冻结工作流保持。交付完整后停READY_FOR_ARCHITECT_REVIEW；本地静态不称原生、不得进入Stage06。DSH70%先落盘同工作区接续。
