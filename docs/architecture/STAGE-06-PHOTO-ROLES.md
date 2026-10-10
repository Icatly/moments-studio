# Stage06 — Photo Role Suggestions and Saved Choices

Architect决定，依据所有者2026-10-10“进行stage06”；Stage04/05已完成新版本人验收，均APPROVED。实施由真实DSH负责，Architect独立Review与交付；Stage07及以后未授权。

## 用户结果与边界

可选打开Photo roles，立即获得逐图主图/配图建议；用户可以保留默认建议，也可把任意照片改为Primary photo、Supporting photo、Collage material、Not for layout或Automatic。一次Save choices保存全部选择，Cancel不写；重开与重启保留已保存选择。下一次显式Layouts预览/Apply使用选择，Focus突出主图。不要新增导入问卷、自动美颜、联网/账号、模型下载、抠图、滤镜、多页、导出或社媒趋势。

拼贴素材是用户指定的用途，不保证可抠图；Not for layout不删除原照片或现有图层。原图/派生图不改动，已有锁定/隐藏/排序/图层身份始终保持。暂时的可选检查页服务后续一键图组，不冒充完整成品闭环。

## 批准的公开契约改动

仅ImportedPhoto新增可选`roleChoice: PhotoRoleChoice?`，初始化参数默认nil。PhotoRoleChoice为实际使用的Codable/Equatable/Hashable/Sendable值：`role`取字符串primary/supporting/collageMaterial/excluded，`source`取automatic/manual。nil是没有保存选择；automatic表示用户Save接受的系统建议，manual表示用户指定。自动算法只生成primary/supporting；不自动排除或分配拼贴素材。

旧schema1/2缺键或null均读作nil；nil编码不增加键，保持原schema2及其旧字段/编码。未知role/source或错误类型拒绝，不猜测；自动来源的collageMaterial/excluded非法。一个包最多一个保存的primary；解码与保存都验证。选择primary时将先前主图改为manual supporting，不能形成两个主图。新照片roleChoice=nil，删除照片不影响其他选择，现有导入/画布保存/恢复均保留选择。旧版App可以读取附加键，但旧版再写可能丢掉角色选择；不宣称降级写入保留。

Project/CanvasDocument/Asset/Layer/ProjectPackage字段、schemaVersion、目录边界不改。角色分析观测、置信分数、人脸框及标签不持久化；不是照片身份识别。该有限附加契约由Architect在本规格批准，DSH不得扩展为独立缓存/服务协议/Swift Package。

## 本地识别与确定性建议

Apple原生Vision批准用于本阶段：VNClassifyImageRequest、VNDetectFaceRectanglesRequest，配合Stage05光色分析。只在现有PhotoLibrary actor的安全项目/asset路径加载已纠正方向、最长边不超320px的缩略图，不加载原图；一次一张，最多20，CGImage/VNObservation不跨UI边界。VNRequest revision实际选择写报告，以supportedRevisions为依据，记录实际revision；不预假定当前SDK默认模型标签或精度。

分类结果先检查identifier确属supportedIdentifiers，confidence有限且0...1；在纯值策略中使用有限、精确匹配的自然场景标识白名单（landscape/nature/scenery/outdoor/mountain/beach/forest/sky/sunset/ocean/lake/cityscape，统一大小写及下划线为空格但不做子串猜测；unsupported视为无证据）。sceneScore为这些标签最高值，>=0.5视为可能自然场景，阈值是工程策略不是准确率。面部框只取有限有效范围内的检测数，用于“Face detected; original photo kept”提示，不推断身份/性别/美颜需求；未检测到不能声称无人。

建议尊重manual：manual primary存在时其他自动照片全supporting；否则从非manual collageMaterial/excluded的可成功分析照片中选一个primary，稳定比较sceneScore（低于0.5归零）→Stage05 adequate采样优先→纠正尺寸像素面积降序→原导入顺序。其他成功自动照片supporting。没成功分析的自动照片无建议，明确失败，仍保留；不把失败解释为不用。人工指定的照片即便分析失败仍保留选择。Vision失败时只显示可解释的内容识别未完成，可利用成功的光色/尺寸作有限建议，不能伪造识别或置信分数。

UI显示照片、小量可理解依据和角色选择，不显示全量模型标签/概率或技术日志，不把场景识别写成美感评分。已有manual选择优先；重新分析只替换自动建议，仍须显式Save才写入。Automatic可清除本次manual草稿并使用当前建议。Save materializes有效自动建议及manual选择为roleChoice；失败且无manual的照片保存nil。最终最多一个primary。

