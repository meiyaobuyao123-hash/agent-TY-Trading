# 天演 TY — 自进化AI金融世界模型

> Self-evolving AI Financial World Model

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)

---

## 愿景

天演（TY）是一个开源的自进化AI金融分析系统。它持续感知全球市场、生成方向性判断、追踪自身准确率，并通过反馈循环不断进化。系统名称取自"天演论"（自然进化），寓意AI通过不断学习和适应来提升自身对市场的理解。

---

## 系统架构

```
┌─────────────────────────────────────────────────────────┐
│  第4层: 自进化引擎 (SELF-EVOLVER)                        │
│  准确率追踪 · 置信度自校准 · 从错误中学习               │
├─────────────────────────────────────────────────────────┤
│  第3层: 偏差检测器 (BIAS DETECTOR)                       │
│  价格偏差计算 · 合理价格对比 · 偏差信号生成              │
├─────────────────────────────────────────────────────────┤
│  第2层: AI推理引擎 (REASONING ENGINE)                    │
│  DeepSeek多模型共识 · 方向判断 · 中文市场分析            │
├─────────────────────────────────────────────────────────┤
│  第1层: 世界感知器 (WORLD PERCEIVER)                     │
│  Binance · AKShare · YFinance/Stooq · Frankfurter ·     │
│  Polymarket · FRED                                      │
└─────────────────────────────────────────────────────────┘
```

| 层级 | 功能 | 插件 |
|---|---|---|
| **世界感知器** | 从6个数据源获取全球市场数据 | Binance, AKShare, YFinance/Stooq, Frankfurter, Polymarket, FRED |
| **AI推理引擎** | 多模型共识判断方向与置信度 | DeepSeek（可扩展 GPT-4o, Gemini） |
| **偏差检测器** | 计算市场价格与AI合理价格的偏差 | 偏差计算器 |
| **自进化引擎** | 追踪准确率，自动结算判断 | 准确率追踪器 |

---

## 功能特性

- **108个全球市场覆盖** — 加密货币 / 美股 / 港股 / A股 / 外汇 / 商品 / 指数 / 宏观指标 / 预测市场
- **6个数据源** — Binance, AKShare, YFinance/Stooq, Frankfurter, Polymarket, FRED
- **AI多模型共识判断** — 当前: DeepSeek；架构支持 GPT-4o, Gemini 并行调用
- **自进化反馈循环** — 判断到期后自动结算，从错误中学习，置信度自校准
- **中文AI分析** — 所有推理和分析均以中文输出，市场类型专属分析策略
- **准确率追踪** — 分市场类型统计准确率，进化趋势可视化
- **AI洞察** — 最高置信信号、最大偏差、连续正确记录
- **开放插件架构** — 可贡献自定义数据源和AI模型插件
- **Apple风格iOS App** — Flutter构建，极简白底中文界面

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

## API 文档

所有接口前缀: `/api/ty/`（通过 nginx 代理）

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 系统健康状态、插件状态、运行时间 |
| GET | `/markets` | 所有跟踪市场列表（含最新快照） |
| GET | `/markets/{symbol}` | 单个市场详情 |
| GET | `/markets/{symbol}/snapshots` | 市场价格历史快照 |
| GET | `/judgments/latest?brief=true` | 每个市场最新AI判断 |
| GET | `/judgments?page=1&page_size=20` | 分页查询判断历史 |
| GET | `/judgments/{id}` | 单个判断详情 |
| POST | `/judgments/trigger` | 手动触发AI判断周期 |
| GET | `/accuracy` | 分市场类型准确率统计 |
| GET | `/stats/overview` | 系统总览（运行天数、总判断数、准确率） |
| GET | `/stats/insights` | AI洞察（最高置信、最大偏差、连续正确） |
| GET | `/stats/accuracy-history` | 准确率历史趋势数据 |

---

## 技术栈

| 组件 | 技术 |
|---|---|
| 后端 | Python, FastAPI, PostgreSQL, SQLAlchemy (async), APScheduler |
| 前端 | Flutter, Riverpod, fl_chart, go_router |
| AI | DeepSeek（可扩展 GPT-4o, Gemini） |
| 部署 | Ubuntu, systemd, nginx, rsync |

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
