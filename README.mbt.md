# Moon Sketch Kit

Moon Sketch Kit 是一个用 MoonBit 实现的流式近似分析工具箱，目标是让 MoonBit 项目可以用很小的内存对事件流、日志 token、埋点数据或简单业务流水做快速画像。

它不是 CSV 解析器，也不是 Web 展示项目，而是偏“基础算法 + 应用生态”的可复用库：把 Count-Min Sketch、Bloom Filter、HyperLogLog-lite、MinHash、Space-Saving Top-K、Reservoir Sampling、直方图、分位数、窗口漂移和质量门组合成一套可运行的分析工具。

当前仓库上传后请替换：

- GitHub: `https://github.com/cauchyQ/moon-sketch-kit`
- GitLink: `https://www.gitlink.org.cn/cauchyQ/moon-sketch-kit`

## 适用场景

- 日志或埋点流：统计高频事件、估算唯一用户数、抽样查看代表性 token。
- 数据质量检查：比较两段流是否发生漂移，输出质量门和建议。
- 浏览器或 CLI 小工具：用较小内存生成 Markdown / JSON 报告。
- MoonBit 生态基础库：给上层可视化、CI 检查、监控示例提供可复用组件。

## 核心功能

- Count-Min Sketch：近似频率统计，支持加权更新和误差报告。
- Space-Saving Top-K：在线高频项发现。
- HyperLogLog-lite：唯一值数量估算。
- MinHash：集合相似度估算。
- Bloom Filter：成员关系判断和误判率估计。
- Reservoir Sampling：确定性抽样，便于测试和报告复现。
- Histogram / Quantile：数值分布、P50/P90/P99 预览。
- Windowed Stream：用 `|` 或 `;` 分隔窗口，查看趋势、尖峰和 Top-K 时间线。
- Quality Gate：比较 baseline / candidate，输出 pass/fail、问题列表和修复建议。
- Token Profile：分析 token 类型、长度分布和前缀 Top-K。
- Budget Planner：根据样本流推荐 sketch 参数。

## 安装和检查

需要先安装 MoonBit 工具链。

```powershell
cd C:\Users\Lenovo\Desktop\Hot100\moon-sketch-kit
moon update
moon check
moon test
```

一键验证：

```powershell
.\scripts\verify.ps1
```

当前测试覆盖核心路径：哈希稳定性、事件解析、Count-Min、Bloom、Top-K、HLL-lite、MinHash、Reservoir、Histogram、Quantile、Drift、Quality Gate、Weighted Stream、Windowed Stream、Token Profile 和 Budget Planner。

## CLI 示例

整体事件流报告：

```powershell
moon run cmd/main -- report "login view login cart checkout login"
```

JSON 报告：

```powershell
moon run cmd/main -- json "login view login cart checkout login"
```

窗口漂移报告：

```powershell
moon run cmd/main -- windows "login login view | view cart cart checkout | checkout refund refund"
```

加权事件报告：

```powershell
moon run cmd/main -- weighted "login:12 view:7 checkout:3 refund:1"
```

数值分布：

```powershell
moon run cmd/main -- histogram "12 18 21 21 35 89" 0 100 10
moon run cmd/main -- quantile "12 18 21 21 35 89"
```

质量门：

```powershell
moon run cmd/main -- gate "login view login cart" "login login checkout refund"
```

参数建议：

```powershell
moon run cmd/main -- budget "login view login cart checkout refund user42 user43" 6
```

运行完整演示：

```powershell
.\scripts\demo.ps1
```

## MoonBit API 示例

```moonbit nocheck
///|
fn main {
  let report = @sketch.windowed_report_from_text(
    "login login view | view cart checkout | refund refund checkout",
  )
  println(@sketch.windowed_report_markdown(report))
}
```

可运行示例：

```powershell
moon run examples/basic
moon run examples/windowed
moon run examples/budget
```

## 测试集说明

仓库内置 `fixtures/` 目录，包含四类小样本：

- `fixtures/events.txt`：普通事件流，用于整体报告、Top-K、Bloom、Token Profile。
- `fixtures/windowed.txt`：带窗口分隔符的事件流，用于漂移报告和时间线。
- `fixtures/weighted.txt`：`key:weight` 加权事件，用于加权 Count-Min。
- `fixtures/numbers.txt`：数值序列，用于 Histogram 和 Quantile。

这些测试集不追求大数据量，而是追求可读、可复现、便于验收时手工检查。

## 项目性质

本项目为原创 MoonBit 实现。算法思想参考公开通用算法资料和业界常见 sketch 结构，但没有移植某个特定开源库，也没有复制第三方实现代码。

许可证：Apache-2.0。

## 参赛交付清单

- MoonBit 主要实现语言：核心库、CLI、示例和测试均为 MoonBit。
- README：包含项目目标、安装、使用、示例、测试集说明。
- CI：`.github/workflows/ci.yml` 覆盖 format、check、test、example run。
- 测试：覆盖核心算法和报告输出。
- 可运行示例：`cmd/main` 和 `examples/*`。
- 开源许可证：`LICENSE`。
- mooncakes.io：上传仓库后再执行 `moon register` / `moon login` / `moon publish`。
