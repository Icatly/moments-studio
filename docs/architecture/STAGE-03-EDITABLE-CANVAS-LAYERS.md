# Stage03 — Editable Canvas and Layer System

## 2026-10-08 真机反馈限定修正

所有者反馈锁定重叠上层会拦截列表所选下层拖动、偶发新增持久化副本，并明确要求编辑器“完成，保存并返回首页”。Architect决定：tap仍选最上可见层（锁层可选），drag在已选可见绑定层包含起点时保持该目标，锁定选层仍拒绝变换；明确添加缩略图及工具视口触控边界，重复新增的真实触发尚待复测，不伪称根因已确认。Done复用唯一writer与mutation gate，saved后才返回首页，失败保留最新项目与可Retry/Discard意图；明确Done允许空项目持久化。内部新增save意图不改变序列化字段/schema/导航route/模块边界，不引入依赖。详见[限定修正任务](../../.ai/tasks/STAGE-03-DEVICE-FIX-2026-10-08.md)。Stage03未通过，Stage04未授权。

Architect 决定，2026-10-06。所有者最新指令：“进入stage03”。Stage02 已按所有者决定收尾，未取回的测试证据见 [收尾记录](../../.ai/reviews/STAGE-02-OWNER-CLOSEOUT-2026-10-06.md)。本文件是 Stage03 唯一新架构与公开契约授权，Stage04–15 未批准。

## 目标与完成范围

在现有编辑器中增加真正可编辑的照片画布：从项目素材中手动添加照片图层，点选、拖动、双指缩放/旋转，调整前后顺序、隐藏/显示、锁定/解锁、重置变换和移除图层；修改可保存并重开恢复。导入仍只添加素材，不自动创建图层；旧项目首次打开保持空画布，用户明确添加。

最多 20 张素材、20 个图层；同一素材可以再次添加为独立图层，总图层数受限。画布暂用已有 1080×1350，不提供画布格式选择。延续已有原生中性 token，照片为视觉重点。

不做自动拼贴/布局引擎、AI、裁剪、蒙版、抠图、调色、文字/贴纸、撤销历史、动画系统、导出、模板、云端或最终品牌。已有 opacity 数据照常渲染，本阶段不增加完整样式面板。

## 数据契约（批准的唯一序列化变化）

保留 Project / Asset / ImportedPhoto / CanvasDocument 现有字段、标识、路径及日期编码。Layer 保留所有原键，增加两个可选字段：

| 键 | 类型 | 语义 |
| --- | --- | --- |
| assetID | UUID? | 指向同一 ProjectPackage.photos 内的 asset.id；不存路径或图像对象 |
| baseSize | CanvasSize? | 图层未缩放的宽高，画布单位；正数且有限；一经添加固定，不随屏幕或预览像素尺寸改变 |

新照片图层必须同时具有这两个值。历史 Layer 缺两键可解码为 nil/nil；只有一个值或非正/非有限 baseSize 拒绝。nil/nil 作为历史未绑定占位保留，图层列表显示不可用，允许移除，不虚构图片或静默丢弃。绑定图层引用不存在于包内的素材、重复 layer.id、超过 20 图层、损坏尺寸/变换必须报错，不自动修复破坏性数据。解码与写入共用包级校验，未知类型或版本仍拒绝。

ProjectPackage.currentSchemaVersion 改为 **2**。解码兼容真实 schemaVersion1：保留项目/素材/原始 Layer 值，在内存升级为 2；读取不重写旧 manifest。下一次成功编辑/导入/移除时原子写 schema2。未知版本拒绝并保留文件。添加冻结的真实形状 v1 fixture 测试，不能用当前 encoder 生成所谓旧格式。旧版 App 无法打开新 schema2 是明确限制：取得 Stage03 可运行包后需要更新安装，不能拿旧 IPA 验新文档。

LayerTransform 的 translationX/Y 定义为**图层中心相对画布左上角的位置**，不是屏幕点，也不是手势累计偏移。scale 为相对 baseSize 的统一倍率，rotationRadians 为中心旋转弧度。保留四个原键。新建图层按已纠正 EXIF 的 displayPixelSize 等比装入画布宽/高各 75% 的框，中心=(W/2,H/2)、scale=1、rotation=0，原图不裁切、不拉伸。

编辑提交范围：centerX ∈ [0,W]、centerY ∈ [0,H]，scale ∈ [0.1,8]，rotation 归一到 [-π,π)。输入必须有限；坏输入不提交。旧包变换保留，不把历史合法但超出本阶段操作范围的有限位置/正倍率静默夹断；包解码要求有限位置/旋转和正有限 scale，交互首次变更按上述范围约束。CanvasSize 要求有限正宽高。所有非法输入可测试。

排序沿用较大 zIndex 在前，同 zIndex 按 layers 数组后者在前。前移/后移为视觉邻层交换，保存后可将全部 zIndex 连续规范为 0...n−1，保持 layer.id 和画面顺序，不依赖溢出的 Int.max+1。图层锁定禁止变换/重置/排序/移除；允许解锁、隐藏/显示。隐藏图层不渲染、不接受画布命中，但在列表可选中与恢复。

## 状态、模块与持久化

ProjectStore 仍是 committed 项目快照唯一来源，constructor 无 I/O。PhotoLibrary actor 仍是唯一包文件写入者。**复用 PhotoImportModel 的 mutationToken**，允许增加具体的画布编辑提交入口和编辑显示状态；不新增第二套 library/store/coordinator 或通用 repository、事件总线、缓存框架。

在 Models 或 Features/Editor 中添加实际需要的纯几何/图层操作值或函数，可独立测试，不能耦合 SwiftUI。EditorPlaceholderView 可改名 EditorView 并更新 RootView，导航 .editor(projectID) 和已有 photoPreview route 不变。仅增加已用到的 Editor 视图与测试文件。

