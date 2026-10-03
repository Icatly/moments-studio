# Stage02 Architect Round17 — FIX08 limited source review

2026-10-04 03:57 Asia/Shanghai。DSH最终回复/停工已实际观察；READY_FOR_ARCHITECT_REVIEW。结论：源码限定修正接受，允许当前阶段真实macOS重跑；所有者PENDING，运行与视觉门禁仍未通过，Stage03禁止。

- 唯一Swift差异为完整UI测试中的只读预览证明（typed Image、30秒有界存在等待、有限非空frame且全在app.frame内）和typed Done/Remove按钮的enabled+hittable等待；loading消失、无missing/unavailable、info、真实Cancel/Remove、0/1计数与再次导入均保留。
- 一张完整App预览截图使用XCTAttachment、keepAlways，不设golden、不引入依赖。报告措辞已由Architect校正：目前只写入保留截图代码，尚无新运行截图，不能说已生成。
- 实际Windows检查：132对象/41文件引用/40Swift6554行/11字面UI查询解析；tree-sitter40文件0错误；所有85方法名相对e84b834保留；所有生产Swift逐字节与HEAD一致；git diff --check干净。
- Architect独立修改既有云工作流：仅附件导出移除--only-failures、同步步骤/告警说明，使成功用例的keepAlways截图可取得；保留旧failure-attachments目录名以连续追溯。xcodebuild测试命令、always原始证据、成功打包条件、macos15/免费构建权限/2天保留均不变。DSH没有改工作流。
- Run7实际性能补充：3×4000×3000 JPEG串行导入0.398秒（不含fixture创建），footprint39,607,040→39,852,800，resident216,399,872→216,629,248 bytes；不是峰值，不代表真机或真实照片。3条AppIntents无依赖元数据告警，未观察到Swift actor或编译器警告。

下一步只重跑85项并核对原生源码/结果/截图；视觉通过须实际看截图。若失败保留原始结果定位，不取消门禁。之后才更新Appetize正确新包并做iOS17.2必要复查；免费3分钟尚未消费。同会话重启/深色大字号/所有者验收尚待完成，精确17.0、真机、iPad/VoiceOver不宣称已测。
