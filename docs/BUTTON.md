# 第七批：鼠标按钮内部契约

状态：第七批 24 个新增用例及 141 个回归、真实鼠标交互与清理已通过，见 [验收记录](../tests/results/STAGE7.md)。第八批键盘激活及期限已通过，见 [KEYBOARD.md](KEYBOARD.md)。第九批宿主驱动 Application 已通过；第十批 run/step、统一入口和示例已准备，尚待整体验收。

`ocgui.button.new(options?)` 继承 Label 的文本和 Widget 的状态接口，默认 focusable=true、参与指针命中，构造不会修改调用者的选项。`isPressed()` 查询当前按下外观。默认按钮背景 0x333333、居中；焦点背景 0x335577、按下背景 0x557799，主题和本地样式仍按既有层次覆盖。禁用优先于按下与焦点。

按钮默认行为由 interaction 路由执行，直接调用纯 dispatcher 不会自动激活控件。左键 down 聚焦后捕获指针并设置按下，先于用户 down 回调。匹配 drag 在按钮为当前位置最上层命中者时显示按下，拖出则取消外观但保留捕获；拖回可以恢复。

匹配 up 先清除按下外观，再派发用户 up，之后释放捕获。只有原捕获仍有效、当前位置命中该按钮、节点可见启用、未移除或重挂接、交互未取消／关闭，才另行派发一次 click。click 保留释放事件的 source、player、button、screenX/Y 和 raw，按普通事件冒泡；不会重入尚未结束的 up 分发。返回 true 消费 up 只控制用户冒泡，不取消默认 click；显式 dispatcher:cancel 或 cancelAll 可以取消待发 click。

隐藏、禁用、移除、超时、停止及关闭均清除捕获和按下状态，不产生 click。右键、无对应 down 的 up、其他玩家／屏幕／按钮的释放不能激活。down/drag/up 用户回调错误会清除按钮捕获并传播原错误；click 回调抛错时捕获已释放。清理动作不会覆盖原始输入回调错误。

内部变化：Label 暴露 methods 供 Button 继承；Painter 绘制 button 文本；Dispatcher:dispatch 内部增加第二返回值 cancelled，第一返回值语义不变。Interaction 在用户回调前执行内置指针默认行为，并在释放分发后检查资格和取消标志。

没有新增原生方法。真实测试使用第五批输入归一化及第二批设备适配的既有 pull/uptime/GPU API；事件来源依据 [EVENTS.md](EVENTS.md) 中锁定 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 TextBuffer.mouseDown/mouseDrag/mouseUp。游戏内 OC 版本仍未独立核验；纯逻辑测试和人工外观不能相互代替。
