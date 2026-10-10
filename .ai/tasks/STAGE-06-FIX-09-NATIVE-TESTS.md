# Stage06 FIX09 — 第二轮原生测试目标编译修复

Architect 已定位；只修当前 Stage06，不扩公开模型/架构，不触碰旧186测试及旧工作流，不减256门禁。

证据：run 38025499129，源 b0ac2dd917560f663d3ea854dabfff42a9327339，真实 iphoneos Release 编译成功；测试目标编译失败，XCTest 未执行，summary 0 不是256项失败。原始证据 `.ai/build/stage06-run-38025499129-20261010-125917/evidence/xcodebuild-test.log`。archive SHA256 `6b7f23f0694629d18b52c04b0075401747e234ed89b890f7272dc0c7b721f601`。

必须最小修复：

1. Stage06RolePolicyTests.swift:426 不得直接写 private(set) opacity；调用已有 `setOpacity(0.6)`，保留完整非参与层不变断言，禁止开放生产 setter。
2. Stage06RolesSheetModelTests.swift:162/166 本地 `captured` 字典遮蔽 `captured(...)` helper。改本地名称，保留失败与人工失败文案两断言。
3. 同文件238 `suggestions: []` 字典应 `[:]`，保留清空自动选择变更断言。
4. 同轮新测试警告最小清理：Stage06RolesRunTests224 var未mutate→let；RolesSheetModelTests134 未用suggestions删除；RoleStorageTests148 未用first改为 `_ =`（保留真实导入调用）。旧 PhotoAnalysisSheet 三处warning不扩大修改。
5. 自查本阶段新测试的同类名称遮蔽/字典类型/现有setter调用，保持245单元+11UI=256且旧186原字节不动。更新实施报告真实结论：二轮测试编译失败/XCTest未执行；不得称通过。

交付最终修改文件、Windows已执行静态证据与未执行macOS边界；root复审后新提交新完整云测试，不自行push/dispatch或Stage07。实际DSH当前62%上下文，到70%先保存详细交接再同工作区新会话续做，保留旧对话。
