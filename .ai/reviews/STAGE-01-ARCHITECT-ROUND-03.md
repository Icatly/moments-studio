# Stage 01 真实运行 Review — Round 03

2026-10-03，Architect。结论：**CHANGES_REQUESTED**，只修当前阶段。

## 已执行的证据

源码49dc9f3，Xcode16.4、iPhone16Pro/iOS18.5：29个单元测试和2个UI测试全部通过。随后相同应用包上传Appetize，在iPhone14Pro/iOS17.2实际操作：Home启动、创建两个不同项目、返回、最近创建顺序、重新打开旧项目不新增项目、Settings、About及Done关闭均正常。未观察到崩溃或严重遮挡。

这些结果不能代替所有者验收；用户9项判断仍未勾选。

## V1 — 深色模式创建按钮文字几乎不可读（必须修）

复现：同一构建在Appetize切换Dark主题并启动。按钮背景接近白色，Create Project文字也为白色。证据：`.ai/build/downloads/dark-button-before.png`。

根因已定位：AccentColor在浅色为深灰、深色为浅灰；Home的borderedProminent按钮使用该accent作为背景，却没有为这组自定义中性背景指定对应的内容颜色。当前iOS17.2系统按钮样式保留白色内容，不能假定它总会根据自定义tint自动反转。

架构决定：保留现有中性accent资源与原生按钮；只在Create Project的Label明确使用浅色模式白色内容、深色模式黑色内容。读取原生colorScheme即可，不新增颜色服务、ButtonStyle、依赖或公开模型字段。

## V2 — List footer的状态说明对比度偏低（必须修）

Home的内存说明与Settings的无选项说明处于List footer，内部又使用层级样式`.secondary`。实际浅色/深色画面均偏淡，Home深色说明尤其难读。

架构决定：仅这两处footer使用明确的语义颜色`Color.secondary`，避免层级secondary叠加footer默认处理；保留字体、文案和布局。其他普通文本样式暂不改。修复后必须实际比较两种主题的说明文字，不凭源码宣称问题解决。

## 复验范围

本轮不做最终视觉设计。DSH只完成上述局部修正与真实文档记录；Architect重新构建/运行同一批31项测试，检查两种主题的按钮与footer，随后交所有者验收。Dynamic Type最大常规字号尚未完成检查，不能记为通过。不开始Stage02。
