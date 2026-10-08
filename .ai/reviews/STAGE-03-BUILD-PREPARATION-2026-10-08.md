# Stage03 设备构建准备复审

日期：2026-10-08。Architect / Design / Final Reviewer；本文件是构建前复审，**不是 Final Review 通过**。

## 当前结论

Round03已完成的应用与测试源码保持，允许准备当前源码的真实设备构建。Stage03仍CHANGES_REQUESTED：没有Stage03 Xcode结果、IPA或本人交互验收；不进入Stage04。旧iPhone照片体验不计Stage03。

## 实际已执行

- 当前46个Swift文件逐个SHA256与Round03独立清单相同，没有重复开发App。126 unit + 7 UI = 133仅为源码方法数，执行数0。
- 新文件纳入暂存后，全量格式检查发现EditorLayerListView末尾多一个空行；已审查为格式提示，保留已复审源码。其余空白检查通过；这不代表原生编译无警告。
- 新设备工作流仅手动触发，标准macos-15、6分钟job超时、contents只读、checkout不存凭据。Release无签名设备构建；核Info.plist、arm64、Mach-O IOS、IPA Payload和包SHA，保存源码commit和完整构建log。
- Architect补充上传守卫：只允许9个已定义产物文件，拒绝目录/符号链接，全部产物合计不超过100MiB，保留2天；守卫失败禁止上传。这是产物大小上限，不是已经生成了安装包。
- 独立Windows检查：设备工作流YAML通过、4段Bash语法通过、4段内嵌Python AST通过。Windows检查不证明Swift类型检查或设备运行。
- 只读GitHub API确认既有仓库Icatly/moments-studio仍私有、凭据可用、最新运行仍旧Stage02；账单API404，未改变凭据范围。
- 实际浏览已登录账号的当前账单：Actions使用1922/2000免费分钟，名义剩78；存储0.1/0.5GB；gross与included同为$11.54，net $0。预算页Actions超额预算$0、Stop usage为Yes；只读，未改设置。私密截图`.ai/build/stage03-20261008-billing.png`与`stage03-20261008-budgets.png`不入仓库。

## 构建执行范围与费用边界

准备推送的设备构建集合为25文件：21个应用/工程/测试文件，1个手动设备工作流，以及AGENTS、Stage03架构、本复审3个文档；准确名单位于私密`.ai/build/stage03-device-push-allowlist.json`。不含`.ai/build`、照片/视频/桌面截图、旧Stage02工作流、其他未提交文档。

当前设备工作流**未推送/触发**。先完成精确本地提交以便审阅；既有九文件批准仅对应旧Stage02，需要具体批准本次新增远端写入和一次设备构建。批准后执行前再读余额/活动运行，保留$0超额停止设置，不改预算、不重跑、不新增费用。单次6分钟设备构建是优先方案，不声称6分钟一定构建成功或一定产出IPA。

GitHub当前官方[计费说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)与[runner价格](https://docs.github.com/en/billing/reference/actions-runner-pricing)显示不同系统耗额不同，macOS标准runner现为$0.062/分钟；不能把78免费分钟当78分钟Mac使用时间，也不能直接把历史10倍规则当当前价格。当前余额只用于一次限时设备构建；18分钟完整原生测试入口本地准备，**不在本轮派发范围**。Actions的$0超额停止预算是零新增费用边界，不扩大付费授权。

## 仍待真实证据

DSH已收到并正在完成独立133方法原生工作流本地任务；Architect已核其初稿YAML/16段Bash/7段Python与真实源码清单，发现早期失败缺少manifest时会拒绝日志上传，需要补正并复审。该工作流未推送/执行，局部静态检查不算交付完成。

设备构建通过只证明App可编译并产出设备包，不执行XCTest。之后须独立核包/源码SHA，在本人iPhone实际测试Stage03照片图层、单指和组合双指、层级/隐藏/锁定、保存恢复与删除，再做Final Review和所有者批准。当前没有这些结果；任何真实编译/交互失败只修Stage03。
