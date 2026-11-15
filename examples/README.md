# 游戏内示例

basic.lua 已编写，使用公开 require("ocgui") 创建标签、更新计数按钮和退出按钮，通过 app:run 驱动；已通过 [第十批整体验收](../tests/results/STAGE10.md)，记录一次有效更新、正常退出及设备恢复。

一键验收会直接执行这个实际示例文件，无需预先安装。独立运行前按 [安装说明](../docs/INSTALL.md) 复制库，然后执行：

```sh
lua /home/OpenOS-GUI/examples/basic.lua
```

点击“更新计数”或先 Tab 选中后按 Enter／空格；点击“退出”或再 Tab 切换后 Enter。退出恢复设备状态并清屏，不恢复旧终端文字。当前 0.1.0-dev，不依赖 MineOS。
