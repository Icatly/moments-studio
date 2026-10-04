# Stage02 Architect Round25 — 修后第二轮真实失败

2026-10-05。结论CHANGES_REQUESTED，今天按所有者最新免逐项审批授权持续推进Stage02；Stage03禁止。

## 实际证据

- run37220074605/attempt1/source d5e31521f31ee9b67dbbeb655e02e1973a36fcdf，job01:19:43–01:30:24，failure。Xcode26.6 build17F113、SDK26.5、iOS26.5/iPhone17Pro arm64；设备Release/校验success。
- 已取回735683bytes原始job.log；80单元0失败、5UI1失败，控制台85/84/1/0/0。唯一失败在选择照片前：正确scope已找到9个`PXGGridLayout-Info`，第一个exists=true但hittable=false。有完整原生层级及first-image frame`{{0.0,346.0},{132.9,133.0}}`；Photos导航Done仍disabled，尚未真实选择照片，不能称导入/预览产品失败或成功。
- 修复后的guard已真实放行一份UUID诊断视频，要求manifest与原xcresult同时存在；导出/guard/上传success，包装skipped。原artifact下载进行中，尚未确认SHA、summary文件或实际录屏画面，不以清单替已下载声明。
- 4条AppIntents无依赖元数据提取warning。平坦合成3×4000×3000照片串行导入0.429秒，before footprint47880000/after47994688bytes，resident306561024/306872320bytes，只有两时点而非峰值，不代表真机性能。

## 有证据的下一步

`isHittable`是当前系统能否计算命中点，不等于元素不存在或永远不能操作；Apple官方说明`tap()`可尝试把滚动容器内的目标滚到屏内后实际点击：[isHittable](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)、[tap](https://developer.apple.com/documentation/xcuiautomation/xcuielement/tap())。本轮具体为何返回false尚未由画面证实；不发明系统根因或称已绕过。

允许下一次仅在iOS26分支以限定scope中的真实photo存在性、有限非空frame与Photos导航就绪作前置，调用一次原生photo.tap()让XCTest自己计算命中点/滚动。以Photos导航Done真正enabled+hittable、后续真实导入计数/图片加载/预览/移除/再导入作为成功证明；不是以一次tap调用算成功。旧iOS分支保留既有前置。添加两张必要原生诊断截图及元素状态记录，失败仍硬失败，不用坐标/无范围兜底或盲重跑。

先让DSH交付最小测试变更、复审实际diff再运行。今天可自行推送当前Stage02限定修复；每轮仍核剩余包含额度与产物存储，绝不把所有者免审批误当允许付费/扩阶段。
