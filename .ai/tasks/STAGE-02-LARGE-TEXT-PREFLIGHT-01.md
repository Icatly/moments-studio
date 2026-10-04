# Stage02最大辅助字号配置 — 仅实施/本地验证，暂不运行

Architect 2026-10-05。FIX05已03:16交付、Round30独立复审，8文件推送01bc5845cb6d25a6bb027af5406305e2e683d213，第五轮run37227995563正在真实执行；DSH不得查询/触发/取消该运行，不再修改已复审FIX05，不重复历史检查。今天Stage02免逐项审批，Apple/付费/Stage03禁止。

实际前置证据：本地run37225749574的simctl-ui-help.txt、content-size-current.txt，均exit_status0。当前large，帮助合法最大accessibility-extra-extra-extra-large。完整读原文件；不要用未核实launch参数或产品注入。

仅允许`.github/workflows/stage02-testflight-preflight.yml`加可选最大字号配置，独立报告`.ai/reports/STAGE-02-LARGE-TEXT-PREFLIGHT-01.md`。产品Swift/UI测试/工程/tools/公开契约/依赖完全不改，默认运行行为、85方法/门禁/timeout20/证据2天/no cache/guard不变；不commit/push/cloud/账户/付费。默认配置第五轮正在跑，不能写本轮已通过。

1. workflow_dispatch增加boolean输入`large_text`，默认false，作用只在一次性模拟器环境，描述明确Stage02最大辅助字号核验。不给产品加开关。不为默认模式增加设置或额外测试。
2. fixture seed之后、测试之前增加条件`if: inputs.large_text`步骤：只读当前类别保存至ARTIFACTS和GITHUB_ENV用于还原，明确拒绝unknown/unsupported或不在help已实见合法类别集合中的值；设置`accessibility-extra-extra-extra-large`，实际读回要求精确同值，不匹配硬失败；记录前值/命令/设置退出码/读回值，生成content-size-applied.txt，任何失败不冒称已应用。`set -euo pipefail`，不为过关忽略失败。
3. 测试后（证据guard/upload之前）条件`if: always() && inputs.large_text && env.STAGE02_ORIGINAL_CONTENT_SIZE != ''`还原原类别，实际读回确认匹配，保存content-size-restored.txt，未成功就如实failure；不跳过原85门禁/诊断导出。
4. 默认false不触碰content_size，最大模式同一80+5方法/87旧body断言在真实最大字号下完整运行，既有keepAlways截图/INTERACTION-VERIFY保留；不要加测试方法、删断言、改source契约或只跑选定UI。报告环境由CLI设置与读回证明，不是测试内字号断言；最大字号下是否可操作/视觉仍待云端原日志/PNG审查。
5. Windows实际YAML/所有内嵌Python解析/工程范围diff check、默认分支/条件/退出失败控制校验，报告READY_FOR_ARCHITECT_REVIEW后停止。没有macOS，最大字号尚未执行。预算按Round30/第五轮结束再核，不为提速静默放弃原85检查。若必要条件表达式不确定，给Architect说明最小写法，不引新依赖。

03:31实际补充送达：Architect用原新增完整shell+本地stub实际发现substring类别检查误接纳small medium组合。需case原值的精确枚举，拒绝组合/空/未知等非法值；设置前核captured help精确整行exit_status=0和支持最大合法值。其他范围不变。模拟分支不是native字号通过，见Round31。
