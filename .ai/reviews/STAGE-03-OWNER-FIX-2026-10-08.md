# Stage03 真机反馈修正复审

Architect本地复审：允许提交本轮最小修正并准备GitHub原生验证，不等于验收。

明确根因：drag的起点hitTest无条件重选最上层，覆盖列表选择，锁层拒绝导致被遮挡下层不可拖。新dragTarget区分tap和drag，选层包含起点时优先选层；锁层/隐藏/未绑定约束保留。测试覆盖锁定/非锁定重叠、未选择、旋转边界、隐藏和画布外；现有原生UI链保留全部74原断言并增加真实锁层/下层drag/身份计数与变换保持。

重复新增：本人报告图层数和重开副本都增加，按数据新增缺陷记录；源码仅add意图创建新UUID。按钮与工具区contentShape候选修正符合Apple的interaction命中区域API；尚无修后真机证据，不标已修复通过，也不推测底层SwiftUI机制。依据：[Apple ContentShapeKinds.interaction](https://developer.apple.com/documentation/swiftui/contentshapekinds/interaction)。

Done：所有者明确保存返回首页。内部save意图无需layerID，复用原子writer/gate及失败draft；成功后检查当前导航仍为同项目才返回，失败或busy留在当前页。空项目的明确保存使用同一已有manifest事务，不改变schema/路径/身份；补真实磁盘恢复、path-guard失败和Retry，以及真实Done/结束App恢复UI源码。

实际Windows结构/tree-sitter/workflow脚本/manifest与旧断言保存检查通过；无Xcode类型检查、138执行、修后IPA或iPhone交互。完整原生入口总数只增不减（130+8），零skip/失败与证据守卫保持，Stage02 workflow未动。GitHub派发须符合本轮所有者最新测试授权及零新增费用；Final Review仍待真实结果。
