# ADR-0001：Stage 01 基础工程决策

状态：**Round 01 修正已实施，待 Architect 复审**（Stage 01 结束前提交）
日期：2026-10-02（D2 于 2026-10-03 按 Architect Round 01 修正）
范围：Stage 01 — Project Foundation and iOS Application Skeleton

本文件只记录决策、理由与代价，不重复 `ARCHITECTURE.md` 的结构描述。每条决策若被 Architect 否决，都属于 Stage 01 范围内的修改。

## D1. Deployment target = iOS 17.0

- **决策**：最低支持 iOS 17.0。
- **理由**：`NavigationStack` 需要 16.0；`@Observable`（Observation）与 `@Environment(Type.self)` 需要 17.0。选 17.0 可以在不引入 `ObservableObject` 样板与 `Combine` 的前提下使用现代状态机制。
- **代价**：放弃 iOS 16 及更早设备。若必须支持 iOS 16，需要把两个状态对象改回 `ObservableObject` + `@StateObject`，属于契约改动。
- **替代方案**：iOS 16 + `ObservableObject`；本 Stage 未采用。

## D2. 状态对象使用 `@MainActor`（已被 Architect Round 01 修正）

- **当前决定（Round 01 起生效）**：`ProjectStore` 与 `AppNavigationModel` 都标注 `@MainActor`；`RootView` 显式标注 `@MainActor`（它是唯一初始化这两个对象的地方）；状态测试在**方法级**用 `@MainActor` + `async`，不改动 `XCTestCase` 子类隔离；不使用 `@unchecked Sendable`、`nonisolated(unsafe)` 或关闭并发检查等绕过。
- **原决定（已废弃）**：起初不加 `@MainActor`，只用文档约定，理由是「本机无 Xcode，无法验证 actor 隔离的编译结果」。
- **修正理由**：正确性不应依赖注释；Architect Round 01 裁定现在就约束访问。该修正未改变任何序列化字段。
- **代价**：隔离相关的编译结果仍需在 macOS/Xcode 上首次构建时确认；本机只能做静态语法与结构校验。
- **替代方案**：仅在 Stage 02 引入异步工作时再加；已被 Architect 否决。

## D3. 近期项目仅存内存，不持久化

- **决策**：`ProjectStore` 只维护内存数组；Home 明确标注「仅本次运行有效，尚未保存」。
- **理由**：项目所有者 Prompt 允许最小持久化；`docs/产品与架构基线.md` 明确要求「若界面宣称可恢复则必须真的持久化」，因此选择「不宣称、不假装」。
- **代价**：退出应用即丢失数据（Stage 01 没有真实用户数据，风险可接受）。
- **后续**：Stage 02 引入沙盒持久化时，`ProjectStore` 是唯一需要改动的接缝。

## D4. 不引入数据库、不引入任何第三方依赖

- **决策**：零第三方运行期依赖；工程文件由 Python 标准库脚本生成。
- **理由**：依赖政策；且 Stage 01 的数据量不需要数据库。未来若需要查询能力，优先评估 SwiftData / 文件 + `Codable`。
- **代价**：`tools/*.py` 成为 Windows 侧的额外工具，需要在报告中说明并在 Xcode 接管工程后可删除。

## D5. Xcode 工程文件由脚本生成（本机无 Xcode 的替代方案）

- **决策**：`MomentsStudio.xcodeproj` 由 `tools/generate_xcodeproj.py` 依据源码目录确定性生成（`objectVersion 56`），并由 `tools/verify_project.py` 校验。
- **理由**：Windows 上无法运行 Xcode 生成工程文件；手写工程文件容易产生引用不一致。脚本化可以保证「源码目录 ↔ 工程引用」一致且可复现。
- **代价与风险**：**工程文件从未被 Xcode 打开过**。首次在 Mac 上打开/构建可能暴露格式或设置问题。一旦开始用 Xcode 管理工程，必须停止重跑生成脚本，否则会覆盖 Xcode 的改动。
- **替代方案**：等有 macOS 环境后用 Xcode 重建工程，或引入 XcodeGen（属第三方工具，需批准）。

## D6. 路由只携带标识符

- **决策**：`AppRoute.editor(projectID: UUID)`，页面自己从 store 取当前值。
- **理由**：避免导航栈里存模型副本导致显示过期数据；未来「重命名 / 删除项目」不需要清理栈内副本。
- **代价**：目标页面需要处理「项目已不存在」的分支（已实现 `editor.missingProject` 空状态）。

## D7. Sheet 能力用一个真实用例验证

- **决策**：设置页的 About 弹窗（`SheetRoute.about`）是真实存在的占位功能，用于证明模态接缝可用。
- **理由**：项目所有者 Prompt 要求「未来模态 sheet 必须可支持」，但直接写空的 presentation 抽象属于未使用的抽象。
- **代价**：增加了一个占位页面；若 Architect 认为多余，删除成本很低（1 个文件 + 1 个 case）。

## D8. UI 文案使用英文占位

- **决策**：所有界面文案为英文，未做本地化。
- **理由**：项目所有者 Prompt 为英文，且显示语言属于产品/设计决定，DSH 不应自行发明中文文案风格。
- **代价**：中文用户验收时看到的是英文占位；需要 Architect 或所有者裁定显示语言，届时再统一处理本地化。

## D9. 只定义被使用的设计 token

- **决策**：`DesignTokens.swift` 只包含 Stage 01 实际使用的间距、圆角、语义色、文本样式与一个动效常量；未创建大量未使用的 token。
- **理由**：项目所有者原始 Prompt 把 Spacing / Typography / Color / Radius / Motion 列为设计系统应包含的内容，而 `docs/产品与架构基线.md` 要求「内容要短、真实」「不预建空服务」，治理规则也要求「目录按实际代码出现」。因此以「只定义被引用的 token」为下限、以原始 Prompt 的清单为检查表，五类各自保留最小可用的一组。
- **代价**：最终设计系统落地时，token 文件会被整体替换。

## D10. 中文文档 + 英文代码标识符

- **决策**：仓库文档（治理/架构/验收/报告）用中文，代码、类型名、identifier、命令用英文。
- **理由**：仓库既有文档（`项目说明.md`、`docs/*.md`）均为中文，项目所有者以中文阅读；代码与 identifier 保持英文便于与 Xcode、Apple 文档一致。
