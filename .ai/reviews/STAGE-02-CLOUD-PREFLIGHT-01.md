# Stage02 Xcode26真实预检 — 费用与源码执行核对

2026-10-05，北京时间。Architect；不是Stage02所有者批准。

## 执行前实际证据

- 所有者提供Included usage and credits截图：2000 included Actions minutes，额度约$12，Actions已抵扣$5.46；0.5GB included Actions storage，约$0.125，已抵扣< $0.01；Packages storage为$0。总览同时显示计量$5.46与抵扣$5.46、GitHub Free。美元额度带近似标记，不冒称截图给出了精确剩余分钟。
- GitHub官方标准macOS费率$0.062/分钟：https://docs.github.com/en/billing/reference/actions-runner-pricing 。本次单个20分钟作业上限折算$1.24，低于图示约$6.54 Actions余量；这是执行前预算估计，不是已扣费结果。
- 存储按GB-hours累计、Artifacts与Packages共用额度：https://docs.github.com/en/billing/concepts/product-billing/github-actions 。原生API实际读取本仓库13个未过期产物合计331158859bytes（约316MiB）；既有run9成功产物约7MB，早期失败产物最大约86MB；本次2天保留，无cache或其他上传。作为单次现有测试证据的预算核对，仍须核验新产物实际大小，不声称新包已生成。
- 原生API核对私有Icatly/moments-studio、写权限、main=d4d4ee7b27f19fae9f3d7712b429b3104a1c1ecf；工作流374642097 active，文件stage02-testflight-preflight.yml；既有预检运行列表为空。
- 用户已授权既有私有仓库上传及零新增费用的云端构建；10月4日又明确批准这9文件推送，已成功。以上余额证据满足本次单轮标准runner预检的预算要求，不启用付费runner/Apple上传/Appetize。

## 当前源码与未提交更新

待运行的是远端d4d4ee7中Round22已复审的工作流。10月5日00:19:41本地工作流出现未提交更新，与远端不同；其作者/交付状态尚待核对，不覆盖、不把它当作本次云端源码。本次Swift/85测试/工程与既有产品源码不变。原85/85仍只属于旧Xcode，Xcode26结果尚未取得。

## 运行计划（未当成执行结果）

执行一次workflow_dispatch；先保存POST尝试记录，不对不确定POST自动重试，防止重复消费。收到run后核对source/toolchain/runtime/device/build/test/警告/包SHA与实际产物大小；失败保留诊断后定位，不删测试、不skip/无限重试。原生模拟器交互环境仍无免费分钟，自动构建不替代所有者验收；Apple账户搁置，Stage03不执行。

## 实际结果（10月5日00:50核对）

POST204已接受；run37216674264/attempt1，源码d4d4ee7，job00:25:01–00:40:59，failure。真实Xcode26.6 build17F113、SDK26.5、iOS26.5；设备Release/产物校验success；85项实际84通过/1失败/0skip。上传guard误拦xcresult导出的UUID.mp4失败录屏，导致原始result bundle/包/截图未留存。已从GitHub取回741647bytes完整job.log，未触发重跑；Round23/FIX02记录两处根因与限定修复。约16分钟标准macOS费率折算$0.992，只是估算，未重新读取实际账单抵扣。具体原始证据见Round23；不存在新的模拟器ZIP/SHA或本人交互结果。
