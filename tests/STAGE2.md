# 第二批测试：渲染与设备状态

批次：`STAGE2-AUTO-004`（一键文件报告）、`STAGE2-RENDER-002`（28 个模拟用例）、`STAGE2-SCREEN-002`（真实屏幕）。状态：**已通过用户运行验收**，stage2-run-003 的模拟、正常屏幕与预设异常模式均通过。证据见 [第二批运行记录](results/STAGE2.md)。以下保留操作与历史修复说明；当前待运行 [第三批测试](STAGE3.md)。

## 推荐：一键运行并自动保存文件

同步最新版项目后，只需执行一次：

已修复一键入口的相对路径问题：`filesystem.makeDirectory` 与 `io.open` 对相对路径的解释不同，旧入口可能在写入首个 `report.json` 时提示“找不到指定的路径”。入口现在先通过 `shell.resolve` 统一项目绝对路径。若遇到这一报错，请先同步更新后的 `tests/run-stage2.lua`，再重新运行；此次启动报错不代表模拟或屏幕测试已执行。本次回传的 `stage2-run-001` 已确认报告可以写入。

第一轮的 `collectgarbage` 中断已修复。第二轮 `stage2-run-002` 已进入正常屏幕阶段，错误为 `missing GPU method: getScreen`；GPU 本身有该方法，问题是组件方法实际为带 `__call` 的表，而适配层只接受普通函数。当前修复统一处理两种形式，包括可选 viewport 和活动缓冲接口。

该轮修复涉及三个文件：`lib/ocgui/platform/openos.lua`、`tests/stage2.lua`、`tests/run-stage2.lua`。用户已同步并运行，新报告 `suite` 为 `STAGE2-AUTO-004`，28 个模拟用例及两种真实屏幕模式均通过，结果保存于 `stage2-run-003/`。重跑时继续递增；Windows 父目录始终为同一个 `tests/results/`。

```sh
cd /home/OpenOS-GUI
lua tests/run-stage2.lua .
```

不需要截图，不需要输出重定向。程序自动依次执行 A/B/C，前一步失败就停止；真实屏幕阶段读取数据后立即退出，不再等待按键或停留 30 秒。屏幕仍会暂时被绘制和清空，原有文字不保留。

结果自动保存到游戏电脑的 `tests/results/stage2-run-001/`，重复运行自动使用 002、003 等新目录，不覆盖旧结果。预期最后显示 `STAGE2 AUTOMATIC RESULT: PASSED`。

```text
tests/results/stage2-run-001/
├── summary.txt               总结与结果目录
├── report.json               各阶段结果、Lua/OpenOS 版本和错误
├── mock.log                  28 个模拟用例组的输出
├── normal.log                正常绘制及恢复检查输出
├── normal-screen.json        屏幕字符/颜色、逐项检查、恢复前后状态
├── exception.log             预设异常及恢复检查输出
└── exception-screen.json     异常模式的屏幕数据与恢复前后状态
```

遇到失败时，后续阶段未运行，因此部分文件可能不存在。日志逐行刷新，并捕获测试文件加载、运行异常及堆栈；报告会在各阶段完成后更新。只有存储故障或进程被强制终止时可能留下不完整文件。

回传整个结果目录，或提供它在 Windows 存档中的路径即可。以此前安装位置为例，它位于该电脑磁盘对应的 `home/OpenOS-GUI/tests/results/` 内，而非开发工作区自动接收结果。

下方 A/B/C 为各内部阶段和手动排查方式；运行一键入口后无需再重复执行这些命令。

## 准备

沿用第一批的 OpenOS、Lua 5.3 环境。将工作区 `OpenOS-GUI` 的最新文件同步到游戏中的 `/home/OpenOS-GUI`，保留第一批日志。建议复制整个项目，第二批需要以下文件：

```text
lib/ocgui/geometry.lua
lib/ocgui/text.lua
lib/ocgui/renderer.lua
lib/ocgui/platform/openos.lua
tests/support/loader.lua
tests/support/fake_openos.lua
tests/stage2.lua
tests/stage2-screen.lua
tests/run-stage2.lua
```

