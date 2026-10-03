# Stage 01 — Architect Review Round 01

日期：2026-10-03。审查者：ChatGPT Architect。结论：**需要修复并再次 Review；未通过用户验收**。

## 范围与证据

已阅读原始 Prompt、架构文档、交付报告、核心模型、状态/导航与测试代码。当前交付限于 SwiftUI 外壳与内存项目状态，范围基本一致。Windows 结构校验不能代替 Xcode 编译、XCTest 或实际视觉验收。

## 必须修复

| 编号 | 位置 | 根因与要求 |
| --- | --- | --- |
| R1 / P2 | Models/Layer.swift | `opacity` 可直接赋值，合成 Codable 解码绕过 initializer；“始终在 0...1”不是事实。封闭写入口，处理非有限数，解码拒绝非法值，保持编码字段不变。 |
| R2 / P2 | Models/CanvasDocument.swift、ARCHITECTURE.md | 数组顺序与 zIndex 同时宣称决定叠放。裁定 zIndex 越大越靠前；相同 zIndex 用数组位置，越后越靠前。当前只定义语义，不实现渲染/排序服务。 |
| R3 / P2 | ProjectStore、AppNavigationModel | UI 状态隔离仅靠注释。现在就用 @MainActor 约束访问，同时修正调用处与测试隔离。 |
| R4 / P2 | SettingsPlaceholderView、ARCHITECTURE.md | Processing 的“On-device only”与“已交付可运行外壳”分别暗示未实现能力、未执行验证。改为真实占位状态。 |
| R5 / P2 | Models/Project.swift 等文档 | Codable 不保证以后无需迁移。当前字段是受 Review 控制的 Stage 01 契约；持久化前还需决定版本/迁移，禁止承诺永久不变。保留现有契约测试。 |

## 当前架构裁定

- DSH 交付状态 READY_FOR_ARCHITECT_REVIEW 合适。修复期间记 IMPLEMENTING（Architect corrections）；交付后回到 READY_FOR_ARCHITECT_REVIEW。用户尚未批准，也没有可运行版本，不能写 WAITING_FOR_USER 或 APPROVED。
- 接受 iOS 17、Observation、当前目录、纯 Foundation 模型、内存 ProjectStore、ID 路由、About modal 接缝、英文临时文案。最终语言与品牌仍待用户决定。
- 保留 Asset 最小模型；本阶段不补素材库、assetID、metadata、版本号、持久化或未知类型回退。开始对应后续阶段之前单独定契约。
- 当前 JSON 字段名/编码形状仍受治理规则控制。修正 opacity 的校验与访问控制已由 Architect 批准；不得顺便更改字段名或日期策略。
- 暂时保留脚本生成工程、pop/popToRoot 与默认画布，不增缓存、协议、包或依赖。脚本的正式可用性最终由 Xcode 实际打开/构建验证。
- 无主线程重图像处理；未发现本阶段需要性能优化的证据。手感、VoiceOver、Dynamic Type 与 iPad 表现待运行验证。
- 空 AppIcon 的实际警告待首次构建确认，不现在设计品牌图标。

## 尚未满足的门槛

Xcode 工程打开、build/test、警告 Review、可运行版本、真实界面与交互检查、用户亲自验收全部待执行。本文件只完成代码层第一轮审查，不能替代这些门槛。

修复任务：`.ai/tasks/STAGE-01-ARCHITECT-FIX-01.md`。
