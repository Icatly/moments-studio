# DSH Task — Stage 01 Runtime Visual Corrections 02

先读`.ai/reviews/STAGE-01-ARCHITECT-ROUND-03.md`和`.ai/reviews/STAGE-01-CLOUD-REVIEW.md`。授权来自Architect对真实运行缺陷的局部修复裁定；不得开始Stage02。

## 目标与允许改动

1. `HomeView`增加原生`@Environment(\.colorScheme)`读取，仅Create Project的Label内容显式使用浅色主题`Color.white`、深色主题`Color.black`。保持现有borderedProminent、tint、按钮动作与identifier。不要替换AccentColor或全局导航色，不创建ButtonStyle/新token/协议。
2. 仅Home和Settings的List footer说明，把层级`.foregroundStyle(.secondary)`改为明确的`.foregroundStyle(Color.secondary)`；字体、文案与布局保留。
3. 你的交付报告、review packet和验收证据表新增本轮记录：云端49dc9f3已执行31项测试零失败，但深色对比度Review退回；你本机仍为Windows。本轮新源码的Xcode测试尚待Architect执行，不能拿旧commit的结果当作新结果。

## 本轮排除项

不修改任何公开模型/序列化字段、导航契约、工程设置、目录边界、依赖、资产颜色、品牌设计；不增加任何产品能力；不改Architect的Task/Review/cloud工作流或操作说明；不上传源码，不操作账户，不自行运行云服务。

## 完成标准与验收

- 局部修复V1/V2，保留现有29个单元和2个UI测试，无需为颜色常量增加镜像测试。
- 执行已有Windows结构和Swift语法校验，如实报告；不要安装新依赖。
- 提交实际改动文件与已执行/未执行检查。最后停在READY_FOR_ARCHITECT_REVIEW。
- Architect重新云端编译测试并在iOS模拟器检查light/dark按钮可读、footer可读、放大字体可用。只有可运行版本及Review完成后才能WAITING_FOR_USER；只有所有者明确批准才能APPROVED。
