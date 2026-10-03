# R3 调用处补充检查

2026-10-03，属于已授权 FIX-01 的主 actor 修复范围。

目前只给 RootView 标注 @MainActor 不足以解释 Xcode15.4 基线：HomeView 的私有 computed properties / open helper、EditorPlaceholderView 的 navigationTitle 都直接访问 main-actor store/navigation。旧版 SwiftUI 仅 body 自动隔离，不能假定整个 View 都继承同样隔离。

请对 HomeView、EditorPlaceholderView、SettingsPlaceholderView 显式标注 @MainActor，检查 App 入口对 RootView 的构造。若 AboutSheet 受影响也明确标注；纯展示组件不需要批量修改。修正 RootView 注释，不泛称所有 SDK 都能从 View 自动推断整体隔离。

不绕过隔离、不提高最低 Xcode 来掩盖问题。最终仍由真实编译验证。
