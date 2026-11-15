# 第九批：宿主驱动的应用生命周期

状态：第九批宿主生命周期已通过，见 [验收记录](../tests/results/STAGE9.md)。第十批 run/step、统一入口及 basic 示例已准备，等待 [整体验收](../tests/STAGE10.md)；独立循环细节见 [LOOP.md](LOOP.md)。

`ocgui.application.new(options?, services?)` 构造 created 状态对象，仅接受 gpu、theme 选项。主题在构造时验证和复制；services 是内部测试注入入口，不属于公开选项。加载或构造不访问设备、不启动循环。app.root 是只读引用，初始 (1,1,1,1)，允许预先添加子控件；根尺寸、坐标和标志由应用管理。

`open()` 只接受 created；依次打开设备、读取实际尺寸和键盘、建立归一化／分发／交互／绘制模块，然后进入 open。部分失败也尝试关闭已建立的管理器和设备，进入 closed，保留原错误并附加清理错误；不能重新打开。GPU 占用与状态快照继续由第二批适配器管理。

宿主顺序为 open → render → isActive → nextTimeout → 宿主 pull → dispatch → render，最终保证 close。`dispatch(name, ...)` 接收原始信号，保留 nil 元组，不自行 pull。无参数只推进期限；未知和外来来源返回 false；false 表示未消费而不是失败。每次分发／绘制先核对屏幕尺寸与设备状态，尺寸变化取消交互并刷新根；组件变化刷新键盘集合，键盘拓扑变化还取消交互以免保留旧按下状态；显示设备移除或解绑停止应用。

`render()` 在根失效时整帧绘制，否则成功返回 true 而不绘图。`nextTimeout(maxWait?)` 返回调用者上限与当前输入期限的较小值：有待绘制修改时为 0，无上限和期限时为 nil。查询不派发事件、不取消过期交互；到期后由 dispatch() 推进。非 open 或已停止时为 0，参数必须有限、非负。若时钟查询本身失败，可返回 nil, err 并停止，调用者必须检查第二返回值。

`stop()` 可在回调调用，幂等取消焦点、指针和键盘激活，阻止本轮待发 click；created/closed 时调用属于用法错误。停止后 dispatch 返回 false，render 不再绘制，宿主负责 close。`isActive()` 为 open 且未停止。`setFocus` 要求活动应用并沿用焦点合法性检查；`setTheme` 可在 created/open 验证、复制并失效，closed 时抛错。

回调内可修改控件、焦点、主题及请求 stop；禁止递归 open/run/step/dispatch/render/close，返回 nil, invalid_state。绘制中的属性修改仍由 Painter 的根保护阻止。

运行方法错误返回 nil, err，err 含 code/message/traceback，可附 cleanupErrors。保留已有结构化设备错误；普通用户回调为 callback_failed、普通绘制错误为 render_failed。运行失败即标记停止，取消交互；宿主须最终 close。错误后的 dispatch/render 保留原错误，避免继续执行。构造、树操作及属性参数错误直接抛出。

`close()` 可以在 created 直接调用、正常打开后调用或错误后调用；重复关闭返回 true。管理器与设备分别尽力清理，失败仍进入 closed 并释放占用；结果 nil, cleanup_failed 列出未完成项。宿主应将清理错误附到先前操作错误，避免覆盖最初原因。

没有新增原生调用：设备适配继续使用既有 getSize/getKeyboards、GPU 状态快照、pull 与 uptime。文档依据为快照 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 libs/event.lua；源码沿用 [PLAN.md](PLAN.md) 锁定 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 OpenOS event.pull、GraphicsCard 与 tty 接口。实际 OC 版本仍未独立核验。
