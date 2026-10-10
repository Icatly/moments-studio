# Stage06 最终技术复审与真机交付

2026-10-10 17:35，Architect。状态 **WAITING_FOR_USER**：实现、独立源码Review、完整原生测试及同源设备包已完成；签名安装与本人验收尚未执行。Stage07未授权。

## 实际运行与来源

- 源码 `321fdfbf1e330c6d66104aaf7d4f92eacfda5fe4`；真实DSH实施，Architect独立复核、精确提交和组织构建。FIX12仅修改新UI测试的真实滑动与导航定位，未修改App、旧186项或工作流。
- [第六轮完整测试](https://github.com/Icatly/moments-studio/actions/runs/38039391177)，attempt1，标准macos-26，Xcode26.6 build17F113 / SDK26.5，iPhone17Pro / iOS26.5：**245单元+11 UI=256通过，0失败、0跳过、0预期失败**。旧186项完整保留；新增70项的方法数为7/19/15/10/18/1。原始xcresult、日志实际计数、逐文件方法与不可变Git blob哈希均独立相等。
- 原始测试artifact 288473295 bytes，SHA256 `31eabead243c0cc4e5e48a25032b2109e0b36d13f128e42eee18f0a4aa6eeb05`。本机私密证据与核验记录保留，不公开原始附件。
- [同源设备构建](https://github.com/Icatly/moments-studio/actions/runs/38041676943)，attempt1，标准macos-26，无签名Release成功；同一Xcode/SDK、iPhoneOS arm64 Mach-O、最低iOS17、bundle `com.example.MomentsStudio`、无测试bundle均核实。
- IPA **858693 bytes**，SHA256 `e8a26edef8d5060ce6222abd0c7fae856ca0cf279cc25b747b882e3c74ec3f0d`；云记录、解包、本机交付与英文安装副本一致。交付 `outputs/Stage06-2026-10-10/MomentsStudio.ipa`；安装副本 `C:/Users/27411/AppData/Local/Temp/MomentsStudio-Stage06-38041676943/MomentsStudio.ipa`。

## 架构、行为与视觉Review

唯一批准新增契约为ImportedPhoto可选roleChoice，nil不编码、旧schema兼容、未知类型/角色/来源与非法自动用途拒绝；Project/CanvasDocument/Asset/Layer字段保持。原子保存复用现有mutation gate，完整照片与角色快照拒绝stale/跨项目，真实IO失败回滚与retry均有本轮运行证据。分析在PhotoLibrary actor内顺序处理最多20张320px缩略图，Vision失败保留真实有限像素依据；自动只建议主图/配图，不做美颜或自动排除。

新UI整条链实际完成：导入两张→人工主图保存/重开来源→Cancel不写→替换主图降旧主图→Automatic清除人工来源→结束App重开→较后导入主图的Focus主位（真实y与scale）→再次Apply身份/数量/变换保持→角色仍保存。首次Focus在目标完全进入本sheet视口后真实点击，Apply从Layouts导航栏自己的后代定位；没有伪造值或跳过断言。

Architect实际查看原始200935C1…png角色页：Cancel/Save choices完整，辅助动作竖排，两张缩略图、Automatic与人工Primary、来源说明分开且无文字重叠。BE77D071…png附件虽名为“saved choice after restart”，实际画面是Layouts，不能冒充角色页重启截图；它显示Grid后Focus，选择按钮在下方可滚区域。重启保留由本轮真实UI断言支持，Focus滑动与两次Apply由原始日志支持。截图使用合成照片与默认字号/浅色，只说明当前功能样式，不代表最终品牌或所有字号/设备视觉通过。

本轮旧大照片导入观察为3×4000×3000 JPEG串行0.523秒，两处phys_footprint差98304 bytes；这只是模拟器两次采样，不能称峰值内存或真机性能。Stage06真实照片建议准确率、20张真机耗时、不同机型与大字号仍需实际体验，未宣称通过。

## 保留的限制与人工闸门

前三个PhotoAnalysisSheet unused invalidate warning与AppIntents元数据提示保留，未称零警告；没有新增第三方运行依赖、费用或账户安全更改。前五轮失败原始证据保持：两轮编译失败未执行XCTest、252/256、255/256首次Save失败、255/256屏幕外Focus未滚动；不得用最终成功改写历史。

本阶段是可选本地角色建议/可保存选择/现有布局衔接，完整AI整组、自适应滤镜、抠图、相册导出和热点监测尚未实现。执行开发已停止，按[三组真机验收](../acceptance/STAGE-06-PHYSICAL-DEVICE.md)等待所有者实际反馈；自动通过及设备构建均不等于APPROVED。
