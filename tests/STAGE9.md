# 第九批：宿主驱动的应用生命周期

批次 STAGE9-AUTO-001、STAGE9-APPLICATION-001、STAGE9-SCREEN-001。**已运行通过：221 项检查、真实应用流程及异常清理通过，见 [第九批记录](results/STAGE9.md)。** 下文保留本批操作说明。 前八批验收依据见 [第八批记录](results/STAGE8.md)。

同步最新完整 OpenOS-GUI 到游戏电脑 `/home/OpenOS-GUI`，保留结果。本批新增 `lib/ocgui/application.lua`、`tests/stage9.lua`、`tests/stage9-screen.lua`、`tests/run-stage9.lua`；沿用此前全部模块、stage3–8.lua、加载器、报告工具与 fake_openos.lua。

```sh
lua /home/OpenOS-GUI/tests/run-stage9.lua /home/OpenOS-GUI
```

先运行此前 191 个回归组，再运行 30 个生命周期新用例，共 **221 项逻辑／模拟检查**。失败则停止后续阶段。接着使用 Application 的 open/dispatch/render/stop/close 显示真实测试卡：

1. 初始焦点为 PRESS KEYS，用主键盘 Enter、空格各激活一次，确认计数更新。
2. 按 Tab 切到 FINISH，再按 Enter 结束。可额外观察鼠标点击及按下／焦点外观，但鼠标不能代替所需键盘操作。
3. 随后自动运行预设异常模式：程序注入一个 click 回调错误，检查应用返回原错误、停止后续输入并完成关闭，无需人工重复操作。

真实卡要求至少 50×18 的本地全屏终端，最多等待 120 秒。保存初始屏幕回读、归一化输入、键盘计数、最终计数字符、预设回调错误及关闭前后设备状态。结束会清屏，不恢复原终端文字，不改变分辨率、色深或绑定；中断或调整尺寸会取消本次卡并尝试关闭。

预期显示 STAGE9 AUTOMATIC RESULT: PASSED；结果目录 `/home/OpenOS-GUI/tests/results/stage9-run-NNN` 包含 report.json、七个逻辑阶段日志、normal/exception.log 与 *-screen.json。完成后回复结果及视觉情况即可。

30 个新用例覆盖延迟获取设备、根保护、状态转换、渲染失效、原始信号、停止与期限查询、尺寸和键盘集合更新、设备丢失、回调／渲染失败、打开回滚、资源占用、清理错误、重入保护与主题复制。

本批仅实现宿主驱动生命周期，不提供 run/step、公开 ocgui 入口、发行版本或 basic 示例。外层测试脚本负责等待信号和最终 close。开发端没有 Lua 5.3；本批通过依据为用户游戏内报告，已归档。独立循环与公开入口尚未实现。
