# 设计与实施清单

## 目标与首版边界

面向 OpenOS 和 Lua 5.3 开发独立 GUI 库。首版先实现一个应用、一个屏幕、容器、标签和按钮，形成可以启动、响应点击并退出的完整流程。输入框、布局管理、滚动容器、窗口管理、图片和高级 GPU 缓冲优化在后续按需要加入。

加载模块不占用事件循环、不修改全局环境。应用显式启动，同时支持调用者传入事件。渲染层集中管理 GPU 调用、矩形裁剪和显示状态；文本处理按显示宽度考虑中文等宽字符。模块边界见 [结构设计](ARCHITECTURE.md)，首版公开接口见 [API 草案](API.md)；两者均为待实现契约。

## 实施顺序

当前停点：**首版最小范围完成，十批验收通过。** 最新 stage10-run-002 的 253 项检查、真实 run、回调异常清理和实际 basic 示例均通过，证据见 [STAGE10.md](../tests/results/STAGE10.md)。独立循环、统一入口、示例及安装说明齐备，版本保留 0.1.0-dev；未对外发布或自动部署。后续为按需求增加输入框、滚动、布局和窗口等。

- [x] 建立独立项目目录，更新工作区入口与开发规则。
- [x] 整理模块职责、参考资料入口和验收要求。
- [x] 设计控件树、设备生命周期、事件分发、渲染策略与公开 API。
- [x] 编写 geometry 和 text 基础模块，并准备第一批测试与说明。
- [x] 用户执行第一批测试并返回结果：33 passed，0 failed。
- [x] 编写渲染上下文与 OpenOS 设备适配，准备模拟及真实屏幕测试。
- [x] 为第二批测试增加一键运行、独立结果目录、日志与屏幕字符/颜色回读报告，替代常规截图要求。
- [x] 回读第二批首次报告：25 个模拟用例通过；归档原始证据，移除阻断阶段切换的非必要 `collectgarbage` 调用。
- [x] 回读第二次报告：原有 25 个模拟用例再次通过；修复 GPU 可调用表识别，新增 B14–B16 回归用例。
- [x] 用户执行第二批测试并返回结果；stage2-run-003 中 28 个模拟用例及两种真实屏幕模式全部通过。
- [x] 编写 widget/container 的状态、树关系、坐标裁剪、层级命中和内部失效钩子，准备第三批 35 个用例及自动文件报告。
- [x] 用户执行第三批控件树测试并返回结果；stage3-run-001 中 35 个用例全部通过。
- [x] 编写输入归一化、事件订阅、全路径快照及冒泡，准备第四批 36 个新用例与 35 个树回归用例。
- [x] 用户执行第四批测试并返回结果；stage4-run-001 中 71 个用例全部通过。
- [x] 编写可聚焦属性、焦点管理、指针捕获、超时取消及键盘路由，准备第五批 40 个新用例和 71 个回归用例。
- [x] 用户执行第五批测试并返回结果；stage5-run-001 中 111 个用例全部通过。
- [x] 编写 Label、主题复制和解析、控件树整帧绘制，准备第六批 30 个新用例、111 个回归用例及正常／预设异常真实屏幕测试，保留必要人工观察。
- [x] 用户执行第六批测试；stage6-run-002 的 141 项检查及两种真实屏幕模式通过，用户视觉确认未发现异常。
- [x] 编写鼠标按钮、默认行为顺序、合法释放 click 与状态绘制，准备第七批 24 个新用例、141 个回归及真实点击测试。
- [x] 回读第七批首轮：141 个回归及 23 个按钮用例通过，修正 P17 将普通 Widget 当成 Button 的夹具错误，归档失败证据。
- [x] 用户复测第七批；stage7-run-003 中 165 项全部通过，真实点击、正常／异常清理及视觉验收通过。
- [x] 实现 Enter/Space 激活及 5 秒按下期限，准备第八批 26 个新用例、165 个回归及真实键盘卡。
- [x] 回读第八批首轮：191 项逻辑检查通过；修正真实屏幕标题仍使用“鼠标按钮”的旧断言，归档失败证据。
- [x] 用户复测第八批；stage8-run-004 中 191 项检查、真实 Enter／空格激活、清理与视觉验收通过。
- [x] 实现宿主驱动的 open/dispatch/render/nextTimeout/stop/close，准备第九批 30 个新用例、191 个回归和真实应用流程。
- [x] 用户执行第九批；stage9-run-001 中 221 项全部通过，真实宿主流程及回调异常清理／恢复通过。
- [x] 实现 run/step 独立循环和 lib/ocgui.lua 统一入口，标记 0.1.0-dev。
- [x] 整合标签、按钮与绘制模块，编写 examples/basic.lua、安装及启动说明。
- [x] 准备第十批 32 个新用例、221 个回归、真实 run 与实际 basic 示例测试。
- [x] 用户执行第十批整体验收；stage10-run-002 的 253 项检查及真实 run、异常和实际示例通过。
- [x] 验证独立循环退出、错误保留及清理错误附加，32 个新增逻辑／模拟用例通过。
- [x] 在实际 OpenOS 完成最小交互验收并记录已知版本／硬件；实际 OC 版本仍标记未独立核验。
- [ ] 根据实际需求扩展输入、布局、滚动和窗口功能。

