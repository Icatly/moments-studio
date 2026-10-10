# Stage06 实现中独立Review补正03 — 实际UI草稿与任务边界

读取PhotoRolesSheet/PhotoRolesRun初稿发现真实交互问题，请与任务01/补正01–02一起修，不仅修静态辅助函数：

1. Automatic setter移除manualRoles键，但getter/candidates/choices()都fallback到photo.roleChoice，导致已保存manual无法回Automatic；同时source automatic被当作manual而冻结旧建议。用可区分“未改/明确Automatic”的真实草稿状态，或在初次加载把**仅source manual**存入本地manualRoles，此后直接从草稿取人工角色、nil就Automatic，完全不fallback到保存角色。Save自动结果用本次suggestion物化；重新分析保留人工草稿，不能保留旧automatic为manual。Use suggested roles明确清当前人工草稿。测试实际UI及它实际使用的值模型：保存manual→重开→Automatic→重算/Save；保存automatic→重算允许刷新；修改主图时先前manual primary按规格降supporting（当前picker setter未处理）。
2. Save()在点击瞬间从store取fresh snapshot，不是产生/展示选择时的原快照，不能保护过期草稿。初次加载/明确Reload捕获原完整metadata/roleChoice快照，保存只提交该快照；保存时store已变须拒绝/提示Reload。Analyze again不能悄悄更新草稿的预期快照。Reload重新载入当前保存选择及期望快照；请求写回/显示signature统一包含roleChoice，可复用同一实际签名不要分叉。测试UI实际状态模型的roleChoice/metadata变化后旧Save拒绝。
3. isSaving时缺interactiveDismissDisabled，可上划关闭写入中的sheet；保存后只用旧sheetWasCurrent bool，会关闭后来别的sheet。添加保存期间禁止交互关闭，成功后核**当前**navigation.sheet精确等于本project Photo roles才关闭；Task完成不关闭其他项目/其他sheet。Cancel即刻失效token，late结果不回写。
4. PhotoRolesRun.candidate目前直接Int宽高相乘，对合法Int但极大/损坏元数据可溢出trap；用有限、正值和multipliedReportingOverflow（或同等标准库安全策略）拒绝，不clamp到最大面积冒充主图。覆盖真实候选入口及非法维度，旧ImportedPhoto字段策略不要无关改动。
5. 保留可理解的Analyze again入口（初稿只有Reload），区分“重新分析保留人工草稿”和“Reload解决过期重新载入”。IO保存失败保持草稿且有Retry/Cancel；save按钮不能把完全相同的保存状态反复写成新成功。至少实际UI自动/人工来源不夸大、partial failure不把照片不用。

这些是初稿问题，当前IMPLEMENTING，不是原生失败或已完成交付；在DSH报告明确逐项回应。不要以新helper测试替代真实UI路径，保持186旧方法和原断言。
