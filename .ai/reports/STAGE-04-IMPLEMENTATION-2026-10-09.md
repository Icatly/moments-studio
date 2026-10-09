# Stage04本地实现报告 — 2026-10-09

执行来源纠正（所有者提醒分工后）：下述本地实现、测试编码和工作流准备实际由Architect直接完成，偏离Architect/DSH既定分工，不是DSH交付。现有改动保留待DSH接手核验；Architect恢复规格/评审职责。尚未发送Stage04任务给DSH，未提交/推送，未派发GitHub运行。

来源：所有者“进入stage04”；范围：[架构](../../docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)。状态READY_FOR_ARCHITECT_REVIEW，原生运行/新包/本人验收未执行。

## 实现

- `Models/CollageLayout.swift`：纯Foundation、三确定性构图预设；空画布按导入照片建层，已有画布只重新排列可见未锁定层；旋转后完整容纳，比例/层身份/堆叠/原始素材保留，重复应用不增层。
- `CollageLayoutSheet`、编辑器Layouts入口、集中sheet路由：三本人照片预览、内置中英文关键词搜索、所选项保留、取消/Apply、失败Retry/Discard。预览只读取320缩略图并禁用手势，不加载原图。
- `PhotoImportModel`新增非持久化layout意图，复用原子保存、gesture/import gate、项目作用域和失败draft。验证错误明确rejected，磁盘写入失败才saveFailed，重试基于最新文档保留新锁定层。
- Codable字段/schemaVersion2不变、无App运行期依赖新增。生成工程使用既有Python标准库脚本；不是App功能，也没有引入包拆分或空接口。

## 已执行

- `tools/generate_xcodeproj.py`与`tools/verify_project.py`：154对象、52文件引用、51 Swift文件结构/括号/标识符检查通过。App31、unit15、UI5 Swift源文件，各进唯一target。这不是Swift类型检查或Xcode构建。
- Stage04两个工作流YAML解析、20段Bash语法、11段嵌入Python语法通过；现有本机YAML解析器复用，未安装新依赖。Windows沙盒阻止Bash信号管道后，仅将只读检查移到沙盒外执行，成功；未执行App或联网。
- 从实际源码生成146单元＋9 UI＝155方法清单；新增17方法（布局11、真实存储4、导航1、UI1）。除导航追加覆盖外，原测试文件按Git行尾规范与HEAD一致，Stage03工作流保留原样。
- 实际结果门禁用10份明确合成输入验证正确计数和拒绝失败/跳过/错误设备等情况。**合成门禁例子不是155项XCTest通过**。本地证据：`.ai/build/stage04-local-review-20261009-211134/review.json`及同目录源码清单；不发布私密原始证据。

## 未执行与限制

Xcode编译、155项XCTest、真实照片预览视觉/无障碍、Stage04 IPA构建/签名/安装及本人验收均未执行。手机仍Stage03 source68864c2。Stage04当前仅一张画布，三功能构图预设，不做AI推荐/滤镜、多页图组、相册导出、外部模板库或实时趋势。锁定/隐藏层完全保留，可能与被重排层重叠；极端历史几何超出现有scale范围会拒绝而非裁图。

下一步：限定源码完整macOS测试，实际成功后准备同源码新包和[本人验收](../acceptance/STAGE-04.md)，不自动进入Stage05或产生新增费用。
