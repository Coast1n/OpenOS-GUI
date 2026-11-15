# 安装与基本使用

当前为 **0.1.0-dev 开发版本**。首版最小范围与本页实际 basic 示例已通过 [第十批验收](../tests/results/STAGE10.md)。安装复制命令未由开发端代为执行，下面步骤供游戏内独立使用。

## 环境与安装

目标为 GTNH OpenComputers、OpenOS、Lua 5.3，直接连接已绑定 GPU 的本地全屏终端。已回读的游戏环境为 OpenOS 1.8.9、Lua 5.3、160×50、8 位色深；实际 OC 版本尚未独立核验。示例及验收界面建议至少 50×18。不依赖 MineOS，不更改分辨率、色深或屏幕绑定。

把完整项目同步到游戏电脑 `/home/OpenOS-GUI`。自动测试可直接从此目录运行，不需要安装库。

要在自己的程序中使用 `require("ocgui")`，在 **游戏电脑的 OpenOS 终端**执行：

```sh
cp -r -u /home/OpenOS-GUI/lib/ocgui /lib/
cp -u /home/OpenOS-GUI/lib/ocgui.lua /lib/ocgui.lua
lua /home/OpenOS-GUI/examples/basic.lua
```

这两条复制命令安装模块目录与统一入口。更新项目后再次复制；若此前已经加载过旧版本，重启游戏内电脑后再运行，避免继续使用旧模块缓存。

安装路径与命令依据锁定 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 OpenOS lib/package.lua（默认 /lib/?.lua 路径与 loaded 缓存）和 bin/cp.lua（-r、-u 选项）。

## 操作示例

点击“更新计数”，或先 Tab 选中它，再按 Enter／空格。标签会更新次数；点击“退出”，或 Tab 切到退出按钮后按 Enter 结束。运行独占终端显示，退出清屏并恢复保存的颜色、活动缓冲及光标状态，不恢复原终端文字。

```lua
local gui = require("ocgui")
local app = gui.application()
local text = app.root:add(gui.label {x = 2, y = 2, width = 24, text = "Hello OpenOS"})
local quit = app.root:add(gui.button {x = 2, y = 4, width = 12, text = "退出"})
quit:on("click", function() app:stop() end)
local ok, err = app:run()
if not ok then error(err.code .. ": " .. err.message, 0) end
```

控件位置从 1 开始，相对父容器；尺寸需显式指定，暂不自动布局。主题字段见 [PAINTING.md](PAINTING.md)，生命周期及事件约定见 [API.md](API.md)、[APPLICATION.md](APPLICATION.md)、[LOOP.md](LOOP.md)。

首版范围为容器、单行标签、按钮、鼠标和键盘激活、主题及单屏应用。输入框、滚动区域、布局管理、窗口、多屏和 GPU 缓冲优化尚未实现，不属于当前验收范围。

单文件部署：额外产物位于 dist/，可直接运行 dist/basic.lua，或只安装 dist/ocgui.lua。构建、许可和新增验收步骤见 [单文件发布说明](BUNDLING.md)。打包产物的游戏内验证尚待完成。
