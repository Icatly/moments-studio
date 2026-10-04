# Stage02 PREFLIGHT-FIX03 — iOS26原生照片点击与诊断

2026-10-05，Architect限定任务。所有者今天要求Stage02无需逐项审批、持续推进；第5节新授权优先旧等待规则，Stage03仍禁止。

先读AGENTS当日例外、Round25、原始run37220074605/job.log。FIX02正确scope现已找到9张照片，但第一个Image exists=true/hittable=false，test125行即失败，尚未真正点击。本轮artifact已上传，下载仍进行中，不假称已看录屏。

只改`MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`及独立FIX03报告/交接。产品/契约/依赖/工程/工作流不改，85项与全部用户路径断言保留。

1. iOS26分支：保持Photos导航就绪、`photosView_content_scroll_view`内`PXGGridLayout-Info`、首个photo有界存在；记录前3个photo的exists/isHittable/frame/label与scope frame，只当诊断。首个photo必须有限非空frame；不以当前isHittable=false直接阻止原生操作，调用一次该元素`photo.tap()`，由XCTest自己计算hit point和必要滚动。不能用屏幕坐标、强制tap私有API、无范围app.images、循环候选/重试，也不能把Apple系统根因写成确定。
2. 旧系统分支保留既有hittable等待；两分支点击后都仍须Photos真实确认控件enabled+hittable，再确认、真实thumbnail/计数/预览loaded Image/屏内frame/Done/取消移除/移除/再导入。原生tap调用本身不构成选中证明；任何点击或真实路径失败仍XCTest失败。
3. iOS26点击前和点击后各保留一张原生全app screenshot（XCTAttachment keepAlways），命名清楚。最终已有预览截图不删。这是测试诊断，不加入产品测试控件/launch注入。
4. 报告明确Windows静态验证及未运行Xcode；80+5方法不变，比较既有断言集合未删。交付`.ai/reports/STAGE-02-PREFLIGHT-FIX-03.md`，停止在READY_FOR_ARCHITECT_REVIEW，云端由Architect串行核额/执行。无需重复FIX01/02已完成实现，不自行推送/触发/支付，不开始Stage03，不覆盖已有报告。

Apple官方依据：isHittable只代表当前命中点可计算；tap允许框架尝试滚动到可点击位置。见Round25官方链接。这个方案尚未实跑，若原生tap失败保留新诊断后另行定位，不偷偷改坐标/skip。
