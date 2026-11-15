# 第十批：独立循环与公开入口

状态：第十批 32 个新用例、221 个回归、真实 run 流程及实际 basic 示例已通过，见 [验收记录](../tests/results/STAGE10.md)。当前版本保留 0.1.0-dev，未对外发布。

## step

`app:step(timeout?)` 要求 open，超时参数为有限非负数或 nil。先无参数 dispatch 推进交互期限；如已停止返回 false，如存在失效则立即绘制并返回活动状态，不拉取事件。否则计算等待上限，调用一次既有设备 pull，以 table.pack 保留返回的 nil，再交给 dispatch，仍活动时最多绘制一帧。

空闲且无期限时传 nil 等待，不主动轮询；有指针／键盘期限时不会等待超过期限。pull 超时也以无信号形式推进取消。收到 interrupted 或回调 stop 后不再分发后续输入、不绘制待发帧。未知信号只消费当前这一条，不重新入队。

step 拒绝重入；等待期间仍设置操作保护，event.pull 的既有外部监听器不能递归分发或关闭应用，但可以 stop。返回 true 表示仍活动，false 表示已停止；错误返回 nil, err 并标记停止，由宿主 close。普通 pull 异常归为 event_failed，已有结构化错误保留原 code；回调与绘制错误仍分别归为 callback_failed/render_failed。

## run

`app:run()` 只接受 created，负责 open → step 循环 → close。不接受已 open 的宿主应用，不接管其他正在运行的循环；回调内递归 run/step 被拒绝。打开失败、绘制失败、回调失败及等待失败均尝试关闭；正常 stop 返回 true。已有主错误优先保留，关闭失败附到 cleanupErrors；若只有关闭失败，返回 cleanup_failed。

直接 run 与宿主 open/dispatch/render 模式都可使用。宿主不要同时启动另一个事件消费者或在 run 的回调中再次驱动应用；控件 setter、setFocus/setTheme 和 stop 仍可在普通事件回调内调用。

## 统一入口与示例

`require("ocgui")` 返回 version、application、container、label、button。工厂函数使用点调用，对象方法使用冒号。加载不获取设备、不启动事件循环、不修改全局 require/package.path/package.loaded。内部 services 注入不暴露为公开选项。

`examples/basic.lua` 使用公开入口，创建计数标签、更新按钮和退出按钮，以 app:run 驱动。第一次键盘操作先 Tab 选中更新按钮，再 Enter／空格；再次 Tab 选中退出按钮。鼠标也可操作。运行／安装见 [INSTALL.md](INSTALL.md)。

项目测试加载器扩展支持主模块 ocgui，依旧使用独立缓存，不修改全局模块路径。真实循环测试只在测试侧包装设备等待，以回读首帧、设置初始焦点、限制 120 秒和注入异常信号；库自身没有测试期限或后台监听器。实际 basic 测试执行同一个示例文件，仅在外层观察有效更新并保证失败时清理。

事件消费沿用锁定文档快照 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 libs/event.lua，以及 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 OpenOS event.pull/pullFiltered；不注册新的 event.listen/timer。游戏内 OC 版本仍未独立核验。
