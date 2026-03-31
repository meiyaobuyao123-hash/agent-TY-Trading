<!-- Badges -->
[![Build Status](https://img.shields.io/github/actions/workflow/status/ty-trading/ty/ci.yml?branch=main&style=flat-square)](https://github.com/ty-trading/ty/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Contributors](https://img.shields.io/github/contributors/ty-trading/ty?style=flat-square)](https://github.com/ty-trading/ty/graphs/contributors)
[![Stars](https://img.shields.io/github/stars/ty-trading/ty?style=flat-square)](https://github.com/ty-trading/ty/stargazers)

<div align="center">

# TY (天演) -- 自演化金融世界模型

**一个开源、自演化的 AI 系统，从数学第一性原理出发，感知、推理并交易所有金融市场。**

[架构蓝图](docs/world-model-blueprint-zh.md) | [免费数据源](docs/free-data-sources-research-zh.md) | [贡献指南](CONTRIBUTING_zh.md) | [English](README.md)

</div>

---

## 为什么选择 TY？

大多数交易系统都是曲线拟合的流水线：抓数据、训模型、部署、然后看着它衰减。TY 采用了根本不同的方法。

**市场是信息处理系统。** 价格不是事实 -- 它是数百万个代理人在不确定性下更新信念后的压缩输出。TY 基于三个数学框架从第一性原理对此建模：

- **信息论** -- 利润来自在市场之前正确估计信息惊奇度（surprisal）。你的优势是你的后验分布与市场后验分布之间的 KL 散度。
- **博弈论** -- 价格是不完全信息下策略行为的 Nash 均衡，而非"正确"的值。系统建模递归信念结构（别人相信别人相信什么）。
- **贝叶斯推断** -- 显式概率分布，从不使用点估计。对模型不确定性设置先验。当证据到达时通过贝叶斯法则更新信念。

TY 不预测价格。它维护一个**世界模型** -- 一个关于经济体、市场和参与者如何互动的因果图 -- 并随着世界变化持续演化该模型。当模型的信念偏离市场价格时，这种偏离就是优势。

"天演"之名取自"天道演化" -- 系统如同自然演化生物体一般演化自身的理解：通过变异、选择与适应。

---

## 四层架构

```
┌─────────────────────────────────────────────────────────┐
│  第四层: 执行引擎                                         │
│  投资组合优化 · 风险管理 · 订单路由                          │
│  仓位管理 · 多场所执行                                     │
├─────────────────────────────────────────────────────────┤
│  第三层: 推理与决策                                        │
│  因果推断 · 贝叶斯更新 · 博弈论建模                         │
│  市场机制检测 · 反身性分析                                  │
├─────────────────────────────────────────────────────────┤
│  第二层: 世界模型                                         │
│  因果图 · 实体关系 · 宏观状态                               │
│  跨市场依赖 · 信念分布                                     │
├─────────────────────────────────────────────────────────┤
│  第一层: 感知层                                           │
│  链上数据 · 订单流 · 社交情绪                               │
│  经济指标 · 新闻 · 预测市场                                 │
└─────────────────────────────────────────────────────────┘
```

| 层级 | 目的 | 关键技术 |
|---|---|---|
| **感知层** | 从所有市场采集并标准化数据 | DeFiLlama, Binance WS, FRED, AKShare, Polymarket, Dune |
| **世界模型** | 维护市场结构的因果理解 | 贝叶斯网络、因果 DAG、知识图谱 |
| **推理层** | 生成假设、评估优势、做出决策 | 概率编程、博弈论求解器 |
| **执行层** | 将决策转化为盈利交易 | 智能订单路由、风险限额、投资组合优化 |

---

## 快速开始

### 前置要求

- Python 3.11+
- Git

### 安装

```bash
# 克隆仓库
git clone https://github.com/ty-trading/ty.git
cd ty

# 创建虚拟环境
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt

# 复制环境变量模板
cp .env.example .env
# 编辑 .env 填入你的 API key（大部分数据源是免费的）
```

### 运行第一次分析

```bash
# 启动感知层（数据采集）
python -m ty.perception.start

# 运行世界模型更新
python -m ty.world_model.update

# 生成交易信号
python -m ty.reasoning.signals
```

### 配置

所有配置位于 `config/` 目录。关键文件：

| 文件 | 用途 |
|---|---|
| `config/data_sources.yaml` | 启用/禁用数据源，设置 API key |
| `config/world_model.yaml` | 因果图结构，先验分布 |
| `config/risk.yaml` | 仓位限额，最大回撤阈值，熔断开关 |
| `config/execution.yaml` | 场所配置，订单类型，滑点模型 |

---

## 文档

| 文档 | 说明 |
|---|---|
| [架构蓝图 (中文)](docs/world-model-blueprint-zh.md) | 完整系统设计与数学基础 |
| [架构蓝图 (English)](docs/world-model-blueprint.md) | Complete system design with mathematical foundations |
| [免费数据源调研 (中文)](docs/free-data-sources-research-zh.md) | 30+ 免费数据 API 深度调研 |
| [免费数据源调研 (English)](docs/free-data-sources-research.md) | Deep research on 30+ free data APIs |
| [贡献指南 (中文)](CONTRIBUTING_zh.md) | 如何贡献 TY 项目 |
| [贡献指南 (English)](CONTRIBUTING.md) | How to contribute to TY |

---

## 如何贡献

我们欢迎交易员、研究者和工程师的贡献。完整指南请查看 [CONTRIBUTING_zh.md](CONTRIBUTING_zh.md)。

简要概述：

1. Fork 仓库并创建功能分支
2. 为你的更改编写测试
3. 提交 PR 并附上清晰的描述
4. 回应代码审查反馈

我们特别需要帮助的领域：

- **数据插件** -- 新数据源的连接器
- **因果模型** -- 特定市场的领域专业知识
- **回测** -- 策略的历史验证
- **文档** -- 教程、示例、翻译

---

## 路线图

- [x] 架构蓝图
- [x] 免费数据源调研
- [ ] 感知层（数据采集框架）
- [ ] 世界模型核心（因果图引擎）
- [ ] 推理引擎（贝叶斯决策系统）
- [ ] 执行引擎（模拟交易）
- [ ] 插件系统（社区扩展）
- [ ] 实盘交易（带安全保护）

---

## 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE)。

---

<div align="center">

**TY (天演)** -- 因为市场在演化，你的交易系统也应当如此。

</div>
