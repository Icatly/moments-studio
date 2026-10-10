# Stage06 FIX06 — FIX05交付后剩余实际缺口

真实DSH 12:00交付停READY_FOR_ARCHITECT_REVIEW，50%上下文。Architect独立结构校验/Swift语法/冻结旧186源与4workflow/真实workflow manifest执行通过：233unit+11UI=244，仅编码方法数，无Xcode或XCTest。初轮主要角色保存/来源/清空/主图替换/签名已修。当前CHANGES_REQUESTED，以下仍是已批准FIX05 C8/C7，不新扩大。

1. **报告称有而实际没有的IO失败回滚。**`Stage06RoleStorageTests`14方法无任何真实写失败，impossible draft拒绝不是IO失败。沿用已有Stage03/04/05实际macOS文件系统失败办法，验证role Save→saveFailed、先前manifest bytes/store役角色/document unchanged、实际草稿不丢且retry或Cancel；不用生产测试开关/假IO错误/仅常量测试。不改旧测试。

   核生产顺序：角色Save先loadPackage，所以Stage04的manifest symlink办法会在load被路径守卫拒绝成projectMissing，而非真实写失败；不能照抄错误路径。使用能保留合法读取、仅令原子写失败的真实macOS目录权限/文件系统条件，defer恢复权限后再retry，保留路径守卫。不要放宽guard或把缺项目改为假IO失败。

   不可`try? makeUnwritableAndProbe`加`if blocked==true`绕过失败断言而把测试标绿；workflow只在macOS执行，若无法制造真实阻断应明确XCTFail，不静默no-op，也不XCTSkip。用throws＋guard失败即fail，确保必经saveFailed/rollback，再恢复retry。未执行Windows失败路径不能宣称已验证。
2. **直接布局覆盖不足。**`Stage06RolePolicyTests`只有1个arrangeFocus，其余仅arrangementOrder/participating helper。补实际CollageLayout.arrange：nil旧算法输出不受角色改变；Grid/Offset有主图仍原计算序；空画布只添加primary/supporting而不是collage/excluded；已有collage/excluded层完整transform不动，locked/hidden完整层不动，stored ID/z/baseSize/opacity保持；多层同asset两个均可编辑时仅首层占Focus主位；repeat Apply仍稳定。用确定几何/已有Stage04真实断言方式，必要新测试文件正确工程接线，别新增镜像常量测试。
3. **实际无 eligible 反馈。**`CollageLayout`仍在所有照片为collage/excluded时抛noPhotos并提示Import，用户已经有照片。已有noPhotos无照片路径保持，批准范围内加实际角色无可用照片错误/可理解建议调整角色；直接测试。已有空画布/照片不得删除或假加层。
4. **UI主位断言仍未实现。**最新`Stage06PhotoRolesUITests`最后保存第二导入为主图，但Focus两次只核IDs/count，文件中无读editor.layerTransform或任何geometry比较；注释却声称real transforms。用真正selectLayer按钮对应asset的稳定IDs和已有可见layerTransform文本读出两个层实际位置/scale，证明第二导入主图进入Focus主位且两次结果保持，不依赖UUID排序。依现有root算法，空canvas创建layerID=photo.id。不新增隐藏测试开关、不修改旧UI断言或skip；macOS上未知AX形态仍交实际run查。
5. **报告真实性。**删“244/235混写”、手机仍Stage03包等错误（手机实际是owner已验收Stage04/05 sourcefe17）。按当前最终真实方法清单重新更新workflows env/manifest及报告hash，先编码后再报告已完成。关于IO/布局/UI新覆盖要指向真实方法和断言；不能以注释和计划当实现。Windows未执行Xcode事实保留。新pure helper/actor/async assertion/所有生产与测试签名再自核。

12:13实现中实读新增测试的明确问题：`testNilRolesKeepTheFrozenStage04Arrangement`里的fixture(width:height:)实际fixture目前无这两个参数，必须保持同一真实签名调用；`CanvasGeometry.addingLayer`不存在，该方法属于同文件里的`CanvasEditor`，新测试必须用真实API，不改生产签名迎合虚构调用；Focus计算主位不改stored layers顺序，因此photos[first,second]输出storedIDs仍[first,second]，不能断言[second,first]，主位应比较transform；makeUnwritableAndProbe仍出现XCTSkip，不得用skip（含unsupported-host no-op）绕过必须执行的写失败测试。这些为当前新测试源码发现，非原生已运行失败，最终交付前逐一消除。

只本地实施，DSH完成上述最小剩余修复并执行结构/真实manifest后停Review。禁止push/dispatch/付费/Stage07。上下文到70%先保存handoff，再同工作区新上下文；目前50%可继续。
