# Stage06 实现中独立Review补正02 — 保存契约

当前DSH仍IMPLEMENTING。Architect读已落盘保存桥接/库代码发现以下需本轮修复：

1. PhotoLibrary.roleSnapshot(of:)漏roleChoice，违反“metadata/roleChoice完整签名”；旧sheet可以覆盖在它之后已保存的新manual选择。包括role和source/nil，保证读取/保存同一完整原快照，补真实文件同asset元数据不变但roleChoice已变时拒绝，跨项目保持。
2. `[UUID: PhotoRoleChoice?]`的下标赋nil会移除键；choices()失败/Automatic无建议的nil被删掉，而saveRoleChoices对缺键continue，不能清除此前已保存的选择。请用简单完整批量语义：可用`[UUID: PhotoRoleChoice]`并规定未出现的当前asset明确清除为nil，提交仍携带完整照片快照（保证不误覆盖变化）。或必须实际用updateValue(nil,forKey:)保留显式nil并要求当前所有asset都有条目。不要把“缺键不改”与“没有建议/Automatic清除”混用。测试已有manual collage/excluded→Automatic且新分析失败→Save后nil，正常建议/失败部分同时批量存储及重开正确。
3. ProjectPackage.validate的非法组合/多个primary错误应转成真实typed `.impossible`/rejected，不把不可重试的草稿当IO saveFailed让用户Retry。IO写失败仍保留草稿/manifest与store不改。禁止为此引入第二个mutation gate/写Store绕过actor。

只修已批准边界，继续完成任务01/补正01，报告各项实际测试及未执行，保留旧186原断言。
