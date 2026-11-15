# 第五批：焦点与指针捕获

状态：第五批 40 个新用例及 71 个回归已由用户运行通过，见 [验收记录](../tests/results/STAGE5.md)。第六批绘制也已通过，第七批鼠标按钮也已通过，第八批键盘激活也已通过，第九批生命周期也已通过，当前停点为 [第十批整体验收](../tests/STAGE10.md)。

## 构造与资源

`ocgui.interaction.new(root, dispatcher, clockFunction)` 接收独立根容器、该根的 dispatcher、单调时钟函数，不加载原生模块。构造只在根节点安装内部树变更钩子，串联原钩子并记录唯一管理者；同一根不能重复拥有管理者。`close()` 幂等，清理状态，尽力恢复原钩子与根节点归属，清理回调抛错也不会留下所有权。

## 焦点

Widget 新增 `focusable=false` 构造选项及 `setFocusable/isFocusable`。未来 Button 构造器将默认开启；当前只提供状态，不产生控件默认行为。管理器通过 `getFocus/setFocus/focusNext(reverse?)` 管理一个焦点。

- 焦点必须属于该根且沿祖先链可见、启用、可聚焦；显式请求不合格对象抛出编程错误。
- 焦点改变触发旧节点局部 blur、新节点局部 focus，附带 relatedTarget；不会向父节点冒泡。通知可调用 setter 或请求另一焦点，焦点转换以队列完成；循环转换超过 32 次会报错并清空焦点，避免无限循环。
- 隐藏、禁用、移除或取消可聚焦状态立即清除当前焦点。回调中使待聚焦对象失效时不再通知该对象 focus。
- 按树的前序顺序遍历，正向／反向均循环；跳过不可见、禁用及不可聚焦节点。左键命中可聚焦对象会先聚焦，背景左键清除焦点；其他按钮不改焦点。
- 焦点通知直接使用 Widget 的局部处理器快照，以允许普通事件回调内 setFocus，同时保留普通 dispatcher 的递归分发保护。

## 指针捕获与时间

`capturePointer(node, pointerDownEvent, onFinish?)` 创建单一捕获；已有捕获时返回 false。这里不自动为普通 Widget 捕获；第七批 Button 在默认 pointer_down 行为中调用，已通过验收。键盘激活存在时暂不接受捕获，参见 [KEYBOARD.md](KEYBOARD.md)。

- 元数据记录 source、player（包括 nil）、button，只有三者全部相同的 drag/up 才交给捕获对象；位置可以移出控件或屏幕边界。
- 匹配 up 分发完毕后清除捕获并调用 onFinish(node, "released")。分发错误时仍清除，原始分发错误优先传播。
- 隐藏、禁用、移除或祖先重挂接立即取消，reason 为 invalidated；过期为 timeout。取消不会制造 pointer_up 或 click。
- 期限为 5 秒不活动；匹配 drag 延长期限，其他来源的输入不延长。`expire()` 及 `nextTimeout(maxWait?)` 只调用注入时钟，不拉取事件、不启动后台 timer。
- onFinish 用于将来清理控件按下状态，每次捕获至多调用一次；即使它抛错，捕获也已清除。清理回调期间不允许开始新的捕获。
- `nextTimeout` 返回期限与调用者上限的较小值；没有捕获与上限时返回 nil。时钟必须有限、非负、单调。

## 输入路由与取消

`route(normalizedEvent?)` 接收第四批 input 已归一化的事件；它本身不做设备来源查询。指针交给捕获者或命中者，普通键盘与粘贴交给当前焦点。键盘按下集合按 source 分开；Tab/Shift+Tab 由管理器消费，重复 Tab 不重复切换。其他 key_down 携带 repeated 布尔字段，不改写调用者传入的表。

`route(nil)` 只检查失效与期限。screen_resized、interrupted 调用 `cancelAll(reason)`，清除焦点、捕获、按键集合并取消当前冒泡；取消与关闭不继续派发用户 focus/blur 通知。未来 Application 仍需处理真正的尺寸更新、停止循环与设备恢复。

`cancelAll/close` 会尝试独立清理项，避免一个捕获清理错误阻止状态释放。普通 route 拒绝重入，错误后恢复路由标志；focus 回调内 close 时不会继续派发后续目标事件。

## 来源与边界

先查文档快照 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 `lua/libs/keyboard.lua`：Tab=15、左/右 Shift=42/54；时间接口参照锁定 OC 源码 `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 `src/main/scala/li/cil/oc/server/machine/luac/ComputerAPI.scala` 的 initialize() 所注册的 uptime。此阶段实际使用注入时钟，不依赖未核验的游戏 OC 版本。

第六批标签、主题与绘制遍历已通过，第七批鼠标按钮 click 及真实输入已通过；第八批 Enter/Space 激活与键盘期限已通过；第九批宿主驱动 Application 已通过；第十批 run/step 与公开入口已准备，尚待整体验收。管理器的内部接口与根节点钩子不是稳定用户 API，纯测试不能替代后续实际交互验收。
