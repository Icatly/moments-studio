# Stage04/05独立源码复审（原生结果另记）

实施/修复由DSH，Architect只读实际源码、写规格/Review、执行验证；现有Stage04早期Architect直接实现的来源已如实保留。所有者明确授权完成两个阶段，不替代本人APPROVED，不延伸Stage06。

首版及FIX01–03实际代码逐轮读后退回DSH；明确指出的重复声明、错误AX容器、无效滚动门槛、过期metadata/项目身份/取消/token、sRGB回退与路径覆盖均按任务编号留痕。Stage04第一次原生153/155的完整失败证据见[原生Round01](STAGE-04-NATIVE-ROUND-01-2026-10-10.md)。

00:49独立源码/工作流检查：176单元+10 UI=186的实际清单与工作流门禁相符；6个公开持久化模型逐字节保持，18个旧测试/支持文件保持，Stage04两冻结工作流保持；57 Swift语法树无ERROR；Stage05 tests 16 Bash/7 Python与device 4 Bash/4 Python语法通过。这里只是静态，尚无Stage05编译/XCTest/IPA/本人结果。私密证据`.ai/build/stage05-independent-20261010-004947/`不公开。

最终[FIX04](../tasks/STAGE-04-05-REVIEW-FIX-04.md)已实际发送既有DSH：dismissSearch父层环境无效且有效时会清查询，要求收键盘后保留筛选和严格视口；Close即时invalidate；标准macos26稳定Xcode26+设备工具链与测试统一，6分钟/2天无签名。该搜索结论依据[Apple官方dismissSearch](https://developer.apple.com/documentation/swiftui/environmentvalues/dismisssearch)与[搜索激活管理](https://developer.apple.com/documentation/swiftui/managing-search-interface-activation)。交付后继续独立复审并冻结源码；本文件尚不构成技术通过。

## 01:07最终源码检查点

旧DSH实见70%完整交付后保留，在同一工作区新DSH实际接续[FIX05](../tasks/STAGE-04-05-DSH-CONTEXT-HANDOFF-2026-10-10.md)，已见实际交付/空闲14%。最终布局导航按真实Layouts标题精确匹配，并核拥有Cancel/Apply，删除误加全App导航数门槛与未验证AX传播；drag由真实viewport几何换算为layout.scroll相对归一化端点。搜索提交采用isPresented绑定且保留查询，提交后过滤/无结果/已选项回归保持；Photo summary.Close同步invalidate，await前后核项目/asset/尺寸/metadata/key/token/cancel，旧任务不清新状态。实际代码已独立读，无公开模型/依赖变化。

独立实跑verify_project通过166对象/58引用/57 Swift；源码语法、18个旧测试文件、6持久化模型和Stage04冻结workflow保持；Stage05源码176+10=186，两个workflow YAML/Bash/Python通过，tests16 Bash/7 Python、device5 Bash/5 Python。私密原始检查`.ai/build/stage05-independent-20261010-010653/`。源码级可进入冻结与原生验证；**Stage05尚无Xcode结果，新IPA和本人验收未执行**，两个阶段都不APPROVED。原生仍须验证实际Layouts AX与搜索保留、CoreGraphics像素、分析UI链和全旧回归。
