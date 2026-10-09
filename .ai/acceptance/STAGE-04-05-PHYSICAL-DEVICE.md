# Stage04/05 真机验收

状态WAITING_FOR_USER；新包源码`fe17ac0d00db53629228f3ff972b5b83d563b551`，[186项原生测试](https://github.com/Icatly/moments-studio/actions/runs/37969910797)通过、[同源设备包](https://github.com/Icatly/moments-studio/actions/runs/37973412193)已校验。尚未签名安装和本人验收，不以Stage03手机包代替。

安装时使用此前同一Apple账户，在本机完成凭据/验证码；保留App和项目，先核旧照片仍在。

1. 创建测试项目，导入至少两张不同的照片，打开编辑器Layouts。Grid/Focus/Offset三方向均能看到自己的照片，构图不同；搜“网格”或“Offset”能筛选，清空后恢复三项。
2. 仅浏览、选择后Cancel，回编辑器检查未新增层或保存新布局；再打开选布局Apply，回编辑器可继续移动/缩放/旋转。
3. 重复Apply，Layers数量不增加。已有锁定/隐藏层保持原状态；Done回首页及结束App重开后，布局和照片保留。
4. 打开Photo summary，照片分别出现尺寸与明确为估计的光色结果；原照片、层数、位置、锁定/隐藏保持。不同照片可以同一分类，不要求算法人为制造差异。
5. Analyze again后关闭，再打开或切换项目，结果对应当前照片，无旧项目结果混入；Done和保存重开正常。

按两阶段分别反馈做了什么、实际结果与问题；只有本人明确通过才APPROVED。该包尚不提供AI自适应滤镜、多页整组生成或保存相册。
