# 库源码约定

本目录用于内部实现，公开入口为上级 lib/ocgui.lua。首版最小范围已通过前十批验收，最近见 [记录](../../tests/results/STAGE10.md)。循环契约见 [LOOP.md](../../docs/LOOP.md)，版本保留 0.1.0-dev。

按实现进度逐个增加以下模块，不预建空函数：

| 规划文件 | 职责 |
| --- | --- |
| `application.lua` | 应用生命周期、运行和退出、外部事件接入 |
| `renderer.lua` | 帧上下文、裁剪、绘制及颜色缓存 |
| `text.lua` | Unicode 显示宽度、截断及对齐 |
| `widget.lua` | 控件边界、可见性、命中及失效标记 |
| `container.lua` | 子控件管理、父子关系和绘制顺序 |
| `geometry.lua` | 矩形相交、包含和坐标转换 |
| `input.lua` | 信号归一化与设备筛选 |
| `dispatcher.lua` | 处理器快照与事件冒泡 |
| `interaction.lua` | 焦点、指针捕获、期限与输入路由 |
| `platform/openos.lua` | OpenOS 设备、事件、时间与状态恢复 |
| `theme.lua` | 默认颜色及样式配置 |
| `label.lua` | 标签 |
| `button.lua` | 按钮与交互状态 |

具体控件当前直接位于本目录，内部引用使用 `require("ocgui.renderer")` 等小写模块名。OpenOS 依赖通过局部变量接收，不依赖 MineOS 初始化所提供的全局变量。

详细依赖方向和运行契约以 [结构设计](../../docs/ARCHITECTURE.md) 为准；公开入口约定见 [API 草案](../../docs/API.md)。
