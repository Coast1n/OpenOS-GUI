# 第四批测试：输入与事件分发基础

批次：`STAGE4-AUTO-001` / `STAGE4-EVENTS-001`。**已由用户在游戏内运行，71 项全部通过。** 证据见 [第四批记录](results/STAGE4.md)。以下保留该批操作步骤；当前测试入口为 [第五批](STAGE5.md)。

## 执行

将当前 `OpenOS-GUI` 同步到游戏目录 `/home/OpenOS-GUI`，保留已有结果。本轮修改 `lib/ocgui/widget.lua`、`lib/ocgui/container.lua`，新增：

```text
lib/ocgui/input.lua
lib/ocgui/dispatcher.lua
tests/stage4.lua
tests/run-stage4.lua
```

依赖第三批已有的 geometry、stage3.lua、tests/support/loader.lua、tests/support/report.lua。执行：

```sh
lua /home/OpenOS-GUI/tests/run-stage4.lua /home/OpenOS-GUI
```

预期先输出 `35 passed, 0 failed, 35 total`，再输出 `36 passed, 0 failed, 36 total`，最后为：

```text
STAGE4 AUTOMATIC RESULT: PASSED
FILES SAVED TO: /home/OpenOS-GUI/tests/results/stage4-run-001
```

每次使用新的 `stage4-run-NNN`。第一阶段回归失败时不继续事件用例。结果文件为 `report.json`、`summary.txt`、`tree-regression.log`、`events.log`，运行后告知已执行即可。

## 用例范围

- I01–I12：源屏幕及键盘筛选、指针事件转换、向上取整坐标、滚动方向、可选玩家名、原始 nil 参数、粘贴、尺寸变化、超时／未知信号、无效数据与键盘列表原子更新。
- H01–H08：订阅顺序、精确 true 消费、幂等退订、分发期间新增或退订处理器、列表隔离、参数验证、修改保护、重复订阅及无绘图副作用。
- D01–D16：目标到根冒泡、各节点局部坐标、全路径快照、脱离／重挂接、禁用、遮挡、裁剪、递归分发拒绝、原错误保留、取消、focus/blur 局部通知及插入新节点的边界。

本轮用人为构造的信号测试纯逻辑，不绘图、不拉取真实输入、不注册 event.listen/timer。focus/blur 只测试通知是否冒泡，尚不管理焦点。指针捕获、真实键盘／触摸接入、按钮默认行为、Application 和公开入口都未实现。

开发端没有 Lua 5.3 运行时；本批通过依据为用户游戏内报告，已归档并核对。
