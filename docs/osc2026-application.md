# Moon Sketch Kit 项目申报书

- 项目名称：Moon Sketch Kit
- GitHub 仓库链接：`https://github.com/cauchyQ/moon-sketch-kit`
- GitLink 仓库链接：`https://www.gitlink.org.cn/cauchyQ/moon-sketch-kit`
- 项目方向：MoonBit 流式近似分析基础库 / 简易图表数据生成和预览
- 项目性质：原创项目

## 项目简介

Moon Sketch Kit 是一个用 MoonBit 实现的流式 sketch 工具箱。它面向日志、埋点、监控样本和轻量数据分析场景，用较小内存生成事件频率、唯一值估计、Top-K、样本抽取、数值分布、窗口漂移和质量门报告。项目同时提供 MoonBit API、CLI、示例、测试、Markdown/JSON 输出，方便接入命令行、Web 预览或 CI 数据质量检查。

## 适用场景

项目适用于需要快速了解一段事件流“发生了什么”的场景：例如统计高频埋点、比较两个版本日志是否漂移、估计唯一用户规模、检查 Bloom Filter 误判率、生成简单图表预览数据，或在 MoonBit 项目中作为可复用基础库使用。

## 拟实现核心功能

- Count-Min Sketch、Bloom Filter、HyperLogLog-lite、MinHash、Space-Saving Top-K、Reservoir Sampling；
- Histogram、Quantile、Weighted Event、Token Profile 和 Budget Planner；
- Windowed Stream 报告，用 `|` 或 `;` 分隔窗口并输出趋势、尖峰和 Top-K 时间线；
- Quality Gate，比较 baseline / candidate 并给出 pass/fail、问题列表和修复建议；
- CLI、MoonBit 示例、fixtures、README、CI 和完整测试。

## 原创或参考说明

本项目为原创 MoonBit 实现。算法思想来自公开通用算法和数据流 sketch 领域的常见结构，没有移植某个特定开源项目，也没有复制第三方源码。项目采用 Apache-2.0 许可证开源。
