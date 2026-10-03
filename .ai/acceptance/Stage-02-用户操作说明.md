# Stage 02 用户验收操作说明

状态：暂停交付验收。2026-10-04已上传Stage02源码0121261运行包，84项macOS测试实际通过，但iOS17.2点预览退出（缺PhotoImportModel，Round12/FIX06）。FIX06/source96dece5已编译，85项中84通过、新增UI在选择照片测试定位失败（Round14/FIX07），尚未验证修正后的预览。等待修正新包；现有包不可批准Stage02。以下操作顺序仍为修正后的验收草案。

## 本阶段检查什么

一次导入多张照片、缩略图与只读预览、追加导入、移除本项目副本、取消、保存与重新启动后恢复。使用中性系统原生界面，最终品牌/UI设计后续单独验收。没有拼贴、AI、调色、画布编辑或导出。

## 测试照片

Architect已准备合成竖图、横图、透明PNG，位置 `.ai/build/downloads/stage02-photo-fixtures/`，没有真实人物或私人照片。将这三张图通过模拟器工具栏 Upload File 放入相册后，再进入应用选择。第四次macOS运行（source0c905a3，run37135113445）的JPEG、合成HEIC和EXIF旋转/镜像单元测试实际通过；该轮总体失败，修正后的当前源码仍需重跑。上述三张PNG本身不证明其他格式，Appetize媒体上传也不作为HEIC验证。

## 操作顺序（待新包可用后执行）

1. Create Project → Import Photos，按指定顺序点选三张，再确认导入。检查缩略图次序与照片数量。
2. 点一张缩略图查看完整预览，比例和方向正确。Done返回。
3. 再次Import Photos追加一张（允许再次选相同照片，独立副本）。检查原有照片仍在、总数增加。
4. 打开一张预览 → Remove → Cancel，照片保持；再次Remove并确认，只有本项目这一副本移除，相册照片仍在。
5. 返回Home，再打开同一项目，照片与数量保持。
6. 在同一个模拟器会话内通过 iOS 应用切换器关闭 Moments Studio，再点应用图标重新启动，核对项目与照片恢复。当前 Appetize 工具栏已观察到 Home 等按钮，但未观察到 Restart App；不要假定有该按钮。也不要用结束会话/刷新网页代替应用重启。
7. 新一批导入中Cancel或返回Home：已保存项保留，剩余项停止；取消不显示为失败。小测试图处理可能太快，需要较大的测试图才能观察到取消。
8. 检查浅/深色和大字号下的导入、数量、预览、移除确认与返回能看清/点击。

## 模拟器边界

Appetize每个新会话是全新安装，结束会话后的数据消失不等于应用本地保存失败；恢复验收必须在同一设备会话内关闭应用再启动。[官方会话说明](https://support.appetize.io/how-do-i-maintain-app-state-between-sessions)。[官方媒体说明](https://docs.appetize.io/features/media)目前列出iOS支持PNG/JPEG/JPG/GIF/MP4、单文件50MB，不列HEIC；Stage02的HEIC支持由macOS测试补证，不声称Appetize可直接上传HEIC。免费会话额度用完按所有者要求暂停，等重置；不付费。

## 验收决定

当前不请求验收。新版本交付后，所有者本人完成检查，回复“通过”或列出修改意见。测试/构建成功不自动通过，Stage03未授权。
