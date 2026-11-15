# 第四批：输入与事件分发基础

状态：第四批 36 个新用例及 35 个树回归已由用户运行通过，见 [验收记录](../tests/results/STAGE4.md)。第五批焦点与捕获已通过验收，见 [INTERACTION.md](INTERACTION.md)；第六批绘制已通过，第七批鼠标按钮已通过，第八批键盘激活已通过，第九批生命周期也已通过，当前第十批整体验收尚待运行。

## 输入归一化

`ocgui.input.new(screenAddress, keyboardAddresses?)` 保存源屏幕及键盘地址副本；`setKeyboards(addressArray)` 在验证完整数组后替换集合。它不自行查询设备。

`normalize(...)` 处理调用方已取得的信号，用 table.pack 保存完整原始参数；未知、超时、其他屏幕或键盘，以及格式错误的已知信号返回 nil。

| 原始信号 | 结果 type | 主要字段 |
| --- | --- | --- |
| touch / drag / drop | pointer_down / pointer_drag / pointer_up | source、screenX/Y、button、player |
| scroll | scroll | source、screenX/Y、delta、player |
| key_down / key_up | 原名称 | source、char、code、player |
| clipboard | text_paste | source、text、player |
| screen_resized | screen_resized | source、width、height |
| interrupted | interrupted | raw |

坐标用 math.ceil 变成整数，不将字节字符转成文本；玩家名缺失时保持 nil。此阶段没有记录修饰键或按下状态。组件变化后的键盘集合刷新、尺寸更新及 interrupted 停止由未来 Application 处理，当前模块只返回数据。

## 订阅与冒泡

Widget `on(name, function(widget,event) ... end)` 返回幂等退订函数；同名处理器按注册顺序执行，仅精确返回 true 才消费。可订阅 pointer_down、pointer_drag、pointer_up、scroll、key_down、key_up、text_paste、focus、blur、click。订阅不绘图、不自动失效；绘制期修改保护钩子也保护订阅和有效退订。

内部 `ocgui.dispatcher.new(rootContainer)` 要求独立根容器。`dispatch(target, normalizedEvent)` 将事件从目标向根冒泡；`dispatchPointer(event)` 先通过根节点命中；返回是否被处理器消费。`cancel()` 仅取消当前分发的剩余处理，不代表应用停止或永久禁用输入。

- 全路径及所有节点处理器在分发开始时快照；新增订阅和新插入节点不接收当前事件，已退订的处理器立即跳过。
- 每个节点处理前更新 currentTarget 和局部 x/y；target 保持原目标，raw 保留原始元组。事件字段供回调只读使用，调用方原始归一化表不被写入。
- 每个处理器执行前检查节点及祖先的父关系、挂接版本、可见和启用状态；脱离再挂回原位也不恢复当前事件的旧路径资格。
- 目标在回调中被移除时，该目标的剩余处理器停止；原路径中仍有效的祖先继续收到冒泡。新父节点不加入当前路径。
- 禁用上层节点仍由命中层阻挡下层；分发器不向禁用节点调用用户处理器。
- focus/blur 只通知目标；自动焦点切换由第五批 interaction 管理；click 可以作为合成通知分发，未实现按钮产生 click 的逻辑。
- 拒绝递归分发；回调错误原样抛出，并释放分发标志，让未来 Application 决定停止及清理策略。

内部 `_snapshotHandlers/_emit` 及 `_attachmentVersion` 不属于稳定公开 API。焦点、捕获与期限管理已通过第五批验证；标签、主题与绘制遍历已通过第六批；第七批鼠标按钮默认行为已通过；第八批键盘激活已通过；第九批宿主驱动 Application 已通过，第十批 run/step、公开入口与 basic 示例已准备，尚待整体验收。

## 源码依据

先查文档仓库 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 `lua/libs/event.lua`。信号参数参照锁定 OC 提交 `a313175a3cbf47f8642dd77838a2d4a56842677c`：

- `src/main/scala/li/cil/oc/common/component/TextBuffer.scala` 的 `sendMouseEvent`、mouseDown/Drag/Up/Scroll，说明 touch/drag/drop/scroll 的坐标、按钮／delta 及可选用户名。
- `src/main/scala/li/cil/oc/server/component/Keyboard.scala` 的 onMessage，说明 key_down/up 与 clipboard 的字段及可选用户名。

实际游戏报告确认 OpenOS 1.8.9、Lua 5.3，OC 安装版本尚未独立核实。合成信号测试通过也不能替代后续真实输入测试。
