# Stage04实现任务

执行角色：DSH（Implementation Engineer）；Architect负责规格与独立Review。2026-10-09所有者提醒后恢复既定分工：已有本地代码、测试与工作流实际由Architect直接写入，尚未交DSH执行，不能称为DSH交付。接手时先核验现有差异及实现报告，在批准范围内完成必要修正与工程/测试工作，保留无关未提交文件，不重复重做已有实现；真实派发与执行结果另行记录。

来源：所有者“进入stage04”；Architect规格：[STAGE-04-DETERMINISTIC-LAYOUT](../../docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)。允许本阶段确定性布局、三真实照片预览与内置关键词搜索、显式Apply保存。禁止扩展为AI/云/多页/导出/最终品牌或第三方依赖。

1. 实现纯Foundation布局，复用现有几何与图层；输出既有CanvasDocument，无序列化字段变化。
2. 新增RootView集中sheet路由，显式复用环境对象；编辑器入口、三预览、搜索、取消/应用与实际失败反馈。
3. `.layout`意图复用PhotoImportModel单一gate和draft/Retry/Discard；锁定/隐藏层不变，重复应用不新增图层。
4. 新增有效XCTest、真实文件事务和UI smoke；保留旧138项及原断言，不把静态检查写成运行通过。
5. 用既有标准库脚本维护工程与结构校验，不新增App依赖。报告列出实际执行/未执行、限制和需本人检查项。

实现者只能到READY_FOR_ARCHITECT_REVIEW；Architect在真实构建和Review具备后交WAITING_FOR_USER。Stage04未验收，下一Stage不自动开始。
