# Stage06 FIX08 — 首轮原生编译根因

真实run38024488499/source198c755145e818bc9f2c7945c896fa72c21d3b48/attempt1，Xcode26.6 build17F113、iphoneos SDK26.5；iphoneos Release真实编译失败（exit65），XCTest未执行，无Stage06 IPA/验收。原始证据私密`.ai/build/stage06-run-38024488499-20261010-123735/evidence/xcodebuild-device.log`，artifact SHA2567b8626b5637f05c570f959711b8e5669c94b301825d4bfadb61adcb838187422；保留失败，不修改旧run或降低门禁。当前CHANGES_REQUESTED，仅已定位最小修复。

1. 两处真正error：PhotoRolesSheet.swift:383 `suggestions[photo.id].role`、:535同模式；字典subscript是Optional Suggestion，必须真实安全处理缺结果，使用可选链/明确fallback而不强解包。修同类新代码真实调用；不能伪造建议或把缺result当Primary。
2. 新增语义警告：PhotoRolePolicy.swift:124 `suggestions[id] = .none`被解释Optional.none删除key，不是Suggestion.none。明确保存期望的Suggestion.none值；新Stage06PolicyTests中对应Optional Suggestion.none断言也显式指向内层enum，不能用nil假证明（不改旧测试）。这不放宽用户角色/保存规则。
3. 新增普通warnings：PhotoImportModel.swift:583 guardletproject未用；PhotoRolesSheet四处invalidate返回未用；PhotoRoleAnalyzer.swift:240/243对已类型化VNClassificationObservation/VNFaceObservation条件cast恒成功。按实际Xcode类型最小清理；不要改已冻结旧Stage01–05测试或Stage05PhotoAnalysisSheet的3条已有invalidate warnings，旧已知warnings记录继续保留。不改VNRequest revision/原生词表安全、fallback/透明行为及取消guard。
4. 新Stage06 workflow Step名称还写`Assert the Stage 06 176 + 10 = 186 test contract`，实际env/guard已是245+11=256；只更正该步骤标题与新文件确实遗留的说明，**不改256完整scheme/清单/SHA/0skip/证据guard实际逻辑、timeouts或冻结旧workflow**。
5. 更新实现报告为FIX08实际source/hash/已执行真实编译失败、XCTest未执行；保持所有256真实测试及其意图。只本地完成结构/语法/实际manifest，停Review；根handoff更新实际状态，不把修复编码等同原生通过。

Architect复审后精确新commit再派发完整256原生测试，同源通过后设备包。DSH不push/dispatch/付费/Stage07。当前59%未到70%；若后续到70%先保存当前新run/根因及dirtysourcehandoff再同工作区接续，不能丢已通过Stage04/05基线。
