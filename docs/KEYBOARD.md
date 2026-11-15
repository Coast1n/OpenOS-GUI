# 第八批：按钮键盘激活

状态：第八批 26 个新用例、165 个回归及真实 Enter／空格交互、正常／异常清理已通过，见 [验收记录](../tests/results/STAGE8.md)。宿主驱动 Application 已通过第九批；run/step、统一入口与示例已准备，等待 [第十批整体验收](../tests/STAGE10.md)。

Interaction 路由在当前焦点为可见、启用的 Button 时，为主 Enter（28）与空格（57）的首次 key_down 创建一个键盘激活记录，设置按下外观，再派发用户 key_down。重复 key_down 不重新激活或延长期限。普通 Widget/Label 不获得按钮默认行为，小键盘 Enter 暂不激活。

激活记录保存节点挂接路径、键盘来源、玩家、键码和创建后 5 秒期限。只有来源、玩家、键码均相同的 key_up 可以结束该记录；先清除按下外观，再派发用户 key_up，之后清理记录。仍处于原焦点、原树路径有效、未取消或关闭时，另行派发一次 click，保留释放事件的 code/char/source/player/raw，不制造指针坐标。消费 key_up 不取消默认 click，显式 dispatcher:cancel 或 cancelAll 可以取消。

焦点离开、Tab 导航（即使绕回同一节点）、隐藏、禁用、移除、超时、尺寸变化、中断、关闭均取消激活而不 click。超时后保持原键仍按下的记录，必须先收到松开再重新按下；避免按键重复在超时后重新激活。nextTimeout 同时考虑指针或键盘期限，route(nil) 可以清除过期状态。

一个管理器同时至多有一个键盘激活或指针捕获。键盘不能抢占已有指针捕获；左键 down 先取消键盘激活，再按既有焦点与指针规则处理。手动 capturePointer 在键盘激活未过期时返回 false。鼠标释放与键盘释放互不替代，pressed 外观不会被不匹配的键盘松开错误清除。

down/up 回调错误会取消键盘激活，保留原错误；click 回调错误发生时记录已清理。close/cancelAll 尝试独立清理指针、键盘与焦点状态；第八批测试卡负责外层清理；第九批宿主驱动 Application 接入统一生命周期，尚待验收。

键码先查文档快照 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 `lua/libs/keyboard.lua` 中 keys.enter=0x1C、keys.space=0x39；原始信号仍沿用 [EVENTS.md](EVENTS.md) 查证的 Keyboard.onMessage，锁定 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c`。计时继续使用注入时钟及既有 uptime 适配，未新增原生 API。游戏 OC 版本仍未独立核验，不能以本地静态检查代替游戏内键盘验收。
