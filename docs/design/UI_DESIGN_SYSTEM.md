# UI_DESIGN_SYSTEM.md

状态：**未定义（NOT_DEFINED）** — 最终视觉由项目所有者批准，DSH 不发明品牌风格。
本文件当前只记录「Stage 01 使用了什么」与「哪些决定还没做」，不是设计方案。

## 1. 当前实际使用（Stage 01 临时外壳）

代码位置：`MomentsStudio/MomentsStudio/DesignSystem/`。

| 类别 | 当前值 | 位置 |
| --- | --- | --- |
| 间距 | 4 / 8 / 16 / 24 pt | `Spacing` |
| 圆角 | 8 pt（仅用于近期项目列表的缩略图占位） | `Radius` |
| 颜色 | 系统语义色（`.primary` / `.secondary`）+ `AccentColor` 资源（浅色近黑、深色近白） | `Palette`、`Assets.xcassets/AccentColor.colorset` |
| 文本 | 系统文本样式：`headline` / `body` / `footnote`（自动支持 Dynamic Type） | `Typography` |
| 动效 | 一个列表更新动画：`easeOut 0.2s` | `Motion` |
| 布局 | 最小触控高度 44 pt | `Layout` |
| 组件 | 仅 `InfoRow`（标签/值行） | `InfoRow.swift` |

原则（来自既有基线，非新决策）：

- 使用系统字体、SF Symbols、语义颜色，自动适配浅色/深色模式与 Dynamic Type。
- 不使用自造配色、渐变、玻璃材质、大面积圆角卡片、装饰性动画。
- 用户照片是未来产品的第一视觉焦点；占位页刻意朴素，不模仿完成态。

## 2. 尚未决定（需项目所有者 / Design Reviewer 裁定）

- [ ] 品牌基调的具体表达（editorial / Instagram 感如何落到字体、间距、留白比例）。
- [ ] 主色与强调色（当前 `AccentColor` 只是中性占位）。
- [ ] 字体策略：是否引入自定义字体，还是坚持 SF 系统字体。
- [ ] 层级与分隔策略：卡片、分隔线、留白三者的主次关系。
- [ ] 动效规范：时长、曲线、触发条件，以及「减少动态效果」下的降级行为。
- [ ] 编辑器画布的视觉框架（工具栏、手势提示、选中态）。
- [ ] 空状态、加载态、错误态的统一表达。
- [ ] App 图标风格。
- [ ] 显示语言（当前界面为英文占位）。

## 3. 落地方式

最终系统确认后：

1. 在本文件写入正式规范（token 表 + 使用规则 + 反例）。
2. 替换 `DesignSystem/DesignTokens.swift` 的占位值，并按需增加组件文件。
3. 已按 token 编写的界面应只需改 token，不需要改视图逻辑；若需要大面积改视图，说明 Stage 01 的抽象不够，需要在报告的技术债中记录。
