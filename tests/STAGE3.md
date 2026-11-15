# 第三批测试：控件与容器树

批次：`STAGE3-AUTO-001` / `STAGE3-TREE-001`。**已由用户运行验收，35 个用例全部通过。** 证据见 [第三批记录](results/STAGE3.md)。下方保留第三批步骤；当前待运行 [第四批测试](STAGE4.md)。

## 执行

同步当前 `OpenOS-GUI` 项目到游戏电脑的 `/home/OpenOS-GUI`，保留已有 `tests/results/`。本轮新增文件：

```text
lib/ocgui/widget.lua
lib/ocgui/container.lua
tests/stage3.lua
tests/run-stage3.lua
tests/support/report.lua
```

沿用原来的 geometry 模块和 tests/support/loader.lua。执行：

```sh
lua /home/OpenOS-GUI/tests/run-stage3.lua /home/OpenOS-GUI
```

预期显示：

```text
SUMMARY: 35 passed, 0 failed, 35 total
STAGE3 AUTOMATIC RESULT: PASSED
FILES SAVED TO: /home/OpenOS-GUI/tests/results/stage3-run-001
```

重复运行自动使用新的 `stage3-run-NNN` 目录；父目录仍是同一个 `tests/results/`。结果包含 `report.json`、`tree.log`、`summary.txt`，无需截图；执行后告知已完成即可，开发端会回读此前提供的 Windows 目录。

## 范围与预期

- W01–W12：默认状态、参数验证、负坐标、布尔开关、setter 原子性、样式防御复制及循环检测、半开边界、溢出检查。
- T01–T07：添加、移除、显式换父节点、环检测、子树保留和子节点列表快照。
- T08–T17：多层坐标、祖先移动、祖先裁剪、上层命中、隐藏与禁用、禁用覆盖区阻挡穿透。
- T18–T23：祖先失效传播、无变化 setter、脱离原根节点、绘制期修改保护钩子及将来应用根节点的保护。

这些测试不获取 GPU、不绘图、不拉取事件，不需要点击或按键。构造器和内部钩子仍是分阶段内部接口，尚未实现公开 `require("ocgui")`、实际焦点与捕获、标签、按钮、Application 和示例。第三批通过后已准备第四批纯输入与分发模块，等待对应测试。

本地只进行静态检查；第三批通过的依据为用户游戏内生成的 stage3-run-001 报告，未声称在开发端另行运行 Lua 测试。
