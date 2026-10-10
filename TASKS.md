# TASKS.md — 路线图与当前状态

## 当前状态

**2026-10-10 12:29最新状态：**所有者“进行stage06”，明确授权Photo Role Suggestions and Saved Choices。真实DSH已完成任务01与FIX05–07，Architect[最终源码预审](.ai/reviews/STAGE-06-SOURCE-REVIEW-2026-10-10.md)通过，独立结构/语法/冻结旧186及256方法清单通过；准备完整原生验证，尚无Stage06 Xcode/IPA/本人验收。先获得本地角色建议，可改用途并保存，下一次显式布局应用尊重主图和留作拼贴/不用的选择。Stage07及以后未授权。下方10:40收尾状态是历史。

**已批准基线与分工：**2026-10-10 10:40所有者在新版真机对三组实际操作分别回复“正常”，Stage04/05均APPROVED，见[收尾](.ai/reviews/STAGE-04-05-OWNER-CLOSEOUT-2026-10-10.md)。Architect负责规格、独立Review及交付，真实DSH负责实现，所有者负责最终验收；详见[工作须知](工作须知.md)及[根交接](项目要求与上下文交接.md)。Stage06已授权，Stage07–15未授权。

已验收基线：Stage04构图预览/搜索/Apply及Stage05只读光色分析均实现。源码fe17ac0完整186/186原生通过，同源设备包已校验并完成本人三组验收，两阶段APPROVED；历史失败及未测限制保留。Stage06初稿尚未原生验证。

