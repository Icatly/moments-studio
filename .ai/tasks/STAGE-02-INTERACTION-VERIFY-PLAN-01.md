# Stage02剩余交互证据方案 — 仅分析交付，暂不改代码

2026-10-05 Architect。今天Stage02免逐项审批，但Stage03/Apple/付费仍禁止。FIX03已复审并实际推送source1d103fb，第三轮run37222556297正在测试；不要查询/触发云端、不要修改本轮源码。

请DSH只阅读当前UI测试、Home/Editor/photo preview与原生工作流，在`.ai/reports/STAGE-02-INTERACTION-VERIFY-PLAN-01.md`给出最小可执行补验方案，不实现Swift/工程/workflow，不修改交接根文件（Architect正在更新），不重复已完成FIX01/02/03。方案与已执行证据严格分开。

剩余真实证据：导入项目的同一进程终止再启动恢复、深色可操作性、大字号可操作性。原有85项/全部断言必须保留；优先在既有完整导入测试末尾追加意义明确检查，不为凑方法造镜像测试。

1. 重启：由真实Home `home.project.<UUID>`和editor真实thumbnail标识确定刚导入的同一个项目/素材（不可凭首行或相似名称猜）。可比较创建前后Home项目ID集合严格要求唯一新ID；保留刚再导入assetID。真实terminate/launch后等待恢复就绪，核同一个项目ID、数量、同一assetID thumbnail、loaded preview与Done可操作。不用reset/产品钩子/数据注入。
2. 深色：Apple官方XCUIDevice.shared.appearance = .dark（https://developer.apple.com/documentation/xcuiautomation/xcuidevice/appearance-swift.property）；保存原设置并在defer恢复，只改测试模拟器。截图Home/导入Editor/loaded preview，图像屏内、关键按钮可用、标签数量正确。不要重新定义品牌/产品样式。
3. 大字号：不猜私有launch参数/未核JSON testplan字段，不给产品加环境注入。可在后续同一真实runner先取回`xcrun simctl help ui`与`content_size`实见帮助/当前值，确认合法命令和值后设最大accessibility字号并读取值证明；保留配置日志，测试截图与元素几何。当前Windows不能声称这些CLI已执行。若方案需工作流改动，明确最少插入点、恢复默认方式、预估新增时间及预算，不创建新包/依赖。
4. 说明新检查增加的失败点、怎样避免把旧85测试结果和新交互结果混淆；任何省略/不可执行项明确未验证。不把自动交互称所有者本人亲自操作。

先交方案等待Architect结论；如果本轮FIX03失败，先以新实际诊断修复当前阻塞，不能把新增交互覆盖当作修复。
