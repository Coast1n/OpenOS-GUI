# 第五批测试：焦点与指针捕获

批次：`STAGE5-AUTO-001` / `STAGE5-INTERACTION-001`。**已由用户运行通过，111 项全部通过。** 证据见 [第五批记录](results/STAGE5.md)。以下保留该批操作步骤；当前测试入口为 [第六批](STAGE6.md)。

## 执行

同步当前 `OpenOS-GUI` 到游戏电脑 `/home/OpenOS-GUI`，保留已有结果。本轮修改 `lib/ocgui/widget.lua`，新增：

```text
lib/ocgui/interaction.lua
tests/stage5.lua
tests/run-stage5.lua
```

沿用此前已有模块、stage3.lua、stage4.lua 和 tests/support 下的加载器及报告工具。执行：

```sh
lua /home/OpenOS-GUI/tests/run-stage5.lua /home/OpenOS-GUI
```

预期依次为 `35 passed`、`36 passed`、`40 passed`，均为 0 failed，最后显示：

```text
STAGE5 AUTOMATIC RESULT: PASSED
FILES SAVED TO: /home/OpenOS-GUI/tests/results/stage5-run-001
```

共 111 项检查。前一个回归阶段失败就停止，不运行后续阶段。每次自动使用新的 `stage5-run-NNN`；结果文件为 report.json、summary.txt、tree-regression.log、events-regression.log、interaction.log。运行完成后告知即可，开发端继续读取此前给出的 Windows 结果父目录。

## 范围

- F01–F14：可聚焦状态、局部 focus/blur、顺序与反向遍历、失效焦点取消、回调中变更焦点、目标在通知中隐藏或移除、左键与背景焦点策略。
- C01–C16：单一捕获、越界拖动、匹配释放、屏幕／玩家／按钮隔离、5 秒不活动超时、匹配拖动延长期限、等待上限、树变更取消、异常后释放及计时验证。
- L01–L10：Tab 重复按键、Shift+Tab、按键盘来源隔离、键盘重复标记、焦点粘贴、尺寸变化／中断取消、树观察恢复、关闭异常及重入保护。

所有输入都是合成信号；时间由测试程序推进，不需要真的等待 5 秒。程序不操作 GPU、不拉取真实键盘或鼠标、不注册定时器。还没有 Application、按钮默认激活、标签、主题、绘制树或公开 ocgui 入口；Enter/Space 的按钮激活与键盘按下超时在后续控件接入时实现。

开发端没有本地 Lua 5.3；本批验收依据为用户游戏内报告，已归档并核对。
