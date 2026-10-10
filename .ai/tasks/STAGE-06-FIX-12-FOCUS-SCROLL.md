# Stage06 FIX12 — 新UI必须真实滚动到Focus

所有者授权继续Stage06，Stage07未授权。仅真实DSH实施，Architect独立Review/取证。

第五轮run38036555619/source`2625988c5c33f687247d7e6c40180a2afce81c1d`，原始job114168074001与summary均已收集：完整256实际255通过/1UI失败/0跳过/0预期失败，245unit与旧186全过。唯一新UI失败：`Stage06PhotoRolesUITests.swift:57`，`layout.choose.focus must be usable inside the layout sheet`。新角色首次保存、重开、Cancel、替换人工主图、Automatic、结束App重开后的角色及source断言均已走过；在首次选择Focus时失败，实际Focus Apply/geometry/repeat末尾未执行。

真实证据`.ai/build/stage06-run-38036555619-20261010-163551/evidence/`，artifact328155039bytes/SHA256`8d469da6375c152bf6401acc2eec256fc8206499b83c06952ca1c31cd28f095f`。AX附件`B98E477A-5253-4F40-B668-B0F98B3DC8DD.txt`：Focus Button frame=(16,974.3,108.7,20.3)，window=(0,0,402,874)，确在屏幕下方。Architect已实际看两张截图：`3AE7DF26-A338-4B1D-B042-2EC8D81C41BB.png`显示角色Save/Cancel与两张角色/source正常；`C16AD83E-B7E1-4605-B621-E92B1FCDA37D.png`显示Layouts，Grid后是Focus（第二个预设），Focus选择按钮在当前视口下方，不是第三个。不得将Layouts截图称为roles页或声称Focus Apply已执行。

## 根因与允许修复

现有新UI `tapLayoutSheet`只确认`layout.scroll`存在，随后等待按钮可点，**没有把后面的Focus滚入视口**。生产布局页是三个约200px预览纵排，选择Focus属于正常滚动路径；旧Stage04 UI已经用自己的`tapChoice`+`usableViewport`执行真实有界滚动。本次最小修新UI，生产App/旧186/完整256/工作流不变。

1. 允许仅`Stage06PhotoRolesUITests.swift`及本阶段报告/交接。参考只读`Stage04LayoutUITests.swift`已有私有滚动算法，在新class内部实现必要的最小同类逻辑，**不能修改旧文件、提取共享helper造成旧186字节改动或用Editor scroll helper滚布局页**。
2. 对`layout.choose.focus`在唯一`layout.scroll`的真实可用视口内作有界、慢速原生拖动。视口由当前scroll/app及该sheet自己的Layouts导航栏/真实键盘裁剪；实际frame与端点必须有限、为正，scroll相对端点在0...1，按目标当前上下溢出方向滚，最多既有5–6次。目标完整进可用视口且enabled/hittable后才tap；已在可用范围却不可点应失败并取证，不盲点/无限等/强行坐标点按钮。
3. `layout.apply`是sheet自己的导航操作，不能要求在scroll内容区或把它向下滚。分别识别内容选择与sheet toolbar，确认同一sheet后真实等待并tap；保持真正保存/Apply消失断言。
4. 保留所有原角色保存/Cancel/替换/Automatic/重启和Focus真y/scale、repeat层ID/数量/transform、末尾角色不变断言。仍245unit+11UI=256，不能删case或放宽业务expected；无需App测试钩子或运行依赖。
5. 最小诊断：第一次Layout截图已有真实附件；若滚动失败，XCTFail前保存截图及真实scope/target/viewport信息，`continueAfterFailure=false`后不能再采集。报告追加第五轮真实结果，保留历史hash/count；交付源码尚未重跑不能称通过。

完成独立可重复本机检查/真实完整清单，停READY_FOR_ARCHITECT_REVIEW；不要push/dispatch/Stage07。DSH当前65%，实到70%须先完整handoff并同工作区新上下文，旧会话保留。第六轮原生、同源IPA与本人验收由Architect继续组织。
