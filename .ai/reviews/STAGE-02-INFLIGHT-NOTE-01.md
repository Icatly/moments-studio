# Stage02 实现中检查记录 01

Architect，2026-10-03。当前仍IMPLEMENTING；本记录为已批准Stage02范围内的定位提醒，不代表完成最终Review，不开始下一阶段。

DSH继续IMPLEMENT01，并在交付前处理以下已观察到的问题：

1. `PhotoDerivativeRenderer.makeDerivatives`：`guard let thumbnail = thumbnail(...)`之后，下一行再调用`thumbnail(...)`会被同名局部CGImage遮蔽，存在类型检查失败。改局部名称或使用明确类型方法调用；不是语法解析能证明通过的问题。
2. 当前renderer直接写ImageIO产出的CGImage，没有8-bit sRGB转换。架构第5节要求派生图明确为8-bit sRGB SDR。只对受限大小派生图做CoreGraphics转换，保留alpha和方向；原始接收文件字节保持不变。不要实现额外HDR风格或滤镜。
3. 当前`decodeDerivative`允许长边达到`maxPixelSize * 2`，随后调用全尺寸`CGImageSourceCreateImageAtIndex`。不符合派生加载受限解码要求。改为使用实际role的320/2048上限执行ImageIO thumbnail解码，或严格拒绝超限派生文件；不能放大上限后解码。

保持已批准模型/接口和任务边界，补充能暴露上述风险的必要测试。Windows语法结果不得写成Xcode类型/运行成功。

进一步检查到的同范围风险（交付前处理）：

4. `PhotoLibrary` 目前只有读取派生文件时完整检查 symlink containment。写 manifest、创建/复制 asset、删除 asset 与恢复清理也必须验证最终路径在预期项目/asset 根内；恢复 manifest 的 project.id 必须等于所在项目文件夹 UUID。`cleanupUnreferencedAssets` 不得删除任意未知目录或文件，只能处理已确认属于当前有效 manifest 项目的 UUID asset 文件夹。未知/损坏 manifest 保留，不得借其 project.id 清理别的项目。增加越界 symlink、目录/project ID 不一致与未知文件保持测试。
5. `PhotoImportModel.removePhoto` 没有在 await 前设置 mutation busy 状态，两次移除或移除与新导入可从相同旧 snapshot 写 manifest，导致移除结果被覆盖。以现有单协调器显式串行保护全部 mutation（包括 restore 与 import），并让 UI 对应禁用。无需新增锁/调度器体系。
6. `runBatch` 在 importPhoto 已成功提交后用 `isBatchActive` 丢弃返回 package。取消恰好发生在 commit 之后会让磁盘已保存照片与 UI/store 脱节。当前项目/批次身份仍匹配时，已提交结果必须 apply；取消只阻止后续工作。不要 apply 到其他项目/新批次。增加能覆盖提交后取消和重复 mutation 的行为测试。
7. import 失败/取消后 stagedFileURL 未清理，只等下次启动会累积 100 MiB 级临时副本。已接收的自有 staging 文件在每项成功/失败/取消退出时都应有明确清理；清理必须走非 MainActor 的已有文件边界并检查归属，不能删 Photos 系统借用 URL。

8. `DerivedImageView` 仅 image=nil 时一直展示 ProgressView，缺失/解码失败会永久转圈。需最小 loading/loaded/failed 状态，明确不可读取照片占位（可重试），并保证旧 reference 的 late result 不覆盖新 reference。`PhotoPreviewSheet` 当前显示原始 UTI（public.jpeg 等）；用户界面用 JPEG/PNG/HEIC 或合适的人类可读文本。这些不是最终视觉设计。
9. 测试当前有 JPEG/PNG，但尚未见 HEIC 行为覆盖；按既有任务加入实际 ImageIO HEIC 合成与导入断言，不用格式常量镜像或无条件 skip 代替。
