# DSH Task — Stage 01 Architect Corrections 01

授权来源：项目所有者已授权 Architect 与 DSH 直接协作；本任务由 ChatGPT Architect 作出架构裁定。仅修 Stage 01，**不得开始 Stage 02**。

先读 `.ai/reviews/STAGE-01-ARCHITECT-ROUND-01.md`，再完成以下有限修改。无需改写原始 Prompt、AGENTS.md 或重建整体架构。

## 1. 透明度不变量

- 保留 Layer 当前所有序列化字段名与格式。
- `opacity` 改为 `private(set)`，所有正常写入经 initializer / setOpacity。
- initializer / setOpacity：有限值 clamp 到 0...1；非有限输入统一使用默认 1，注释清楚这个策略。
- 自定义 `init(from:)` 验证 opacity：非有限或不在 0...1 的数据抛 DecodingError.dataCorruptedError。不得把损坏存档悄悄修正。其他字段沿用当前解码要求；不添加新框架或验证抽象。
- 保持 Codable encode 的形状不变。现有 round-trip 与契约测试保留。
- 添加有意义的边界测试：initializer/setter 非有限输入，非法解码负数/大于1，以及有效边界0/1。若使用 JSONDecoder.nonConformingFloatDecodingStrategy 验证非有限解码，明确只用于测试。

## 2. 图层顺序与契约说明

- 统一所有相关注释和架构文档：zIndex 越大越靠前；相同 zIndex 以数组位置作稳定次序，数组越后越靠前。
- 不新增渲染器、排序 API 或功能。数组 Codable round-trip 测试检查的是存储顺序保持，不冒充渲染测试。
- 改掉 Project 的“以后无需模型迁移”承诺。明确当前契约受 Review 约束，持久化与迁移仍未实现。不删除/弱化已有 JSON key 与 fixture 测试。

## 3. 主 actor 隔离

- ProjectStore 和 AppNavigationModel 加 @MainActor，删除推迟到 Stage 02 的线程注释。
- 检查 RootView 的状态初始化和其他调用处，在需要处显式标注 @MainActor，兼容文档声明的 Xcode 15.4 / iOS17 基线。
- 状态测试使用能兼容 XCTest 的隔离方式；优先在测试方法上标注 @MainActor，并使用 async 签名，避免给整个 XCTestCase 子类强行改变父类隔离。纯值模型测试无需 actor。
- 不使用 @unchecked Sendable、nonisolated(unsafe)、全局关闭并发检查或其他绕过。

## 4. 真实文案与记录

- Settings 的 Processing 值改为 Not implemented（英文占位保持一致）。
- ARCHITECTURE 当前交付说明改为“已实现外壳源码与工程，运行未验证”，消除其他同类误导。
- 更新交付报告、review packet 与验收说明中的已知问题/决策/测试数量，保留未执行 Xcode build/test 的事实。历史报告若保留旧状态，注明已在本轮修正。

## 完成标准与验证

1. 以上 root cause 都得到局部修复，未实现本阶段之外功能，未改编码字段。
2. 重跑 Windows 已有结构/语法校验，报告真实输出。不要安装新的依赖。
3. 不声称 build/XCTest/UI 验证通过；本机无 macOS/Xcode。真实编译仍待执行。
4. 输出本轮改动文件、关键决策、执行/未执行的检查与剩余限制，标 READY_FOR_ARCHITECT_REVIEW，停止开发等待我 Review。

## 协作边界

你只修改源码、现有工程/测试与 DSH 交付文档；我维护本轮 Architect Review/Task 与构建路径提案。不要修改我的文件，不操作旁边空 Git 仓库，不上传源代码、不付费、不改账户。若需要改变本任务裁定，先提出具体原因。
