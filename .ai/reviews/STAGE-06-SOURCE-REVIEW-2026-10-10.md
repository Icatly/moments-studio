# Stage06最终源码预审 — 2026-10-10

源码预审通过，准备完整原生验证；不是Xcode通过、本人验收或Stage06 APPROVED。真实DSH于12:27交付FIX07并idle59%，Architect逐轮退回后独立核实际源码与断言；实现由DSH，Architect未代写App/测试/工作流。

批准仅ImportedPhoto可选roleChoice附加字段；4既有公开模型及schema保持。用户明确人工选择优先、auto参与重算但只Save持久化、草稿三态及UI/source一致、完整roles/metadata快照、取消/项目/token防过期、同mutation gate/原子提交及失败保持；Focus仅首可编辑主图计算位置优先，保存顺序/身份/保护层保持，collage/excluded原照片不删除。Vision只已生成320px/顺序最多20张，真实supported词表精确交集/有效confidence与face范围；失败保留成功光色测量，透明明确跳过；无网络/依赖/原图处理/持久化观察缓存。

已执行：本机结构192对象/70 Swift/40App23unit7UI；Swift tree-sitter无语法错；新workflow YAML、16+5 Bash及7+5内嵌Python检查；执行工作流真实清单245unit+11UI=256，重复方法0，旧186源/断言与4冻结workflow未改。证据本机私密stage06-independent-20261010-122912；manifest SHA256 6830cfc9d043440645d87e0a235dc3a602affc6ae3663778eb047885c09334ca。CRLF/LF在提交时可能规范化，云证据须按实际提交Git blob核对，不直接拿本机raw SHA声称云同源。

新增70方法实际覆盖严格序列化/primary唯一、manual/auto/三态/source/失败/排序、完整metadata+role/token/project隔离、真实库清空/部分清/后续编辑删除保持、真实目录只写失败→强制saveFailed/rollback/retry、真实Vision与透明请求、布局真实角色/保护层/重复Apply；新增UI从真实导入到Cancel/Save/更换已存主图/Automatic/重启，再非首导入主图实际transform/重复Apply。无需虚构API、XCTSkip、旧回归放宽或生产测试开关。

尚未：Swift类型/actor编译、XCTest、云run、IPA、真机本人反馈。已知限制：工程排序不是审美评分；自然标签有限且与OS词表相交；只自动primary/supporting，拼贴和不用由用户；取消阻止后续与回写，不保证中止当前同步Vision；旧版再写可能丢角色；仍单画布，未实现云AI整组/滤镜/相册导出/趋势。原生警告待实际日志，不能声称零警告。对模型/source/API形态的剩余不确定性交实际原生证据，不提前批准。

按既有“修改完毕后去github测试”与当前Stage06授权，精确审核文件清单正常提交/推送公开仓库，排除私密.ai/build/原照片/原始桌面与历史会话材料；仅标准macos26/稳定Xcode26+、40分钟完整scheme、2天证据。零新增付费/账户设置/强推/自动重跑。原生真实通过后同源6分钟设备构建，具备包与验收说明后WAITING_FOR_USER。Stage07未授权。
