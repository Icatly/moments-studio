# Stage 02 Architect Review — Round 01

2026-10-03，Architect。结论：CHANGES_REQUIRED；当前Stage02继续修正，不开始Stage03。Windows实际结构/语法校验通过，36 Swift文件/124工程对象；不是Xcode类型或运行证据。原Stage01模型/fixture保持不变，原始Prompt SHA256仍为7D73E49676040B678292F7F5982B95784AEDB8B2E1FBE2E308A04EA2E8FCAA1B。DSH初版59单元+4UI报告未执行；实现中修正新增后当前统计67单元+4UI，尚未执行，最终数量以macOS实际输出为准。

先前13项实现中检查见 STAGE-02-INFLIGHT-NOTE-01.md，DSH已确认修正。以下是修正代码的再次检查（FIX01含附加第6项真实alpha/协调器行为测试），授权精准任务 STAGE-02-ARCHITECT-FIX-01.md：

1. **P1 类型返回契约**：PhotoFileTransfer.transferRepresentation 的 importing闭包现在直接返回stageCopy的URL，未构造PhotoFileTransfer。该类型的Transferable表示必须返回自身；保留async文件复制，将URL包装为PhotoFileTransfer。Windows parser不检查泛型/返回值类型。
2. **P1 staging路径边界**：stageCopy没有验证Temporary父目录symlink，目标复制/失败remove可越过库根；文件复制后缺少取消检查，可在已取消任务中返回未清理文件。PhotoLibrary.removeStagingCopyIfOwned只以输入lastPathComponent拼自有Temporary路径，未确认传入URL确实是该路径，不能称为ownership检查。与library已有规范一致：canonical root+期望相对路径严格匹配，拒绝子路径symlink；只删当前收到的自有UUID暂存文件。
3. **P1 staging清理错误被吞**：discardStagedFile创建warnings后丢弃，协调器看不到删除失败。用户需要知道临时文件未清理，后续恢复重试；保持最小内部结果传递，不新增公开Codable字段/清理服务/协议。
4. **P2 文件事务输入验证**：import只校验加入照片后的package；remove/writeManifest没有共享验证，remove把传入未来schemaVersion包直接重新构造成schema1，可能写入不能重新读取的非法照片引用/尺寸。mutation入口拒绝未知schema与非法输入，最终写入再保证共享校验；不要修补或重置坏package。
5. **P2 像素上限计算**：metadata.pixelWidth*pixelHeight在上限检查前计算，极端损坏属性可Int溢出。用正尺寸前置条件与除法/overflow检测做上限判断，超限按可辨错误返回，不制造崩溃。

6. **P2 测试缺口**：SyntheticImageFactory hasAlpha仅添加通道，绘制全部alpha1，透明保留断言目前只检查扩展名；协调器的单mutation防覆盖还没有真正的行为测试。已批准限定的内部file-loader闭包接缝用于需要的确定性测试，不引入仓储协议或生产测试入口。核心fixture生成失败不能skip冒充通过；HEIC skip须披露不构成支持证据。

性能：本次未运行，不声称流畅或真实内存预算通过。视觉：保持基础原生功能壳，未做最终UI批准。运行门槛：修正报告与再次Review后才进行当前commit macOS build/test与Appetize验收；现有Stage01包不是Stage02证据。
