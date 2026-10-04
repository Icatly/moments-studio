# Stage02 预检工作流限定修复01

Architect 2026-10-04。先读 Round21。只修已有预检工作流及对应 README/报告；不重做原任务，不改 Swift/测试/工程/生成器/既有工作流或公开契约，不进入Stage03。Apple账户搁置；不得触发云端或产生费用。

1. 修复 xcodebuild `Build version 17…` 无冒号输出解析；测试必须执行实际内嵌选择脚本并 mock 正式工具链成功/无合格版本/错误输出，记录完整版本/build。
2. 证据守卫加 id，上传只在守卫 outcome==success 时执行（仍可上传安全的失败运行日志）。用一次含 `.p8`/照片的拒绝检查与工作流条件核对，证明失败阻断上传；不要复制新测试体系。
3. runtime 按完整数值版本排序，打乱26.2/26.4/26.5与旧18.5顺序仍选最高；确认选中 UDID 是所选 Xcode 下现有 scheme 的实际可用 destination（不能跳过、不重试或下载runtime）。
4. 记录 arm64 主机、选择后 runtime 清单；summary 守卫除原85/85/0/0/0外，还拒绝 iOS18.5、非模拟器、非arm64、非选中UDID/缺设备证据。用实际run9 summary结构而非猜字段，记录检查。
5. 更新真实交付报告（新文件 `.ai/reports/STAGE-02-PREFLIGHT-FIX-01.md`）；更正旧报告“最高runtime”和“拒绝上传”结论，标注本轮修复证据。Appetize当前最新31/30、0分钟。所有本轮 `tools/*.py` 和工作流Python只用标准库；不新增依赖，不卸载现有本机诊断包。

Windows只核验静态/模拟输入，不称Xcode通过。交付停止于READY_FOR_ARCHITECT_REVIEW；报告写明剩余限制。Architect负责额度核验、精选提交、真实云端运行和验收准备，所有者PENDING。
