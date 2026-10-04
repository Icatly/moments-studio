# Stage02 Round27 — 真实原生tap失败后的限定决策

2026-10-05。CHANGES_REQUESTED，Stage03禁止。

实际run37222556297/source1d103fb，Xcode26.6/SDK26.5/iOS26.5 iPhone17Pro arm64；84/85、0skip。device Release/校验/证据上传success，包装skipped。712845bytes原日志及原summary/source/device/manifest已取回并核member CRC；完整外层SHA未核。原生tap在418行硬失败，XCTest自行滚动/内部3次尝试，hit point均{-1,-1}。

**已实际目视**manifest所列1206×2622原生点击前PNG D556472C-B271-4F30-8077-3BAC01313B44.png：首个合成照片完整可见、隐私说明位于网格上方，没有覆盖该照片。前3个元素frame在屏内但isHittable全false。原生层级的PXGGridLayout-Group直接包含9个Image，没有可供这些单元格单独查询的Button/Cell；PhotosUI是远端进程元素，但不把此事实推断为系统内部根因。未看视频，没有点击后截图，因为点击失败即终止。

## Architect明确限定修订

此前任务禁止坐标是Architect为避免无证据固定屏幕点击制定的限制。现在已有目标scope、真实元素、稳定frame、原生截图和原生tap实际失败，**仅放宽iOS26已记录布局的一次元素相对中心点击**：`photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()`。这是Apple公开XCTest API：[coordinate](https://developer.apple.com/documentation/xcuiautomation/xcuielement/coordinate(withnormalizedoffset:))、[tap](https://developer.apple.com/documentation/xcuiautomation/xcuicoordinate/tap())；不改产品/接口，不调用私有API。

只允许首个真实scope内photo，必须有界存在、finite/nonempty frame且完整包含于scope及app；保存诊断和点击前后原生截图；日志明确相对中心策略和目标frame。禁止绝对屏幕数值、scope整体盲点选、候选循环/无范围查询、点击重试、skip、产品数据注入。旧iOS分支原native tap/hittable等待不变。成功必须由真正的Done enabled+hittable及所有导入/loaded preview/移除/再导入断言证明，中心点击本身不算成功。此放宽由Architect明确作出，DSH不得自行进一步放宽。

## 同轮补验决策

已审DSH PLAN ONLY剩余交互方案，允许在原完整路径之后追加同项目/同asset真实terminate→launch恢复，以及XCUIDevice官方appearance深色预览/Done交互，保存原appearance并defer恢复。原48条断言全部保持，85方法不增加/删除；新增断言使用INTERACTION-VERIFY标签，报告说明失败属于旧路径或新增检查。Home精确项目ID由创建前/返回后ID集合唯一差值获得，不猜名称/首行；重启等待createProject enabled证明restore ready、libraryError不存在。新增检查只在原路径全通过之后才执行。

下一轮可在现有runner记录`simctl help ui`及content_size当前值/退出状态，**只读**，用于大字号后续决策；不能凭Windows方案假称已设大字号。当前不改变字号、不设未知字段、不新增测试plan/依赖。Appetize0分钟、Apple暂停；付费和Stage03仍禁止。所有者今天Stage02免逐项审批授权有效，但技术验收尚未通过、本人操作未执行。
