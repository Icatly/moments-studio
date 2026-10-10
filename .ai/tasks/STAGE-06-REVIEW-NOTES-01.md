# Stage06 实现中独立Review补正01

Architect 2026-10-10读取已落盘初稿；当前DSH仍IMPLEMENTING，以下请在本轮完成，不是新阶段或扩大范围。

1. PhotoRoleAnalyzer目前没有实际调用supportedIdentifiers筛选；faces仅检有限/正尺寸，未检0...1矩形范围。按规格补真实supportedIdentifiers配置筛选，纯值降减只接收支持标签；验证x/y>=0且maxX/maxY<=1及正面积，超界/非有限舍弃。Vision失败回退不能fabricate识别。
2. PhotoRolePolicy把sceneScore!=nil或adequateSample当成功证据，误把成功但limited采样且无自然标签的照片标failed；非nil NaN/Inf/超界又可当证据。区分真实分析成功/有限尺寸与adequate，limited成功也可作主图/配图候选，真正两路都失败才无自动建议。有效sceneScore必须有限0...1，超界舍弃不能clamp成强证据。actual UI候选输入/策略及测试均覆盖。
3. CollageLayout初稿对Grid/Offset也prioritizingPrimary，违反仅Focus主位优先的规格。仅Focus调整计算序列；多层同primary资产只把原顺序首个层提到计算主位，其余保持原相对顺序；实际输出layers存储顺序/层级不变。nil严格保留原行为。顺手恢复noEditableLayers/tooManyLayers在同一行的误拼接，不做无关格式大改。

后续保存/UI/测试/工程/工作流继续任务01，需在报告回应这三项与实际未执行。禁止削弱旧186或新边界测试。

原生API复核补充：Apple Swift文档VNRequest.revision是Int、supportedRevisions是IndexSet（元素Int）；当前观测字段UInt可能和request.revision不匹配。请核实际Swift签名，统一实际使用的Int，不按ObjC NSUInteger猜Swift UInt。Apple同时明确Vision丢弃alpha；Stage05返回noVisiblePixels时不得仅因Vision产生标签当作成功可用照片，跳过Vision并保留明确失败/manual选择。添加实际全透明输入及类型签名检查，避免Windows语法检查误当类型编译通过。

依据：[VNRequest](https://developer.apple.com/documentation/vision/vnrequest)、[supportedRevisions](https://developer.apple.com/documentation/vision/vnrequest/supportedrevisions)。
