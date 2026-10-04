# Stage02 FIX05 — 实见系统Popover取消路径

先读Round29与本地run37225749574原日志/manifest/9EC5723E…原生层级。当前HEAD8d1f954，Stage02 CHANGES_REQUESTED。今天免逐项审批；Apple/付费/Stage03禁令不变。不重复FIX04，不自行commit/push/cloud。DSH只改Stage02ImportUITests.swift及独立报告，根交接可追加当前实际日志；产品Swift/工程/契约/依赖/workflow不改。

本轮已真正导入、loaded preview、Done返回Editor，84/85唯一失败在243行Cancel：Popover内Sheet只有Remove，外部Other PopoverDismissRegion实见(0,0,402,874)，Popover(81,72,240,247.3)；没有Cancel按钮。

1. iOS26取消确认时，明确验证Popover内Sheet精确标题Remove this photo from the project?及原件不变说明、唯一typed Other PopoverDismissRegion（全identifier匹配，非first任意节点），有界就绪；验证其frame/Popover.frame均finite非空正宽高且app屏内。计算DismissRegion相对中心，验证在屏内且严格位于Popover外；保存取消前原生全app截图和debugDescription。只执行一次`dismissRegion.coordinate(withNormalizedOffset: CGVector(dx:0.5,dy:0.5)).tap()`。这是Architect新增明确授权，仅限实见关闭区域及validated outside point。若条件不满足硬失败，不改为别的点/候选/坐标循环。旧版本仍真实Sheet/Alert Cancel按钮路径。
2. 不删/改旧48行为断言原文及FIX04追加行为检查，不把取消替成Remove。可将原Cancel `.tap()`调用改成窄helper完成上述操作；返回后保存取消后全app截图，原removeButton/Done可用、照片仍count1及之后确认Remove→empty→真实再导入→同project/asset terminate/launch→dark全部保留。精确Remove action仍限定真实Sheet/Alert，不得全app同名按钮任取。
3. 新日志/截图前缀INTERACTION-VERIFY[confirmation]，提供真实窗口层级和frame/center/动作策略。不得fixed sleep、手工重试、skip、forceTap、私有API或产品测试钩子。
4. 实际Windows独立检查：与8d1f954比所有现有body断言有序子序列保留、80+5=85methods不变，Swift语法/结构校验/diff check。报告`.ai/reports/STAGE-02-PREFLIGHT-FIX-05.md`，如实Xcode/新取消/恢复/深色尚未执行。READY_FOR_ARCHITECT_REVIEW后停止，若需工具精确identifier豁免先报告，不自行扩大。

大字号help/current已实见，最大accessibility-extra-extra-extra-large，但本任务不改字号/workflow。当前失败解决后Architect单独安排该环境。不得在报告把能力日志等同大字号已通过。

03:08排队、03:12实际送达实现复审补充：popover要求count==1后.element，该Popover内Sheet label精确等于问题标题且count==1，标题和说明查询限定到同一Sheet；不使用任意popover.firstMatch或全app相似文本替代归属。捕获popoverFrame后与regionFrame同时再次finite/nonempty/正宽高验证。其余断言与范围不变。
