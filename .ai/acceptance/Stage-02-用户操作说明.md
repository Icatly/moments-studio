# Stage 02 用户验收操作说明

状态：暂停交付验收。2026-10-04第四轮之后的有效旧包0121261仍在Appetize（预览缺PhotoImportModel，iOS17.2退出）；FIX06已显式传入同一模型实例。最新run8/sourceb9cf5a7真实编译成功，新的完整导入/预览/移除/再次导入用例已通过，18.5实际预览截图已审；全85项中84通过、既有取消选择器smoke失败，正在执行FIX09。待全套通过的新包及17.2必要复查；现有包不可批准Stage02。以下是新包准备后的验收顺序。

## 本阶段检查什么

一次导入多张照片、缩略图与只读预览、追加导入、移除本项目副本、取消、保存与重新启动后恢复。使用中性系统原生界面，最终品牌/UI设计后续单独验收。没有拼贴、AI、调色、画布编辑或导出。

## 测试照片

模拟器默认相册的照片可直接用于导入/预览检查，无需先上传。Architect另备合成竖图、横图、透明PNG，位置 `.ai/build/downloads/stage02-photo-fixtures/`，没有真实人物或私人照片。检查方向/透明时，通过工具栏 Upload File **逐个**上传到当前会话相册，再在应用内选择；此前一次多文件选择仅观察到第一张实际加入，不能假定三张都已上传。最新第八次macOS运行（sourceb9cf5a7，run37149876593）JPEG、半透明PNG、合成HEIC和EXIF旋转/镜像单测通过，完整真实导入预览移除再次导入UI也通过；唯一取消选择器smoke失败仍需修正。上述PNG本身不证明HEIC，Appetize上传不作为HEIC验证。

## 操作顺序（待新包可用后执行）

1. Create Project → Import Photos，按指定顺序点选三张，再确认导入。检查缩略图次序与照片数量。
2. 点一张缩略图查看完整预览，比例和方向正确。Done返回。
3. 再次Import Photos追加一张（允许再次选相同照片，独立副本）。检查原有照片仍在、总数增加。
4. 打开一张预览 → Remove → Cancel，照片保持；再次Remove并确认，只有本项目这一副本移除，相册照片仍在。
5. 返回Home，再打开同一项目，照片与数量保持。
6. 在同一个模拟器会话内，从屏幕底边上滑到中部并停顿，打开应用切换器；将 Moments Studio 的应用预览向上滑动关闭，再点应用图标启动，核对项目与照片恢复（[Apple 操作说明](https://support.apple.com/guide/iphone/switch-between-open-apps-iph1a1f981ad/ios)）。当前 Appetize 工具栏已观察到 Home 等按钮，但未观察到 Restart App；不要假定有该按钮。也不要用结束会话/刷新网页代替应用重启。
7. 新一批导入中Cancel或返回Home：已保存项保留，剩余项停止；取消不显示为失败。小测试图处理可能太快，需要较大的测试图才能观察到取消。
8. 检查浅/深色和大字号下的导入、数量、预览、移除确认与返回能看清/点击。

## 模拟器边界

Appetize每个新会话是全新安装，结束会话后的数据消失不等于应用本地保存失败；恢复验收必须在同一设备会话内关闭应用再启动。[官方会话说明](https://support.appetize.io/how-do-i-maintain-app-state-between-sessions)。[官方媒体说明](https://docs.appetize.io/features/media)目前列出iOS支持PNG/JPEG/JPG/GIF/MP4、单文件50MB，不列HEIC；Stage02的HEIC支持由macOS测试补证，不声称Appetize可直接上传HEIC。免费会话额度用完按所有者要求暂停，等重置；不付费。

## 验收决定

当前不请求验收。新版本交付后，所有者本人完成检查，回复“通过”或列出修改意见。测试/构建成功不自动通过，Stage03未授权。
