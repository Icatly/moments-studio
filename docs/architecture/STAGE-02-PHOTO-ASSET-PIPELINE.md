# Stage 02 — Photo Import and Asset Pipeline

Architect 决策，2026-10-03。所有者原话：“确认验收 继续下一阶段任务”。Stage01已批准；本文件授权Stage02实现，不批准Stage02验收或Stage03。

## 1. 目标与排除项

建立真正可用的多照片导入管线：系统选择 → 应用拥有的文件副本 → 原图/缩略图/预览 → 项目关联 → 本地恢复。照片处理与SwiftUI分离，并有明确进度、取消、失败和清理行为。

包含：JPEG/PNG/HEIC静态图、原始接收文件保存、EXIF方向处理、素材网格、只读预览、移除导入照片、导入过照片的项目重启恢复。

排除：画布/图层编辑、裁剪、手势变换、AI、拼贴、滤镜/LUT、抠图/贴纸、动态/视频、静态导出、订阅、账户、云后端、同步、全图库扫描、拍摄、文件选择器、最终品牌设计。Live Photo只接收其静态照片，不处理视频/音频；不承诺RAW、动画GIF、多帧编辑或HDR预览保真。

## 2. 本阶段产品行为

- 新建项目仍直接进入现有Editor占位路由；该页新增“Import Photos”、已导入数量、照片网格、进度与取消、错误摘要。
- `PhotosPicker`多选，ordered、matching images、preferredItemEncoding current；单次剩余选择数随项目余量变化。不申请完整图库权限，不添加未使用的权限用途描述。
- 当前工程性暂定上限：每项目20张，每文件100MiB，单图80百万源像素；串行处理，一次最多解码一张。上限需在本阶段用实际数据记录，不宣称是真机性能已测出的产品结论。
- 支持再次追加导入；重复选择视为独立副本，当前不实现内容去重。失败项不创建资产，其他项可成功；按用户选择顺序追加。
- 点缩略图打开只读、aspectFit预览；有Done，无编辑控件。缩略图网格可aspectFill；该显示裁切不改照片数据。
- 移除只删除本项目内的副本与派生文件，不删除系统相册原图；使用明确的原生确认界面。
- 空白新项目仍仅内存；首次照片成功保存后，该项目及其照片持久化。移除最后一张后，已经保存的项目仍保留并可恢复。Home说明必须准确区分未保存的空项目与已保存项目。
- Back或Cancel停止剩余处理；已成功提交的照片保留。取消不是失败。新一轮选择清空上一轮picker selection，允许再次选同一图。
- UI继续原生中性样式，检查浅/深色、大字号、安全区域、可返回与44pt触控；不开始品牌系统。

## 3. 数据契约：保留Stage01字段，新增包格式

**Project / CanvasDocument / Asset / Layer / LayerTransform / CanvasSize的现有编码字段、日期编码、枚举原始值与旧fixture不变。** 当前不增加Layer.assetID，不自动创建Layer。

新增纯Foundation、Codable/Equatable值模型，明确编码字段：

| 模型 | 编码字段与含义 |
| --- | --- |
| ImportedPhoto | `asset`（现有Asset，id为素材身份，kind=photo，localReference为原始接收文件）；`thumbnailReference`；`previewReference`；`pixelWidth`、`pixelHeight`（源文件未旋转像素尺寸，Int）；`orientation`（EXIF1...8，缺省1）；`contentType`（ImageIO实际识别UTI） |
| ProjectPackage | `schemaVersion`（Int，当前1）；`project`（原Project）；`photos`（[ImportedPhoto]，导入顺序） |

照片库属于ProjectPackage；Project只保留现有创作文档。这避免在导入阶段提前决定画布图层结构。所有相对路径都以照片库根目录为基准，恢复时重算沙盒URL，不序列化绝对URL、PhotosPickerItem、UIImage、CGImage、相册标识或完整EXIF/GPS。

ProjectPackage显式编码键，解码拒绝未知schemaVersion，验证尺寸正数、orientation范围、照片/ID唯一、数量上限与路径归属。损坏/未来版本项目报告并保留文件，不静默重置、覆盖或删除。此为首次持久化格式；Stage01未产生磁盘存档，不发明旧存档迁移系统。

## 4. 文件归属与事务

库根：`Application Support/MomentsStudio/`（本地持久数据，不放Caches）。

