# 第六批：标签、主题与绘制遍历

状态：第六批 30 个新增用例及 111 个回归通过，正常／预设异常真实屏幕模式各 12 个回读检查及状态恢复通过，用户视觉确认未发现异常，见 [验收记录](../tests/results/STAGE6.md)。第七批鼠标按钮绘制及实际输入已通过，第八批键盘状态也已通过，第九批生命周期也已通过，第十批整体流程等待 [验收](../tests/STAGE10.md)。

## 标签

`ocgui.label.new(options?)` 继承 Widget，新增字符串 text（默认空串）、`getText/setText`。非字符串直接报错；相同文本不失效，修改文本会失效祖先。文本原样存储，绘制时由已有 text/renderer 单行净化、按显示宽度对齐和截断。

Label 默认不可聚焦，且不接收指针命中，允许命中它覆盖的底层交互对象。显式 focusable=true 仍可用于焦点路由。标签自身整个矩形填背景，文字仅绘制在第一行；高度不会自动适应内容。

## 主题

`ocgui.theme.new(options?)` 复制主题数据，接受 widget、container、label、button 四种条目。每个条目支持 foreground/background（0 到 0xFFFFFF 的整数 RGB）、alignment（left/center/right），以及 disabled/focused/pressed 状态子表。状态子表只支持上述三个基础字段，不继续嵌套；未知字段、类型或颜色报错。

`resolve(kind, localStyle?, state?)` 返回新表。逐字段覆盖顺序为内置 Widget 默认值、应用 widget 条目、应用具体类型条目、本地 style。每一层先使用普通字段，再用当前状态的字段覆盖，因此本地普通字段也能覆盖应用的状态颜色。默认白色文字、黑色背景、左对齐；禁用前景默认 0x777777。不会继承父节点样式，仅继承可见和启用状态。

Widget 的通用 setStyle 仍允许保存其他数据；本绘制器只接受这里定义的样式字段，在绘制计划验证时报告不支持的字段。Label/Container 不自动产生 pressed 状态；第七批 Button 的鼠标行为已验收，第八批键盘行为也接入 pressed，已通过验收。

## 绘制

`ocgui.painter.new(root, renderer, themeOptions?)` 要求独立根 Container 与已有 renderer。`render(force?)` 在根失效时完整重绘，返回 true；无失效且未强制时不查询设备，返回 false。`setTheme(options?)` 先验证和复制，再替换并使根失效；不合法的新主题保留旧状态。

绘制时临时安装根的修改保护，阻止 setter、增删、订阅等通过现有保护入口修改树；拒绝递归绘制。先生成可见绘制计划并验证样式及坐标，再填充整个 viewport 的根背景，按父先子后、子节点插入顺序绘制。每个节点受全部祖先和 viewport 裁剪；完全不可见子树不提交绘图命令。容器和普通 Widget 填充背景，标签及第七批按钮再绘制文字。

状态优先级为 disabled、pressed、focused、普通；focused 从第五批 interaction 管理器读取。仅在 renderer 整帧成功后清除所有节点的 dirty（包括隐藏子树）。失败时根保持失效，恢复此前修改保护和绘制标志，保留原错误，允许之后全帧重试。失败后屏幕可能包含半帧，本层不负责设备恢复，后续 Application 负责生命周期。

本批测试卡会操作真实终端 GPU 并短暂等待按键或触摸，保存屏幕字符、颜色和状态恢复报告；人工外观结论与自动通过分开记录。第七批鼠标按钮与专用交互测试卡已验收，第八批键盘卡也已通过，第九批宿主驱动 Application 已通过，第十批独立循环、统一入口与示例已准备，尚待验证；用户自定义 draw 回调仍不在首版范围。原生文本行为沿用 [FOUNDATION.md](FOUNDATION.md)、[RENDERING.md](RENDERING.md) 已查证的 unicode 接口及锁定源码（OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 UnicodeAPI.initialize），未引入新原生组件调用；游戏内 OC 版本仍未独立核验。
