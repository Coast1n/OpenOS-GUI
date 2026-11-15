# 第一批测试：几何与文本基础

测试批次：`STAGE1-FOUNDATION-001`。状态：**用户已运行并回传，33 个用例组全部通过**，见 [验收记录](results/STAGE1.md)。以下保留本批原始操作说明，当前待执行的是 [第二批测试](STAGE2.md)。

## 本批内容

- `lib/ocgui/geometry.lua`：矩形、半开边界命中、相交、平移、空区域和参数校验。
- `lib/ocgui/text.lua`：注入 unicode 接口的文本处理，控制字符替换、显示宽度、按单元格裁剪和对齐。
- `tests/stage1.lua`：33 个测试用例组；部分组包含多次边界与性质断言。

本批交付时尚无 `lib/ocgui.lua` 公开入口、GPU 渲染或按钮界面。本批仅验收后续渲染依赖的坐标和宽字符基础；不要运行 API 文档中的 GUI 使用草案。

## 准备与运行

在实际 GTNH OpenComputers 的 **OpenOS、Lua 5.3** 环境执行。普通 Windows Lua 不提供这里需要的真实 `unicode` 模块，不作为本批验收环境。

把项目目录复制到游戏电脑的一个新目录，例如 `/home/OpenOS-GUI`。最少需要保留以下相对路径及 UTF-8 内容：

```text
/home/OpenOS-GUI/
├── lib/ocgui/geometry.lua
├── lib/ocgui/text.lua
└── tests/stage1.lua
```

文件传输方式沿用你现有的方式，本批不要求安装下载工具或覆盖系统 `/lib`。在 OpenOS shell 执行：

```sh
cd /home/OpenOS-GUI
lua tests/stage1.lua .
```

最后的 `.` 是项目根目录。使用其他目录时，相应替换 cd 路径。脚本直接用 loadfile 加载本目录的两个模块，不改变 `package.path`，不会误加载已经安装的同名库。

如需保存完整日志，可使用尚不存在的文件名，避免覆盖已有结果：

```sh
lua tests/stage1.lua . > /home/ocgui-stage1-result-001.txt
```

除你主动重定向日志外，脚本不会写文件；不调用 GPU、拉取事件、改变分辨率、注册监听或修改系统配置。它会向当前终端输出测试结果，正常终端输出会推进光标和滚屏。

重定向保存的是标准输出；若终端另外显示启动或未捕获错误，也请一并复制返回。

## 预期结果

开始输出批次号与 `LUA: Lua 5.3`。每个用例组输出 `PASS` 或 `FAIL`，最后应为：

```text
SUMMARY: 33 passed, 0 failed, 33 total
STAGE1 PASS: return this summary and your GTNH / OC / OpenOS versions
```

脚本会验证中文“中”宽度为 2、裁剪宽字符时用空格替代被截断的单元格，并将不同裁剪窗口的输出宽度与真实 `unicode.wlen` 对照。预期字符串写死在用例中，不依赖本库自己生成预期答案。

| 用例 | 范围 |
| --- | --- |
| G01–G04 | 构造、负坐标、半开边界及空矩形 |
| G05–G09 | 重叠、分离、相邻边界、包含及无副作用平移 |
| G10–G11 | 非法参数、NaN、无穷与整数溢出 |
| G12 | 相交区域与两矩形逐点命中的一致性 |
| L01 | 加载模块不改变全局字段及 package 搜索路径 |
| T01–T05 | 空文本、ASCII、中文、原生宽度对照、控制字符 |
| T06–T13 | 左右裁剪、宽字符切边、越界、零宽及补空格 |
| T14–T19 | 左中右对齐、溢出截断、非法参数及依赖注入 |
| T20 | 不同文本和窗口下，输出占据要求的显示宽度 |

`FAIL` 会继续执行其他用例，末尾报告失败总数并抛出错误。Lua 版本不符、文件缺失、语法加载失败或没有真实 unicode 模块时会直接停止；不算通过。请返回原始错误，不必自行修改测试代码。

## 返回结果

复制以下模板，附完整日志或终端文字：

```text
测试批次：STAGE1-FOUNDATION-001
GTNH 版本：
OpenComputers 版本：
OpenOS 版本（不知道可填未知）：
Lua 输出版本：
运行命令：
SUMMARY 行或阻止运行的错误：
完整输出／失败信息：
```

本批不验证实际字体绘制、GPU 恢复或交互性能。收到结果后，先处理本批失败，再进入渲染与设备适配开发；下一次需要测试时再次暂停并交付新批次。
