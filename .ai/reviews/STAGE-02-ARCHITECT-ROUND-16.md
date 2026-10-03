# Stage02 Architect Round16 — read-only preview assertion

2026-10-04 03:49 Asia/Shanghai。CHANGES_REQUIRED；所有者PENDING，Stage03禁止。

## 实际证据

Run7 https://github.com/Icatly/moments-studio/actions/runs/37148549701 (job111277399157)，source e84b834740ea52c477c0f57080e36cc0baa7b1d7；workflow8m26/job8m14。编译成功，80单元+4既有UI通过；完整流程第5UI仍失败，85总数/84通过/1失败/0跳过/0预期失败。

本地.ai/build/downloads/run-37148549701/保留test-summary.json/xcodebuild.log/Stage02.xcresult/failure-attachments/BBA7314A-FB29-4E7F-B227-35532026428D.txt。下载ZIP84,100,743bytes SHA256814bbb59422ddb78a6f43df549f30d5f95fc18e2b57e8e4876a3b3082b7e082b，与GitHub摘要前缀一致。

选择器精确查询成功，真实Photo→Add→导入1张→点缩略图→preview.info出现、missingPhoto不存在、加载指示器消失、unavailable不存在，均执行通过。失败在Stage02ImportUITests.swift:158：把只读preview.image的isHittable当作显示/加载断言。原生层级实际包含Image identifier preview.image，frame(16,166.3,370,555)位于402×874设备窗口内，info为360×540 PNG；Done/Remove实际Button同时还有同标识的Other包装层。

生产DerivedImageView的loaded(CGImage)分支才生成Image(decorative:).resizable().aspectRatio，loading是ProgressView、failed是unavailable控件。因此精准的app.images[preview.image]存在可以为loaded分支提供正证据；只查询任意包装层的存在不够。

## 判断/范围

本轮已运行到18.5预览且没有此前PhotoImportModel fatal；但没有像素截图，不宣称视觉通过或17.2崩溃已消失。isHittable测试的是可计算交互命中点（[Apple文档](https://developer.apple.com/documentation/xcuiautomation/xcuielement/ishittable)），只读图片不是点击动作。这里测试判据不符合产品要求；仍不能仅因exists或frame就证明像素可见，也不能声称已经确定Apple内部为何返回false。

授权FIX08：用正向限定Image查询+有界加载等待+有限非空且落在屏幕内的frame，保留missing/unavailable/加载消失等检查；保留一张keepAlways的完整预览截图供Architect实际审图。操作按钮以已观测的Button类型查询，仍进行真实点击/等待，不拿几何代替按钮可用性。其他全流程及85方法保持；不得生产添加交互、改图片或删/skip用例。

Architect将既有工作流附件导出改为导出所有保留附件，以便成功测试也能拿到截图；只移除--only-failures，保留raw xcresult/原有测试命令/失败状态/免费额度设置。DSH不得改工作流或运行账户。

17.2必要运行复查与同会话重启/深色大字仍待完成；Appetize3分钟暂停且未消耗。执行任务.ai/tasks/STAGE-02-ARCHITECT-FIX-08.md。
