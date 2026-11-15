# 公开 API 草案

本文件描述首版接口。前十批及首版最小范围已通过本环境验收，见 [第十批记录](../tests/results/STAGE10.md)。当前版本保留 0.1.0-dev，未对外发布。生命周期见 [APPLICATION.md](APPLICATION.md)，循环见 [LOOP.md](LOOP.md)，安装见 [INSTALL.md](INSTALL.md)。

## 构造与基础属性

| 接口 | 返回值 | 说明 |
| --- | --- | --- |
| `gui.application(options?)` | Application | 只建对象，不访问设备 |
| `gui.container(options?)` | Container | 无装饰容器 |
| `gui.label(options?)` | Label | 单行文本 |
| `gui.button(options?)` | Button | 可点击、可键盘激活的单行按钮 |

Widget 共有选项：`x=1`、`y=1`、`width=1`、`height=1`、`visible=true`、`enabled=true`、`focusable=false`、`style={}`。尺寸须显式适配内容，首版不自动撑开。Label/Button 另有 `text=""`；Label 默认不可聚焦，Button 默认可聚焦。应用 `options` 仅包含可选 `gpu` 和 `theme`；传入无效参数时抛出明确的 Lua 参数错误。

`gui.version` 当前为 "0.1.0-dev"，表示已通过本环境验收、尚未对外发布的开发版本。

## Application

`app.root` 是公开、只读引用的根 Container，根坐标固定为 `(1,1)`，尺寸由设备决定。它在构造时已存在，可在 open 前添加控件；此时尺寸暂为 `(1,1)`，不代表探测到的屏幕尺寸。`open()` 成功后才能读取实际区域。

| 方法 | 返回值 | 说明 |
| --- | --- | --- |
| `app:open()` | `true` 或 `nil, err` | created -> open；失败会清理并进入 closed |
| `app:run()` | `true` 或 `nil, err` | 只接受 created；独立运行并保证尝试 close |
| `app:step(timeout?)` | `active` 或 `nil, err` | 必须 open；有待绘制修改时立即绘制返回，否则拉取至多一条信号；超时为非负秒数，nil 表示无调用者期限；false 表示已请求停止 |
| `app:dispatch(name, ...)` | `handled` 或 `nil, err` | 必须 open；handled 是布尔值，false 不表示错误 |
| `app:nextTimeout(maxWait?)` | 非负秒数或 nil；失败 nil, err | 纯查询；返回本地期限与调用者上限的较小值，均无则为 nil；非 open 或已停止时为 0 |
| `app:render()` | `true` 或 `nil, err` | 必须 open；无失效时成功但不绘制 |
| `app:stop()` | 无 | 幂等请求停止；可用于回调，created 时调用属于用法错误 |
| `app:isActive()` | boolean | 纯查询；open 且没有停止请求时为 true |
| `app:close()` | `true` 或 `nil, err` | 幂等；created 也可直接关闭；失败仍释放本库占用 |
| `app:setFocus(widgetOrNil)` | 无 | 设置焦点或清除；目标必须在应用内且可见、启用、可聚焦 |
| `app:setTheme(theme)` | 无 | 复制主题并触发全量失效 |

stop 后本轮不再派发新事件或执行待触发的 click；run 在安全点退出并关闭。宿主驱动调用者收到 step 的 false 或运行错误后应 close，不能继续派发输入。`dispatch()` 无参数时只推进本地期限并返回 false，不拉取信号；已请求停止后 dispatch 同样返回 false，不再触发处理器。宿主可用 `app:isActive()` 读取是否处于 open 且未请求停止，其他状态均为 false。

生命周期状态错误和设备/回调错误统一通过生命周期方法返回 `nil, err`；构造、属性 setter、树结构和焦点参数不合法属于编程错误，直接抛出。`err` 为 `{code, message, traceback?, cleanupErrors?}`。代码至少区分 `invalid_state`、`device_unavailable`、`device_busy`、`device_lost`、`callback_failed`、`render_failed`、`cleanup_failed`，等待信号时的普通异常为 `event_failed`。清理错误附加到原错误，不覆盖最初原因。

## Widget / Container

