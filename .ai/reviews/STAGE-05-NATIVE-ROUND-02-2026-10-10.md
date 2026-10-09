# Stage04/05 原生第二轮 — 184/186，需修复

[run37966461191](https://github.com/Icatly/moments-studio/actions/runs/37966461191)，源码`5369354cb7a3efee264f8ab6c61e9bf50e42c2b4`、attempt1、标准macos26，实际Xcode26.6 / SDK26.5 / iPhone17Pro iOS26.5模拟器。App和测试target编译通过；完整**176单元全通过 + 8/10 UI通过 = 186运行/184通过/2失败/0跳过/0预期失败**。Stage05新增30单元+1 UI均通过，不外推整套回归通过或本人批准。

1. **产品入口回归**：Stage02旧导入取消测试:58，真实AX显示无Photos picker；编辑区ScrollView y436...874，导入按钮y872.3...916.3、中心894.3越出窗口。新增Photo summary独立行把旧导入位置推后68pt，原本正常的直接点击未打开图库。Architect批准将两个可选入口放同一原生HStack，保留44pt/ID/禁用条件/导航和其余段顺序；不改Stage02旧测试、共享helper或增加等待制造通过。
2. **错误测试前提**：Stage04布局测试:69，精确Layouts navigationBar查询已找到唯一1个，但其label实际为空。此前FIX05额外label==Layouts检查是Architect未以原生证据验证的假设，现按实际identifier映射删除；仍要求精确唯一identifier、拥有Cancel/Apply、严格几何与全部原始行为断言，不添加新猜测。

修复由DSH按[FIX07](../tasks/STAGE-04-05-NATIVE-REVIEW-FIX-07.md)执行，Architect不代写App/测试。独立已读两文件差异：仅单HStack包装原按钮及删除新加的错误label前提/改注释；Spacing.small=8pt、minimumTapTarget=44pt，符合ui-ux-pro-max本地移动Touch Spacing/Touch Target Size匹配，沿用临时原生样式，不定义品牌。公开模型/所有Stage01–03测试/其余源码与workflow均保持；57语法/176+10清单本机再次通过，私密`.ai/build/stage05-independent-20261010-015355/`。修复版原生尚未执行；完成DSH交付与精确冻结后新一次完整186验证。

原始zip193223173 bytes，SHA256`556d3e1ce19033b4fcc675e63d9c368d29a6422767be2c97181bd44fdcffc77f`，下载与GitHub digest一致、解包/source核验通过。Windows默认GBK令collector仅在最后读取Unicode summary时报错；修成显式UTF8后，复核已下载zip与每个解包文件相同并补写集合记录，**未重下载、未重跑云测试、未丢失原证据**。目录`.ai/build/stage05-run-37966461191-20261010-014726/`保持私密。

历史155/153/2及首轮编译失败0测试均保留。两阶段CHANGES_REQUESTED，尚无新IPA/本人验收；Stage06未授权。上轮FIX06实际解决共享扩展编译冲突，不能替代本轮UI根因修复。

01:55已观察DSH完整FIX07交付并停止（23%）；最终两Swift差异与前述独立复核一致，其余App/测试/工程/工作流不变，报告与私密manifest更新。准备精确5文件修复提交及一次完整186原生验证；不声明新源原生通过或本人APPROVED。
