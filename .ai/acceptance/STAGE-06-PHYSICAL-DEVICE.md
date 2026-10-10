# Stage06 真机交付与三组验收

当前：**WAITING_FOR_USER**，完整原生256/256、最终Review和同源IPA校验完成；签名安装/本人验收未执行。

范围：可选 Photo roles（照片角色）入口；本地照片建议、用户选择与现有布局衔接。本阶段尚不包含一键整组生成、自适应滤镜、抠图、导出或热点监测。

## 安装与旧项目

使用上次同一 Apple 账户更新，不卸载旧 App。凭据仅在本机 AltServer 弹窗填写，勿发聊天。安装成功后打开原项目，确认旧照片、图层数量、位置、隐藏/锁定保留，Photo roles 入口可见。

## 第一组：建议与决定权

在有至少两张照片的项目打开 Photo roles，等分析结束，核对缩略图与建议对应。Automatic 表示采用当前建议，人工选择显示对应来源。

1. 把一张设为 Primary photo，保存后重新打开。
2. 再把另一张设为 Primary photo，旧人工主图应改为 Supporting photo，保存成功且仅一个主图。
3. 把一张设为 Collage material（拼贴素材）或 Not for layout（不参与排版）；Analyze again 后人工选择仍在。将它改回 Automatic 可恢复当前建议，只有 Save choices 才写入项目。

## 第二组：取消与持久化

改一个选择后 Cancel，重新打开应是原保存选择。随后修改并 Save choices，Done 返回首页重开、结束 App 后重开，选择及来源仍保留。保存角色本身不改画布层数、位置、隐藏或锁定。不同项目的照片和选择分别对应各自项目。

## 第三组：布局衔接与重复应用

在可编辑且可见的层中，将较后导入照片设主图，打开 Layouts 的 Focus 预览并 Apply，主图应占主位；重复 Apply 不增加图层。现有锁定/隐藏及拼贴素材/排除照片的图层应保持位置，不删除照片。

可另建临时空画布项目：照片设为 Collage material/Not for layout 后 Apply，不应自动加这些层；全部为非参与照片时应提示去 Photo roles 改角色，照片仍在。恢复至少一张 Primary/Supporting 后能够排版。

## 证据记录

- 完整云测试：第六轮[run38039391177](https://github.com/Icatly/moments-studio/actions/runs/38039391177)/source321fdfbf1e330c6d66104aaf7d4f92eacfda5fe4完整245单元+11UI=256/256，0失败/跳过/预期失败。角色保存/重启、真实Focus主位与重复Apply均通过；前五轮失败保持。
- 同源设备包：[run38041676943](https://github.com/Icatly/moments-studio/actions/runs/38041676943)成功，arm64/iPhoneOS/iOS17+/Xcode26.6/SDK26.5/同源/hash均校验；[安装包](../../outputs/Stage06-2026-10-10/MomentsStudio.ipa)858693bytes，SHA256 e8a26edef8d5060ce6222abd0c7fae856ca0cf279cc25b747b882e3c74ec3f0d。成功构建不等于安装成功。
- 实际安装：未执行。AltServer安装菜单实际显示“No Connected Devices”；已请所有者用USB连接并解锁，等待设备识别，尚未选取IPA或出现Apple登录弹窗。
- 所有者三组反馈：未取得；只有本人明确反馈后才能 APPROVED。
- 原生失败记录与未验证限制如实保留；Stage07未授权。