以下 setter 返回 self，便于链式调用。只能通过公开方法修改控件状态。

| 方法 | 适用对象 | 语义 |
| --- | --- | --- |
| `widget:setBounds(x,y,width,height)` | 全部，根节点除外 | 更新边界并失效 |
| `widget:getBounds()` | 全部 | 返回四个值，相对父节点 |
| `widget:setVisible(value)` | 全部，根节点除外 | 隐藏时取消子树焦点与捕获 |
| `widget:setEnabled(value)` | 全部，根节点除外 | 禁用时取消子树焦点与捕获 |
| `widget:setFocusable(value)` / `widget:isFocusable()` | 全部 | 设置或读取自身可聚焦属性；false 取消当前焦点 |
| `widget:setStyle(style)` | 全部 | 复制并替换本地样式覆盖 |
| `widget:invalidate()` | 全部 | 标记需要重绘；未挂接时仅保存本地标记 |
| `widget:on(name, handler)` | 全部 | 返回退订函数，不返回 self |
| `container:add(child)` | Container | 返回 child；禁止重复、环及已有父节点 |
| `container:remove(child)` | Container | 返回移除的 child；不存在时返回 nil |
| `label:getText()` | Label | 返回原始字符串 |
| `label:setText(value)` / `button:setText(value)` | 对应控件 | 更新文本并失效，返回 self |

`on()` 同名处理器按注册顺序调用；返回 true 即消费。退订函数可重复调用。处理器列表取分发时快照，新注册者不接收当前事件，被退订者不再执行。控件自带默认行为先于用户处理器，返回值只控制用户处理器链及向父节点冒泡。

主题首版字段为 `background`、`foreground` 和 `label/button` 的状态样式；颜色使用 RGB 整数。完整字段随控件实现补充，不允许控件任意修改 GPU 调色板。

## GUI 事件对象

所有处理器形式为 `function(widget, event)`。公共字段包括 `type`、`target`、`currentTarget`、`raw`；指针事件另有屏幕坐标 `screenX/screenY` 和当前接收控件局部坐标 `x/y`，以及 `source/player/button/delta`。键盘事件含 `source/player/char/code`。`raw` 使用 `table.pack` 保留原始参数及 nil。

可订阅：`pointer_down`、`pointer_drag`、`pointer_up`、`scroll`、`key_down`、`key_up`、`text_paste`、`focus`、`blur`、`click`。focus/blur 只通知对应控件，不冒泡；其他事件从目标冒泡。click 是按钮合成事件，仅在合法释放时产生；target 为按钮，保留触发的原始输入。事件对象只在当前处理期间有效，需留存时自行复制数据。

处理器内部允许 setter、add/remove、setFocus 和 stop；禁止调用事件循环或直接绘制。监听业务组件事件由宿主负责，不向控件塞入设备控制逻辑。

## 使用草案

以下只用于评审 API，不是当前可运行示例。

```lua
local gui = require("ocgui")
local app = gui.application()

local label = app.root:add(gui.label {
  x = 3, y = 2, width = 24, height = 1,
  text = "OpenOS GUI"
})

local button = app.root:add(gui.button {
  x = 3, y = 4, width = 16, height = 1,
  text = "点击更新"
})
button:on("click", function()
  label:setText("按钮已点击")
  return true
end)

local quit = app.root:add(gui.button {
  x = 3, y = 6, width = 16, height = 1,
  text = "退出"
})
quit:on("click", function()
  app:stop()
  return true
end)

local ok, err = app:run()
if not ok then
  io.stderr:write(err.message .. "\n")
end
```

宿主驱动的顺序为：构造并添加控件 -> open -> render 首帧 -> 检查 isActive -> 用 nextTimeout 计算等待时间 -> 宿主 pull 原始信号 -> dispatch -> render -> 最终 close。nextTimeout 可接收宿主自己的等待上限，避免阻塞其他业务期限；pull 超时后调用无参数 dispatch 以取消过期交互。此模式不调用 step，不需要固定频率轮询。宿主须以受保护调用保证最终 close；生命周期细节见 APPLICATION.md，独立程序可直接使用 examples/basic.lua 的 run 写法。
