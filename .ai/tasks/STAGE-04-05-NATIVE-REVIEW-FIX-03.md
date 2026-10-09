# Stage04真实失败 + Stage05 FIX02补正03

Architect已实际收集Stage04 run37957684567，冻结edeca4d，155运行/153通过/2UI失败/0跳过；146单元全通过、iphoneos Release编译与产品校验通过。私密原始证据`.ai/build/stage04-run-37957684567-20261010-003618/evidence/`，zip SHA256 ac086b438e303a814b8e64c0999c5758706e3d6de8bb21da5e5265b839f662f2。DSH先读实际证据再修，不能盲重跑或削弱断言。

## A. Stage04实际路径失败

1. Stage02ImportUITests.swift:155：`prepareEditorGallery`滚到photoCount即停，count y852.3高15.7已进窗口874，但后面的LazyVGrid还未被实例化，thumbnail仍false。层添加缩略图真实存在、count1说明导入已完成，不是照片丢失。截图23B4B0C0…png及issue C1F1B93A…txt已核。批准**最小修改现有共享helper**以定位并滚到实际图库：限定唯一编辑器滚动、count==1、picker/preview不在场，保持有限正frame/nav裁切/慢拖上限；可使用已有真实图库容器/有界从count向下实际滚动以实例化网格，随后必须保留原thumbnail存在、唯一身份、完整视口可点、预览/删除等全部断言。不得改Stage02测试断言/增加等候充当修复；必要新增生产AX标识须解释真实位置，不能生产测试开关。
2. Stage04LayoutUITests.swift:44：搜索OFFSET后`layout.choose.offset`存在frame(16,541.3,110,20.3)，layout.scroll整个(0,62,402,812)，键盘/search仍活跃，choice不能hittable。原始C1B41C30…txt和记录6F614D37…mp4。限定layout.scroll扣除真实nav/keyboard形成可用视口，必要通过真实搜索提交/收键盘让选择可点；用户正常搜索必须仍能选择并Apply。保留搜索OFFSET、无结果、已选Offset保留、清搜索、重复Apply层ID与变换重启全部断言。不可直接坐标穿透/跳过hittable/盲滑；必要原生SwiftUI最小搜索结束交互由你实施。是否产品层需要修须基于实际证据说明。

## B. FIX02仍有编译与请求生命周期缺陷

3. `PhotoAnalysisSheet.swift`行41和213有**两个同名isSheetCurrent计算属性**，静态tree-sitter不检重复声明；必须消除编译阻断，并主动扫描新增代码同作用域重复成员，不能只宣称语法通过。
4. FIX02 startRun不生成新token，metadata的`.task(id:)`重启会复用旧token和旧结果；旧任务defer可把新isRunning改false。最小修正：每个真实新task在**检查!Task.isCancelled / 捕获的任务key仍当前 / 当前sheet之后**原子产生新token并清旧数据，不能让过期task清新state；重算/Close动作先即时invalidate，onDisappear兜底。项目变更确保run.projectID与该project一致。按实际采用的请求模型测试旧token成功/失败拒绝、新metadata新token、无误清旧回写；不需新服务/调度器/人为延迟。

Stage04两个冻结工作流保持不改；修复后最终Stage05完整suite应含保护的155项+实际新增全部项，作为两个阶段的同源回归，无需先盲重跑Stage04入口。实际计数更新Stage05清单/报告/工程。DSH当前约61%，65%整理接续，70%安全点落盘提示Architect续开同工作区。交付READY_FOR_ARCHITECT_REVIEW；原生/新IPA/本人尚未通过，Stage06禁止。
