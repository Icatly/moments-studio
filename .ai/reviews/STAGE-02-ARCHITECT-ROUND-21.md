# Stage02 Architect Review — Round21

2026-10-04，北京时间。范围：DSH TESTFLIGHT-PREFLIGHT-01 本地交付；不是产品功能重审或所有者验收。

结论：CHANGES_REQUESTED。暂不提交/触发新版工作流。

## 已核对

- 完整读取接续提示词、当前快照、AGENTS、预检任务/报告、新工作流与 README diff。HEAD f185738；实际受跟踪 diff 没有 Swift/测试/生成器/工程/旧工作流变更。
- Architect 实际执行 `python tools/verify_project.py`：PASS，40 Swift/6567 行、132 对象、11 UI 查询标识符；`git diff --check` 无错误。这不是 Xcode 类型检查或运行测试。
- GitHub 官方文档列出 macos-26 为标准 arm64 runner，可使用私有仓库账户的 included minutes；镜像内容须以实际运行记录为准。当前账户额度尚未重新核验，不能承诺零新增费用。来源：https://docs.github.com/en/actions/reference/runners/github-hosted-runners 。
- PyYAML 6.0.3 仅是 DSH 本机诊断安装；当前交付工作流内 Python 与 tools 均未引入 PyYAML。不据此认定 App 依赖违规，也不批准新增工程依赖。44/13 项是 DSH 报告，尚不是 Architect 独立确认的完整结果。

## 阻断与限定修复

1. P1：`Build version` 行用 `line.split(':', 1)[1]` 取值，但 xcodebuild 标准输出是 `Build version 17…`（无冒号），会抛 IndexError，工具链选择根本无法完成。按真实格式解析，保留 build 号证据；缺失/格式错误明确失败。
2. P1：上传前守卫和上传步骤都用 `if: always()`；守卫失败并不能阻止下一步骤上传。守卫加 step id，上传条件明确要求守卫 outcome==success，同时仍能保存安全的失败构建/测试证据。需检查 YAML 条件和实际拒绝分支，不能只测 Python 退出码。
3. P2：runtime 只按 major 排序；同为26的26.2/26.4/26.5取决于 JSON 顺序，DSH 所称最高26.5并无可靠实现。按完整数值版本排序（打乱输入仍选最高），且确保选中目标是该 Xcode 可用于 scheme 的 destination；保留失败诊断。
4. 证据补齐：在工具链选定后记录 runtime 清单、主机 arm64；测试 summary 明确验证实际 iOS26+ / Simulator / arm64 与选中 UDID，防止旧 summary 或错误 destination 被计数条件接受。版本/设备断言失败不打包成功包。

DSH 修复范围见 PREFLIGHT-FIX-01；禁止改 Swift/85测试/契约、自动云端运行、Apple账户、付费或 Stage03。旧 run9 85/85、17.2 单张预览证据继续有效，不扩大为新 SDK 通过。

尚未执行：Xcode26真实构建/测试、新包、重启/深色/大字号检查、所有者交互验收。Appetize最新31/30、零可用分钟；此前账单周期记录下次重置为11月1日08:00北京时间，未新启动会话。

## 独立复现补证

Architect已执行本地标准库诊断 `.ai/build/round21-reproduce.py`（本地证据，不上传）：抽取原工作流选择脚本，以标准 `Xcode 26.5 / Build version 17F42` mock实际运行，确认IndexError；打乱26.5/26.2顺序确认只按major会选26.2；核对上传always且无守卫成功依赖。初次临时目录检查因Windows沙箱权限失败，改固定本地诊断目录后检查执行成功；不把初次失败称通过。未执行Xcode。

21:50前后实际DSH画面显示已读任务、模型请求自动重试5/5后TRANSPORT失败；未产生修复报告或工作流变化。21:52已发送一次限定续执行重试并实见DSH处理，未确认新交付。