Apple明确Vision忽略alpha。Stage05已检出noVisiblePixels的照片，不调用Vision并保持明确失败/人工选择，不能把透明RGB残值的标签当有效照片。revision按实际Swift API的Int和IndexSet元素处理，不按Objective-C NSUInteger猜值类型。

关闭/重算检查任务token、projectID和完整照片metadata/roleChoice签名；关闭后或跨项目不得写入旧结果。同步Vision调用可能完成当前单张，取消必须阻止后续照片及旧UI回写，不能声称立即中止系统推理。检查取消在读取/推理前后；单张失败不阻塞其他照片。

## 保存与布局集成

新增实际使用的PhotoLibrary保存角色方法和PhotoImportModel桥接。复用现有mutationToken、isSavingEdits及原子manifest写入；不得新增第二个mutation gate或丢失未保存CanvasDraft。角色保存遇到活跃手势/导入/保存/未解决画布失败草稿必须busy/rejected。提交携带预期照片metadata/roleChoice快照，与最新已提交包核对；缺项目/素材变化拒绝并提供Reload，不把过期选择写给另一项目。只更改photos的roleChoice及updatedAt；原照片/派生图字节、document完整值、项目其他字段不变。写失败不更新store，保留sheet草稿可Retry或Cancel；保存中禁止交互关闭，成功才返回编辑器。

布局引擎签名仍接收ImportedPhoto数组，直接读取已保存选择：nil保持Stage04行为；primary/supporting是完整照片；collageMaterial/excluded暂不参与自动排版。空画布只为完整照片创建层，素材照片保留于图库；无可用照片真实提示。已有画布只调整完整照片的可见未锁定层；拼贴/排除层位置也保持，不删除/隐藏层。Focus的可调整主图移到计算序列第一位（若同资产多个层，保持原层顺序取首个作为主位）；输出layers存储顺序/z-order/IDs/baseSize/opacity/保护层不变。没有可调整主图时使用原顺序，不解锁、不重排保护层。Grid/Offset保持原可调整顺序。预览与Apply复用同一策略，重复应用不增层。

Editor新增可选Photo roles入口采用topBarTrailing工具按钮，保留现有Done名称/标识/行为与导入工具区原几何，避免Stage05已有导入按钮被新增行挤出视口的回归。保持44pt目标、系统临时样式、照片为焦点。Root集中`.photoRoles(projectID:)` sheet路由、同实例环境注入；取消/浏览不写。列表逐图显示，loading/partial error/empty/Retry/Reload可理解；Save choices与Cancel明确。重算不覆盖manual草稿；取消丢弃本次草稿无需额外问卷。允许用户保留默认建议后一键Save，不逐张强制确认。

## 测试与交付

保留Stage01–05全部186真实方法及旧行为断言。新增有逻辑的纯策略测试（manual优先/最多一primary/精确标签/有限数据/失败回退/稳定tie/Automatic重置）、真实序列化兼容/未知值/重复primary拒绝、保存/恢复/删除/后续画布编辑仍保留选择、原图/派生图字节与画布不变、写失败回滚/跨项目或metadata变化拒绝/取消过期隔离。布局测nil完全保持旧行为、Focus主位、collage/excluded不自动加层及已有保护层/顺序不变、重复Apply。Vision真实CGImage请求至少一次原生smoke，只断言有界有效输出/取消，不断言系统必须识别合成图的具体标签；策略通过实际使用的纯值输入测试，不引入生产测试开关。

关键UI smoke：真实导入→Roles自动结果/人工选择→Cancel不改→Save→重开和App重启保留→Focus预览/Apply尊重主图且旧图层不复制；关/重算/当前项目隔离。使用既有稳定视口辅助函数，不放宽旧断言/skip，不错误假定全App只有一个navbar或title等于AX label。

DSH新增stage06-tests/device手动工作流，最小复用已验证Stage05：标准macos-26、稳定Xcode26+/SDK26+；完整scheme、实际源码方法数与manifest/blobSHA门禁、0失败/跳过、原始日志/xcresult/summary/evidence guard、2天证据；测试40分钟/设备6分钟，零付费运行器。Stage04/05冻结工作流不改。Windows只做静态/结构检查，不能写Xcode通过；DSH停止READY_FOR_ARCHITECT_REVIEW，Architect独立核源码/原始结果/同源设备包，最后本人验收。不得自行提交/推送/云派发或进入Stage07。

原生依据：[Apple VNClassifyImageRequest](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)、[supportedIdentifiers](https://developer.apple.com/documentation/vision/vnclassifyimagerequest/supportedidentifiers())、[VNDetectFaceRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest)。角色规则/阈值为本项目决定，不是Apple推荐算法。
