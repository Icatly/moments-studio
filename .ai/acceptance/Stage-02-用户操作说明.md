# Stage 02 用户验收操作说明

状态：草稿，尚无 Stage02 可运行版本。当前旧 Appetize 版本为 Stage01，不可用来验收 Stage02。待实际构建、Architect Review与照片导入检查完成后更新此文件。

## 本阶段检查什么

一次导入多张照片、缩略图与只读预览、追加导入、移除本项目副本、取消、保存与重新启动后恢复。使用中性系统原生界面，最终品牌/UI设计后续单独验收。没有拼贴、AI、调色、画布编辑或导出。

## 测试照片

Architect已准备合成竖图、横图、透明PNG，位置 `.ai/build/downloads/stage02-photo-fixtures/`，没有真实人物或私人照片。将这三张图通过模拟器工具栏 Upload File 放入相册后，再进入应用选择。JPEG/HEIC与EXIF镜像/旋转需补充macOS自动测试或实际检查证据；上述PNG本身不证明这些格式。

## 操作顺序（待新包可用后执行）

1. Create Project → Import Photos，按指定顺序点选三张，再确认导入。检查缩略图次序与照片数量。
2. 点一张缩略图查看完整预览，比例和方向正确。Done返回。
3. 再次Import Photos追加一张（允许再次选相同照片，独立副本）。检查原有照片仍在、总数增加。
4. 打开一张预览 → Remove → Cancel，照片保持；再次Remove并确认，只有本项目这一副本移除，相册照片仍在。
5. 返回Home，再打开同一项目，照片与数量保持。
6. 在同一个模拟器会话内使用工具栏 Restart App重新启动应用，再检查原项目与照片恢复。不要用结束会话/刷新网页代替重新启动。
7. 新一批导入中Cancel或返回Home：已保存项保留，剩余项停止；取消不显示为失败。小测试图处理可能太快，需要较大的测试图才能观察到取消。
8. 检查浅/深色和大字号下的导入、数量、预览、移除确认与返回能看清/点击。

## 模拟器边界

Appetize每个新会话是全新安装，结束会话后的数据消失不等于应用本地保存失败；恢复验收必须在同一设备会话内Restart App。[官方会话说明](https://support.appetize.io/how-do-i-maintain-app-state-between-sessions)。[官方媒体说明](https://docs.appetize.io/features/media)目前列出iOS支持PNG/JPEG/JPG/GIF/MP4、单文件50MB，不列HEIC；Stage02的HEIC支持由macOS测试补证，不声称Appetize可直接上传HEIC。免费会话额度用完按所有者要求暂停，等重置；不付费。

## 验收决定

当前不请求验收。新版本交付后，所有者本人完成检查，回复“通过”或列出修改意见。测试/构建成功不自动通过，Stage03未授权。