```text
Projects/<projectUUID>/manifest.json
Projects/<projectUUID>/assets/<assetUUID>/original.<detectedExtension>
Projects/<projectUUID>/assets/<assetUUID>/thumbnail.<jpgOrPng>
Projects/<projectUUID>/assets/<assetUUID>/preview.<jpgOrPng>
```

临时传输副本只放应用自有temporary子目录，按UUID命名。选择器的系统临时URL在Transferable importing闭包结束前复制到应用拥有的位置；不能返回一个即将失效的系统URL。原始接收文件按字节复制，不压缩、不重编码、不写回相册。它是选择器提供的表示，不声称绕过用户照片编辑/共享选项获得了相机最初原始文件。

每张照片是一个提交单元：验证源文件 → 写原始副本与派生文件 → 原子写新manifest → 返回已提交package → 主actor更新ProjectStore。任何提交前失败/取消清理该项新文件，旧manifest和已导入照片不变。不能先把UI记成成功再尝试保存。

移除顺序：原子提交不含该photo的新manifest → 更新内存快照 → 清理该素材目录。提交失败时保留原数据；提交后清理失败不恢复已移除记录，返回清理警告供UI披露，后续恢复可重试清理。

所有路径需验证：仅允许该projectUUID/assetUUID对应的生成式路径；拒绝绝对路径、`..`、跨项目引用和符号链接逃逸。只清理库根内属于本应用的文件；损坏/未知版本manifest的目录不进行自动清扫。

恢复时清理可验证项目的未引用素材目录和应用自有暂存残留，以处理提交前进程中断。缺失/损坏文件不可假装恢复成功：保留原件/manifest，界面显示问题，仍允许访问正常素材；不静默改写损坏项目。只检查元数据/引用与必要的小派生文件，不在启动时解码所有原图。

## 5. 图像管线

- Foundation、PhotosUI、CoreTransferable、UniformTypeIdentifiers、ImageIO、CoreGraphics均为本阶段批准的Apple原生框架；不增加第三方依赖，不提高deployment target。
- 以URL+CGImageSource读取属性，禁止批量Data/UIImage全尺寸加载。数据传输走FileRepresentation(.image)，不走全部原图的DataRepresentation。
- 处理位于非MainActor的PhotoLibrary actor；不要因View/Task继承主actor而把解码、复制或JSON磁盘I/O放到UI线程。MainActor只编排、显示和应用已提交的值。
- ImageIO受限downsample：thumbnail长边最多320px，preview长边最多2048px，不上采样；CreateThumbnailFromImageAlways + CreateThumbnailWithTransform处理EXIF方向。orientation5...8的展示宽高与源尺寸交换，检查镜像方向，不仅测试90度旋转。
- 派生图为8-bit sRGB SDR；保留透明通道的PNG，其余JPEG质量0.85。不复制GPS或整个源EXIF到派生图；原始接收文件字节不变。HDR/宽色域原始文件保留，但本阶段不声称派生预览有HDR保真。
- 网格只按需加载可见缩略图，预览只加载当前2048派生图；避免一次预载20张preview或解码原图。小图文件读取/解码也在处理边界，返回CGImage后UI仅构造Image。
- 每项处理使用局部autoreleasepool释放CoreGraphics临时资源；转换前后、manifest提交前检查取消。任务取消或非目标项目的晚到结果不能修改另一个项目。

## 6. 已批准模块与接口

新增模型放Models。主要文件服务一个`PhotoLibrary` actor放Services，同时承担本阶段紧密相关的文件事务、派生处理和包恢复；内部小处理函数即可，不拆仓储协议、插件或Swift Package。

接口（内部实现可精简，语义不可改变）：

```swift
// 纯值；非Codable的运行结果，不进入manifest
PhotoLibraryLoadResult { packages: [ProjectPackage], warnings: [String] }
PhotoLibraryMutationResult { package: ProjectPackage, warnings: [String] }

actor PhotoLibrary {
    init(rootURL: URL) // 单测独立临时根目录；App使用Application Support
    func restore() throws -> PhotoLibraryLoadResult
    func importPhoto(fileURL: URL, into package: ProjectPackage, at: Date) throws -> PhotoLibraryMutationResult
    func removePhoto(assetID: UUID, from package: ProjectPackage, at: Date) throws -> PhotoLibraryMutationResult
    func loadDerivedImage(reference: String) throws -> CGImage
}
```

服务方法在actor内工作，调用方通过await访问；处理函数中没有主actor绘图。`loadDerivedImage`必须校验为派生引用并受限解码，不成为原图加载旁路。文件错误和取消用可区分的Error，不能try?吞掉提交失败。恢复某一坏包产生warning，其他正常包继续加载。

