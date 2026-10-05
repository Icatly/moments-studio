# Stage02 FIX06 — 最大字号下真实用户操作补齐

Architect 2026-10-05。第六轮run37230253288/source64fb192实际04:12:17结束failure，85/84/1/0/0；80单元及其他4UI通过，完整路径133行照片选择失败（photos存在scope，但PXGGridLayout-Info count0）。真实最大content_size与dark设置、测试后持续读回、还原均双exit0/精确值。完整76,876,546bytes artifact SHA951fd7c4833d2fc9e1f6adfc8f248fd3e8b04fa661e887daece82bdcc7103acf已匹配GitHub；原job.log756332bytes。

先完整读本地`.ai/build/downloads/run-37230253288/job.log`故障附近及`failure-attachments/2E070560-7350-4C4F-801B-0644D838AEA2.txt`，Architect已用Windows原生WPF解码实际录屏请求40秒帧`recording-frame-40s.png`并目视：真实深色、最大字号的系统Private Access说明占满可视区，关闭X实际可见，照片还在下面。仅抽帧审阅，未完整播放视频。不要宣称产品坏/权限失效/没有照片或换scope。

实际层级：scope ScrollView photosView_content_scroll_view frame(0,72,402,802)；Other PXGSingleViewContainerView_AX唯一，frame(0,184,402,896.7)、label Private Access…，其内Button label Close frame(350,192,30,22)；外部重复banner也有Close，不得用app.buttons.Close或firstMatch掩盖归属。photos_sectioned_layout的网格从y1080.7起、在874屏幕下面。Editor真实ScrollView内容2256.3高/4pages，正文559.3高，Import125.3高从y786.7起，count920/empty988.7；最大字号路径需要真实用户滚动，不能把屏外元素存在当可操作。

范围只允许`MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`以及workflow的timeout20→18（下述预算决定），独立报告`.ai/reports/STAGE-02-PREFLIGHT-FIX-06.md`和交接日志。产品/Swift模型/接口/原图/工程/tools/依赖全部不改；原87条body断言原文及顺序完整保留，仍80+5方法/85门禁/2day/no cache/guard/app包装/环境apply/读回/restore不变。不commit/push/cloud/付费/账户/Stage03，不重复已完成工程检查。

1. 在modern照片选择分支、原photo等待前，仅针对真实overflow onboarding进行一次原生关闭：要求scope存在且唯一观测AX container、框架finite/正、container高度大于可视scope且当前photo count0；不符合overflow条件走旧默认路径不改。Close只在该AX container内唯一查询，wait enabled+hittable，frame在scope/app内；before/after keepAlways截图/实际层级与计数记录，一次Close.tap，不用私有API/绝对坐标/多次点击。关闭后回到原photo存在/有效frame/相对元素中心单次选择和Done启用、真实导入等全部断言，失败硬报具体证据。不要改系统权限，不隐藏实际照片。
2. 在**Editor内**对import/已导入thumbnail的可操作等待与点击，允许一个最小有界用户滚动helper：只在当前目标exists但不可hit、且实际Editor导航和唯一Editor ScrollView成立时，至多3次该ScrollView原生swipeUp或swipeDown，方向据真实目标frame相对viewport；每次重读目标/可操作性，失败返回false并保留原断言。不是点击重试；不可用于系统picker/preview/全app跨scope。已可hit默认路径不做手势。确保首次thumbnail、再次import、恢复后/深色Editor目标均使用该helper再保留原wait/assert，不删断言、不跳过用户路径；不预建通用滚动服务。Scroll方向若真实frame无法决定，硬失败，不猜屏幕坐标。导航操作仍用现有精确project/asset标识。
3. Popover取消保持FIX05原逻辑，本轮没有到取消，不猜新的失败或做未定位修改。照片中心点击/default旧系统分支也保留。新keepAlways截图便于下一次实际审核。
4. 云时限只20→18，其余workflow逐字保留。依据第六轮14:18按15min估$0.930，前6轮合计$5.270，所有者截图$12 included减$5.46推算余$1.270；下一18+2min预算$1.240在估余内，不是新账单。不得压缩测试/忽略失败，若18min超时也真实failure，不自动重跑。真实运行须Architect复审完成再单次触发。
5. Windows范围diff/语法/工程现有必要验证及原87断言顺序保留检查如实记录；没有Mac，不声称新关闭/滚动native通过。DSH停止于READY_FOR_ARCHITECT_REVIEW。今天Stage02免逐项审批，本人亲自操作未执行；Stage03禁令保持。

## 04:22实际画面补充：唯一允许的小型产品布局修复

Architect又用同一原始录屏解码并实际查看请求6秒/9秒帧：Home与Editor均真正深色且最大字号。Home原生导航大标题截断是系统表现；但主操作Create Project实际显示“Cre- / ate Proj…”且省略尾部，主按钮操作词不可完整阅读，属于当前Stage02真实视觉缺陷，不能用测试操作通过掩盖。

扩展允许文件仅`MomentsStudio/MomentsStudio/Features/Home/HomeView.swift`中现有createProjectButton Label的最小垂直自适应修改，优先对现有Label/Text应用`.fixedSize(horizontal: false, vertical: true)`、多行居中，保留原Create Project完整字符串、系统语义字体/plus/动态颜色/最小44/创建动作/identifier/启用与ready行为。不得改导航、模型、copy、品牌、依赖或其他product文件；若固定纵向仍不能保证完整，先报告最小替代方案（原生Label的title Text自适应），不重设计Home。

原完整UI路径在创建前增加keepAlways初始Home截图，供下一轮真实最大字号原文是否完整审查；不添加镜像常量测试。现有87断言仍全部保留。本轮仅新增此真实证据定位的微小布局修复，产品范围变化如实列出，不再写产品零改动。原3×12MP性能不受此布局改变；新版Home视觉仍未native验证。

## 04:26初稿独立复审必须修正

当前scroll helper只以navigationBars.count==1证明Editor是不足的；它一次算target.midY相对app.midY后最多三次固定方向也违背任务：即使target在可视区被覆盖仍盲滚，后续frame跨过目标也不改方向。需guard实际editor.placeholder存在、无Photos/Preview导航、唯一Editor ScrollView；viewport取scrollView与app交集、排除实际Editor navigationBar.frame覆盖区，finite/正。每次循环重新取target/frame/viewport：只有目标超过可视底边才swipeUp，超过可视顶边才swipeDown；在可视区却不可hit或frame非法就返回false/诊断，不按app中心猜方向。至多3次native swipe，默认可hit不做手势。

另外初稿漏了4个现有Editor可操作断言前的用户滚动：editorAfterRestore；restoredDone后；darkDone后；darkProjectRow重新打开后。补调用但保留这4个旧XCTAssert文本逐字，不改原待断言表达式。新增8个滚动断言是初稿计数，不是固定最终断言数；报告按实际统计（原87保持）。Popover/Photos坐标单次点击原文完全不改。

## 08:36部分溢出边界复审
当前helper只处理完全屏外而遗漏第六轮实见Import部分溢出。须targetFrame.maxY > viewport.maxY则swipeUp；targetFrame.minY < viewport.minY则swipeDown；完全在viewport内部却不可hit才false。每次重读app/scroll/target frame；Editor navigationBars.count==1才用.element，navigation frame无效硬false。仍至多3次、保留99当前断言/85方法。报告清除旧35/95计数或明确历史；今天免审批与本人未操作分别记录。
