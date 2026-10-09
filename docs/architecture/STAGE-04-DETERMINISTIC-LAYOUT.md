# Stage04 — Deterministic Layout and Three Preset Previews

架构规格：Architect已定义并决定按本文件实施。实现状态READY_FOR_ARCHITECT_REVIEW，本地代码与静态检查完成，Xcode155项尚未执行。所有者2026-10-09“进入stage04”授权开始；本文件不是最终视觉或阶段验收。

## 1. 阶段交付

在已有照片项目中，打开布局选择页，直接浏览三个使用本人照片的布局预览；可按关键词筛选，选定后显式Apply，结果原子保存到当前画布，返回编辑器仍可手动修改。取消/浏览/搜索不改项目，失败不显示保存成功。

三个临时功能预设为Grid（整齐并列）、Focus（第一张突出）、Offset（轻微错落/旋转）。这是构图预设，不是最终品牌风格，不提供AI推荐、调色或外部模板库。完整多页图组、张数/角色输入、AI分析与逐图自适应、相册导出仍按[产品基线](../产品与架构基线.md)继续规划；Stage04是其底层步骤，不作为完整生成闭环验收。

## 2. 数据与导航决定

- 不新增/删除/重命名Project、CanvasDocument、Asset、Layer或ProjectPackage序列化字段，schemaVersion维持2，v1读取兼容保持。
- 新增实际使用的纯Foundation `CollagePreset` 与 `CollageLayout`，不Codable、不做空服务或包拆分。输出现有CanvasDocument普通照片图层，保存仍走PhotoImportModel→PhotoLibrary。
- 若画布完全无图层，按素材导入顺序为每张照片建立一层，使用EXIF纠正尺寸和现有fittedBaseSize。新层ID取该素材ID（仅空画布，没有既有层冲突）；同输入预览/应用/重试无随机差异，重复应用不新增图层。
- 若已有任何图层，仅排列可见、未锁定、绑定照片的既有层；不把库中未上画布的照片偷偷加回。保留所有层ID、素材绑定、baseSize、opacity、zIndex、数组顺序；锁定/隐藏/历史未绑定层所有字段不变。布局可以与保留的锁定层重叠，不承诺绕障。
- 当前仍一张1080×1350画布、最多20素材/20层。未自动使用的素材、无可编辑层或不能容纳的极端几何应明确反馈，不能截掉照片或静默删除图层。
- 新增非持久化导航 `SheetRoute.collageLayout(projectID:)`，RootView负责呈现并显式注入原有三个环境对象。sheet内部搜索/所选预设仅为本次呈现状态，不改主导航栈；搜索不重置选择。
- PhotoImportModel新增非持久化 `.layout(CollagePreset)`编辑意图，复用现有单一mutation gate、失败draft/Retry/Discard。重试对最新文档重新规划并遵守新锁定/隐藏状态，不回放过期整文档。布局验证错误为rejected，不伪称文件保存失败。

## 3. 几何算法

2026-10-10接手Review明确：Focus“第一张”为空画布导入顺序首张，已有画布orderedBackToFront首个可排列层（最底层）；缺照片Layouts入口禁用并复用编辑器导入说明。fitScale>8时取现有scale上限8，仅缩小格内照片、不造成裁切/越界；fitScale<0.1仍拒绝。“不clamp掩盖越界”不禁止此安全上限。见[技术检查点](../../.ai/reviews/STAGE-04-DSH-CHECKPOINT-2026-10-10.md)。

纯函数只读元数据，不读文件、不加载原图、不调用AI。输入校验有限正尺寸、唯一层/素材ID、有效绑定及上限。

Grid枚举1…N列，按比例完整容纳每张照片，选可见照片占画布面积最大的可行网格；空出的末行居中，分数相同保留最早枚举结果。Focus将第一张安排在上方主区域，余图在下方网格；主区域占比随数量减小，避免20张时缩得过密。Offset基于网格设置确定性的轻微中心错位和正负旋转，旋转后边界仍在所属格中。

只修改位置、scale和rotation。所有照片等比例完整显示，不拉伸、不裁切；scale维持现有0.1…8编辑范围。无法满足范围或旋转边界时拒绝，不用clamp掩盖越界。保持canvas/document身份；重复生成相同值，未来AI可使用同类几何边界但本阶段不预建接口。

最多20层的轻量枚举允许同步执行；thumbnail文件读取/解码继续由既有PhotoLibrary actor处理。三预览只用320缩略图，禁用手势写入；不在主线程做图像处理。

## 4. 用户界面与保存

编辑器增加Layouts入口，不挤进现有画布手势区域。选择sheet用中性系统原生样式，三方向均直接可发现（可滚动），每项标题/差异描述/真实照片预览/选择按钮。搜索覆盖内置三个预设的中英文关键词，无匹配显示清楚的空结果和清除入口，不宣称远端模板搜索。

明确当前应用对象：空画布使用已导入照片，已有画布只排列可见未锁定层，锁定/隐藏层保留。Apply之前只预览；Apply成功才关闭，保存中禁用冲突控制和交互式关闭。失败保留真实错误与Retry/Discard，不静默丢稿；取消未应用的预览不写盘。缺照片或无可编辑层有说明；预览素材读取失败使用现有不可用占位，并提供重新载入预览入口。

复用EditorCanvasView只读模式（无所选层、编辑禁用、触控禁用），包装预览的可访问标签，避免三个重复的编辑器canvas标识泄漏到选择页面。主要按钮至少44pt，选择有明确文字状态并支持VoiceOver。

原生API沿用[Apple sheet](https://developer.apple.com/documentation/swiftui/view/sheet(item:ondismiss:content:))与[searchable](https://developer.apple.com/documentation/swiftui/view/searchable(text:placement:prompt:))。无第三方依赖、未决定云服务或新增费用。

## 5. 验证和交付边界

单元覆盖三预设确定性/差异、1…20张混合比例与旋转边界、EXIF、锁/隐藏/身份保持、重复应用不加层、非法/无照片/不可容纳输入；真实磁盘测试覆盖Apply原子保存/重启/原图不变、写入失败与Retry、跨项目及gesture gate。导航与UI smoke覆盖三预览、选择/搜索/取消、Apply后层数及重启。

Windows只执行工程/语法检查，不能记XCTest通过。完整macOS scheme须保持既有138项并加入新项，实际运行后才给测试结论；新运行包与本人验收仍需独立记录。部署与运行器沿用既有零新增费用范围，远端公开写入依用户授权具体执行。
