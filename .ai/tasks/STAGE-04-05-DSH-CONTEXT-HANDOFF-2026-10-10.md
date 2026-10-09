# Stage04/05 DSH 70%同工作区接续 — 2026-10-10

旧DSH会话Stage03图层UUID与重启恢复测试于00:55观察70%、FIX04交付后空闲。保留旧会话；新DSH仍为D:/朋友圈生成应用、One-click generation for Moments，不新建仓库。所有者明确让DSH实施、Architect决定规格/独立Review，并授权完成Stage04和Stage05；Stage06禁止。先读工作须知/AGENTS/根交接最新快照，本文件优先于旧阶段停止历史。

## 实际状态

- Git main本地/远程edeca4ddaba03c727a7779bbbf042d899e408222；Stage04冻结27文件已推。工作树有Stage05新代码和无关旧脏文件、私密.ai/build（不ignore）；不reset/clean，不git add宽泛，不自推送/云派发/付费。Architect组织精确公开提交和验证。
- Stage04原生run37957684567真实155运行153通过2UI失败/0跳过，146单元全通过，设备编译成功；原始结果`.ai/build/stage04-run-37957684567-20261010-003618/evidence`。两失败图库懒实例化、Offset搜索键盘遮挡已由你按FIX03/04修，**尚未原生补验**。
- Stage05按规格`docs/architecture/STAGE-05-PHOTO-ANALYSIS.md`实现只读sRGB64px光色统计、PhotoLibrary actor/桥接、集中sheet/summary、自身PhotoAnalysisRun身份/token/key guard。DSH报告`.ai/reports/STAGE-05-IMPLEMENTATION.md`已按FIX01–04更新；首版本172/180历史，当前真实176unit+10UI=186。6publicCodable/schema2未改，旧155全保留，Stage04两个工作流字节保持。
- FIX04结束：searchable isPresented binding false提交保留query（仍待实际验证）；Close当前动作invalidate且onDisappear兜底；Stage04测试新增严格viewport；Stage05 device标准macos26/稳定Xcode26+/SDK26+选择、6分钟/2天/无签名。两阶段新IPA/手机本人验收均未执行，手机仍Stage03，不APPROVED。
- Stage04先前direct代码来源Architect已承认，恢复分工后所有App/tests/workflows改动由你完成，Architect没有代改产品代码。

## 新DSH本轮唯一修复任务（FIX05，小范围冻结前Review）

1. Stage04LayoutUITests.usableViewport目前要求**app.navigationBars.count==1**，但这是整个App，sheet背后的Editor也可能暴露。不能把全App唯一当对应sheet唯一。改为实际Layouts导航标识/title精确scope并核恰一（必要结合布局sheet真实AX，不盲firstMatch）。保持scroll唯一、所有finite positive/扣导航键盘/目标完整视口/不可点失败。拖拽把实际viewport端点换算为相对**layout.scroll**的归一化坐标，不用app起点+绝对屏幕几何offset（app.frame可能非零）；保持慢速/最多5次/端点范围验证。

01:03补充已发送新DSH：全App navigationBars==1是FIX04新误门槛、并非冻结155旧断言，应删除；不要假定NavigationStack新增AX标签会传播成UINavigationBar.identifier。直接精确复用实际navigationTitle Layouts的导航身份/label，并核该bar拥有本sheet Cancel/Apply；不新增未验证layout.navigationBar标签传播。保留所有冻结155行为断言。
2. DSH报告表有stage05-device两行重复，FIX01–02“未改UITestSupport”需限定历史时点，当前FIX03已修改共享helper。按实际写清历史和当前，不夸大清单/XCTest/视觉通过。README Stage04第一次实际失败、Stage05无原生两者明确。
3. 在受影响当前Swift主动检查重复成员/变量（语法树不检类型）与新增searchIsPresented时现有查询/无结果/已选保留/清除/重复Apply断言保持。无需再写镜像常量测试、新调度器、持久化字段或新依赖。原生结果由Architect组织，禁止删/跳过断言换绿色。

交付：明确实际改文件、保护旧测试/公开模型/冻结workflow、本机执行和未执行、真实186方法数/源哈希及简短更新报告/根交接。然后停READY_FOR_ARCHITECT_REVIEW。Architect将独立复审、精确冻结/推送/单次完整186原生测试、通过后同源IPA，再本人分别验收；开始授权不冒充本人APPROVED。当前无需重复全旧测试静态大扫或新产品功能。