测试从项目目录加载文件，不需要安装到系统 `/lib`，也不会修改 package.path。真实屏幕需要至少 **40×14** 的可见区域和可工作的 GPU/屏幕，程序不会自动调整分辨率。分辨率不足时返回错误，保留错误信息即可。

## A. 模拟设备测试

```sh
cd /home/OpenOS-GUI
lua tests/stage2.lua .
```

该脚本使用真实 unicode 接口和模拟 GPU，不绘制测试卡、不改变真实 GPU 状态。预期：

```text
SUMMARY: 28 passed, 0 failed, 28 total
STAGE2 MOCK PASS: real screen test is still required
```

R01–R12 覆盖裁剪、宽字符左右切边、空区域、颜色缓存、上下文过期、帧异常、栈平衡与重入；B01–B13 覆盖无副作用构造、状态保存恢复、重复占用、启动回滚、清理失败、幂等关闭、接口回退、绑定变化、GPU 拒绝、原始信号、无 GPU 和尺寸变化后的清理。

B14–B16 覆盖可调用 GPU 代理表的完整生命周期、不可调用对象拒绝、不完整的可调用活动缓冲 API 检查。这 3 个新增用例已在 stage2-run-003 中运行通过。

若有 FAIL 或加载错误，**先停止，不运行 B/C**，将完整输出返回。模拟测试全部通过后再运行真实屏幕测试。

## B. 正常绘制与退出

```sh
lua tests/stage2-screen.lua .
```

本步会暂时独占并绘制当前屏幕，退出时清屏并恢复颜色、调色板标志、活动缓冲、光标位置和闪烁；旧终端文字不会保留。不会更改分辨率、色深或调色板内容。请在游戏电脑空闲时运行，不同时向该屏幕输出其他程序的文字。

一键模式自动读取左上角 40×12 区域内的每个单元格，保存字符、前景/背景 RGB 及调色板索引，并自动检查以下内容；无需截图。仅在手动运行本脚本时，测试卡才保留最多 30 秒，按键或触摸可提前退出：

- 标题为 `STAGE2 / 渲染测试`，ASCII 行为 `ASCII: abc 123`。
- 中文行显示 `中文：中文测试`，没有乱码；低色深设备颜色可有差异。
- 第 8 行蓝色区域应显示 `[A ]`，第 9 行显示 `[ B]`，不出现半个“中”或越界字符。
- 第 11 行仅最左边两个单元格为绿色；右侧说明文字位于正常背景。

退出后程序检查四项，预期均为 PASS：

```text
READBACK: PASS
EXECUTION: PASS
CLEANUP: PASS
STATE RESTORE: PASS
STAGE2 SCREEN PASS / normal
```

终端后续若出现无法输入等异常，补充一句现象即可；不必为正常终端截图。本步如有失败，停止并返回文件结果，不运行 C。

## C. 人为异常后的恢复

```sh
lua tests/stage2-screen.lua . fail
```

会显示同一测试卡。等待或按键结束后，脚本在受保护区域故意抛出 `STAGE2_INTENTIONAL_FAILURE`，再调用设备清理。这是验证异常路径的预设行为，不是真实故障。

预期四项仍为 PASS，最后一行为：

```text
STAGE2 SCREEN PASS / fail
```

一键模式自动完成此步。若返回提示符后出现无法输入等异常，请一并说明。

## 结果回传

直接回传 `stage2-run-NNN` 结果目录或其 Windows 本地路径，不再要求手动保存日志或填写完整模板。报告自动读取 Lua 与 `_OSVERSION`；GTNH 和 OC 版本没有可靠的运行时读取入口时标为 unknown，不自行猜测。

```text
结果目录的 Windows 路径：
额外异常现象（没有可省略）：
```

本批尚不测试控件树、按钮点击和完整 Application。收到结果后先修复失败并复测，再进入这些功能的开发。

GPU 回读能够确认字符、裁剪、颜色数据及恢复状态，无法证明 Minecraft 客户端字体最终画出的像素外观，也无法代替实际键盘输入。此两项不因文件报告通过而宣称已验证；当前无需常规截图，只有出现相关异常时再进一步查证。1-bit 色深的颜色区分检查会明确标注 skipped，其他检查照常运行。
