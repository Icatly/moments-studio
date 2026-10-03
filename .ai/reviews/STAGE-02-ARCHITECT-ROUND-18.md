# Stage02 Architect Round18 — run8 actual results and picker readiness defect

2026-10-04 04:18 Asia/Shanghai。Stage02 CHANGES_REQUESTED、所有者PENDING；Stage03禁止。

## 原始证据

- source b9cf5a7fff593a9b7ed55660f0ab21fdbb4afe3d，run https://github.com/Icatly/moments-studio/actions/runs/37149876593 ，job111281259985。
- macOS实际编译成功；80unit+4UI通过，1UI失败；总85/通过84/失败1/跳过0。新的完整真实导入→预览→Done→取消移除→确认移除→空计数→再次导入用例通过54.357秒。
- 唯一失败：既有 testImportPickerCanBeDismissedBackToTheEditor，Stage02ImportUITests.swift:65，Cancel tap后20秒有界消失等待失败。不得取消此测试，也不得把该运行说成全通过或生成有效交付包。
- 原始日志、test-summary、Stage02.xcresult、保留附件在 .ai/build/downloads/run-37149876593/；浏览器下载zip86201221bytes SHA256 2da71fb8a95570f4db7ebed2bb6fb043b5a022c91d1aefb5e6a1758fbc2bd2a 与GitHub完整原生上传记录一致。

## 根因证据与限度

源码在首次Cancel存在后直接tap，未等Photos导航出现，也未等该按钮enabled+hittable。原生日志约t8.4点击；实际本地查看6250FC7B-A343-4B87-B0DF-6F3779389425.mp4，约6秒画面仍为初始化Loading、可见Cancel但没有Photos导航，13秒末才是完整Photos/Collections/网格。证实存在先出现Cancel、后完成原生选择器呈现的窗口；原来仅exists不是就绪判据。Apple内部为何该次早期tap未生效及当时按钮enabled值未由原始dump证明，不声称生产应用Cancel回调损坏，不改生产代码。

决定FIX09只修这一个取消smoke的同步和原生控件作用域：正向等待Photos导航，在该导航下查询Cancel，有限等待enabled+hittable，一次真实点击，然后仍等待选择器消失与Editor可操作。失败保留原生层级诊断；不靠sleep/skip/坐标/retry/改产品换取通过。

## 预览视觉实审

已用本地图像查看器实际检查附件6BA9E4EB-EDE1-4B17-B345-563367F66A26.png（1206×2622，360×540 PNG素材）：照片正向、2:3比例、aspect-fit留白、无裁断，Preview/Done/Remove及信息可辨，无loading/missing/unavailable。这是iOS18.5临时功能预览的像素检查，非最终品牌验收，也不代表17.2/深色/大字号/真实照片已测。

生产预览依赖修复在18.5真实全流程通过；17.2之前的fatal仍需新有效包实际复查。Appetize余3免费分钟暂停未消费。需FIX09实际全85通过后再打包上传。所有者9项验收未勾选。

实际预览附件SHA256：2577e72fff2dfd31a32cba9b27050e1f414c32e3491225c304e06a45997027c1。

Run8实际性能附件：3×4000×3000JPEG串行导入0.300秒（不含fixture生成）；phys_footprint38,378,240→38,574,848bytes，resident214,466,560→214,646,784bytes。两时点快照不是峰值，合成图模拟器不代表真机性能。
