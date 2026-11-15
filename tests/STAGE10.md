# 第十批：循环、统一入口与基础示例整体验收

批次 STAGE10-AUTO-001、STAGE10-LOOP-001、STAGE10-SCREEN-001、STAGE10-EXAMPLE-001。**已通过本环境验收：253 项检查、真实 run、异常恢复与实际 basic 示例通过。** 证据见 [第十批记录](results/STAGE10.md)，以下保留操作说明。 前九批依据见 [第九批记录](results/STAGE9.md)。

同步最新完整 OpenOS-GUI 到游戏电脑 `/home/OpenOS-GUI`，保留历史结果。本批修改 application.lua 与 tests/support/loader.lua，新增统一入口 lib/ocgui.lua、examples/basic.lua、stage10.lua、stage10-screen.lua、stage10-example.lua 和 run-stage10.lua；请同步全部 lib、tests 和 examples。

```sh
lua /home/OpenOS-GUI/tests/run-stage10.lua /home/OpenOS-GUI
```

先运行前九批的 221 个回归组，再运行 32 个循环／入口新用例，共 **253 项逻辑／模拟检查**。任一阶段失败则停止。随后依次执行：

1. **整体验收卡**：初始焦点自动放到 PRESS KEYS，用主键盘 Enter、空格各激活一次，再 Tab 切到 FINISH，按 Enter 结束。观察文字、按下／焦点颜色与计数更新。最多等待 120 秒。
2. **异常模式**：自动通过 run 注入 click 回调错误，检查原错误保留、应用关闭和设备恢复，无需操作。
3. **实际 basic 示例**：出现中文“更新计数”和“退出”按钮。至少激活一次“更新计数”，确认标签变化，再激活“退出”。可鼠标点击，或 Tab 选中更新、Enter 激活，再 Tab 选中退出、Enter 结束。最多等待 120 秒。

测试通过本地加载器读取项目中的真实公开入口与示例文件，不会复制或安装到 /lib，也不修改全局模块路径。结束后如需独立运行示例，再按 [安装说明](../docs/INSTALL.md) 操作。

预期显示 STAGE10 AUTOMATIC RESULT: PASSED。结果目录 `/home/OpenOS-GUI/tests/results/stage10-run-NNN` 包含 report.json、八个逻辑阶段日志、normal/exception/example.log 及对应 *-screen.json。正常／异常卡保存首帧字符颜色、有效键盘计数、原错误及状态恢复；实际示例保存有效更新次数、执行和关闭结果及设备前后状态。人工外观结论另行记录，完成后告知是否发现异常即可。

真实阶段建议至少 50×18 本地全屏终端。会清屏并尝试恢复状态，不恢复原终端文字，不改变分辨率、色深和绑定。中断或超时会结束本次测试并进行清理，未完成必需操作则报告失败。

32 个新用例覆盖公开工厂、加载副作用、初始绘制、单信号 step、有限／无限等待、期限、停止与中断、重入、打开／等待／绘制／回调错误、run 始终关闭以及清理错误不覆盖主错误。当前版本为 0.1.0-dev；本批已通过，首版最小范围已完成，仍保留开发版本标识。
