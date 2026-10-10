# Stage06 原生第三轮：CHANGES_REQUESTED

[run38026510813](https://github.com/Icatly/moments-studio/actions/runs/38026510813)，源`7c3f08d7230214fef3cbd1675ec734b70b025bc7`：真实Xcode26.6/SDK26.5设备与测试目标编译成功，arm64 iPhone17Pro/iOS26.5模拟器执行完整256，**252通过、4失败、0跳过、0预期失败**。245单元中242通过/3失败；11UI中10通过/1失败。旧186全部通过。

四失败均定位到新测试数据/读取的错误：包projectID与照片路径ID不一致；合法manual excluded被误期待抛错（注释automatic但未换source）；manual primary占位却期待另一automatic primary；原生Picker标签`Role, Primary photo`未去固定前缀。修复任务[FIX10](../tasks/STAGE-06-FIX-10-NATIVE-BEHAVIOR.md)保持生产契约和真实业务断言，自动角色刷新必须以有效fixture实际证明，不改expected成不刷新，不允许测试常量假通过。

原始私密证据 `.ai/build/stage06-run-38026510813-20261010-133711/evidence/`，archive 241484584bytes/SHA256`7b019c44c45fab960f436f3173561a7f60b9ef09381616e2dba2ca7aa2118566`。UI在首次主图选择后失败，后续保存/取消/重启/Focus末尾路径尚未执行，不能以旧测试通过外推这些行为。首二轮未执行XCTest，与本轮实际252/256分别记录。没有Stage06IPA/本人验收，Stage07未授权。