| 项 | 值 |
| --- | --- |
| 当前 Stage | **Stage06 — Photo Role Suggestions and Saved Choices** |
| Stage 状态 | READY_FOR_ARCHITECT_REVIEW；源码预审通过，原生验证与最终技术Review/本人验收仍待执行 |
| 本地代码 | 原生缩略图角色建议/四用途人工选择/角色保存/显式布局集成及来源一致；当前单画布，完整AI整组与导出尚未实现 |
| Xcode 构建 / 测试 | [原生run37969910797](https://github.com/Icatly/moments-studio/actions/runs/37969910797)完整176单元+10 UI=186/186通过，0失败/跳过；源码fe17ac0。旧失败保留，见[技术复审](.ai/reviews/STAGE-04-05-NATIVE-FINAL-2026-10-10.md) |
| 当前手机包 | Stage04/05 sourcefe17ac0；新版两个入口可见，三组实际操作获本人正常反馈 |
| 下一步 | 冻结精确已审源码，完整256项原生验证；真实通过后同源设备交付 |

Stage 01 的详细任务见 [.ai/tasks/STAGE-01-TASKS.md](.ai/tasks/STAGE-01-TASKS.md)，验收清单见 [.ai/acceptance/STAGE-01.md](.ai/acceptance/STAGE-01.md)。

## 产品交付优先级（2026-10-09校正，后续仍为草案）

所有者最新定位：以大量风景照搭配少量无需美颜或已修好的人像，快速生成合意图组；商业目标为基础回本。三个推荐方向均须有参考图或预设，用户看过并选定后生成整组。风格来源可考虑GitHub照片skill，但需许可、适配和稳定效果验证。发布用途/数量给可改建议，避免新增必填问卷。该产品方向已按所有者要求记入文档；具体阶段实施、最终风格和定价尚未批准。见[产品基线](docs/产品与架构基线.md)及[客户与商业评估](.ai/reviews/PRODUCT-COMMERCIAL-REVIEW-2026-10-09.md)。

主路径：**导入照片及同页可改建议 → 三方向视觉参考/预设＋可选搜索 → 选定后AI生成整组 → 可选微调 → 保存相册**。画面短文字和配套文案按需使用。

1. 首个成品闭环的输入与选择：照片导入、可改的用途/数量建议、自动角色建议、三个差异明确的参考方向、基本关键词搜索与选择保留。先提供参考/轻量预览，选择后才生成整组；不以单一风格或三个名称代替此要求。
2. 同一闭环的核心生成与交付：AI理解/整组构图、逐图自适应调色、局部修改、静态图片保存相册；允许完整照片与拼贴页混排，保护已修人像。可选文字辅助表达。基本预设与静态导出必须服务首个用户闭环，不等到旧Stage13/14；不能仅完成手动排版就宣称核心AI产品交付。
3. 成品质量与商业验证：用目标用户真实照片组检验构图、色彩、人像保真、整组接受、修改时间、失败/重试成本及付费意愿；小范围验证基础回本。具体试验门槛与定价待确定。
4. 主线稳定后扩充经过验证的风格库、适用的抠图/剪影、高级编辑和生产准备；实时多平台趋势采集及动态效果另行定范围。人工趋势策展是先验证价值的建议。

以上是产品交付顺序，不是四个获批Stage。Stage04已完成其中的确定性布局与三构图预设预览/搜索/保存，见[规格](docs/architecture/STAGE-04-DETERMINISTIC-LAYOUT.md)。首个完整用户闭环仍须包含三风格参考、AI自适应图组与相册导出；具体后续阶段拆分与执行尚未批准。

原图保护、AI结构化提案、确定性渲染及用户修改/锁定保留原则不变。具体阶段编号与AI执行方案待定义，不以文档校正代替执行授权。详见[产品主线校正](.ai/reviews/PRODUCT-DIRECTION-2026-10-09.md)。

## 原始技术模块拆分（保留参考，后续编号与交付顺序待重排）

以下表格保留原始Prompt的技术模块划分，后续交付优先级以顶部2026-10-09校正为准。Stage01–05已按所有者反馈通过；Stage06仅批准顶部本地角色范围，Stage07–15未批准，不是自动执行队列。

| Stage | 名称 | 说明 | 状态 |
| --- | --- | --- | --- |
| 01 | Project Foundation | 工程骨架、导航、基础模型、测试 | APPROVED（所有者2026-10-03明确确认） |
| 02 | Photo Import and Asset Pipeline | 多图导入、原始副本/派生图、关联包与导入项目恢复 | APPROVED（所有者2026-10-06明确进入Stage03；云验证缺口保留） |
| 03 | Editable Canvas and Layer System | 手动照片图层、变换/层级/隐藏锁定、原子保存与旧包兼容 | APPROVED（所有者“进入stage04”；未完真机项保留） |
| 04 | Deterministic Layout and Three Preset Previews | 单画布确定性排版、三真实照片预览/基本搜索/显式保存 | APPROVED（2026-10-10两组真机反馈正常；历史失败保留） |
| 05 | Photo Analysis Foundation | 每图光色测量、采样置信度、类型化失败和可选摘要 | APPROVED（2026-10-10最后一组真机反馈正常；见[收尾](.ai/reviews/STAGE-04-05-OWNER-CLOSEOUT-2026-10-10.md)） |
| 06 | Photo Role Suggestions and Saved Choices | 本地主图/配图建议，人工拼贴素材/不用，保存选择并显式布局集成 | IMPLEMENTING（任务01已实送既有DSH并观察运行，见[规格](docs/architecture/STAGE-06-PHOTO-ROLES.md)） |
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

1. **静态导出应早于动态系统**：必须在静态渲染与导出链路被验证之后，才在其上建立动态图层。因此上表中 Stage 12/13 的编号与顺序仅是草案，具体编号与顺序由项目所有者与 Architect 按当前产品主线确定，尚未批准。
2. 每进入一个 Stage 前，都需要重新确认该 Stage 的范围、验收标准与技术选型。

## 待办登记（Backlog，未排期）

- 应用显示语言（当前所有界面文案为英文占位）。
- 产品名称、Bundle ID、App 图标占位替换（提审前必须完成）。
- 已按所有者授权初始化根目录Git；仓库后已按“那公开吧”指令公开，标准运行器验证成功。嵌套空仓库保持独立，不纳入提交。
- `tools/` 生成式 Xcode 工程与 Xcode 直接管理工程之间的取舍。

- Stage02遗留验证：9fac第三轮/最新设备包/环境还原、Home最大字号native检查，真实结果未知；在Stage03真实回归中覆盖，不伪填历史结果。Round37辅助运行链不作为新阶段门禁。
