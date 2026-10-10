# Stage06 FIX07 — 自动来源的Picker仍显示旧角色

12:19实见FIX06交付idle56%，IO强制失败/实际布局边界/UI主位transform已补。此次仅一个实际用户行为缺陷与报告一句更正，仍Stage06，不扩大架构/契约。

当前PhotoRolesSheet.pickerBinding.get和displayedRole在absent时不分source返回captured.role。复现：之前Save接受A automatic primary→重开选B manual primary；policy现在给A supporting，Save也将存A supporting，但A的Picker还显示Primary、B也显示Primary，界面与将保存的选择矛盾。Analyze again改变自动建议时也仍显示旧Primary；失败时displayedRole把旧automatic称为“Kept your choice”。

批准最小表示：人工角色才作为Picker明确四角色的当前选择；未触碰的captured automatic和未保存默认以及explicit Automatic的Picker都显示Automatic，旁边实际建议显示这次生成的角色，历史已存来源可另行说明。untouched captured manual保持其角色；explicit manual保持新角色；auto绝不被显示为人工选择。suggestedLine也不能把已存manual所强制的policy role声称device suggestion。保留Save派生/快照/持久化全部现有语义，仅修实际UI来源表示；不改旧测试。

用UI真实调用的同一纯取值函数补有逻辑回归（captured automatic primary+另一个manual primary后，只后者Picker Primary；capturedmanual保留；explicitautomatic还原；同角色改manual可Save），不要复制算法假测。实际来源与建议文案保持准确；所有非人工分支有真实当前建议/失败反馈。新测试方法按真实数量更新仅Stage06 workflow/env/报告/README，执行结构/真实manifest；报告§0.0第1项目前仍写XCTSkip，与当前throw失败代码矛盾，请更正，不改已正确的测试去配报告。

其余FIX06范围保持，只做本地修复停Review；禁止push/dispatch/Stage07。当前56%未到70%，仍同工作区。
