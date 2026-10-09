# Stage04本地源码Review — 2026-10-09

范围：[Stage04规格](../../docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)。本记录只覆盖源码与本地检查，不作为最终技术或本人验收。

- 架构：布局只读元数据、返回普通CanvasDocument；不改公共序列化字段。RootView集中路由并传原有环境对象，不新增平行store或文件写入通道。
- 数据保护：预览无写入、Apply单一gate；已有锁定/隐藏/未绑定层与baseSize/身份/堆叠保留，空画布使用确定性层ID，重复应用不添加。布局失败为rejected，真正文件失败保留draft并按最新目标Retry。
- 几何：完整等比例容纳，旋转边界留余量，枚举网格稳定，已有scale范围内失败时拒绝，不自动裁切或更改旧文档范围。最多20层，轻量计算同步；图像I/O复用actor与缩略图。
- 交互：三方向都有用户照片预览，可滚动发现；搜索仅筛选内置预设，明确所选状态，取消不提交。沿用中性临时视觉，最终效果需原生截图/本人确认。
- 验证：新增17个有效XCTest方法保留旧138项；工程、脚本解析、155方法清单及10个合成结果门禁例子已执行。实际XCTest/设备包/视觉/手势尚未执行，Windows脚本不证明Swift类型正确。

结论：本地实现交READY_FOR_ARCHITECT_REVIEW，需完整原生运行后继续复审。暂不转WAITING_FOR_USER，也不称Stage04通过。限制与证据见[实现报告](../reports/STAGE-04-IMPLEMENTATION-2026-10-09.md)。
