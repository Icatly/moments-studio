# Stage06 FIX05 — 完整交付独立Review退回

DSH已交付READY_FOR_ARCHITECT_REVIEW；Architect独立源码复核发现以下阻断，当前Stage06 CHANGES_REQUESTED，禁止发布/派发/验收。仍只修当前Stage06，不改Stage01–05旧186方法/断言或冻结工作流。

## A. 实际编译/清单阻断

1. 原生workflow的真实manifest逻辑本机独立执行失败：Duplicate test method names `testBeginRequestOnlyStartsForTheCurrentKeyAndSheet`（新Stage06RolesRunTests与旧Stage05同名）。只重命名新方法为明确Roles名字，保持断言/真实235以上清单；不放宽既有门禁。报告此前“同一清单已通过”与独立失败不符，应更正并实际执行工作流中的真实清单代码。
2. Stage06PhotoRolesUITests调用`tapEditor`/`waitForLabel`，它们仅是其他测试class的private方法，本class或共享XCTestCase没有定义。用现有公开共享scrollEditorToMakeHittable等能力在本class定义最小局部助手，勿引用其他class的private成员；检查所有新增调用。Stage06RolesSheetModelTests无MainActor标注却同步调用@MainActor PhotoRolesSheet.choices；把实际纯函数放在可测非UI值模型（并由UI使用），或明确nonisolated纯成员，不能漏actor语义。不改旧测试权限制造假通过。

## B. 保存清空与Automatic仍不成立

3. PhotoLibrary.saveRoleChoices非可选字典采用缺键清nil，但仍`Set(choices.keys) == Set(current.keys)`，所有清nil/部分失败都被拒绝。已选方案：**完整原照片快照必须与当前照片全集相等**；choices只允许当前asset子集，未出现的当前asset明确清nil。拒绝外来asset但允许合法缺entry。实际真实存储清空/部分失败/全清测试必须通过，报告中“全键相等且缺键清除”的矛盾删除。
4. PhotoRolesSheet Automatic setter仍`manualRoles[id] = nil`，删key，随后getter/candidate回保存role。注释声称.some(nil)不等于实际存储；现有tests用字典literal[id:nil]与真实setter不同。请简化成明确实际草稿状态（例如非Codable枚举automatic/manual(Role)，或显式updateValue(nil,forKey:)且所有读取区分缺键/显式nil），由同一实际值函数处理UI setter/候选/hasChanges/Save，测试走这一真实setter。saved source automatic不能被candidate当manual，也不能choices()直接保留旧auto；重算在显式Save时允许刷新auto。仅原saved manual未改时保留其manual来源。
5. 选择新主图时只遍历manualRoles，不会降级尚未在草稿里出现的**已保存manual primary**，新主图Save因此被ProjectPackage拒绝。按本页实际照片＋原捕获角色＋本次草稿求有效人工角色，再降旧primary为manual supporting。覆盖“保存A manual primary→重开→选B primary→Save→重开只有B主图”，不要只测两个新草稿。

## C. 回退/真实路径覆盖

6. Vision perform抛visionUnavailable时PhotoRoleAnalyzer直接throw，PhotoLibrary没有返回成功的Stage05 analysis，导致Pixel测量成功也整张failed，违反批准fallback。保留已成功测量/尺寸作有限建议，同时返回明确识别未完成状态/提示，不编造face/分类成功或分数；取消必须继续传播。测试生产实际降减函数及真实请求失败处理路径，不用未使用helper伪证据。
7. UITest `importedAssetIdentifiers`从Editor gallery读ID却在Roles modal打开后才取；不要依赖背后Editor可访问。导入后在Editor通过已有gallery实例化策略取得真实顺序assetID，或从本sheet实际行取得，不依赖lazy未实例化/背后控件。当前Cancel路径没做修改，重开只断言picker存在、Focus只断言preview存在，不能证明保存/取消/重启/主位。增加实际可见已选角色/来源断言、真实修改→Cancel→重开仍旧选择、manual→Automatic→Save、新主图换旧主图、Focus真实Apply/无复制；使用真实生产反馈，不新增测试开关。UI test数量按实际更新，不跳过失败。
8. 补至少有逻辑的布局直接arrange测试（nil旧行为、Focus主位、Grid/Offset原序、collage/excluded空画布不创建层、已有层/锁定隐藏/存储顺序保持、重复Apply）；角色保存真实IO失败回滚/store及草稿保持、后续画布保存/删除照片仍保留其他角色、取消/项目/metadata隔离已有测试保持。全为规格要求，不是额外Stage。无可参与照片时不得提示“再导入”掩盖已有照片全被指定不用，应有改角色的可理解反馈。

交付修正报告：本机项目结构已由Architect独立通过；Swift语法树通过不等于类型编译；Bash在沙箱初始化失败仅本机权限问题，提升只读后脚本语法已检、真实清单仍因重复方法失败。当前没有macOS/XCTest/IPA。不要再以file数量/仅picker存在/仅编译内嵌Python当路径通过。

只本地修复，保留用户原图/旧代码/私密证据，不自提交/云派发；完整响应上述A–C、准确源清单/数量/实际未执行后停止READY_FOR_ARCHITECT_REVIEW。Architect复核后才精确发布并单完整原生验证。
