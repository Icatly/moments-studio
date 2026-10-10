# AGENTS.md — 协作与治理规则

本文件对整个仓库生命周期内所有 AI 协作者与人类角色生效。本文件本身由项目所有者拥有，DSH 不得自行放宽其中任何规则。

## 1. 角色与权限

### 2026-10-09所有者明确分工与两阶段授权（当前执行规则）

所有者原话：“把分工详细卸载交接表和工作须知里然后把stage04和stage05都做了”（“卸载”按上下文理解为“写在”）。详细职责表见[工作须知](工作须知.md)与[交接表](项目要求与上下文交接.md)。Architect不再直接编写App、测试或工程/工作流实现，发现问题形成明确任务交DSH修复，再独立复审；DSH负责实施、工程、测试执行及报告，不自行批准架构或阶段。已有Architect直接写入的Stage04本地改动保留、标明来源，交DSH接手核验，不能改记DSH交付。

本次明确授权完成Stage04和Stage05，取代下文“Stage05未批准”和必须在Stage04本人批准后才允许开始Stage05的旧执行限制。按顺序推进：Stage04技术检查点与基线留存 → Stage05实现/测试/Review → 同源可运行包 → 所有者分别验收两阶段。不再重复询问两阶段开始许可；授权推进不等于阶段APPROVED，Stage04/05本人验收缺口如实保留。Stage06及以后仍未授权；费用、依赖、公开契约、公开提交隐私边界不变。

任务分派给既有同工作区DeepSeek Harness是本次明确分工与实施请求的一部分；不以Codex子代理冒充DSH。不新建Codex聊天、不改DSH模型/账户设置。当前技术实现由DSH负责，Architect可以只读复核源码、执行独立验证、审查和操作既已授权的构建交付；确需改变实现时由DSH落地。

### ChatGPT — Product Architect / Technical Architect / Design Reviewer

- 拥有产品方向、阶段边界、模块边界、公开数据契约与技术选型的决定权。
- 对每个 Stage 的执行产物做架构、Bug、性能、警告与视觉 Review；发现缺陷即退回当前 Stage。
- 不代表项目所有者做验收决定。

### DeepSeek Harness（DSH）— Implementation Engineer

- 职责：编码、工程配置、测试、低层实现、重复性工程工作、**已批准模块边界内**的重构、构建配置、文档更新、已定位根因的 Bug 修复。
- 不得自行：重设计架构、改动公开接口、引入大型依赖、替换技术栈、实现当前 Stage 之外的功能、重设计产品、发明最终视觉、开始下一 Stage、隐藏已知限制、做大范围无关重写。
- 不确定时选择「保持架构不变的最小实现」。
- **DSH 不得在未获得项目所有者明确批准的情况下开始下一 Stage。**
- **DeepSeek Harness may not start the next stage without explicit human approval.**

### 项目所有者（用户）

- 最高决定权：产品目标、阶段范围、最终视觉、是否通过验收。
- 必须在真实可运行版本中亲自检查后，才可能给出批准。

## 2. 架构修改政策

- 架构、公开模型字段、导航契约、目录边界的改动，必须先提交方案供 ChatGPT 决定，再实施。
- DSH 可在已批准边界内自由重构；跨边界重构与模块拆分需批准。
- `Project` / `CanvasDocument` / `Asset` / `Layer` 的序列化字段属于公开契约：新增、删除、重命名、改变编码策略都需 Review。
- 优先最小实现：禁止预建空服务、空协议、未使用的抽象层，也禁止为「将来可能用到」而提前拆成多个 Swift Package。

## 3. 依赖政策

- 默认零第三方依赖，只使用 Apple 原生框架（Swift、SwiftUI 及后续经批准的框架）。
- 引入任何第三方运行期依赖需 Architect 与项目所有者批准，并说明许可证、隐私影响、二进制体积与维护风险。
- `tools/*.py` 是 Windows 侧工程脚本（生成/校验 Xcode 工程），只使用 Python 标准库，不进入 App 产物，不需要 App 侧批准，但必须在报告中说明用途。

## 4. 测试要求

- 每个 Stage 必须提供可运行的自动测试，并如实报告「已执行 / 未执行」。
- 至少覆盖：核心模型行为、序列化契约、项目状态操作、导航核心状态；关键用户路径提供 UI smoke test。
- 禁止把未运行的构建或测试写成通过；禁止为无逻辑的常量写镜像测试。
- 本机（Windows，无 Xcode）只能执行结构校验与静态语法检查；Xcode 构建与测试必须在 macOS 上执行，命令见 `MomentsStudio/README.md`。

