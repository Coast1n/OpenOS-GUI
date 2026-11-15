# OpenOS GUI 文本编辑器

开发版本，尚待本批游戏内验收。使用**外部单文件 ocgui.lua**，代码中为 require("ocgui")；Lua 模块名不带 .lua、星号或空格。编辑器没有修改 GUI 核心，界面用现有容器、标签及按钮构成。

## 预览与测试（先执行）

同步最新完整 OpenOS-GUI 到游戏电脑 `/home/OpenOS-GUI`，执行：

```sh
lua /home/OpenOS-GUI/tests/run-editor.lua /home/OpenOS-GUI
lua /home/OpenOS-GUI/editor/preview.lua /home/OpenOS-GUI /home/editor-test.txt
```

第一条预期 **20 项通过**，报告自动保存到 tests/results/editor-run-NNN，覆盖中文、多行、行尾、撤销、显示宽度、容量限制与模拟保存失败；不修改用户文件。第二条读取 dist/edit.lua 和实际单文件 dist/ocgui.lua 预览，不替换系统 edit，也不依赖此前安装的库版本。

在预览中输入中文及多行文字、移动和删除、粘贴、撤销／重做，Ctrl+S 保存；退出后再次打开，确认内容正确。修改后尝试退出，分别验证“取消”和“放弃退出”。请检查行号、滚动、黄色光标、文字宽度和退出后设备恢复。目标测试文件可能被创建，保存后会保留旧版本备份。

## 安装 edit 命令（预览通过后）

```sh
lua /home/OpenOS-GUI/editor/install.lua /home/OpenOS-GUI
```

安装脚本先暂存、回读校验两个产物，再安装到 `/lib/ocgui.lua` 与 `/bin/edit.lua`。已有文件移动到不重名的 `.before-ocedit` 备份，实际备份路径会打印；失败时尝试回滚。这里只替换 edit 命令和 GUI 库，不修改 shell 或全局配置。若 OpenOS 系统盘只读，安装会报错，需先使用可写的 OpenOS 安装。

重启游戏内电脑后使用：

```sh
edit /home/notes.txt
edit "notes with spaces.txt"
edit -r /home/notes.txt
```

相对路径以执行命令时的当前目录为准；文件不存在时新建，父目录须已存在。`-r` 为只读。恢复原命令时，将安装时打印的 edit 备份复制回 `/bin/edit.lua`，例如首次备份为该路径时：

```sh
cp /bin/edit.lua.before-ocedit /bin/edit.lua
```

## 编辑操作

| 操作 | 方法 |
| --- | --- |
| 定位 | 鼠标点击、方向键、Home/End、PageUp/PageDown |
| 滚动 | 鼠标滚轮；移动光标时自动纵向／横向跟随 |
| 编辑 | Enter、Backspace、Delete、普通字符 |
| 粘贴 | OpenComputers 的 clipboard 事件／游戏粘贴功能 |
| 保存 | Ctrl+S 或保存按钮 |
| 撤销／重做 | Ctrl+Z / Ctrl+Y |
| 插入制表符 | Ctrl+I 或插入Tab按钮；显示为 4 列制表位 |
| 切换按钮焦点 | Tab；返回编辑区也可直接点击正文 |
| 退出 | Ctrl+Q 或退出按钮；有修改时选择保存退出、放弃退出或取消 |

Tab 保留为 GUI 焦点导航。当前不提供选区、复制／剪切、查找替换、语法高亮或自动换行；长行水平滚动。支持文本文件，拒绝 NUL 二进制内容，限制 64 KiB / 4096 行，撤销和重做各最多 16 项并限制历史字节量。需要至少 44×10 本地全屏终端。

保存保留 LF 或 CRLF 格式（混合行尾会统一），先写同目录临时文件，旧文件重命名为不重名的 `.ocedit-backup` 备份，再提交新文件；提交失败尝试恢复。每次保存保留旧版本，不自动删除备份。保存前检查文件是否被外部修改，发现变化会拒绝覆盖。异常退出时尽力将未保存内容写到不重名的 `.ocedit-recovery` 文件，原路径不自动覆盖。

## 构建与来源

开发电脑在 OpenOS-GUI 下执行 `npm run build:editor`。dist/edit.lua 内含编辑器和两个私有模块，ocgui 刻意作为外部依赖；dist/editor-manifest.json 记录模块及 SHA-256，产物头保留 luabundle 许可。

先查文档快照 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 keyboard/unicode/filesystem 定义；键码、shell.resolve 和 edit 命令入口参照 OC commit `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 loot/openos/bin/edit.lua、lib/shell.lua、lib/filesystem.lua。未复制上游编辑器实现。实际游戏 OC 版本仍未独立核验。

开发端已生成产物并做 Lua 5.3 语法、模块及哈希检查；自动逻辑测试、真实界面、保存回滚和安装脚本的游戏内执行尚待用户验证，未声称已安装到游戏电脑。
