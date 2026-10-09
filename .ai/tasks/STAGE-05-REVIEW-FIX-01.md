# Stage05 Review补正01（Architect，2026-10-10）

依据：所有者两阶段授权、Stage05架构及工作须知。当前先记录已读源码问题，任务文件存在不代表已实际发送；待DSH当前实施交付后实际分派。只修Stage05及对应测试/工作流计数，不直接由Architect代写。

1. **异步过期结果缺严格身份检查与回归**：PhotoAnalysisSheet只在新`.task`开始时更新runToken，await后只核token/cancel；metadata/照片集合已变、新task尚未开始时没有核当前ImportedPhoto是否等于本轮快照。结果字典只存assetID、不带测量metadata，渲染也没有严格匹配，因此同ID新metadata可短暂显示旧值。用实际UI采用的最小身份/请求guard，在写回和显示时都核projectID、当前照片metadata/签名；素材删掉/更改、关闭或重算后旧成功/失败都不能写回/显示。补可运行的有效旧请求/元数据变化/项目隔离回归，测试实际用到的guard/state，禁止只测试与UI不相连的副本、生产测试入口或空服务。
2. **UI测试错误容器类型/可见性门槛**：Stage05PhotoSummaryUITests用`app.staticTexts`查`analysis.row.`，实际row是VStack `.accessibilityElement(children: .contain)`的容器，不能把它当Text。定位真实容器且明确单行/asset身份，不放宽断言。tapEditor不能只在!isHittable时滚动：Stage03真实原生已证明部分露出按钮仍isHittable、tap失效；沿已有scrollEditorToMakeHittable严格完整视口门槛核再tap，保持所有旧断言不变。
3. **可解释弱采样提示保持用户语言**：当前低置信度直接展示confidenceExplanation中的像素计数和coverage内部指标。UI改为简短“这张图可供分析的内容较少，仅作粗略参考”的现有英文占位等价文案；数值/阈值留在实际分析数据、报告和测试，不塞入用户流程。
4. **明确sRGB和安全派生图实证**：PhotoAnalyzer要求明确sRGB，不能在sRGB创建失败时静默改DeviceRGB还把结果标sRGB；失败用类型化错误。补真实thumbnail符号链接/越界路径守卫拒绝且外部/项目文件字节不变的测试，现有缺文件案例不能代替路径守卫。补alpha门槛12/13边界的有效数值回归；已知输入用正确预乘字节避免高量化误差造成假预期。

同步实际新增测试清单/Stage05门禁、工程引用与报告，Stage04冻结155项/工作流不改。存储模型/schema2不改，零依赖；报告区分编码/静态与原生。保留无关未提交工作，交完整补正后停止READY_FOR_ARCHITECT_REVIEW；不自行推送/派发/付费或进入Stage06。
