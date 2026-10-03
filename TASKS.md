# TASKS.md — 路线图与当前状态

## 当前状态

| 项 | 值 |
| --- | --- |
| 当前 Stage | **Stage02 — Photo Import and Asset Pipeline** |
| Stage 状态 | CHANGES_REQUESTED（Architect Round18）；run8 完整流程（导入→预览→移除→再导入）**实际通过且预览截图已目视审过**，仅既有 Cancel smoke 的就绪判据需 FIX09；17.2 复查与新交付包仍缺；所有者PENDING，Stage03禁止 |
| 实现 | Stage01 已完成并获所有者批准；Stage02 已实现，并完成 Architect 实现中检查 13 项、FIX-01 六项、FIX-02 三项、FIX-03 调用标签、FIX-04 测试字面量显式类型、FIX-05 四项运行期修正 + 三项复审澄清、FIX-06 模态环境注入与导入预览 UI 回归、FIX-07 系统选择器原生定位修正、FIX-08 只读预览判据与保留截图、FIX-09 Cancel smoke 就绪同步：多图导入、应用自有 original 副本、ImageIO 缩略图/预览、项目包持久化与恢复、导入/网格/只读预览/移除 UI |
| Xcode 构建 / 测试 | 第八次run37149876593/sourceb9cf5a7：**编译成功**，80单元+4既有UI通过，**新的完整真实流程用例通过（54.357秒）**且其预览截图已目视审查（照片正向、2:3、无裁断、信息与按钮可辨、无 loading/missing/unavailable）；**唯一失败**是既有 `testImportPickerCanBeDismissedBackToTheEditor`（`Stage02ImportUITests.swift:65` Cancel 点击后 20 秒有界消失等待超时），85/84/1/0。原生录屏显示选择器先出现初始化 Loading+Cancel、约 13 秒才有完整 Photos 导航/网格；原生树（run 37147120379:72-77）证实真正的 Cancel 位于 `NavigationBar identifier: 'Photos'` 之下。**FIX09 已把该 smoke 改为：正向等待 Photos 导航 → 该作用域内类型化 Cancel → 有界 enabled+hittable → 单次点击 → Cancel 与 Photos 导航双双有界消失 → Editor enabled+hittable，失败附原生层级。** 本机 Windows 无 Xcode，**80 单元 + 5 UI = 85 项全部未执行**，FIX09 的 macOS 结果 **UNVERIFIED** |
| 可运行版本 | Stage02源码0121261已上传Appetize，真实多选3张成功；预览退出，当前版本阻塞验收；FIX06–09 修正版均未打包（尚无通过构建门禁的新交付包）。Appetize 额度 27/30、剩 3 分钟、暂停未消耗；原Stage01批准保持 |
| 下一步 | Architect 复审 FIX09 → macOS 重跑全 85 项（期望 Cancel smoke 与完整流程同时通过）→ 生成有效新包并做 17.2/重启/深色大字号必要复查 → 所有者验收 |

Stage 01 的详细任务见 [.ai/tasks/STAGE-01-TASKS.md](.ai/tasks/STAGE-01-TASKS.md)，验收清单见 [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)。

## 路线图（Stage01已批准；Stage02实现已授权；后续为草案）

以下路线图来自原始Prompt。Stage01已通过，所有者明确要求继续Stage02；Stage02细化范围见执行任务和架构。Stage03–15仍未批准，不是自动执行队列。

| Stage | 名称 | 说明 | 状态 |
| --- | --- | --- | --- |
| 01 | Project Foundation | 工程骨架、导航、基础模型、测试 | APPROVED（所有者2026-10-03明确确认） |
| 02 | Photo Import and Asset Pipeline | 多图导入、原始副本/派生图、关联包与导入项目恢复 | IMPLEMENTING（DSH已开始，验收PENDING） |
| 03 | Editable Canvas and Layer System | 可编辑画布、图层模型扩展、手势与变换 | 未批准 |
| 04 | Deterministic Collage Layout Engine | 确定性布局引擎（同一文档 → 可复现结果） | 未批准 |
| 05 | Photo Analysis Foundation | 每图测量、置信度、失败原因 | 未批准 |
| 06 | Photo Role Classification | 角色分类（主图、次要、可抠主体、剪影/贴纸候选、不用） | 未批准 |
| 07 | Cutout / Silhouette / Sticker Engine | 主体分割、剪影与贴纸生成 | 未批准 |
| 08 | Adaptive Style Engine | 目标观感 + 每图测量 + 独立调整量 | 未批准 |
| 09 | AI Art Direction and Collage Planning | 结构化拼贴规划提案 | 未批准 |
| 10 | Sticker Placement Intelligence | 贴纸摆放建议 | 未批准 |
| 11 | Advanced Manual Editing | 完整手动编辑与用户锁定 | 未批准 |
| 12 | Motion Layer System | 轻量动态图层 | 未批准 |
| 13 | Export Pipeline | 静态导出（含动态导出） | 未批准 |
| 14 | Template System | 模板与预设 | 未批准 |
| 15 | App Store Production Readiness | 上架准备、隐私、元数据、性能 | 未批准 |

### 关于顺序的两点约束

1. **静态导出应早于动态系统**：必须在静态渲染与导出链路被验证之后，才在其上建立动态图层。因此上表中 Stage 12/13 的编号与顺序仅是草案，具体编号与顺序留待 Stage 01 通过后由项目所有者与 Architect 决定。
2. 每进入一个 Stage 前，都需要重新确认该 Stage 的范围、验收标准与技术选型。

## 待办登记（Backlog，未排期）

- 应用显示语言（当前所有界面文案为英文占位）。
- 产品名称、Bundle ID、App 图标占位替换（提审前必须完成）。
- 已按所有者授权初始化根目录Git，并上传私有仓库；嵌套空仓库保持独立，不纳入提交。
- `tools/` 生成式 Xcode 工程与 Xcode 直接管理工程之间的取舍。