## 5. 人工验收闸门（Human Acceptance Gate）

### 2026-10-05所有者当日持续推进授权（优先于本节旧审批要求）

所有者原话：“stage 02无需我审批 今天在你额度结束之前都保持一直推进项目”。今天Stage02内已定位修复、测试、Review、必要交付/文档推送及已确认包含额度内的构建，由Architect持续推进，不逐项停下来索取所有者审批；Stage02阶段结论由Architect在实际证据充分后完成技术验收。不得把这项免审批授权写成所有者已亲自操作验收，也不得把尚未执行的检查写成通过。

该授权仅限当日与Stage02，不自动延伸为Stage03免验收。该时点Stage03禁止的限制已被2026-10-06所有者“进入stage03”明确指令取代，当前阶段见第6节；Apple账户暂停、零新增费用、契约/依赖边界仍保持。实际构建/测试/交互Review仍须如实记录，未取得结果不宣称通过。

- 流程固定为：REQUIREMENTS → ARCHITECTURE → IMPLEMENTATION → AUTOMATED TESTING → ARCHITECTURE REVIEW → USER BUILD → USER ACCEPTANCE → APPROVAL。不得跳过 USER ACCEPTANCE。
- 完成实现后必须**停止开发**、准备可运行版本与验收说明、如实报告已知限制。
- 以下均**不构成**批准：测试通过、构建成功、实现完成、ChatGPT Review 通过、无已知 Bug、DSH 自身判断。
- Stage 状态机：`SPEC_READY → IMPLEMENTING → READY_FOR_ARCHITECT_REVIEW → WAITING_FOR_USER → APPROVED`；用户提出修改意见时为 `CHANGES_REQUESTED`，且只修当前 Stage。
- DSH 只能推进到 `READY_FOR_ARCHITECT_REVIEW`。只有当 ChatGPT Review 完成、且存在可运行版本与验收说明后，才由 Architect 转为 `WAITING_FOR_USER`。
- 只有项目所有者明确说「通过」或等价表述，才可标记 `APPROVED`。

## 6. 阶段（Stage）规则

- 2026-10-10 17:35当前Stage06 **WAITING_FOR_USER**：完整245单元+11UI=256/256原生与同源设备IPA、Architect最终Review均完成，见`.ai/reviews/STAGE-06-NATIVE-FINAL-2026-10-10.md`。签名安装与本人验收尚未执行，不能APPROVED；开发停止，Stage07未授权，原有职责与闸门不放宽。

- 一次只推进一个 Stage。未获批准不得开始新功能、新 Stage，也不得开始 `TASKS.md` 路线图中的下一步。
- Stage01已于2026-10-03由项目所有者明确确认验收（原话：“确认验收 继续下一阶段任务”），状态APPROVED。
- Stage02于2026-10-06按所有者最新指令“进入stage03”记APPROVED。所有者已亲自体验照片路径并反馈正常；旧版录屏已复审。最新云第三轮/设备构建/还原等仍未验证，批准不等于补测通过，具体见 `.ai/reviews/STAGE-02-OWNER-CLOSEOUT-2026-10-06.md`。
- Stage03于2026-10-09按所有者“进入stage04”指令记APPROVED。新版安装、旧照片/Done/重开位置本人正常，原生138/138通过；其余新版真机验证缺口保留，见 `.ai/reviews/STAGE-03-OWNER-CLOSEOUT-2026-10-09.md`，批准不等于补测通过。
- Stage04、Stage05于2026-10-10按所有者新版真机三组逐次反馈“正常”记APPROVED（第5节通过的等价表述）；技术复审、同源186/186原生和设备IPA证据保持，未额外人工测试项不外推通过，见`.ai/reviews/STAGE-04-05-OWNER-CLOSEOUT-2026-10-10.md`。Stage04范围为确定性单画布排版/三用户照片预设预览/搜索/保存；Stage05范围为可选只读光色分析基础，不扩大为AI、多页、导出或付费。
- Stage06已获2026-10-10所有者“进行stage06”明确开始授权，范围以`docs/architecture/STAGE-06-PHOTO-ROLES.md`及`.ai/tasks/STAGE-06-IMPLEMENT-01.md`为准：本地角色建议/保存选择/显式布局集成；Architect批准有限ImportedPhoto.roleChoice附加契约和原生Vision。Stage07–15仍未授权。后续阶段仍须完整测试、独立Review、可运行版本与本人验收，DSH仅可推进到READY_FOR_ARCHITECT_REVIEW；职责与验收门槛不变。

