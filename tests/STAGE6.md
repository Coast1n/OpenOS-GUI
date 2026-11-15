# 第六批测试：标签、主题与控件树绘制

批次：`STAGE6-AUTO-002` / `STAGE6-PAINT-001` / `STAGE6-SCREEN-001`。**已通过用户运行和视觉验收，见 [第六批记录](results/STAGE6.md)。** 当前入口为 [第七批测试](STAGE7.md)。以下保留本批操作说明。 前五批验收记录见 [第五批记录](results/STAGE5.md)。

同步最新 `OpenOS-GUI` 到游戏电脑 `/home/OpenOS-GUI`，保留已有结果。本轮新增文件：

```text
lib/ocgui/label.lua
lib/ocgui/theme.lua
lib/ocgui/painter.lua
tests/stage6.lua
tests/stage6-screen.lua
tests/run-stage6.lua
```

沿用此前全部模块、stage3/4/5.lua 和 tests/support 中的加载器及报告工具。执行：

```sh
lua /home/OpenOS-GUI/tests/run-stage6.lua /home/OpenOS-GUI
```

预期依次 35、36、40、30 passed，全部 0 failed，合计 **141 项逻辑与模拟绘制检查**。之后运行正常、预设异常两种真实屏幕测试，各含 12 个回读检查，并验证执行、清理及状态恢复。最后显示：

```text
STAGE6 AUTOMATIC RESULT: PASSED
FILES SAVED TO: /home/OpenOS-GUI/tests/results/stage6-run-001
```

每次使用新的 stage6-run-NNN；任一阶段失败便停止后续阶段。目录包含 report.json、summary.txt、tree-regression.log、events-regression.log、interaction-regression.log、painting.log、normal.log、exception.log、normal-screen.json、exception-screen.json。完成后告诉我即可，开发端继续读取此前指定的 Windows 结果父目录。

30 个新增用例包括 8 个主题、6 个标签、16 个绘制检查：复制和覆盖顺序、参数验证、文本失效、前后遮挡、父容器裁剪、中文半字符留空、隐藏和禁用、清除移动／删除留下的内容、焦点样式、异常重试、绘制时修改保护和重入保护。

## 真实屏幕与人工观察

请使用至少 50×18 的本地全屏终端。模拟阶段之后程序会使用当前终端 GPU 显示测试卡，正常模式最多保留 60 秒，任意键或触摸可提前结束。测试卡结束后清屏并恢复设备颜色、活动缓冲和光标等状态，原有终端文字不会恢复；不改变分辨率、色深或屏幕绑定。

请观察：

- 中文标题及“中文：中文测试”是否正常显示，有无缺字或异常半个字符。
- 第 8 行两块裁剪区域分别应为“ AB ”和“A ”，边缘不出现半个“中”。
- 第 12 行应为 AABBBAAA，中间 BBB 使用不同背景；禁用标签文字应较暗（单色设备除外）。
- 第 14 行左侧旧位置为空，只在右侧显示 NEW；整体无错位或越界。

自动报告会保存屏幕前 40 列、16 行的字符与颜色及设备前后状态。自动通过并不代表字体外观通过。运行完成后可回复“完成，视觉正常”，或指出哪一处显示异常；仅在问题不易描述时再补截图。人工结论单独记录，不会把按键结束视为视觉通过。

若想单独重新观察，可执行（该命令只显示测试卡并输出检查，不生成独立结果目录；正式报告使用上面的一键命令）：

```sh
lua /home/OpenOS-GUI/tests/stage6-screen.lua /home/OpenOS-GUI
```

本批仍无按钮、Application 或公开入口，测试卡专门用于真实显示验证。开发端没有本地 Lua 运行时；本批通过依据为用户游戏内报告及人工确认，均已归档。
