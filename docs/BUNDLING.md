# 单文件发布产物

模块化源码保留在 lib/，使用 luabundle 1.7.0 额外生成 dist/。Node.js 只在开发电脑打包时使用，游戏里无需安装 Node.js 或打包工具。

| 文件 | 用途 |
| --- | --- |
| dist/ocgui.lua | 内含全部 15 个库模块；可作为唯一的 GUI 库文件安装 |
| dist/basic.lua | 内含示例及 15 个库模块，可直接运行，不需另装 ocgui |
| dist/manifest.json | 来源文件、模块清单、产物 SHA-256 与构建配置 |
| dist/THIRD-PARTY-LICENSES.txt | luabundle 运行时的 MIT 许可；Lua 产物头部也保留许可 |

term、unicode、component、event、computer 保留为 OpenOS 运行时依赖。打包器使用局部模块缓存，未包含的原生模块回退给原 require，不修改全局 require 或 package.path。源码引用相同模块时仍共享同一打包缓存。未打包文档、测试、参考仓库或 node_modules。

## 构建

在开发电脑的 OpenOS-GUI 目录执行：

```sh
npm ci --ignore-scripts
npm run build
```

依赖固定在 package.json 和 package-lock.json；构建脚本为 tools/build.cjs。两个产物均先完成 Lua 5.3 语法解析和模块清单检查，再写入 dist。保留源代码和调试元数据，不压缩，不生成依赖特定平台的字节码。

工具依据：[luabundle 官方文档](https://github.com/Benjamin-Dobell/luabundle)，使用 luaVersion=5.3、isolate=false 和项目 lib 搜索路径。现有平台适配器的动态 require(name) 专用于原生服务，构建脚本仅允许这一处动态加载。

## 游戏内使用和验证

将 dist/basic.lua 单独复制到游戏电脑任意目录，直接执行即可，例如：

```sh
lua /home/basic.lua
```

至少操作一次“更新计数”，然后“退出”；也可 Tab 选中更新、Enter 激活，再 Tab 切到退出、Enter 结束。界面和设备恢复行为与已验收的模块化示例相同，但打包产物仍须单独验证。

若要安装单文件库，将 dist/ocgui.lua 复制到游戏电脑 `/lib/ocgui.lua`，自己的应用继续使用 require("ocgui")。无需再复制 ocgui/ 子目录。更新已加载的库后重启游戏内电脑，避免旧模块缓存。

自动烟雾验证：同步项目中的 dist、tests/support 及 tests/run-bundle.lua 后执行：

```sh
lua /home/OpenOS-GUI/tests/run-bundle.lua /home/OpenOS-GUI
```

预期 6 项通过，报告自动写到 tests/results/bundle-run-NNN。覆盖实际打包文件的延迟加载、鼠标／键盘、run、回调错误清理、独立示例及全局加载状态。这些用注入的模拟设备，不操作真实 GPU；随后仍请单独运行 dist/basic.lua 观察实际显示与退出恢复。

当前验证状态：构建、Lua 5.3 语法、模块完整性、重复构建及哈希检查在开发端执行；单文件产物的 OpenOS 烟雾测试和真实显示尚待用户运行。前十批通过记录对应模块化源码，不能替代新增产物验收。
