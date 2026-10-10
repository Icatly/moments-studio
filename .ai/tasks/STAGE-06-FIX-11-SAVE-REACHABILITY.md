# Stage06 FIX11 — 保存入口可达性

所有者“进行stage06”及“继续1”授权继续当前阶段；Stage07未授权。Architect分派真实DSH实施，不代写App/测试/工作流。

第四轮 [run38028987350](https://github.com/Icatly/moments-studio/actions/runs/38028987350)，源 `090bebfc4679f88a624ebe447ff8245be30728b4`，Xcode26.6/SDK26.5，iPhone17Pro/iOS26.5：完整256实际执行，255通过/1UI失败/0跳过/0预期失败；245单元和旧186全部通过。FIX10三个unit失败已消失。

原始私密证据 `.ai/build/stage06-run-38028987350-20261010-155032/evidence/`，archive267402215bytes，SHA256 `bc2bbcd66a1a756664787a1feeaf894a1c2df7a834f125c2f93ee24a8ce00d68`。UI日志5310–5447：打开roles、Checked2of2、选第二张Primary及真实role/source断言已通过；第一次saveChoices在新UI第186行失败，118.74–147.85秒找 `app.buttons["roles.save"]` 一直不存在。附件debug description仅query chain，无匹配元素。未执行首次保存及后续重开/Cancel/Automatic/重启/Focus，不能宣称这些已通过。

源码PhotoRolesSheet导航栏同时有Cancel、Analyze again、Reload、Save choices。这是当前首要可达性缺陷；导航拥挤/原生overflow是有源码依据的判断，尚无失败末帧视觉证据，不能伪称截图已证明。

## Architect决定与最小实施

1. PhotoRolesSheet导航栏只保留Cancel和Save choices；Analyze again与Reload移到现有ScrollView的内容区，用普通原生按钮及44pt触点。保留原动作、disabled条件、accessibilityIdentifier、快照/请求token语义，不能改为隐藏按钮或仅供测试控件。辅助按钮在手机窄屏可达，避免同一不可换行超宽横排。Use suggested roles原语义保留。不新增依赖/抽象/导航或序列化字段。
2. 检查原生toolbar按钮AX实际类型：如果既有 `.frame(minHeight:)` 导致包装成Other，则最小修饰器/AX方式保持真实Button可达；必要时新UI用既有通用element helper读真实按钮，不是假构造/常量、坐标盲点或绕过保存。仅当前新UI允许必要locator改动，旧186不改。
3. 首次真实角色修改后Save必须存在、enabled、hittable并调用真实保存；明确诊断缺元素/disabled/不可点击，可附真实roles页面/AX截图或debug信息供下一轮定位。所有原保存/Cancel/主图替换/Automatic/重启/Focus真geometry/重复不复制断言完整保留，不减少256、不只跑新增、不放宽expected或等待无限超时。
4. 允许范围：PhotoRolesSheet.swift、必要Stage06PhotoRolesUITests.swift、本阶段报告/交接；若发现其他生产根因先反馈Architect，不大范围修。四冻结workflow、4旧公开模型、生产存储/策略/架构不改。
5. 报告追加第四轮255/256真实结果及FIX11实际变更，保留FIX08/09/10历史行数/hash/证据不泛替换。完成本机结构、语法、完整245+11清单和旧基线保护后交READY_FOR_ARCHITECT_REVIEW；不要commit/push/dispatch或开始Stage07。DSH当前62%，到70%先保存handoff再同工作区新上下文，旧会话保留。

成功全256的原生结果及同源IPA仍待Architect执行；DSH本机静态通过不能称原生通过或所有者验收。
