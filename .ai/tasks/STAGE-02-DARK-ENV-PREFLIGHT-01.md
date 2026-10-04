# Stage02真实深色环境预检补充

Architect 2026-10-05。第五轮37227995563/source01bc584实际03:38:58成功，85/85/0/0/0，原生取消保留/确认移除/再导入/同project与asset重启实际通过，完整artifact SHA已匹配。但Architect实际查看三张标记dark的PNG，全部仍浅色，因此深色视觉没有通过。产品没有preferredColorScheme/UIUserInterfaceStyle/overrideUserInterfaceStyle。不能把XCUIDevice setter日志当渲染证据，不能断言已证明Apple regression或产品bug。

依据本地run37227995563/simctl-ui-help.txt（exit_status=0）明确支持appearance读/设置light|dark；Apple官方Xcode11.4 release notes也公开simctl ui appearance dark：https://developer.apple.com/documentation/xcode-release-notes/xcode-11_4-release-notes。使用这一环境控制补验，与已复审最大辅助字号合并单次运行；本机Windows不冒称native执行。今天Stage02免逐项审批，账户/付费/Stage03禁令保持。

只改`.github/workflows/stage02-testflight-preflight.yml`，新增独立报告`.ai/reports/STAGE-02-DARK-ENV-PREFLIGHT-01.md`。不得改产品Swift/UI测试/工程/tools/87断言/85方法/guard/timeout20/2day/no cache，原有步骤内容不变（已有最大字号两步也保持）。不得提交/推送/云端触发/查询/付费/账户；由Architect复审后执行。

1. workflow_dispatch加boolean `dark_appearance`默认false，描述一次性模拟器环境；默认false不改appearance。
2. fixture之后、tests之前加`if: inputs.dark_appearance`应用步骤：核原help整行exit_status=0与appearance支持；读当前值/保存完整命令和exit/value到appearance-original.txt，只接受精确light或dark；改前保存STAGE02_ORIGINAL_APPEARANCE至GITHUB_ENV。set dark及readback精确dark/双exit0，否则硬失败；appearance-applied.txt记录原值、目标、command、各exit和readback。不修改App/launch参数，不改系统安全设置，只一次性runner模拟器。
3. 在测试/85门禁后、app包装前增加一次只读环境持续核验：`if: always() && (inputs.large_text || inputs.dark_appearance)`；只检查实际被请求的值，large_text须content_size精确accessibility-extra-extra-extra-large，dark_appearance须appearance精确dark；全部exit0，不成立硬失败，记录environment-after-tests.txt。真实环境读回仍不能替代PNG审查。
4. guard/upload之前`if: always() && inputs.dark_appearance && env.STAGE02_ORIGINAL_APPEARANCE != ''`还原，readback要求原值/双exit0，保存appearance-restored.txt；原最大字号还原不变。失败也保留诊断并如实failure，不忽略错误或自动重试。
5. Windows本地解析及实际shell stub故障分支，包括非法组合light dark/unknown/unsupported/读取失败/设置失败/读回不匹配/帮助非零/还原失败，以及持续核验两个输入分别/一起/故障；默认分支及全部旧steps原文核验。报告真实已执行、尚未native执行与警告。交付READY_FOR_ARCHITECT_REVIEW后停止。

报告不重新复制旧默认85检查或冒称深色通过。新轮最大字号+深色的实际可操作性/像素/源码/包SHA由Architect对新原始证据判断。UIKitToolbar运行告警目前根因未确立，暂记录限制，不擅自修改纯SwiftUI toolbar。
