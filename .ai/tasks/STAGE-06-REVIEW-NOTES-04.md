# Stage06 实现中独立Review补正04 — Swift类型编译准备

Architect读目前新源码/新测试，仅静态发现，尚未原生运行：

1. PhotoRoleAnalyzer `VNClassifyImageRequest.supportedIdentifiers`不能当class属性：Apple Swift签名是实例`func supportedIdentifiers() throws -> [String]`，应创建并配置该request revision后调用，真实异常不能伪造词表。纯scene降减函数接收实际supported集合/测试注入集合，策略测试不要依赖某个SDK恰好支持landscape等标签。
2. `request.supportedRevisions`不能当VNRequest实例属性：这是class var。用实际具体request类型的supportedRevisions或type(of: request)动态class属性（核真实类型）来配置；不要Windows平衡括号/语法解析当类型检查。观测revision Int已批准。
3. 新Stage06RoleStorageTests多处`XCTAssertEqual(await model.saveRoleChoices(...), .saved)`：XCTest断言autoclosure不支持async。先await到局部真实outcome再assert；检查所有新增测试类似await/autoclosure/actor隔离/类型重名/私有helper与既有XCTestCase扩展冲突，不改变断言或跳过。`guard let`不能绑定非Optional的roleSnapshot字典，UI已改期望快照时也检查所有新调用。

尚在实施的Automatic UI补正03仍须完成：当前getter/candidates依然fallback保存角色，不能用注释或测试helper代替真实交互修复。请继续完整交付而非只报静态清单通过。

原生依据：[supportedIdentifiers](https://developer.apple.com/documentation/vision/vnclassifyimagerequest/supportedidentifiers())、[supportedRevisions](https://developer.apple.com/documentation/vision/vnrequest/supportedrevisions)。
