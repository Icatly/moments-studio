# Stage05 — Photo Analysis Foundation

Architect决定，依据所有者2026-10-09明确“把stage04和stage05都做了”。开始许可已具备，实施前先完成Stage04技术检查点并留存基线；该推进不把Stage04本人验收写成通过。实施由DSH负责，参见[工作须知](../../工作须知.md)。

## 交付目的与边界

逐图提取可解释的光色数据，供后续自适应风格和选择建议使用。用户可在编辑器按需打开“Photo summary”查看照片及简短光色估计，打开即分析，无必填问卷；不增加导入流程步骤，不自动选模板、调滤镜、改人像、加/删图层或写项目。它是照片分析基础，不冒充云AI、场景识别或完整一键图组。

不新增第三方运行依赖、网络请求、账号/付费接入、模型下载或GPU管线。仅Foundation/CoreGraphics及现有Apple框架。Project/CanvasDocument/Asset/Layer/ImportedPhoto/ProjectPackage字段和schema2均不改，兼容v1。分析数据只在本次sheet内存中持有，重开重新计算，不预建持久化缓存、空服务/协议或Swift Package。

## 数据和算法契约

新增实际使用、值类型、Equatable/Sendable的`PhotoAnalysis`结果（不Codable），明确assetID、纠正EXIF后的原图显示宽高、采样宽高/有效像素数、平均RGB、平均亮度、亮度标准差、平均饱和度、暗/亮像素占比、采样coverage，以及可解释的`confidence`与其依据。失败结果按assetID保存类型化原因（missing/unreadable/invalidMetadata/noVisiblePixels等），不把失败数值写0或保留上次成功冒充当前成功。

采用既有已经纠正方向的320px thumbnail，进一步等比例缩到最长边最多64px，不放大、不拉伸。CoreGraphics明确转为sRGB 8bit RGBA（明确byte order和premultiplied alpha），不假设输入像素格式/色域。alpha<=0.05排除；其余先去预乘再参与等权统计，透明边界不算黑色。有效像素为0返回noVisiblePixels。alpha门槛、缩图取整和插值策略在实现报告中冻结并由测试检验。

设非预乘sRGB通道r/g/b均在[0,1]，亮度代理L=0.2126r+0.7152g+0.0722b；这明确是编码sRGB上的相对亮度代理，非物理照度、摄影EV或线性光亮度。均值为mean(L)，对比度为sqrt(mean((L-meanL)^2))，浮点误差导致微小负方差时只归零；饱和度按HSV S=(max-min)/max，max=0时S=0。暗像素L<=0.1、亮像素L>=0.9，对比度范围[0,0.5]，其他比例与均值[0,1]且有限；统计比例分母只用有效像素。

coverage=有效像素/采样总数。confidence仅表达采样充分度，非美感/语义/曝光判断准确率：有效像素>=256且coverage>=0.75为adequate，其他有效样本limited；结果说明缩略图估计。阈值属于当前工程策略，不能称训练出来的AI概率。

UI只给“Estimated darker / balanced / brighter”（meanL<0.25 / 0.25…0.75 / >0.75）和“Estimated muted / moderate / colorful”（meanS<0.2 / 0.2…0.5 / >0.5），弱采样提示；不展示一屏原始指标、不评照片好坏、不声称能识别人脸/美颜需求或分配照片角色。显示纠正后尺寸。实际数据供测试/后续已批准代码使用，当前不做任何推荐优先级改变。

## 服务和导航边界

1. 新`Services/PhotoAnalyzer.swift`只做有界纯像素统计，不访问文件/SwiftUI。实际调用放在既有PhotoLibrary actor上下文，避免MainActor绘图。纯统计方法可直接测试，不新增独立队列/调度器。
2. PhotoLibrary新增实际使用的只读`analyzePhoto(projectID:assetID:)`方法，从当前包查该asset元数据和thumbnail，通过原路径守卫加载派生图，不接受任意外部路径、不加载/修改原图；返回值类型，CGImage不跨UI边界。在读取前、解码后和计算循环适当位置checkCancellation；取消向上传播，不转换成成功或普通坏图。
3. PhotoImportModel新增对应只读异步桥接供sheet调用，不占用项目mutation gate、不写store/manifest/failedDraft。sheet按照片顺序一次只处理一张，最多20，期间可关闭/取消；Task取消和请求身份防止上一轮/上一项目结果写回。结果按assetID匹配，已删除或元数据变化的素材不挂旧结果。
4. 新`SheetRoute.photoAnalysis(projectID:)`由RootView统一注入环境对象；新增`Features/PhotoImport/PhotoAnalysisSheet.swift`拥有有限状态（loading/results/errors）。现有Editor滚动工具区增加“Photo summary”入口。缺照片/项目有可解释空态；独立单张读取失败不阻塞其余，可显式“Analyze again”重新计算，旧失败不显示成功。
5. sheet异步任务绑定projectID及照片身份/metadata签名，素材集合变更触发取消/重新计算；非当前导航关闭后不继续写UI。已有画布手势、保存、照片导入与Done行为保持。

## 测试与证据

保留Stage04完整155项及旧断言；新增必要有效测试：已知黑/白/灰/RGB/双区图统计（用真实CGImage和明确容差）、任意原bitmap格式转换、半透明去预乘/全透明失败、混合alpha覆盖/采样置信度、EXIF显示尺寸、最大采样边界/不放大/比例、非法元数据/缺失派生图/路径守卫、取消传播、逐图失败隔离、分析前后manifest及原图/派生图字节不变、请求过期/项目隔离。至少一个UI smoke走真实导入→summary→结果→关闭→层数/旧照片不变；不新增生产测试入口。

DSH提供Stage05手动原生测试/设备工作流，最小复用Stage04流程，保持完整scheme、真实方法清单与分组门禁、0失败/跳过、标准macOS运行器、合理明确时限和2天证据保留；不得硬填“通过”或减少旧断言。每阶段分别记录源码清单/检查点，最终包与实际全套原生测试同App树。Windows仅静态，macOS实际Xcode结果才构成原生证据。设备IPA/真机/阶段APPROVED仍需后续实际动作。

2026-10-10 Architect工具链决定：Stage05测试和设备包均用标准macos-26，明确选择稳定Xcode26+/iphoneos26+，分别30/6分钟，避免照抄Stage03旧macos15默认Xcode16.4/SDK18.5导致展示不同。仅DSH更新新的Stage05 device工作流；Stage04冻结入口保持原记录。免费标准运行器，不授权larger或费用/账户设置变更。

原生依据：[Apple CGImageAlphaInfo](https://developer.apple.com/documentation/coregraphics/cgimagealphainfo)、[CGContext bitmapInfo](https://developer.apple.com/documentation/coregraphics/cgcontext/bitmapinfo)、[Swift Task](https://developer.apple.com/documentation/swift/task/)、[Swift concurrency](https://docs.swift.org/latest/documentation/the-swift-programming-language/concurrency/)。具体统计公式与置信度阈值为本项目工程决定，不是Apple推荐算法。
