# Stage06 FIX10 源码预审

本轮只修三份新增测试及报告。包与photo引用统一projectID，legacy另用一致ID；非法JSON场景实际为automatic excluded/collageMaterial，合法manual excluded继续可读，unknownrole/source/type和变体确实改变均断言；角色策略fixture为manual supporting保持及无manual限制的automatic supporting经真实suggest升primary，实际角色变化证明自动刷新；原生Picker只去已取证固定前缀`Role, `，仍严格比对完整角色，未用contains/常量假通过。

UI末尾保存/取消/人工主图替换/重启/Automatic/Focus真实transform与重复Apply断言未删除。App生产代码、公开契约、旧186与冻结工作流本轮不改，完整245单元+11UI=256门禁保持。

真实DSH13:48最终交付（62%idle）。Architect 13:51独立检查通过：70份Swift语法、结构、旧186测试源/四工作流和四公开模型保护；真实workflow清单245+11=256，manifest SHA256 `15a91db008f89460c9d52240fa7bee503a13797ac10471377b9671e74dd5970c`。私密证据 `.ai/build/stage06-independent-20261010-135102/`。legacy fixture明确版本1输入/版本2解码，全部UI末尾原断言保留；生产App本轮没有diff。报告两处旧FIX08/09静态快照恢复为原提交数据，避免把当前哈希错误覆盖历史。

源码预审不代表原生通过。提交前核最终源码哈希。第三轮252/256已真实执行，四失败根因与原始日志保留；新FIX10源需要新提交完整运行，不能以第三轮旧186通过外推新UI末尾。设备包必须等待同源完整测试成功，Stage07未授权。
