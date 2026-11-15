# 第二批：渲染与 OpenOS 设备适配

状态：**已由用户运行验收**，`stage2-run-003` 中 28 个模拟用例全部通过，正常及预设异常真实屏幕测试的回读、执行、清理、状态恢复均通过。详见 [第二批运行记录](../tests/results/STAGE2.md)。第三至第九批也已通过，当前停点为 [第十批整体验收](../tests/STAGE10.md)。

## Renderer 内部接口

`renderer.new(backend, unicode)` 构造对象。`renderer:frame(function(context) ... end)` 创建一次性绘制上下文，回调退出或出错后立即失效。禁止帧重入；出错后允许下一次新帧。此阶段仅实现绘制上下文，控件树的遍历在后续控件阶段接入。

| 上下文方法 | 语义 |
| --- | --- |
| `pushClip(x,y,width,height)` | 屏幕绝对坐标，与当前区域取交集；空区域也保留在栈中 |
| `popClip()` | 弹出一层，禁止弹出最底层 viewport；帧结束时必须平衡 |
| `fillRect(x,y,width,height,background)` | 按有效区域填充空格，颜色为 RGB |
| `drawText(x,y,text,foreground,background,width?,alignment?)` | 单行绘制，先按宽度对齐，再按当前区域裁剪 |

上下文提供只读约定的 `width/height`。颜色接受 0–0xFFFFFF 整数；低色深设备的实际颜色由 GPU 转换，不保证视觉上精确还原 RGB。每帧重新读取可见区域、重置颜色缓存；空区域不发送绘制或设色调用。调用者负责整帧背景填充，本层不启动循环、不管理 dirty 标志。

## OpenOS Backend 内部接口

`platform.new({gpu=可选代理}, services?)` 构造后不加载原生模块，`open()` 才获取设备与保存状态。`services` 仅供模拟测试注入，不是应用公开配置。

- `open/close` 返回 true 或 nil, error；close 幂等，关闭后不能重新打开。
- `getSize` 校验绑定屏幕及活动缓冲，返回当前 viewport，缺少 viewport 接口时退回 resolution。
- `getKeyboards` 返回绑定屏幕的键盘地址副本。
- `setForeground/setBackground/fill/set` 封装不带 self 参数的 GPU 代理调用；RGB 设色显式传 false。
- GPU 方法接受普通函数以及带函数 `__call` 的 Lua 表；必需方法与可选 viewport、活动缓冲接口使用一致的可调用性判断，不把组件回调表误判为缺失方法。
- `pull(timeout)` 延迟加载 event 并保留原始返回元组；`now()` 延迟加载 computer 并读取 uptime。
- 内部操作失败抛出 `{code,message}`，由后续 Application 统一捕获；GPU 通过 nil/false 返回的失败同样传播，包含 `device_error`，不会静默继续绘制。

打开时检查本库占用、保存原活动缓冲、切到屏幕 0、保存屏幕颜色及调色板标志，再保存当前终端光标并关闭闪烁。不支持非全屏本地终端区域；不改变绑定、分辨率、viewport、色深或调色板内容。

正常关闭先选择屏幕 0，恢复屏幕颜色并清理应用区域，再恢复原活动缓冲和光标。终端尺寸没变时原样恢复光标，保留 OpenOS 可能尚未滚屏的待处理光标位置；尺寸变化时才限制到可见区域。不会恢复运行前的屏幕文字。

部分启动失败时回滚但不清屏。清理步骤分别受保护，某一步失败也继续其他恢复并释放占用。检测到屏幕绑定改变时跳过该屏幕的设色和清屏，报告清理不完整，不写入新绑定屏幕。

## 源码依据

先查文档仓库 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 `lua/components/gpu.lua`、`lua/libs/term.lua`。以下源码来自 OpenComputers `1.13.1-GTNH`，commit `a313175a3cbf47f8642dd77838a2d4a56842677c`：

| 文件（相对锁定 OC 仓库） | 方法 | 依据 |
| --- | --- | --- |
| `src/main/scala/li/cil/oc/server/component/GraphicsCard.scala` | `getActiveBuffer/setActiveBuffer` | 屏幕为缓冲 0；切换返回原索引，0 也是成功结果 |
| 同上 | `getForeground/getBackground/setForeground/setBackground` | getter 返回颜色和调色板标志；RGB setter 显式传 false |
| 同上 | `set/fill` | 能量不足可返回 nil 与原因，必须处理失败 |
| 同上 | `get` | 返回单元格字符、前景/背景 RGB 及对应调色板索引，用于第二批屏幕文件回读 |
| `src/main/resources/assets/opencomputers/loot/openos/lib/tty.lua` | `gpu/getViewport/getCursor/setCursor` | 当前终端 GPU、区域和光标 |
| `src/main/resources/assets/opencomputers/loot/openos/lib/term.lua` | `getCursorBlink/setCursorBlink` | 保存及恢复闪烁设置 |
| `src/main/resources/assets/opencomputers/lua/machine.lua` | `componentCallback.__call`、`libcomponent.proxy` | 组件代理方法是带 `__call` 的表，不能只接受 `type(method) == "function"` |

游戏报告已确认 OpenOS 1.8.9、Lua 5.3；具体 OC 安装版本仍未知。第二批包含实际绘制和状态回读程序，以验证锁定源码推导在用户环境中的行为。

一键报告通过 OpenOS 的 `_OSVERSION` 读取系统版本；锁定源码 `src/main/resources/assets/opencomputers/loot/openos/lib/core/boot.lua` 中初始化此字段。不据此猜测实际 GTNH 或 OC 版本。报告与日志写入测试项目自己的结果目录，不改写库代码、系统配置或已有测试结果。

日志关闭依据同一锁定提交的 `src/main/resources/assets/opencomputers/loot/openos/lib/buffer.lua` 的 `flush/close` 以及 `src/main/scala/li/cil/oc/server/component/FileSystem.scala` 的 `close`：原生关闭成功可能没有返回值。报告器先显式 flush，再受保护地 close，不把无返回值误判为失败。
