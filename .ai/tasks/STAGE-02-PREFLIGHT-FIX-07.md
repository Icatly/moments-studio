# Stage02 FIX07 — 实际导入后的屏下图库与主按钮截断

2026-10-05 09:02 Architect。原任务范围仅当前Stage02，今天无需逐项审批；Stage03禁止。

先读第七轮原job.log与失败层级（`.ai/build/downloads/run-37248700016/`）：run37248700016/source590ccf34f8fba8cfe11dcad13b4f99a65dafd425，08:44:58–08:57:56实际12:58，85/84/1/0/0。失败154行thumbnail.waitForExistence90，145.660秒。完整artifact124,915,141bytes SHA043b42a34559a34b57661f6dd200303ac438b782e1c00d52a93d824f0f38113d匹配GitHub。原job808551bytes；AX DF6EF151-B5E7-4308-891D-130A61823132.txt。

实际日志/原始PNG证明FIX06唯一Close一次成功，photo count0→9；元素相对中心选择真照片、Done启用并返回Editor。失败时Editor确实`editor.photoCount`为`1 of 20 photos`、项目状态Photos1/Saved on deviceYes；不是导入未完成或原图丢失。Editor视口874高、真实nav(0,62,402,54)，photoCount(16,920,268,52.7)，gallery位于其下；LazyVGrid未在屏下创建缩略图AX，之前“target.exists才滚动”与先wait90存在的顺序不能处理这一实见状态。

Architect实际查看原生Home DDC2A057-095F-4DB4-9C05-B56DAC68D303.png仍Cre-/ate Proj…，FIX06外Label纵向修饰符未解决。Photos before/after Close、选中1的PNG亦实际目视真dark/最大字号。全部85未通过，预览/Popover/移除/再导入/重启/后段dark未执行到，不修改尚未失败的Popover逻辑。

## 仅允许的实现

1. 仅`MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`：在初次thumbnail存在等待、再导入存在等待、恢复/深色资产ID枚举，以及移除/确认移除等thumbnail查询前，增加一个最小Editor图库准备调用。只有当前thumbnail未exists才处理；用真实唯一`app.staticTexts[editor.photoCount]`的已提交`1 of 20 photos`作为锚点，必要时有界等该真实label（最多原有90秒），然后调用FIX06已审的Editor有界滚动helper让该锚点进入真实viewport。实际photoCount目前y920，在screen下；不能把不存在thumbnail的frame当有效或猜坐标。锚点已可见却thumbnail仍缺失时原存在/ID断言照常失败，不继续盲滚。默认thumbnail已exists不增加手势。保留所有99现有完整断言原文/顺序及80+5方法。新helper只是本UI路径小函数，不改产品LazyVGrid、不改变素材标识/去重/原PhotoCount及ID断言。截图/层级显示gallery准备前后；PhotoCount1不是预览完成证据，原缩略图/typed preview等旧断言仍决定通过。
2. 仅`MomentsStudio/MomentsStudio/Features/Home/HomeView.swift`的createProjectButton：按FIX06报告已提的最小替代把现有Label title写成显式`Text("Create Project")`，在该Text上`.multilineTextAlignment(.center)`、`.lineLimit(nil)`、`.fixedSize(horizontal:false,vertical:true)`，icon仍原plus，原系统字体/颜色/44/按钮style/动作/identifier/ready全保留。可移除已经无效的外Label两修饰符避免重复，保持最小差异；无其他Home布局重设计/文案/导航改动。无native环境，不能声称已消除截断。
3. workflow、Photos唯一Close、照片相对中心点击、Popover相对中心取消逻辑、所有其他产品/契约/依赖/工程/tools全部不改。独立报告`.ai/reports/STAGE-02-PREFLIGHT-FIX-07.md`与交接日志。真实clock不具备时仅写日期/任务时刻，不自填未来时间。
4. Windows必要静态验证和99完整断言比对如实记录。DSH只到READY_FOR_ARCHITECT_REVIEW，不commit/push/cloud/付费/账户/Stage03。上一轮13整分估$0.806，七轮合计$6.076，旧截图推剩$0.464，不足18+2完整下一轮；本任务明确仅本地实施/复审，新native验证未执行。不得绕过85门禁或开启另一次云任务。

证据措辞边界：原dump直接证明photoCount1/SavedYes且无缩略图AX、图库所在段在屏下；结合产品LazyVGrid源代码推断惰性布局/AX未暴露是当前原因，不能宣称已验证Apple内部节点创建机制。修复只按实见photoCount位置模拟用户滚动，仍由后续原断言验证thumbnail真正出现。

## 09:07初稿复审
图库准备须严格Editor上下文先验/唯一真实count锚点；用XCTNSPredicateExpectation/XCTWaiter真正等exists与label1最多90秒，不能只等节点存在再立即读label（初始0可能先存在）。原99断言保留。注释仅写实际锚点存在但屏下；惰性AX解释是推断，Home Text换行是意图而非已经native通过。
