# OpenOS GUI + 文本编辑器

面向 GTNH OpenComputers / OpenOS / Lua 5.3 的 GUI 库与文本编辑器，开发版本 `0.1.0-dev`。

## 使用 wget 安装

游戏电脑需要互联网卡和可写的 OpenOS 系统盘：

```sh
wget -f https://raw.githubusercontent.com/Coast1n/OpenOS-GUI/main/installer.lua /tmp/ocgui-installer.lua
lua /tmp/ocgui-installer.lua
```

安装器下载并检查两个发布文件，然后安装：

- `/lib/ocgui.lua`：完整单文件 GUI 库，应用使用 `require("ocgui")`。
- `/bin/edit.lua`：图形文本编辑器，使用 `edit xxx` 打开或新建文件。

已有文件会备份到不重名的 `.before-ocedit` 路径，安装时打印实际位置；替换失败会尝试恢复。更新时重新下载 installer，避免旧安装器校验信息与新产物不一致。校验使用长度及 Adler-32 检测下载损坏，SHA-256 发布清单另见 dist；这不构成独立数字签名。

安装后重启游戏内电脑，运行：

```sh
edit /home/notes.txt
edit "notes with spaces.txt"
edit -r /home/notes.txt
```

Ctrl+S 保存，Ctrl+Q 退出，Ctrl+Z/Y 撤销／重做，Ctrl+I 插入 Tab；Tab 切换焦点。支持中文、多行、粘贴、行号、滚动和未保存退出提示。保存保留原文件备份；限制 64 KiB / 4096 行。建议至少 44×10 屏幕。详细操作和恢复原 edit 命令见 [编辑器说明](editor/README.md)。

## 使用 GUI 库

```lua
local gui = require("ocgui")
local app = gui.application()
local quit = app.root:add(gui.button {x = 3, y = 3, width = 12, text = "退出"})
quit:on("click", function() app:stop() end)
local ok, err = app:run()
if not ok then error(err.message, 0) end
```

[接口](docs/API.md) · [库安装与示例](docs/INSTALL.md) · [单文件构建](docs/BUNDLING.md)

## 源码和构建

lib/ 保留模块化源码，editor/ 是编辑器项目，examples/ 是示例，dist/ 是额外单文件产物。Node.js 仅用于开发电脑构建，游戏运行不需要 Node.js。

```sh
npm ci --ignore-scripts
npm run build:editor
npm run build:installer
```

生成 dist/ocgui.lua、dist/basic.lua、dist/edit.lua 和根目录 installer.lua。依赖锁定 luabundle 1.7.0，产物保留其 MIT 许可。自己的应用通过单文件库加载，编辑器没有把 GUI 再次嵌入自身。

## 验证状态

GUI 模块化源码已在实际游戏中完成十批验收：第十批 253 项逻辑／模拟检查、真实独立运行、异常恢复与 basic 示例通过。版本仍为开发版本。

新增单文件打包、文本编辑器和在线安装器目前通过构建与 Lua 5.3 语法／模块检查；新增 OpenOS 测试和联网安装仍需在目标环境验证，不等同于已通过全部游戏内验收。可在完整项目目录运行：

```sh
lua tests/run-bundle.lua .
lua tests/run-editor.lua .
```

原始游戏日志含设备标识及本地路径，保留在开发工作区而不上传；仓库只保留验收摘要与测试代码。参考上游源码不包含在本仓库。实际游戏 OC 版本尚未独立核验，兼容范围以实际测试环境为准。
