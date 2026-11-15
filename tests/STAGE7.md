# 第七批：鼠标按钮

批次 STAGE7-AUTO-001、STAGE7-BUTTON-002、STAGE7-SCREEN-001。**已通过复测、真实交互与视觉验收。** 详见 [第七批运行记录](results/STAGE7.md)。当前入口为 [第八批测试](STAGE8.md)，下文保留历史操作说明。

本次修复只更新 `tests/stage7.lua`。若已同步上一版全部第七批文件，只需重新同步此文件，再执行下方一键命令；新结果会使用 stage7-run-002 或之后的新目录。首轮尚未进入真实屏幕阶段，复测通过逻辑检查后仍需完成下面的点击操作。

同步最新完整 OpenOS-GUI 到游戏电脑 `/home/OpenOS-GUI`，保留已有结果。本批新增 button.lua、stage7.lua、stage7-screen.lua、run-stage7.lua，并修改 label、theme、painter、interaction、dispatcher；请同步所有 lib 文件与测试依赖。

```sh
lua /home/OpenOS-GUI/tests/run-stage7.lua /home/OpenOS-GUI
```

先运行 35、36、40、30 个回归组及 24 个按钮新用例，总计 **165 项逻辑／模拟检查**。任何阶段失败则停止。然后在至少 50×18 的本地全屏终端显示真实交互卡：

1. 可先在 CLICK ME 内按下，拖到按钮外释放，确认 Clicks 不增加。
2. 正常点击 CLICK ME，确认 Clicks 增加；可拖出再拖回内部释放，确认只增加一次。
3. 点击 FINISH 结束。程序要求至少一次 CLICK ME 成功点击，最长等待 120 秒；键盘不能代替此项点击。接着自动执行预设异常模式，不需要再次操作。

真实模式保存初始标题和两个按钮的 3 项回读检查、最多 80 条归一化输入、点击计数及最终计数字符回读，并验证无遗留捕获／按下状态，以及正常／异常退出时的管理器清理和设备状态恢复。按下／焦点背景、按钮文字对齐和拖出／拖回外观请人工观察。自动通过与外观结论分别记录。

测试结束清屏，不恢复原终端文字；不改分辨率、色深或屏幕绑定。中断或调整屏幕尺寸会结束测试并尝试清理。预期最终显示 STAGE7 AUTOMATIC RESULT: PASSED，报告保存到 `/home/OpenOS-GUI/tests/results/stage7-run-NNN`，包括 report.json、各阶段日志、normal-screen.json、exception-screen.json。完成后回复结果和视觉情况即可。

24 个新用例覆盖按钮构造、默认行为顺序、内外释放、拖出拖回、输入来源隔离、遮挡、失效与超时取消、回调异常、事件消费／取消、click 冒泡、原始输入保存，以及按钮状态绘制。本批验收未覆盖 Enter/Space 键盘激活及期限（第八批已准备），仍无正式 Application 或公开入口；真实卡的短循环仅用于测试。开发端没有 Lua 5.3；本批通过依据为用户运行报告及人工确认，已归档。
