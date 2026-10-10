# Stage06 原生第五轮：CHANGES_REQUESTED

[run38036555619](https://github.com/Icatly/moments-studio/actions/runs/38036555619)，源`2625988c5c33f687247d7e6c40180a2afce81c1d`，attempt1，Xcode26.6/SDK26.5，iPhone17Pro/iOS26.5：完整256真实执行，**255通过/1新UI失败/0跳过/0预期失败**。245单元与旧186全部通过。

唯一失败是新UI的`tapLayoutSheet`第57行：Focus按钮存在，frame=(16,974.3,108.7,20.3)，window402×874，位于屏幕外；新helper未实际滚动，仅等待enabled/hittable。既有Stage04私有helper会在唯一layout.scroll内按真实可用视口有界滚动；当前任务[FIX12](../tasks/STAGE-06-FIX-12-FOCUS-SCROLL.md)只补新UI操作，生产App和旧测试保持。

新UI本轮已真实完成首次Save/重开、Cancel不写、替换人工主图与旧主图降配图、Automatic清人工来源、重启后角色及来源保留。Focus第一次选择失败，Apply/几何/repeat及末尾角色不变尚未执行，不能外推通过。

原始证据`.ai/build/stage06-run-38036555619-20261010-163551/evidence/`，archive328155039bytes/SHA256`8d469da6375c152bf6401acc2eec256fc8206499b83c06952ca1c31cd28f095f`。实际查看`3AE7DF26-A338-4B1D-B042-2EC8D81C41BB.png`：角色页顶部Cancel/Save choices完整可见、辅助动作竖排、两缩略图与Automatic/人工Primary来源分别显示、无文字交叠；仍只是合成照片和默认字号截图，不是最终品牌或所有者真机验收。`C16AD83E-B7E1-4605-B621-E92B1FCDA37D.png`是Layouts，Focus在Grid之后且选择按钮屏幕外，与AX一致。

没有Stage06成功全256或同源IPA/本人验收，前四轮失败证据保留，Stage07未授权。
