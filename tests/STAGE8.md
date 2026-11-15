# 第八批：按钮键盘激活

批次 STAGE8-AUTO-001、STAGE8-KEYBOARD-001、STAGE8-SCREEN-002。**已通过复测、真实键盘交互与视觉验收。** 详见 [第八批运行记录](results/STAGE8.md)。当前入口为 [第九批测试](STAGE9.md)，以下保留本批历史操作说明。

本次只需重新同步 `tests/stage8-screen.lua`，再执行下面的一键命令。真实键盘操作和预设异常清理仍需完成，新结果自动保存到 stage8-run-002 或后续目录。

同步最新完整 OpenOS-GUI 到游戏电脑 `/home/OpenOS-GUI`，保留已有结果。本批主要修改 interaction.lua（焦点、期限与键盘默认行为）；新增 stage8.lua、stage8-screen.lua、run-stage8.lua。沿用此前模块及 stage3–7.lua 等测试依赖。

```sh
lua /home/OpenOS-GUI/tests/run-stage8.lua /home/OpenOS-GUI
```

先运行 35、36、40、30、24 个回归组，再运行 26 个键盘新用例，共 **191 项逻辑／模拟检查**。任何阶段失败即停止。随后在至少 50×18 的本地全屏终端显示真实键盘卡，最多等待 120 秒：

1. 初始焦点在 PRESS KEYS。按下并松开主键盘 Enter，确认 Clicks 增加一次。
2. 按下并松开空格，确认再增加一次。也可短暂按住，观察只显示按下外观、不连续计数；超过 5 秒将取消本次按下，不计数。
3. 按 Tab 将焦点切到 FINISH，再按下并松开 Enter 结束。必须先让 PRESS KEYS 分别完成 Enter 和空格激活；鼠标点击不能替代本批键盘验收。

正常模式记录归一化输入、有效键盘激活计数、Enter／空格分别完成标记与最终计数字符回读，检查无遗留按下／捕获。然后自动执行预设异常模式，无需再次操作。两种模式都验证管理器清理、设备清理和状态恢复。按下和焦点颜色、Tab 切换及文字外观请人工观察，自动通过与人工结论分开记录。

预期显示 STAGE8 AUTOMATIC RESULT: PASSED，结果在 `/home/OpenOS-GUI/tests/results/stage8-run-NNN`，包括 report.json、六个逻辑阶段日志、normal/exception.log 和对应 *-screen.json。中断或调整尺寸会结束测试并尝试清理；结束会清屏，不恢复原终端文字，不改变分辨率、色深或绑定。

26 个新用例覆盖 Enter／空格、重复按键、来源／玩家／键码匹配、焦点和树变更取消、期限计算、超时后重新按下、鼠标键盘互斥、停止关闭、回调错误、消费／取消、原始输入、click 冒泡与 Tab 取消。暂不提供小键盘 Enter 激活，第九批宿主驱动 Application 已准备，尚待验收；run/step 和公开入口未实现。开发端没有本地 Lua，本批通过依据为用户游戏内报告及人工确认，已归档。
