# Stage 02 验收

Stage: 02

Name: Photo Import and Asset Pipeline

Status: IMPLEMENTING

User Decision: PENDING

Stage01于2026-10-03由所有者明确批准，并授权继续下一阶段。Stage02需求、架构、执行任务已定义；实现/测试/Review/可运行版本尚未完成。本文件不表示Stage02已获验收批准。

## 所有者验收清单

- [ ] 系统照片选择器一次选择多张照片，导入顺序和数量正确。
- [ ] 不申请完整图库权限；原图仅复制，系统相册中的照片不被修改。
- [ ] 原始文件、缩略图与预览图正确保存，方向、比例与透明图显示正确。
- [ ] 追加导入、只读预览、移除本项目照片正常，未影响其他项目。
- [ ] 导入进度、取消和失败提示明确，旧素材不因失败丢失。
- [ ] 导入后的项目在应用重新启动后可恢复；未保存的空项目限制明确。
- [ ] 导入时可操作导航，无明显UI阻塞；浅/深色与大字号基本可用。
- [ ] 当前源码的自动测试与macOS构建实际执行，Architect完成架构/Bug/性能/警告/视觉Review。
- [ ] 所有者已亲自检查Stage02可运行版本，并明确作出验收决定。

## 验收方法

用至少3张合成照片（竖/横/EXIF旋转或镜像、不同格式）一次导入，再追加、预览、移除。返回Home、重开对应项目，terminate/relaunch后核对照片和项目；取消新一批导入，确认已完成项保留而剩余项停止；受控失败不损坏旧数据。容量、大图、文件摘要、方向和回滚由自动测试及Architect证据补充。

需求/完成标准：[Stage02架构](../../docs/architecture/STAGE-02-PHOTO-ASSET-PIPELINE.md)。执行任务：[IMPLEMENT01](../tasks/STAGE-02-IMPLEMENT-01.md)。当前没有Stage02运行包；Stage01 Appetize链接不能冒充新阶段版本。用户操作说明在真实构建与Review完成后提供。

## 状态记录

| 日期 | 状态 | 触发 |
| --- | --- | --- |
| 2026-10-03 | SPEC_READY | 所有者批准Stage01并要求继续；Architect完成Stage02需求、架构与执行任务 |
| 2026-10-03 | IMPLEMENTING | 执行任务已实际发送，DSH回复“Stage 01 approved — starting Stage 02”并开始读取/实现 |

只有所有者亲自检查并明确通过后可APPROVED。提出修改意见即CHANGES_REQUESTED，仅修当前阶段。DSH交付只到READY_FOR_ARCHITECT_REVIEW；Stage03–15未批准。
