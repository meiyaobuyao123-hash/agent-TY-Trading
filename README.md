# 天演 TY v3.0.0 — 自进化AI金融世界模型

> Self-evolving AI Financial World Model — 30轮AI驱动迭代，通宵开发马拉松成果

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Version](https://img.shields.io/badge/version-3.0.0-green.svg?style=flat-square)]()
[![Markets](https://img.shields.io/badge/markets-342-orange.svg?style=flat-square)]()
[![Judgments](https://img.shields.io/badge/judgments-555%2B-blue.svg?style=flat-square)]()

---

## 愿景

天演（TY）是一个开源的自进化AI金融分析系统。它持续感知全球市场、生成方向性判断、追踪自身准确率，并通过反馈循环不断进化。系统名称取自"天演论"（自然进化），寓意AI通过不断学习和适应来提升自身对市场的理解。

**v3.0.0 里程碑**：经过30轮AI驱动的通宵迭代开发，系统从初始原型演进为覆盖342个市场、19种类型、7个数据源的完整金融世界模型，累计生成555+条AI判断，Brier校准分数0.21。

---

## 核心数据

| 指标 | 数值 |
|---|---|
| 覆盖市场 | **342个** |
| 市场类型 | **19种**（加密货币/美股/A股/港股/日股/欧股/外汇/商品/指数/宏观/预测市场等） |
| 数据源 | **7个**（Binance/AKShare/YFinance/Frankfurter/Polymarket/FRED/Fear&Greed） |
| 累计判断 | **555+条** |
| Brier分数 | **0.21**（越低越好，完美校准=0） |
| 迭代轮次 | **30轮** |
| API端点 | **31个** |

---

## 系统架构（L1-L4四层）

```
┌─────────────────────────────────────────────────────────────┐
│  L4: 自进化引擎 (SELF-EVOLVER)                    ★★★★★    │
│  准确率追踪 · Brier概率校准 · 策略基因组进化              │
│  置信度自校准 · 偏差干预 · 从错误中学习                   │
├─────────────────────────────────────────────────────────────┤
│  L3: 偏差检测器 (BIAS DETECTOR)                   ★★★★☆    │
│  价格偏差计算 · 波动率归一化 · 合理价格对比               │
│  偏差显著性评分 · 认知偏差识别与自动干预                   │
├─────────────────────────────────────────────────────────────┤
│  L2: AI推理引擎 (REASONING ENGINE)                ★★★★★    │
│  DeepSeek多模型共识 · 方向+概率判断 · 中文市场分析        │
│  市场体制识别 · 质量评分 · 多维度推理                     │
├─────────────────────────────────────────────────────────────┤
│  L1: 世界感知器 (WORLD PERCEIVER)                 ★★★★★    │
│  Binance · AKShare · YFinance · Frankfurter ·             │
│  Polymarket · FRED · Fear&Greed                           │
└─────────────────────────────────────────────────────────────┘
```

| 层级 | 功能 | 评分 | 插件 |
|---|---|---|---|
| **L1 世界感知器** | 从7个数据源获取342个全球市场数据 | ★★★★★ | Binance, AKShare, YFinance, Frankfurter, Polymarket, FRED, Fear&Greed |
| **L2 AI推理引擎** | 多模型共识判断方向、概率与置信度 | ★★★★★ | DeepSeek（可扩展 GPT-4o, Gemini） |
| **L3 偏差检测器** | 计算价格偏差，识别认知偏差并自动干预 | ★★★★☆ | 偏差计算器, 偏差干预器 |
| **L4 自进化引擎** | 追踪准确率，Brier校准，策略基因组进化 | ★★★★★ | 准确率追踪器, 基因组进化器 |

---

## 功能特性

- **342个全球市场覆盖** — 加密货币/美股/港股/A股/日股/欧股/外汇/商品/指数/宏观指标/预测市场/国企等19种类型
- **7个数据源** — Binance, AKShare, YFinance, Frankfurter, Polymarket, FRED, Fear&Greed
- **AI多模型共识判断** — 当前: DeepSeek；架构支持 GPT-4o, Gemini 并行调用
- **概率分布预测** — 看涨/看跌/观望三向概率分布，Brier分数校准
- **自进化反馈循环** — 判断到期后自动结算，从错误中学习，置信度自校准
- **策略基因组进化** — L4级自进化，策略参数通过遗传算法自动优化
- **偏差识别与干预** — 自动检测动量偏差、锚定偏差等，干预过高/过低置信度
- **中文AI分析** — 所有推理和分析均以中文输出，市场类型专属分析策略
- **准确率追踪** — 分市场类型、分时段、分置信度统计准确率
- **AI洞察与发现** — 最高置信信号、最大偏差、连续正确记录、异常发现
- **校准诊断** — 概率校准曲线、分桶准确率分析
- **日报系统** — 每日自动生成AI分析日报，支持分享
- **Apple风格iOS App** — Flutter构建，极简白底中文界面，深色模式支持
- **开放插件架构** — 可贡献自定义数据源和AI模型插件
- **通宵迭代开发** — 30轮AI驱动的持续迭代，从原型到生产级系统

---

## 快速开始

### 后端开发

```bash
# 克隆仓库
git clone https://github.com/project-ty/tianyan.git
cd tianyan

# 创建虚拟环境
python -m venv .venv
source .venv/bin/activate

# 安装依赖
pip install -r backend/requirements.txt

# 配置环境变量
cp .env.example .env
# 编辑 .env 填入:
#   DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/dbname
#   DEEPSEEK_API_KEY=your_key
#   FRED_API_KEY=your_key (可选)

# 创建数据库 schema 和种子数据
psql -f infra/schema.sql
psql -f infra/seed_markets.sql

# 启动后端
uvicorn backend.main:app --host 0.0.0.0 --port 8003 --reload
```

### Flutter App 开发

```bash
cd app

# 安装依赖
flutter pub get

# 修改 API 地址（可选）
# 编辑 lib/core/config/api_config.dart 中的 baseUrl

# 运行
flutter run
```

---

## API 文档（31个端点）

所有接口前缀: `/api/ty/`（通过 nginx 代理）

### 核心端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 系统健康状态、插件状态、运行时间、内存占用 |
| GET | `/markets` | 所有跟踪市场列表（含最新快照） |
| GET | `/markets/{symbol}` | 单个市场详情 |
| GET | `/markets/{symbol}/snapshots` | 市场价格历史快照 |
| GET | `/markets/{symbol}/related` | 关联市场推荐 |
| POST | `/markets` | 创建新市场 |
| POST | `/markets/cleanup-inactive` | 清理非活跃市场 |

### 判断端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/judgments` | 分页查询判断历史 |
| GET | `/judgments/latest` | 每个市场最新AI判断 |
| GET | `/judgments/{id}` | 单个判断详情 |
| POST | `/judgments/trigger` | 手动触发AI判断周期 |

### 准确率端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/accuracy` | 分市场类型准确率统计 |
| GET | `/accuracy/calibration` | 概率校准数据 |
| GET | `/accuracy/{market_type}` | 单个市场类型准确率 |

### 统计与洞察端点

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/stats/overview` | 系统总览（运行天数、总判断数、准确率） |
| GET | `/stats/insights` | AI洞察（最高置信、最大偏差、连续正确） |
| GET | `/stats/accuracy-history` | 准确率历史趋势数据 |
| GET | `/stats/bias-report` | 偏差分析报告 |
| GET | `/stats/genome-status` | 策略基因组进化状态 |
| GET | `/stats/accuracy-by-hour` | 分时段准确率统计 |
| GET | `/stats/discoveries` | AI异常发现 |
| GET | `/stats/alerts` | 系统告警 |
| GET | `/stats/meta-insights` | 元洞察（系统自我分析） |
| GET | `/stats/daily-summary` | 每日摘要 |
| GET | `/stats/daily-report` | 完整日报 |
| GET | `/stats/global-view` | 全球市场视图 |
| GET | `/stats/market-stats/{symbol}` | 单个市场统计 |
| GET | `/stats/data-coverage` | 数据覆盖率 |
| GET | `/stats/sector-performance` | 板块表现 |
| GET | `/stats/calibration-diagnostics` | 校准诊断 |
| GET | `/stats/watchlist-alerts` | 自选股告警 |

---

## 插件开发

### 添加数据源插件

创建 `backend/plugins/data_sources/my_source.py`，继承 `DataSourcePlugin`:

```python
from backend.core.plugin_base import DataSourcePlugin
from backend.core.types import DataQuery, MarketData, MarketType

class MyDataSource(DataSourcePlugin):
    name = "my-source"
    display_name = "我的数据源"
    markets = [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        self.api_key = config.get("my_api_key", "")

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        # 获取数据逻辑
        return [...]

    async def health_check(self) -> bool:
        return True
```

然后在 `backend/main.py` 中注册:

```python
from backend.plugins.data_sources.my_source import MyDataSource
pm.register_data_source(MyDataSource())
```

### 添加AI模型

在 `backend/core/ai_client.py` 中添加新的 `_call_xxx()` 函数，然后将其加入 `call_all_models()` 的并行调用列表。

详细指南参见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 技术栈

| 组件 | 技术 |
|---|---|
| 后端 | Python 3.11, FastAPI, PostgreSQL, SQLAlchemy (async), APScheduler |
| 前端 | Flutter 3.x, Riverpod, fl_chart, go_router, Dio |
| AI | DeepSeek（可扩展 GPT-4o, Gemini） |
| 部署 | Ubuntu, systemd, nginx, rsync |
| 数据库 | PostgreSQL 15, 异步连接池 |

---

## 开发历程

天演 v3.0.0 是一次通宵AI驱动开发马拉松的成果。30轮迭代中，系统经历了：

1. **R1-R5**: 基础架构搭建，5个数据源接入，AI共识引擎
2. **R6-R10**: Flutter App 构建，Apple风格UI，市场详情页
3. **R11-R15**: 概率预测系统，Brier校准，偏差检测
4. **R16-R20**: 策略基因组进化，高级统计端点，日报系统
5. **R21-R25**: 数据覆盖扩展至342市场，校准诊断，板块分析
6. **R26-R30**: 深色模式，全面打磨，v3.0.0里程碑发布

---

## 贡献

欢迎参与共建！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解：

- 如何添加数据源插件
- 如何接入新的AI模型
- 如何添加新市场
- 开发环境搭建指南

---

## 许可证

MIT License. 详见 [LICENSE](LICENSE)。
