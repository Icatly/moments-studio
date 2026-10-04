# Stage02 FIX04 — 证据限定元素中心点击及同轮恢复/深色补验

2026-10-05 Architect。先读Round27与run37222556297原日志、selected-members原生层级及PNG。今天Stage02免逐项审批，Stage03/Apple/付费仍禁止。任务优先于之前FIX03坐标禁令；**仅允许Round27明确的元素相对中心**，不得自行扩展。

修改范围：Stage02ImportUITests.swift；workflow中只读simctl ui帮助/当前值诊断；独立FIX04报告与交接日志。产品Swift/公开契约/依赖/工程不改，85方法不变，既有48行为断言完整保留（新断言可追加）。不要覆盖历史FIX03/只读方案，不自行commit/push/cloud。

1. iOS26首个scope内真实photo仍waitForExistence20、finite/nonempty frame，新增scope.frame及app.frame均contains该frame条件。保存原diagnostic/screenshot，明确日志策略。替换现代分支photo.tap为一次`photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()`；旧分支原hittable/native tap不改。禁止绝对CGPoint/应用原点坐标、盲点scope、循环候选/重试、forceTap、skip、产品launch注入。tap后原真正Done可用与整个既有导入路径全部保留。
2. 原完整路径再导入的最后count=1断言通过之后，追加恢复检查。创建前Home ready后记录home.project.完整identifier集合；最后保留真实唯一thumbnail的完整identifier，返回Home（run3层级实见导航Button identifier BackButton），Home ready后记录集合差恰好1个完整项目ID。不能猜首行/名称，不reset。terminate/launch，等home.createProject enabled且libraryError不存在，再精确打开该ID；核count1、同一thumbnail ID且仅1张，loaded typed preview Image无loading/failure/缺素材、finite且app内frame，Done可用且返回可操作Editor。截图与日志统一INTERACTION-VERIFY[restart]。
3. 同个真实已恢复项目核深色：保存XCUIDevice.shared.appearance、defer恢复，设.dark，记录Home/Editor/loaded preview原生keepAlways截图；可使用已实见BackButton返回Home再精确打开同项目。核按钮enabled+hittable、数量/同素材、图片loaded/frame、Done能返回Editor。统一INTERACTION-VERIFY[dark]。不加入产品样式/测试钩子；截图由Architect实际看后才可判视觉通过。
4. 大字号只读能力证据：现有workflow照片fixture步骤bootstatus后记录`xcrun simctl help ui`、`xcrun simctl ui "$STAGE02_SIMULATOR_ID" content_size`输出及退出状态到ARTIFACTS命名txt；不改变字号、不使用未知参数、不改变原测试/门禁条件。诊断命令不支持时留非零状态，如实写未验证，不把不支持冒称成功。实际macOS命令仍由Architect下一轮执行。
5. Windows验证断言原文48条全部保留（与1d103fb有序子序列比对，不以断言数相等代替），80+5方法不变、工作流YAML/内嵌Python无误、工程校验与diff check。只报告实际执行；Xcode/相对中心是否选中/恢复/深色/字号帮助实际内容均尚未执行。报告`.ai/reports/STAGE-02-PREFLIGHT-FIX-04.md`，READY_FOR_ARCHITECT_REVIEW后停止。

这是证据限定的修复与当前Stage02补验，中心点击不是通过证明。失败保留截图和层级，不能继续自行放宽。

02:32 Architect追加复审要求：允许`tools/verify_project.py`仅增加实见系统BackButton的精确豁免（静态校验工具，不是产品API），若需其他豁免先报告。thumbnail数量按唯一完整asset identifier核，不能把同一SwiftUI按钮重复AX节点当两张照片；可用已实见原生Button类型查询并去重，保留count1与同ID断言。深色preview补齐finite/nonempty/正宽高frame，不能仅用contains对空frame当可见。记录旧18.5导航返回无BackButton ID、label Moments Studio的真实证据，版本分支可复用，不猜标签，不降低原断言。
