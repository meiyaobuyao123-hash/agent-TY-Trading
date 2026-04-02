# 贡献指南 — TY (天演)

感谢你对天演项目的关注！本指南将帮助你快速上手开发和贡献。

---

## 目录

- [后端开发环境搭建](#后端开发环境搭建)
- [Flutter App 开发环境搭建](#flutter-app-开发环境搭建)
- [添加数据源插件](#添加数据源插件)
- [添加AI模型](#添加ai模型)
- [添加新市场](#添加新市场)
- [Pull Request 流程](#pull-request-流程)
- [代码风格](#代码风格)

---

## 后端开发环境搭建

### 前置条件

| 工具 | 版本 | 用途 |
|---|---|---|
| Python | 3.11+ | 后端运行时 |
| PostgreSQL | 14+ | 数据库 |
| Git | 2.30+ | 版本管理 |

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/project-ty/tianyan.git
cd tianyan

# 2. 创建虚拟环境
python -m venv .venv
source .venv/bin/activate

# 3. 安装依赖
pip install -r backend/requirements.txt

# 4. 配置环境变量
cp .env.example .env
# 编辑 .env，至少填入:
#   DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/finance_nav_db
#   DEEPSEEK_API_KEY=your_deepseek_api_key

# 5. 初始化数据库
psql -f infra/schema.sql
psql -f infra/seed_markets.sql

# 6. 启动后端
uvicorn backend.main:app --host 0.0.0.0 --port 8003 --reload

# 7. 验证
curl http://localhost:8003/health
```

### 运行测试

```bash
python -m pytest backend/tests/ -v
```

---

## Flutter App 开发环境搭建

### 前置条件

| 工具 | 版本 | 用途 |
|---|---|---|
| Flutter | 3.22+ | App 框架 |
| Dart | 3.4+ | 编程语言 |
| Xcode | 15+ | iOS 构建（macOS） |

### 安装步骤

```bash
# 1. 进入 app 目录
cd app

# 2. 安装依赖
flutter pub get

# 3. 修改 API 地址（可选，默认指向生产服务器）
# 编辑 lib/core/config/api_config.dart

# 4. 运行
flutter run

# 5. 静态分析
flutter analyze
```

### 项目结构

```
app/lib/
├── core/
│   ├── config/         # API 配置
│   ├── providers/      # Dio HTTP provider
│   ├── router/         # GoRouter 路由
│   └── theme/          # AppTheme 主题常量
├── features/
│   ├── dashboard/      # 首页仪表盘
│   ├── markets/        # 市场列表
│   ├── market_detail/  # 市场详情
│   ├── accuracy/       # 准确率进化页
│   └── settings/       # 设置页
├── shared/
│   ├── models/         # 数据模型
│   └── widgets/        # 共用组件
└── main.dart
```

---

## 添加数据源插件

天演的数据层采用插件架构。每个数据源是一个 `DataSourcePlugin` 子类。

### 第1步：创建插件文件

```bash
touch backend/plugins/data_sources/my_source.py
```

### 第2步：实现接口

```python
# backend/plugins/data_sources/my_source.py

from backend.core.plugin_base import DataSourcePlugin
from backend.core.types import DataQuery, MarketData, MarketTick, MarketType

class MyDataSource(DataSourcePlugin):
    """我的自定义数据源。"""

    @property
    def name(self) -> str:
        return "my-source"

    @property
    def display_name(self) -> str:
        return "我的数据源"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]  # 支持的市场类型

    async def initialize(self, config: dict) -> None:
        """初始化，读取 API key 等配置。"""
        self.api_key = config.get("my_api_key", "")

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        """根据查询条件获取市场数据。"""
        # 实现你的数据获取逻辑
        # 返回 MarketData 列表
        return []

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """获取指定 symbol 的实时行情。"""
        # 返回 MarketTick 列表，包含 symbol, price, volume, change_pct
        return []

    async def health_check(self) -> bool:
        """健康检查 — 返回 True 表示数据源可用。"""
        return True
```

### 第3步：注册插件

在 `backend/main.py` 的 `lifespan()` 函数中添加:

```python
from backend.plugins.data_sources.my_source import MyDataSource
pm.register_data_source(MyDataSource())
```

### 第4步：编写测试

```python
# backend/tests/test_my_source.py

import pytest
from backend.plugins.data_sources.my_source import MyDataSource

@pytest.mark.asyncio
async def test_health_check():
    plugin = MyDataSource()
    await plugin.initialize({})
    assert await plugin.health_check() is True
```

### 现有数据源参考

| 文件 | 数据源 | 市场类型 |
|---|---|---|
| `binance_ws.py` | Binance REST API | 加密货币 |
| `akshare_cn.py` | AKShare | A股、港股、国内指数 |
| `yfinance_global.py` | YFinance/Stooq | 美股、全球指数、商品 |
| `frankfurter_fx.py` | Frankfurter API | 外汇 |
| `polymarket_gamma.py` | Polymarket Gamma | 预测市场 |
| `fred_macro.py` | FRED API | 宏观经济指标 |

---

## 添加AI模型

天演的AI推理层支持多模型并行调用和共识判断。

### 第1步：在 `ai_client.py` 中添加调用函数

```python
# backend/core/ai_client.py

async def _call_my_model(prompt: str, system: str = "") -> Optional[dict]:
    """调用自定义AI模型。"""
    if not settings.MY_MODEL_API_KEY:
        logger.warning("MY_MODEL_API_KEY not set — skipping")
        return None
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            # 实现你的 API 调用
            resp = await client.post(
                "https://api.example.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.MY_MODEL_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "my-model",
                    "messages": [
                        {"role": "system", "content": system},
                        {"role": "user", "content": prompt},
                    ],
                    "max_tokens": 1024,
                    "temperature": 0.3,
                },
            )
            resp.raise_for_status()
            data = resp.json()
            text = data["choices"][0]["message"]["content"]
            return _parse_json_response(text, "my-model")
    except Exception:
        logger.exception("My model API call failed")
        return None
```

### 第2步：加入并行调用

在 `call_all_models()` 函数中添加你的模型:

```python
async def call_all_models(prompt: str, system: str = "") -> list[dict]:
    results = await asyncio.gather(
        _call_deepseek(prompt, system),
        _call_openai(prompt, system),
        _call_gemini(prompt, system),
        _call_my_model(prompt, system),  # <-- 新增
        return_exceptions=True,
    )
    ...
```

### 第3步：添加 API Key 配置

在 `backend/config.py` 的 `Settings` 类中添加:

```python
MY_MODEL_API_KEY: str = ""
```

AI 模型的返回格式必须是 JSON:

```json
{
  "direction": "up",
  "confidence": 0.7,
  "rational_price": 69500.0,
  "reasoning": "分析推理文本..."
}
```

---

## 添加新市场

### 第1步：在种子数据中添加

编辑 `infra/seed_markets.sql`，添加新的 market 记录:

```sql
INSERT INTO ty.markets (id, symbol, name, market_type, source, is_active)
VALUES (
    gen_random_uuid(),
    'TSLA',                        -- 交易代号
    'Tesla (特斯拉)',               -- 显示名称（含中文）
    'us-equities',                 -- 市场类型
    'yfinance',                    -- 数据来源插件名
    true
) ON CONFLICT (symbol) DO NOTHING;
```

### 第2步：确保数据源支持

确认对应的数据源插件（如 `yfinance_global.py`）能获取该 symbol 的数据。

### 市场类型列表

| market_type | 说明 | 数据源 |
|---|---|---|
| `crypto` | 加密货币 | binance |
| `cn-equities` | A股 | akshare |
| `us-equities` | 美股 | yfinance |
| `hk-equities` | 港股 | yfinance |
| `global-indices` | 全球指数 | akshare, yfinance |
| `forex` | 外汇 | frankfurter |
| `commodities` | 商品 | yfinance |
| `macro` | 宏观指标 | fred |
| `prediction-markets` | 预测市场 | polymarket |

---

## Pull Request 流程

### 提交前检查

1. **创建功能分支**: `git checkout -b feat/your-feature`
2. **编写测试**: 所有新功能需要测试
3. **运行测试**: `python -m pytest backend/tests/ -v`
4. **Flutter 分析**: `cd app && flutter analyze`
5. **清晰的 commit 消息**:
   ```
   feat(plugin): 添加 xxx 数据源插件
   fix(accuracy): 修复准确率计算边界情况
   docs(readme): 更新 API 文档
   ```

### PR 模板

- **概要**: 1-3 点描述变更内容
- **动机**: 为什么需要这个变更
- **测试计划**: 如何验证变更有效

---

## 代码风格

### Python

- 使用类型注解
- 异步函数使用 `async/await`
- 每个函数保持简短（< 30 行）
- 文件名使用 `snake_case`

### Dart/Flutter

- 使用 AppTheme 中的颜色常量，不要硬编码颜色
- 所有用户可见文本使用中文
- 遵循 Flutter lint 规则
- Widget 使用 `const` 构造函数

---

## 许可证

参与贡献即表示你同意你的代码将以 MIT License 发布。