## 7. 性能原则

- 不在主线程做重图像处理；重计算必须放在可隔离、可测试的异步边界内。
- 编辑使用预览分辨率素材，最终导出使用原始素材；原始照片不可被破坏性修改。
- 避免不必要的内存复制；处理逻辑不得与 SwiftUI 视图耦合。
- AI 不直接控制渲染：`AI 分析 → 结构化模型 → 布局/风格决策 → 确定性渲染引擎`。AI 输出必须是可序列化、可编辑、可回退的结构化数据。

## 8. 视觉设计权威

- 最终视觉由项目所有者批准；ChatGPT 作为 Design Reviewer 提供评审意见；DSH 不发明品牌风格。
- Stage01已验收基础外壳；Stage02和Stage03延续中性、系统原生、功能优先的临时样式，Stage03仅增加批准的画布/图层交互，不定义最终品牌；临时token见 `MomentsStudio/MomentsStudio/DesignSystem/DesignTokens.swift`。
- 设计系统与视觉规范见 `docs/design/UI_DESIGN_SYSTEM.md`（当前状态：未定义）。
- 用户照片在未来产品中始终是第一视觉焦点；禁止霓虹、紫蓝 AI 渐变、过量玻璃材质、满屏卡片、无意义动画、Web 控制台式布局。

## 9. 文档与仓库纪律

- 新上下文或新协作者接续时，先读根目录 `项目要求与上下文交接.md`，再核对当前验收状态、最新 Review 与原始证据。
- 按项目所有者要求，每次关键需求、决策、数据、实现/Review/构建进展或验收状态变化，及时更新该文件的当前快照与关键日志；不得通过更新文档代替所有者批准或扩大执行权限。
- 文档保持简短、真实、可执行；不得把未实现的功能写成已实现。
- 目录按实际代码出现；不为填充目录树而创建文件。
- 每个 Stage 必须产出：有内容时的 `.ai/tasks/`、`.ai/reports/`、`.ai/reviews/`、`.ai/acceptance/` 文档。

## 10. 变更记录

| 日期 | 变更 | 说明 |
| --- | --- | --- |
| 2026-10-10 | Stage06明确启动 | 所有者“进行stage06”；Architect定义照片角色建议/持久选择/布局集成，Stage07仍未授权 |
| 2026-10-10 | Stage04/05本人真机验收收尾 | 新版三组操作逐次回复“正常”，按等价通过表述记录APPROVED；未测限制保留，Stage06仍未授权，不放宽分工或门槛 |
| 2026-10-02 | 初版 | Stage 01 由 DSH 建立治理基线；规则内容来自项目所有者 Prompt（唯一任务来源）与 `docs/产品与架构基线.md`。同日 Architect 以 `docs/Stage-01-Architect-Review备忘.md` 取代了先前的执行任务书 |
| 2026-10-03 | 上下文交接入口 | 按项目所有者要求新增 `项目要求与上下文交接.md`，规定接续先读及关键事实持续更新；原有权限与验收闸门不变 |
| 2026-10-03 | Stage01所有者批准 / Stage02启动 | 所有者明确确认验收并要求继续；Architect定义照片导入和素材管线范围，Stage03仍未批准 |
| 2026-10-05 | 所有者当日免逐项审批 / Stage02持续推进 | 原话及临时执行范围见第5节；技术结论仍基于实际证据，不伪称本人验收；Stage03和Apple暂停边界不变 |
| 2026-10-06 | Stage02所有者收尾 / Stage03启动 | 所有者在已体验且获告知取证失败后明确“进入stage03”；保留验证缺口，不伪称云测试通过。Architect定义画布/图层契约，Stage04仍未批准 |
| 2026-10-09 | Stage03所有者收尾 / Stage04启动 | 所有者明确“进入stage04”；Stage03未完真机项保留。Architect定义确定性排版与三真实照片预设预览，不放宽费用、依赖或验收规则 |
