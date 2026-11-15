# 第二批运行记录

当前结论：**已通过验收**。最终通过证据为 `stage2-run-003`，此前失败及修复过程保留在下方。

## stage2-run-001

- 接收日期：2026-11-15。
- 证据：用户提供游戏电脑结果目录，开发端直接回读并复制，未修改原始日志。
- 批次：`STAGE2-AUTO-002`。
- 环境：`Lua 5.3`、`OpenOS 1.8.9`，均来自报告。
- GTNH：宿主目录名为 `GT New Horizons 2.9.0`，未单独核验模组安装版本；报告中的 GTNH 与 OC 版本为 unknown。
- 模拟阶段：**25 passed, 0 failed, 25 total**；覆盖渲染调用、裁剪、宽字符、颜色缓存、上下文生命周期、设备占用及状态恢复等模拟用例。
- 整体状态：**未通过验收**。模拟阶段完成后，测试入口第 124 行调用 `collectgarbage("collect")`，实际环境报告 `attempt to call a nil value (global 'collectgarbage')`。
- 真实屏幕正常阶段：未开始；无 `normal.log` 或屏幕报告。
- 真实屏幕异常恢复阶段：未开始；无 `exception.log` 或屏幕报告。
- 已确认前次路径修复后的报告写入能够完成；本次中断不是 GUI 模拟用例失败。

原始文件与 SHA-256：

| 文件 | SHA-256 |
| --- | --- |
| report.json（原始记录保留在开发工作区） | EE302C82A459AA02E5C9B000A32B46C014399196CC525018D6ADFFF7BBB1B29F |
| summary.txt（原始记录保留在开发工作区） | 836FD8BFCF7E07134516224BEC8F1AB54DE76CD7657BC2A09299CFAF07FBF288 |
| mock.log（原始记录保留在开发工作区） | 3CB8A8DA86B5D9FC972D7CDDD7265F141F9D571CF958FA177FA7EC34053089E4 |

## AUTO-003 修复与第二次运行前状态

一键入口更新为 `STAGE2-AUTO-003`，移除了模拟、正常、异常阶段之间的两处显式垃圾回收调用；不要求普通 Lua 的可选函数在 OC 用户环境中可用。未改动 GUI 实现，不推进下一阶段。

依据是本次真实游戏报告。参考 OC 源码锁定为 `a313175a3cbf47f8642dd77838a2d4a56842677c`，`src/main/resources/assets/opencomputers/lua/machine.lua` 定义用户环境；实际安装的 OC 版本尚未核实，不能将参考快照当作已验证游戏版本。

同步 `tests/run-stage2.lua` 到游戏项目后重跑，收到正常和异常真实屏幕报告，再判断本批是否通过。当前只有源码检查和用户回传的原始模拟结果，尚无修复后的游戏运行结果。

## stage2-run-002

- 接收日期：2026-11-15；直接回读用户此前提供的 Windows 结果父目录下的新子目录。
- 批次：`STAGE2-AUTO-003`，确认用户已运行修复后的入口。
- 环境：Lua 5.3、OpenOS 1.8.9；实际 OC 安装版本仍未知。
- 模拟阶段：**25 passed, 0 failed, 25 total**。
- 正常屏幕阶段：已开始，但 `device:open()` 报 `missing GPU method: getScreen`，尚未绘图或执行单元格回读，`checks` 为空。
- `normal-screen.json` 显示 before/after 相同，cleanup/restored 为 true；这只说明本次启动失败未留下设备状态差异，不能视为完成了正常绘图或异常恢复测试。
- 预设异常阶段：未运行，因为正常屏幕阶段失败。
- 整体状态：**未通过验收**。
- 结果父目录保持不变；本轮子目录为 `stage2-run-002`，没有覆盖 `stage2-run-001`。

原始证据：report.json（原始记录保留在开发工作区）、mock.log（原始记录保留在开发工作区）、normal.log（原始记录保留在开发工作区）、normal-screen.json（原始记录保留在开发工作区）、summary.txt（原始记录保留在开发工作区）。复制后逐一与游戏目录原文件核对 SHA-256，哈希记录见 SHA256.json（原始记录保留在开发工作区）。

## AUTO-004 修复与待复测

根因：适配层 `checked()` 要求 `type(gpu[name]) == "function"`；实际组件代理方法为带 `__call` 的 Lua 表，导致把存在的方法误报为缺失。锁定 OC 源码 `a313175a3cbf47f8642dd77838a2d4a56842677c` 的 `lua/machine.lua` 中，`componentCallback.__call` 实现调用，`libcomponent.proxy` 用 `setmetatable` 创建回调表；游戏测试脚本自身的直接 `gpu.getScreen()` 调用也已成功读取 before/after，提供了实际运行证据。

修复必需方法及可选 viewport、活动缓冲接口的可调用性判断，兼容普通函数和带函数 `__call` 的表。新增 B14–B16，分别覆盖代理方法的打开、绘制、状态恢复，不可调用表拒绝，以及不完整缓冲 API 检查。模拟批次改为 `STAGE2-RENDER-002`，总计 28 个用例，一键入口改为 `STAGE2-AUTO-004`。

本地仅完成源码和静态一致性检查；没有可用的本地 Lua 5.3 运行时，因此新增回归用例和修复后的真实屏幕测试均未运行。同步本轮三个文件后复测，再判断是否通过本批关口，后续功能开发继续暂停。

## stage2-run-003：验收通过

- 接收日期：2026-11-15；依据用户执行后保存的报告与日志，开发端未重新执行游戏测试。
- 批次：`STAGE2-AUTO-004` / `STAGE2-RENDER-002` / `STAGE2-SCREEN-002`。
- 模拟阶段：**28 passed, 0 failed, 28 total**，包括 B14–B16 的可调用代理回归用例。
- 正常屏幕：7 项单元格检查全部通过；READBACK、EXECUTION、CLEANUP、STATE RESTORE 均通过。
- 预设异常屏幕：7 项单元格检查全部通过；预期异常被正确识别，清理与状态恢复通过。
- 两份屏幕报告 before/after 一致，differences 为空；颜色及调色板标志、活动缓冲、屏幕绑定、160×50 分辨率与 viewport、8 位色深、光标和闪烁状态均有回读证据。
- 环境：Lua 5.3、OpenOS 1.8.9；实际 OC 版本仍未知，GTNH 2.9.0 仅由客户端目录名指示。
- 边界：不据此宣称字体外观、真实触摸／键盘交互或尚未实现的 Application 已通过。

原始证据：report.json（原始记录保留在开发工作区）、mock.log（原始记录保留在开发工作区）、normal.log（原始记录保留在开发工作区）、normal-screen.json（原始记录保留在开发工作区）、exception.log（原始记录保留在开发工作区）、exception-screen.json（原始记录保留在开发工作区）、summary.txt（原始记录保留在开发工作区）。七份文件复制后均与游戏原文件逐一核对 SHA-256，见 SHA256.json（原始记录保留在开发工作区）。

第二批关口已完成。下一小阶段为控件与容器状态树，已准备 [第三批测试](../STAGE3.md)，尚未运行。
