# Stage02 PREFLIGHT-FIX-02 — 真实iOS26 picker与失败证据

2026-10-05；Architect批准当前Stage02范围内的最小修复。先读Round23及本地原始job.log。不得开始Stage03。

执行范围仅`MomentsStudio/MomentsStudioUITests/Stage02ImportUITests.swift`、`.github/workflows/stage02-testflight-preflight.yml`与对应报告/交接。产品Swift、公开契约、依赖、工程布局不变。

1. run37216674264的原生层级明确iOS26.5 Photos导航、`photosView_content_scroll_view`、`PXGGridLayout-Info`、Photos导航内Done；旧iOS18.5层级是`content_scroll_view`、同photo id与Add。使用系统版本分支及两个明确scope，等待Photos导航就绪；iOS26确认限定Photos导航内Done，旧版保留已观察Add。保留85项、原有真实导入/预览/取消删除/确认删除/再导入的全部断言。禁止skip、镜像测试、增加timeout掩盖、盲猜兜底/坐标。
2. 工作流guard只允许`failure-attachments/<UUID>.mp4`这一类XCTest自动诊断视频，必须同时存在该目录的xcresult导出manifest.json与原result bundle，并在日志注明合成/系统默认媒体来源。其他视频/照片/credential-like文件仍fail。保留`${{ always() && steps.evidence_guard.outcome == 'success' }}`，不改always绕过guard。用实际guard脚本做stdlib正负验证（合法诊断录屏；未知目录/name；缺manifest/bundle；凭据；照片），不能仅镜像实现。
3. 报告精确区分Windows检查与未运行的Xcode验证，不代替或覆盖Codex FIX01报告。新报告`.ai/reports/STAGE-02-PREFLIGHT-FIX-02.md`。更新交接的当前事实，保留其他并行日志。

无需重复先前已完成四点修复，不大范围重写整个工作流。没有允许远端推送/构建的新指令；交付到READY_FOR_ARCHITECT_REVIEW，由Architect核对。Apple问题暂停，不购买Appetize，不标记Stage02 APPROVED。
