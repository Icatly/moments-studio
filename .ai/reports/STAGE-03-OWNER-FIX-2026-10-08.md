# Stage03 所有者真机反馈修正

## 实际反馈与实现

安装包6bd2fbf/run37743959206由所有者确认能打开、旧照片保留。横竖照片加入画布、比例、单指拖动、同时双指缩放旋转及松手本人反馈正常。随后反馈锁定重叠上层时列表所选下层不能移动；拖动锁层偶发增加持久化副本，图层数增加且重开仍存在。第二组未通过，其他步骤不外推。

- `CanvasGeometry.dragTarget` 与画布drag接线：已选可见照片层包含触点时保持该层，否则沿用最上层命中；锁层不可变换、tap选最上层保留。源码确认旧drag会覆盖列表选择，是下层拖动缺陷的确定原因。
- 取消/拒绝的手势也清理分量，避免未取得gate时留下旧值。新增缩略图、素材预览和工具ScrollView的明确interaction contentShape，添加按钮用plain样式；新增层只存在add按钮→add意图这条路径。副本真实触发尚未独立原生复现，触控边界修正是候选，不声称偶发副本已证实修复，不删除用户数据。
- 所有者明确要求Done保存返回首页：toolbar Done使用同一PhotoImportModel mutation gate及PhotoLibrary原子写；成功且仍在本项目编辑页才popToRoot。失败保留save意图，沿用Retry/Discard，不伪称已保存或提前返回。Done可保存空项目，首页/编辑器说明同步更新；不新增数据字段、schema、导航route、依赖或writer。
- 新增2个拖动几何、2个真实存储save/失败Retry、1个Done返回首页并terminate恢复UI方法；现有完整UI链追加锁层拒绝、无新增层、选下层重叠drag及上下层独立变换断言。测试入口同步为130 unit+8 UI=138；原133方法与原断言保持。

## 实际校验

Windows结构检查exit0：144 objects、47 references、29 App/13 unit/4 UI=46 Swift。独立tree-sitter解析46文件0错误；原生入口16段Bash/7段Python语法、真实manifest生成138项通过。Stage02原99、Stage03 UI原74、Contract原118、Storage原129完整断言按原序保留；本轮分别99/94/128/147。原Stage02两workflow不变。

受限执行环境首次Bash预检exit3221225794，仅为本机工具启动失败；同一预检在Windows MCP宿主执行exit0。私密证据`.ai/build/stage03-owner-fix-review-20261008-235545/review.json`，manifest SHA `b5e8f0c759e45079b6153ca2fa1d0e297ddcfafe839d88ff28f99acc16a81843`。这是静态与工程脚本验证，Swift类型检查、138 XCTest和新包真机复测未执行。

## GitHub与费用

所有者最新明确“根据我提到的内容进行修改 修改完毕后去github测试”，授权本轮修正及GitHub测试，取代旧一次build不能作为本轮测试授权的限制；不等于允许新增费用。当前网页登录刷新实见1953/2000、0.1/0.5GB、gross/included $11.73相抵net$0；API账单404不改变网页证据。完整18分钟原生入口额度不足，费用边界确认前不派发、不改预算；不重建旧包、不伪称测试通过。仅精确提交本轮App/测试/入口与本报告/Review/任务，不包含其他未提交文档/README或私密.ai/build。

2026-10-09 00:00重新核实预算页面：Actions为账户范围$0预算，Stop usage为Yes；不改动此预算。完整测试待费用边界或免费macOS环境确认，本轮提交本身不自动触发workflow_dispatch入口。

Stage03保持CHANGES_REQUESTED，138方法执行数0，Final Review与所有者最终验收未发生，Stage04未授权。手机仍运行修正前6bd2fbf IPA，不能用它证明本次修改。
