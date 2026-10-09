# Stage04第一次原生结果与退回 — 2026-10-10

[run37957684567](https://github.com/Icatly/moments-studio/actions/runs/37957684567)，冻结源码`edeca4ddaba03c727a7779bbbf042d899e408222`，attempt1，标准macos-26、Xcode26+/iOS26+，未重试或跳过。**155运行/153通过/2UI失败/0跳过/0预期失败**；146单元全部通过。设备Release无签名编译及产品校验通过，但阶段技术状态CHANGES_REQUESTED，不能当作验收通过。

独立下载原始日志、xcresult、附件并校验archive SHA256 `ac086b438e303a814b8e64c0999c5758706e3d6de8bb21da5e5265b839f662f2`，205603120 bytes；私密证据`.ai/build/stage04-run-37957684567-20261010-003618/`，不提交到公开仓库。

- Stage02ImportUITests:155：导入已完成count1且添加层素材存在。图库准备helper只滚到count y852.3，高15.7；窗口高874，后面LazyVGrid未进入/实例化，所以真实图库thumbnail仍不存在。实际截图与完整AX已读。保留原存在/完整视口/预览/删除断言，批准DSH最小修共享图库准备helper。
- Stage04LayoutUITests:44：搜索OFFSET后选择按钮frame(16,541.3,110,20.3)存在，search/keyboard仍活跃，原helper只检查整个layout.scroll而不检查真实nav/keyboard占区，等待hittable失败。需按实际搜索交互和可用视口修复，不允许穿透点选或绕过门槛。

已在既有DSH会话实际派发[FIX03](../tasks/STAGE-04-05-NATIVE-REVIEW-FIX-03.md)，同时指出Stage05 FIX02重复isSheetCurrent编译成员与自动任务复用token缺陷。Architect不代写；修复后以最终Stage05完整scheme包含全部旧155项，完成两阶段同源回归；保留这次失败原始证据，不通过盲重跑隐藏失败。

Architect另用本机已装浏览器、独立临时配置从原始录屏约140秒读取画面（无新依赖/账户设置）；`.ai/build/stage04-run-37957684567-20261010-003618/offset-frame.png`。实际看到Offset预览底缘紧接键盘，下面的Choose按钮被键盘遮挡，印证滚动helper的整个scroll.frame不能代表可点视口。受限浏览器首次管道失败，关闭自身错误弹窗后只读复核成功；未修改用户浏览器配置。
