# Stage05 DSH实施任务

所有者已明确“把stage04和stage05都做了”；范围由Architect决定见[Stage05规格](../../docs/architecture/STAGE-05-PHOTO-ANALYSIS.md)。实施由DSH，Architect独立Review。当前SPEC_READY，尚未实施；Stage04检查点复审后由Architect实际发送启动，不把文件存在当已发送。

1. 实现实际使用的PhotoAnalysis值类型与PhotoAnalyzer；有界sRGB采样、透明处理、指定统计/采样置信度和类型化失败。禁止语义/美颜/AI概率夸大。
2. 复用PhotoLibrary actor的安全派生图路径，新增项目/asset只读分析方法；PhotoImportModel只读桥接，不写store/manifest或mutation草稿。不改公开Codable字段。
3. 新集中photoAnalysis sheet路由、Editor可选Photo summary入口、结果与失败/取消/重算；顺序最多20张，过期结果不跨项目回写。保留所有原照片/图层及保存交互。
4. 写有效单元/真实文件事务/UI smoke和手动原生测试/设备工作流；保留既有155项/原断言，精确实际新增数量门禁。不要引入运行依赖或生产测试按钮。
5. 更新工程/README和`.ai/reports/STAGE-05-IMPLEMENTATION.md`：源文件列表、真实清单、实际执行/未执行、统计算法选择、限制、待原生/本人验证。交付后停READY_FOR_ARCHITECT_REVIEW；不得进入Stage06。

默认本地实现权限，不自行git提交/推送/云派发/付费/账户设置。公开提交/实际原生验证由Architect复审后组织，全部证据与源码绑定。静态失败修根因，不能放宽测试制造通过。
