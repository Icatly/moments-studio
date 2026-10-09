# Stage04 DSH接手核验与技术检查点

所有者2026-10-09已明确完成Stage04/05并恢复分工。执行者DSH；Architect负责规格/Review，不直接代写代码。既有工作区D:/朋友圈生成应用。先读根交接当前分工、工作须知、AGENTS、Stage04架构/实现报告和实际差异；下方旧Stage03停止安排已被本任务取代。

## 当前事实

Stage03历史source68864c2的138项原生通过，手机仍该包。Stage04本地代码/测试/工作流由Architect此前直接写入，不是DSH交付；51 Swift结构检查及脚本检查已执行，146 unit+9 UI=155项只是源码清单，Xcode/IPA/本人Stage04验收均未执行。工作区许多无关旧未提交文件；不能reset/clean、广泛暂存或清理.ai/build。

## 本轮任务

1. 接手Stage04现有实现，完整读CollageLayout、CollageLayoutSheet、PhotoImportModel layout保存/重试、RootView/AppRoute、测试与两个Stage04工作流。沿既有架构核对编译类型/actor isolation、布局边界、保留锁定/隐藏/ID、重复Apply不增层、原子失败与重试、三预览搜索取消和可访问性。
2. 发现明确缺陷可在Stage04已批准边界最小修复；不得改公开Codable模型、原始照片、旧测试断言/skip逻辑或Stage01–03工作流。不重新执行没有变更的完整静态检查；有变更执行必要生成/验证和精确相关检查。
3. 写`.ai/reports/STAGE-04-DSH-TAKEOVER-01.md`，明确实际改动/检查/未执行/问题，并写基线源文件与测试方法清单。尤其不要把源清单155项当XCTest运行。
4. 完成本地核验后停在READY_FOR_ARCHITECT_REVIEW，通知Architect。**本轮先不修改Stage05文件**，Architect检查Stage04检查点后再发已获授权Stage05实施任务；这是技术检查，不再要求所有者重复授权两个阶段。

允许修改：Stage04实际App/测试源文件、必要工程引用、两个Stage04工作流及本任务对应报告；无关文件保留。禁止本轮git提交/推送/云派发/付款/账户设置；Architect负责公开集合审核和外部执行组织。DSH70%先落盘再同工作区接续，保留旧会话，不创建新目录。