为保持小批量验收，原先的“控件、容器和事件分发”拆开执行：第三批实现树与状态，第四批接入处理器和纯输入分发；之后再接焦点与捕获、Application、Label/Button 和公开示例。纯逻辑通过不代表真实输入交互已经通过。

## 资料入口与已知差异

文档仓库提交：`3199a89d598802e665027cdb8282da7edcb7b3b5`，类型定义位于工作区 `.gtnh-oc-dev/docs/GTNH-OC-Lua-Documentation/lua/`。优先查 `libs/event.lua`、`libs/component.lua`、`libs/unicode.lua` 和 `components/gpu.lua`。

当前 OpenComputers 锁定为 `1.13.1-GTNH`，commit `a313175a3cbf47f8642dd77838a2d4a56842677c`，源码根目录为 `.gtnh-oc-dev/sources/OpenComputers/`。相关查证入口：

| 源码文件（相对上述根目录） | 方法或入口 | 后续用途 |
| --- | --- | --- |
| `src/main/resources/assets/opencomputers/loot/openos/lib/event.lua` | `event.pull`、`event.pullFiltered`、`event.listen` | 事件消费、监听和生命周期 |
| `src/main/scala/li/cil/oc/server/component/GraphicsCard.scala` | `getForeground`、`setForeground`、`getBackground`、`setBackground` | 颜色参数与状态保存恢复 |
| `src/main/scala/li/cil/oc/server/machine/luac/UnicodeAPI.scala` | 注册的 `wlen`、`wtrunc` | 文本显示宽度与截断行为 |
| `src/main/resources/assets/opencomputers/loot/openos/lib/tty.lua` | `gpu`、`getViewport`、`getCursor`、`setCursor` | 终端设备与光标状态 |
| `src/main/scala/li/cil/oc/common/component/TextBuffer.scala` | `mouseDown`、`mouseDrag`、`mouseUp`、`mouseScroll` | touch、drag、drop、scroll 对应关系 |
| `src/main/scala/li/cil/oc/server/component/Keyboard.scala` | `onMessage` | 键盘事件与可选玩家名 |

已发现文档类型标注未覆盖的分支：`event.listen` 在成功注册时通过 `event.register` 返回数字 ID，在同名事件与同一回调已注册时返回 `false`。后续事件清理需区分这两种结果，不能假定每次调用都获得新的可取消 ID。

文档声明面向 GTNH 2.9，实际游戏安装版本尚未核实；完整版本信息以工作区 `.gtnh-oc-dev/source-lock.json` 为准。涉及参数、性能或兼容性时继续核对锁定源码，并提供游戏内最小程序验证。

## 单文件发布增补

- [x] 保留模块化源码，固定 luabundle 1.7.0 及依赖锁文件，生成独立库与独立 basic 示例。
- [x] 完成 Lua 5.3 语法、模块清单及可重复构建检查，保留许可和 SHA-256 清单。
- [ ] 游戏内执行 6 项打包烟雾检查，并验证单文件 basic 的真实显示与退出恢复。步骤见 [BUNDLING.md](BUNDLING.md)。

## 文本编辑器项目

已新增基于单文件 ocgui 的编辑器、dist/edit.lua、预览与安装脚本；当前等待 20 项逻辑／保存测试及真实编辑验收，尚未替换游戏系统命令。说明见 [编辑器项目](../editor/README.md)。