ProjectStore保留原公开方法/参数行为，允许新增：

- `private(set) photoCollections: [UUID: [ImportedPhoto]]`和已保存project ID集合。
- `photos(for projectID: UUID) -> [ImportedPhoto]`。
- `apply(_ package: ProjectPackage)`：只应用指定project的已提交快照，按ID替换或插入，不重复创建。
- `restore(_ packages: [ProjectPackage])`：恢复有效包，合并ID，保留创建顺序用于recentProjects；不可丢掉已经存在的内存项目。

`ProjectStore()`继续为纯内存对象，init不自动做文件I/O，旧单测保持独立。UI层新增`@MainActor @Observable PhotoImportModel`作为本阶段编排状态（Services或Features/PhotoImport），持有PhotoLibrary与ProjectStore；RootView创建一次并注入。初始化恢复是异步，Home显示loading/retry/warning，恢复完成前禁用Create/Import以防状态竞争。

PhotoImportModel入口：`restoreProjects() async`、`importSelection(_: [PhotosPickerItem], projectID: UUID) async`、`cancelImport(projectID: UUID)`、`removePhoto(projectID: UUID, assetID: UUID) async`。只允许一个活跃批次/修改，捕获projectID和batchID；逐项继续失败，取消终止后续项。每次导入从最新已提交ProjectPackage开始，updatedAt在成功提交时更新。

PhotosPickerItem与Transferable适配仅在导入编排边界，不进入模型或文件actor。实现文件生命周期适配需要的最小helper即可；不要创建通用任务系统。

已有push路由保持。允许SheetRoute新增`.photoPreview(projectID: UUID, assetID: UUID)`，RootView集中处理只读预览。系统PhotosPicker控件的选择绑定是导入UI状态；这是对“应用模态集中路由”的明确局部例外，不给其他页面增加私有导航框架。

EditorPlaceholderView保留类型/路径及Stage01 UI标识，文案更新为“import available, canvas/AI/editing/export not implemented”；Home、Settings/About的旧描述按实际状态修正。保留FIX02按钮与footer修复，不重新发明品牌。

## 7. 测试、实查与完成门槛

保留Stage01全部29单元+2UI测试，不删失败测试、不改旧JSON fixture迎合新实现。新增测试覆盖：包/ImportedPhoto编码键与往返、未知版本/非法引用、JPEG/PNG/HEIC派生尺寸与方向/alpha、原图字节不变、跨项目隔离、失败回滚、取消、顺序、项目容量、恢复/重复恢复、移除和文件清理。

单测使用可复现的程序生成小型图像和独立临时根，模拟损坏、缺失、限制与I/O错误；不使用网络或私人照片，不把单测测试数据塞进生产UI。UI smoke覆盖空项目导入入口、picker取消/返回及只读预览路由；真实多选导入由macOS模拟器预置合成测试照片后手查，不能只用生产绕过按钮来验收。

Architect实查：至少3张不同方向/比例/格式的照片一次导入，再追加、预览、移除；相册原图不变，返回与重开正确，terminate/relaunch后恢复同项目与素材，取消后不晚到新增，受控失败不损伤旧素材；浅/深色和常规最大字号。大图批次记录实际环境、耗时/可观测内存和取消反应；模拟器数据不冒充真机性能。

必须有当前commit的实际macOS build/tests与警告Review、可运行版本及准确验收说明。DSH在Windows只能运行结构/语法校验，Xcode未执行必须标未验证；Architect负责后续免费云构建。交付止于READY_FOR_ARCHITECT_REVIEW，Stage02所有者判断不代勾。

## 8. 官方依据

- [Apple Photos picker：系统选择、延迟加载及文件表示](https://developer.apple.com/videos/play/wwdc2022/10023/)。
- [Apple：current编码与通用image类型、共享选项](https://developer.apple.com/videos/play/wwdc2023/10107/)。
- [FileRepresentation](https://developer.apple.com/documentation/coretransferable/filerepresentation)。
- [ImageIO受限缩略图尺寸](https://developer.apple.com/documentation/imageio/kcgimagesourcethumbnailmaxpixelsize)、[方向变换](https://developer.apple.com/documentation/imageio/kcgimagesourcecreatethumbnailwithtransform)。

以上是Architect选定方案；20张/100MiB/80MP/320px/2048px为本阶段暂定工程策略，不伪称Apple官方要求。
