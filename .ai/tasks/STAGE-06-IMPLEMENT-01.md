# Stage06 DSH实施任务01

所有者2026-10-10明确“进行stage06”，Stage04/05已完成三组真机验收APPROVED。[Stage06规格](../../docs/architecture/STAGE-06-PHOTO-ROLES.md)为Architect批准边界，先读[工作须知](../../工作须知.md)、根交接最新状态和真实代码。不要用旧DSH接续文件的Stage06禁止覆盖新授权。

1. 批准仅ImportedPhoto新增可选roleChoice（role/source）；旧缺键/nil不新增编码键，schema2/其他公开字段不变。严格角色/来源/primary唯一验证，保留旧schema1/2及186方法断言。
2. 现有PhotoLibrary actor内用Apple Vision + Stage05统计，320px/20张/逐图、原路径守卫、值类型结果、取消token/项目metadata guard。纯确定性策略生成主图/配图，人工优先，不自动删图/拼贴；失败真实，Vision观测不落盘，不美颜。
3. 可选Editor顶部Photo roles入口与Root sheet路由；自动建议/四角色/Automatic、重算、Cancel/Save choices。明确保存接受自动建议及manual选择，重开保留；复用同一mutation gate/原子manifest，写失败保留草稿Retry/Cancel、过期拒绝Reload，不丢画布失败草稿。
4. CollageLayout使用已保存角色：完整照片参与、空画布不添加collage/excluded；现有其他层保持，Focus可编辑主图计算位置优先，但不改layers顺序/锁定隐藏/IDs/opacity/baseSize。预览与Apply同源，无选择维持原Stage04行为。
5. 有效策略/序列化/真实存储/布局/真实Vision请求/关键UI回归；新Stage06 tests/device工作流完整scheme/实际方法数/原始证据，同免费稳定Xcode标准macos26，40/6min。旧Stage04/05工作流保持字节，禁止旧方法删减/跳过或新增生产测试入口。
6. 更新工程/README、`.ai/reports/STAGE-06-IMPLEMENTATION.md`、必要验收说明：文件列表/契约/算法真实选择/执行及未执行/限制/方法清单和旧186保护。仅本地实现，禁止自提交推送/派发/付费/账户更改/Stage07。交付停READY_FOR_ARCHITECT_REVIEW，由Architect独立Review。

baseline原生/手机源码fe17ac0d00db53629228f3ff972b5b83d563b551，完整186/186；当前Git main文档提交f8efc60fbc2578e959f85c5ce3dbdb3926d8529f，另有本轮验收文档与历史脏文件。不要reset/clean或覆盖无关变更，`.ai/build`私密不公开。上下文到70%先落盘再同工作区接续，不伪称未观察阈值。

分派状态：SPEC_READY/任务已准备，实际发送/运行/交付由Architect观察后另记。实现有规格矛盾先报告最小方案，勿擅自扩大。

2026-10-10 10:51实送记录：Architect通过既有同工作区DSH会话提交任务01；实见消息出现在会话，随后DSH“正在分析请求”/“深度求索中”，上下文21%。当前IMPLEMENTING，尚未交付/Review/原生验证。
