# AGENTS.md — 协作与治理规则

本文件对整个仓库生命周期内所有 AI 协作者与人类角色生效。本文件本身由项目所有者拥有，DSH 不得自行放宽其中任何规则。

## 1. 角色与权限

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

- 流程固定为：REQUIREMENTS → ARCHITECTURE → IMPLEMENTATION → AUTOMATED TESTING → ARCHITECTURE REVIEW → USER BUILD → USER ACCEPTANCE → APPROVAL。不得跳过 USER ACCEPTANCE。
- 完成实现后必须**停止开发**、准备可运行版本与验收说明、如实报告已知限制。
- 以下均**不构成**批准：测试通过、构建成功、实现完成、ChatGPT Review 通过、无已知 Bug、DSH 自身判断。
- Stage 状态机：`SPEC_READY → IMPLEMENTING → READY_FOR_ARCHITECT_REVIEW → WAITING_FOR_USER → APPROVED`；用户提出修改意见时为 `CHANGES_REQUESTED`，且只修当前 Stage。
- DSH 只能推进到 `READY_FOR_ARCHITECT_REVIEW`。只有当 ChatGPT Review 完成、且存在可运行版本与验收说明后，才由 Architect 转为 `WAITING_FOR_USER`。
- 只有项目所有者明确说「通过」或等价表述，才可标记 `APPROVED`。

## 6. 阶段（Stage）规则

- 一次只推进一个 Stage。未获批准不得开始新功能、新 Stage，也不得开始 `TASKS.md` 路线图中的下一步。
- 当前 Stage：**Stage 01 — Project Foundation and iOS Application Skeleton**。
- `TASKS.md` 中的 Stage 02–15 是**未批准、可调整的路线图草案**，不是待执行队列。

## 7. 性能原则

- 不在主线程做重图像处理；重计算必须放在可隔离、可测试的异步边界内。
- 编辑使用预览分辨率素材，最终导出使用原始素材；原始照片不可被破坏性修改。
- 避免不必要的内存复制；处理逻辑不得与 SwiftUI 视图耦合。
- AI 不直接控制渲染：`AI 分析 → 结构化模型 → 布局/风格决策 → 确定性渲染引擎`。AI 输出必须是可序列化、可编辑、可回退的结构化数据。

## 8. 视觉设计权威

- 最终视觉由项目所有者批准；ChatGPT 作为 Design Reviewer 提供评审意见；DSH 不发明品牌风格。
- Stage 01 只交付中性、系统原生、功能优先的外壳；临时 token 见 `MomentsStudio/MomentsStudio/DesignSystem/DesignTokens.swift`。
- 设计系统与视觉规范见 `docs/design/UI_DESIGN_SYSTEM.md`（当前状态：未定义）。
- 用户照片在未来产品中始终是第一视觉焦点；禁止霓虹、紫蓝 AI 渐变、过量玻璃材质、满屏卡片、无意义动画、Web 控制台式布局。

## 9. 文档与仓库纪律

- 文档保持简短、真实、可执行；不得把未实现的功能写成已实现。
- 目录按实际代码出现；不为填充目录树而创建文件。
- 每个 Stage 必须产出：有内容时的 `.ai/tasks/`、`.ai/reports/`、`.ai/reviews/`、`.ai/acceptance/` 文档。

## 10. 变更记录

| 日期 | 变更 | 说明 |
| --- | --- | --- |
| 2026-10-02 | 初版 | Stage 01 由 DSH 建立治理基线；规则内容来自项目所有者 Prompt（唯一任务来源）与 `docs/产品与架构基线.md`。同日 Architect 以 `docs/Stage-01-Architect-Review备忘.md` 取代了先前的执行任务书 |
