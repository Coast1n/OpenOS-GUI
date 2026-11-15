# 第一批基础模块契约

状态：用户已运行第一批测试，33 个用例组全部通过，见 [验收记录](../tests/results/STAGE1.md)。原测试说明为 [STAGE1.md](../tests/STAGE1.md)。这些是内部模块，不替代公开 API 草案。

## geometry

无外部依赖，导出四个普通函数：

| 函数 | 结果 |
| --- | --- |
| `rect(x, y, width, height)` | 新建 `{x,y,width,height}`；宽高允许 0，不允许负数 |
| `contains(rect, x, y)` | 是否位于半开矩形区域内 |
| `intersect(a, b)` | 新矩形或 nil；仅边界相邻时为 nil |
| `translate(rect, dx, dy)` | 新矩形，输入不变 |

参数须可表示为 Lua 5.3 整数，拒绝数字字符串、NaN、无穷和小数；计算矩形端点及平移时检查整数溢出。所有操作都不修改输入矩形。内部允许空矩形以描述裁剪，后续 Widget 的公开尺寸仍要求正整数。

## text

`text.new(unicode)` 创建文本处理对象；必须显式传入具有 `len/sub/charWidth` 函数的接口，模块本身不 require OpenOS 库。

| 方法 | 结果 |
| --- | --- |
| `sanitize(value)` | 将每个 ASCII 控制字符替换为一个空格 |
| `width(value)` | 清理后的显示单元格宽度 |
| `clip(value, firstCell, count)` | 从 1 开始的单元格窗口；结果恰占 count 个单元格 |
| `fit(value, count, alignment?)` | 默认左对齐，可用 center/right；不足补空格，超出统一从右侧裁剪 |

被左右边缘切断的宽字符仅在可见部分输出空格，超出原文本部分也补空格。count 允许为 0，firstCell 必须为正整数。居中时奇数个空余单元格中多出的一个放在右边。输入以有效 UTF-8 为前提，不保证字素簇排版；不对畸形编码进行修复。

实现通过 `unicode.sub` 按字符取值并用 `charWidth` 累计，字符宽度下限为 1。此策略依据锁定 OC 源码的 `src/main/scala/li/cil/oc/server/machine/luac/UnicodeAPI.scala`，`initialize()` 注册的 `wlen` 使用 `math.max(1, FontUtils.wcwidth(ch))`。当前依据 commit 为 `a313175a3cbf47f8642dd77838a2d4a56842677c`；先查的文档定义来自 `3199a89d598802e665027cdb8282da7edcb7b3b5` 的 `lua/libs/unicode.lua`。实际游戏版本仍待核对。

没有直接调用 `unicode.wtrunc`，因为这里需要同时支持左侧裁剪、被切断字符留空和按指定宽度补空格。当前实现逐字符调用 unicode 接口，首版不承诺长文本处理性能；真实原生宽度对照已纳入本批测试。
