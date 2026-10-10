# Stage06 FIX10 — 第三轮四项实际失败

run 38026510813 /源7c3f08d7230214fef3cbd1675ec734b70b025bc7；Xcode26.6/SDK26.5已真实编译执行256，252pass/4fail/0skip/0expected，旧186全部pass，新unit3fail/UI1fail。原始log、summary、附件位于 `.ai/build/stage06-run-38026510813-20261010-133711/evidence/`，archive SHA256 `7b019c44c45fab960f436f3173561a7f60b9ef09381616e2dba2ca7aa2118566`。

只修本阶段三个新测试文件及报告，不改生产契约/算法/旧186/完整256门禁，不删测试，不只跑新增，不push/dispatch。Architect已定位，禁止把合法人工排除改为禁止或开放跨项目路径。

1. RoleChoice `testDecodedPackageKeepsSavedChoicesAndLegacyOneStillReads`：photo helper的所有引用使用 self.projectID，但package Project(name:)随机新ID；legacy又独立legacyID。必须使包project与该包全部photo路径属于同一个明确ID。保持真实现代包角色roundtrip以及schema1旧包升级nil角色断言，不能catch无效引用假通过，生产路径校验正确不能放松。
2. RoleChoice `testUnknownRoleSourceAndTypeAreRejectedNotGuessed`：最后用manual primary→manual excluded，manual excluded合法，注释称automatic但实际source仍manual。构造真正非法的automatic excluded（并覆盖automatic collageMaterial，可放同方法不增方法数）；保留unknownrole/source/wrongtype拒绝。确认JSON变体确实不同于base且role/source实际正确，避免字符串replace不生效假测试。不要更改合法manual excluded语义。
3. RolePolicy `testUntouchedCapturedChoiceIsKeptOnlyWhenItWasManual`：manual primary占主位，automatic候选还传manual supporting，却期望另一个primary，自相矛盾。重设有效fixture：manual supporting保存/source manual保持；automatic supporting保存但candidate无manualRole且有有效场景证据，当前pass自动建议升primary。断言manual supporting保持、automatic primary刷新，来自真实suggest而非手造outcome。不要仅把失败expected改成旧值导致失去刷新证明，不构造两个captured primary的无效包前提。
4. UI `testRolesSheetSavesManualChoiceSurvivesRestartAndFocusUsesIt`：真实首次选Primary成功，XCT269 actual `Role, Primary photo` vs expected `Primary photo`。SwiftUI Picker原生label包含固定Role前缀，`shownRole`先value再label读取实际UI，可只去确切开头 `Role, ` 后仍严格比对完整目标角色；未知标签仍失败，不能contains任意/返回选中的常量、不改生产AX隐藏钩子、不链接App module。所有保存/取消/人工主图替换/重启/Automatic/Focus几何/repeat不复制断言保持，最终原生执行到末尾才能证明完整路径。

最小自查同类新fixture的projectID、source合法性和当前pass是否真刷新、UIlabel规范化。更新报告准确两轮compilefail+第三轮252/256实际执行，不称通过，保留新数据和原失败。最终静态完整256/旧186/工作流冻结后交Review。DSH当前65%；到70%先写完整handoff，再同工作区新DSH会话续做，旧聊天保留。
