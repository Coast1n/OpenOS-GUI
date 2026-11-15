# 第三批：控件与容器基础

状态：第三批 35 个用例及第四批树回归均已由用户运行通过，见 [第四批验收记录](../tests/results/STAGE4.md)。focusable 属性与焦点／捕获已通过 [第五批测试](../tests/results/STAGE5.md)。第六批标签与绘制已通过，见 [PAINTING.md](PAINTING.md)，第七批鼠标按钮已通过，第八批键盘增量已通过，第九批生命周期已通过，第十批整体验收尚待运行。

`ocgui.widget`、`ocgui.container` 是内部模块，分别提供 `new(options?)`；只依赖已验收的 `ocgui.geometry`，不加载 OpenOS 模块或访问设备。

## 已实现

- 默认位置 `(1,1)`、尺寸 `1×1`，位置必须为整数，尺寸必须为正整数。
- `getBounds/setBounds`、`getParent`、`setVisible/isVisible`、`setEnabled/isEnabled`、`setStyle/getStyle`、`invalidate`。
- 容器 `add/remove/getChildren`，禁止重复、已有父节点、环和附加应用根节点。移除保留子树，换父节点前须先 remove。
- `getAbsoluteBounds/getClipBounds/hitTest` 供后续绘制与分发器使用。坐标相对父节点，以 1 为起点；命中使用全部祖先的可见裁剪范围，子控件从后向前检查。
- `isVisible/isEnabled` 表示沿祖先链合并后的有效状态，修改祖先不会覆盖子节点自己的开关。隐藏子树不参与命中；禁用控件或容器仍阻挡所覆盖范围，避免穿透。
- 样式在输入和读取时递归复制，仅接受字符串键和有限数字、布尔值、字符串、嵌套样式表，拒绝循环和函数。字段含义及颜色解析留待主题与控件实现。
- 修改与结构变更沿祖先链标记 `_dirty`，没有变化的位置／开关 setter 不重复失效。内部字段不属于公开修改接口。

## 后续应用接入的内部约定

应用将持有唯一根节点，设置 `_isApplicationRoot` 以保护位置、尺寸及开关。该标志当前只用于保留边界并由模拟用例验证；Application 还未实现。

根节点可设置以下无参数或带参数闭包，这些不是用户事件处理器，也不由当前构造器自动安装：

| 根节点字段 | 调用 | 用途 |
| --- | --- | --- |
| `_mutationGuard` | `guard()` | 绘制期间拒绝修改，修改提交前调用，必须是无副作用的检查 |
| `_onInvalidate` | `callback()` | 标记将来应用需要重绘 |
| `_onTreeChanged` | `callback(node, kind)` | 修改完成后的内部通知，供后续取消无效交互使用 |

通知 kind 为 `bounds/visible/enabled/style/added/removed`。移除通知发送给旧根节点，此时 node 已脱离父节点；内部通知必须不抛出错误。对子树的失效在脱离后不再影响旧根节点。

## 尚未实现

第四批新增 `on`、输入归一化与纯冒泡已通过验收，说明见 [EVENTS.md](EVENTS.md)。第五批焦点、捕获与期限已通过验收，契约见 [INTERACTION.md](INTERACTION.md)。第六批 Label、主题及实际绘制遍历已通过，第七批鼠标 Button 已通过，第八批键盘激活已通过，第九批宿主驱动 Application 已通过，第十批 run/step、公开入口和 basic 示例已准备，尚待运行。当前纯状态模型的测试不能代替实际交互或生命周期测试。