手势过程中使用瞬时 draft（不写 committed store、不每帧写磁盘）；一个连续组合手势结束后原子提交一次完整 document。不能分别用拖动/缩放/旋转的 onEnded 互相覆盖其他分量。按钮操作同样读取最新 committed 包，只修改目标字段，保留项目身份、素材和其他图层。

编辑/import/remove/restore 共享一把 mutation gate。手势活动期间阻止导入/移除/列表按钮并保持系统返回可用；保存期间禁用冲突编辑，显示真实保存状态；不暗中丢掉快速后续操作。写入失败保留旧 committed manifest/store，保留 draft 供重试或明确放弃，不写“已保存”。导航离开或应用转后台时，已完成的 edit task 不随视图销毁取消；活动手势安全结束/丢弃须有明确可测规则，不导致假保存。不要引入无界自动重试/防抖排队。

移除**图层**只改变 document，不删除素材文件。移除**素材照片**必须显示它会移除引用图层的说明，并在同一 manifest 事务中删除该照片及所有关联图层，再清理文件；失败保留原包，后续清理失败沿用现有 warning 机制。既有 staging/path guard/取消/限额不得退化。

## 画布和交互

画布按逻辑尺寸等比 fit 到视口，预览矩阵为 viewportOrigin + canvasPoint × fitScale。视口尺寸、横竖屏变化只改变 fitScale，不能修改 document。画布内容按边界裁切，选中框为外层可见 UI，不写入文档。背景浅深模式均可区分画布与照片边界。

拖动使用未被图层变换的画布命名坐标空间，屏幕 delta / fitScale 得画布 delta；倍率/旋转均从同一次手势开始快照合成，连续跟手，不增加惯性漂移或回弹装饰。缩放/旋转围绕照片中心；不得把触点强制跳到中心。优先 SwiftUI 原生手势，双指可同时缩放旋转，和单指拖动组合不跳变。UIKit 仅在有确切 SwiftUI 阻碍且提出最小原因后由 Architect 决定。

画布独立手势区域，不能放在吞掉单指拖动的纵向 ScrollView 内；素材/图层列表在独立可滚动区域或原生 sheet。必须可返回、打开素材预览、重试保存、选中被遮挡或隐藏图层。点空白取消选择；点照片选择最上方可命中可见层。锁定层可以点选但不能编辑。选择状态仅内存保存，不序列化。

照片仍通过 DerivedImageView / PhotoImportModel / PhotoLibrary 异步加载派生图，解码不在主线程。未选中图层用 thumbnail，选中层最多一个 2048px preview，避免 20 个大预览同时解码；切选及任务取消保留既有过期结果丢弃规则，不能每次 transform 刷新就重新解码。缺文件显示明确占位与重试，不拖垮整个画布。

提供带文字的原生图层列表与“添加到画布”入口，选中/锁定/隐藏可区分，不只靠颜色。主要按钮 ≥44×44pt，SF Symbols、系统字体，最大 Dynamic Type 可以滚动访问按钮，不覆盖画布关键控件。移动/缩放/旋转至少有可访问的数值或步进按钮替代手势，VoiceOver 可选择并操作层。深色/浅色、减少动态效果、375pt 宽与横屏列为实际检查项；iPad 完整产品适配留后续，不伪称已验。

依据：[Apple MagnifyGesture](https://developer.apple.com/documentation/swiftui/magnifygesture)、[画布坐标空间](https://developer.apple.com/documentation/swiftui/draggesture/coordinatespace)、[原生可访问操作](https://developer.apple.com/documentation/swiftui/accessible-controls)。apple-design 只采用跟手/空间一致/可中断原则，不采用其 Web/CSS 实现或材质品牌。ui-ux-pro-max 两次 SwiftUI 手势查询未匹配，采用其通用触控/可访问性规则，不声称检索验证了 API。

## 验证与交付

自动测试覆盖：v1 冻结 fixture→v2 兼容与无读时重写；新字段 Codable；坏尺寸/非有限变换/无效引用/重复身份/上限；EXIF5...8初始尺寸、屏幕映射及组合变换；稳定排序及极端 zIndex；锁定/隐藏；图层移除保留素材；照片移除级联且原子；保存成功/失败/重试、mutation gate 和项目切换/后台不串写；保存重建 library/store 后几何与层级一致。保留 Stage01/02 原有行为断言；因正式版本升级变更旧 schema=1 断言时说明原因，不能削弱测试。

新增 Stage03 UI smoke：真实导入→添加两层→选择/拖动→按钮缩放旋转→调序/隐藏锁定→重开持久化→删层保留素材。双指原生手势、误触/中断和视觉需要独立运行证据；用按钮代替的 smoke 不能声称双指通过。不得添加 App 的测试演示入口或测试专属业务分支。

Windows 只跑既有工程生成/结构/静态检查。macOS Xcode 构建/完整 unit+UI、设备 IPA 及本人交互均 **待执行**，使用届时实际可用且经确认的环境，不自动续租/付费/上传私密内容。不复用 Round37 未通过的辅助链，也不把 Stage02 的 85 写成 Stage03 固定测试总数。Stage03 完整测试必须按实际新增清单核对，无跳过关键用例；待原生结果再讨论 CI 门禁适配，不在本任务暗改现有 workflow。

DSH 完成交付代码、报告、Review packet 和验收说明后停止于 READY_FOR_ARCHITECT_REVIEW。Architect 做架构/Bug/性能/警告/视觉 Review，准备真实可运行版本。只有所有者亲自验收并明确批准才结束 Stage03；不能开始 Stage04。
