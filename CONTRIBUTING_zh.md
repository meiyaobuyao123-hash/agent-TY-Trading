# 贡献 TY (天演)

感谢你有兴趣为 TY 做出贡献！本指南将帮助你快速完成环境搭建并开始有意义的贡献。

---

## 目录

- [开发环境搭建](#开发环境搭建)
- [5 分钟创建一个插件](#5-分钟创建一个插件)
- [Pull Request 流程](#pull-request-流程)
- [代码风格](#代码风格)
- [测试要求](#测试要求)
- [沟通渠道](#沟通渠道)

---

## 开发环境搭建

### 前置要求

| 工具 | 版本 | 用途 |
|---|---|---|
| Python | 3.11+ | 核心引擎运行时 |
| Node.js | 20+ | 可选：TypeScript 插件运行时 |
| Git | 2.30+ | 版本管理 |
| Docker | 24+ | 可选：容器化开发 |

> **注意：** TY 是一个多语言项目。核心引擎使用 Python，但插件可以用 Python 或 TypeScript 编写——两者都是一等公民。详见 [open-architecture.md](docs/open-architecture.md) 了解插件系统。

### 逐步搭建

```bash
# 1. Fork 并克隆仓库
git clone https://github.com/<your-username>/ty.git
cd ty

# 2. 创建虚拟环境
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 3. 安装依赖（包括开发工具）
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 4. 安装 pre-commit hooks
pre-commit install

# 5. 复制环境变量模板并配置
cp .env.example .env
# 编辑 .env 填入你的 API key

# 6. 验证安装
python -m pytest tests/ -v
```

### IDE 配置

推荐使用 VS Code 或 PyCharm，并安装以下扩展/插件：

- **Ruff** -- 代码检查和格式化
- **mypy** -- 类型检查
- **Python Test Explorer** -- 测试运行器集成

---

## 5 分钟创建一个插件

TY 的感知层基于插件架构构建。每个数据源都是一个实现简单接口的插件。

### 第 1 步：创建插件文件

```bash
mkdir -p plugins/my_data_source
touch plugins/my_data_source/__init__.py
touch plugins/my_data_source/plugin.py
```

### 第 2 步：实现接口

```python
# plugins/my_data_source/plugin.py

from ty.perception.base import DataSourcePlugin, DataPoint

class MyDataSourcePlugin(DataSourcePlugin):
    """从 MyDataSource 采集数据的插件。"""

    name = "my_data_source"
    version = "0.1.0"
    category = "on_chain"  # on_chain | sentiment | economic | order_flow

    async def setup(self, config: dict) -> None:
        """初始化连接，验证 API key。"""
        self.api_key = config.get("api_key")
        self.base_url = "https://api.example.com"

    async def fetch(self) -> list[DataPoint]:
        """获取最新数据。按计划调度调用。"""
        # 你的数据获取逻辑
        response = await self.http_get(f"{self.base_url}/data")
        return [
            DataPoint(
                source=self.name,
                timestamp=item["timestamp"],
                metric=item["metric"],
                value=item["value"],
                metadata={"raw": item},
            )
            for item in response["data"]
        ]

    async def teardown(self) -> None:
        """清理资源。"""
        pass
```

### 第 3 步：注册插件

```yaml
# config/data_sources.yaml
plugins:
  my_data_source:
    enabled: true
    schedule: "*/5 * * * *"  # 每 5 分钟
    config:
      api_key: "${MY_DATA_SOURCE_API_KEY}"
```

### 第 4 步：编写测试

```python
# tests/plugins/test_my_data_source.py

import pytest
from plugins.my_data_source.plugin import MyDataSourcePlugin

@pytest.mark.asyncio
async def test_fetch_returns_data_points():
    plugin = MyDataSourcePlugin()
    await plugin.setup({"api_key": "test_key"})
    data = await plugin.fetch()
    assert len(data) > 0
    assert all(d.source == "my_data_source" for d in data)

@pytest.mark.asyncio
async def test_handles_api_failure_gracefully():
    plugin = MyDataSourcePlugin()
    await plugin.setup({"api_key": "invalid"})
    # 不应抛出异常，应返回空列表或记录警告
    data = await plugin.fetch()
    assert isinstance(data, list)
```

### 第 5 步：提交

```bash
git checkout -b feat/plugin-my-data-source
git add plugins/my_data_source/ tests/plugins/test_my_data_source.py
git commit -m "feat(plugin): add MyDataSource data connector"
git push origin feat/plugin-my-data-source
# 在 GitHub 上创建 PR
```

---

## Pull Request 流程

### 提交前准备

1. **从 `main` 创建功能分支**：
   ```bash
   git checkout -b feat/your-feature-name
   # 或: fix/bug-description, docs/topic, refactor/module
   ```

2. **为所有更改编写或更新测试**

3. **在本地运行完整测试套件**：
   ```bash
   python -m pytest tests/ -v --cov=ty --cov-report=term-missing
   ```

4. **运行代码检查和类型检查**：
   ```bash
   ruff check .
   ruff format --check .
   mypy ty/
   ```

5. **编写清晰的 commit message**，遵循 conventional commits 规范：
   ```
   feat(perception): add Binance WebSocket order book plugin
   fix(world-model): correct Bayesian update for multi-asset case
   docs(readme): add Chinese translation
   refactor(execution): simplify order routing logic
   test(reasoning): add edge case tests for regime detection
   ```

### PR 模板

创建 PR 时，请包含：

- **摘要**：1-3 个要点描述变更内容
- **动机**：为什么需要这个变更
- **测试计划**：如何验证变更有效
- **破坏性变更**：任何不向后兼容的变更（如适用）

### 审查流程

1. 所有 PR 需要至少 **1 个批准的审查**
2. CI 必须通过（测试、代码检查、类型检查）
3. 维护者可能会要求修改 -- 请及时处理
4. 批准后，维护者将使用 squash-merge 合并

---

## 代码风格

### 总体原则

- **清晰优于聪明** -- 写出像结构良好的散文一样易读的代码
- **显式优于隐式** -- 处处使用类型提示，不要使用魔法全局变量
- **小函数** -- 每个函数只做一件事，理想情况下不超过 30 行

### Python 风格

| 规则 | 工具 | 配置 |
|---|---|---|
| 格式化 | Ruff (format) | `pyproject.toml` |
| 代码检查 | Ruff (check) | `pyproject.toml` |
| 类型检查 | mypy (strict) | `mypy.ini` |
| Import 排序 | Ruff (isort) | `pyproject.toml` |

### 命名约定

| 实体 | 约定 | 示例 |
|---|---|---|
| 文件/模块 | `snake_case` | `order_book_parser.py` |
| 类 | `PascalCase` | `BinanceWebSocketPlugin` |
| 函数/方法 | `snake_case` | `fetch_order_book()` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| 类型变量 | `PascalCase` | `DataPointT` |

### 文档字符串

使用 Google 风格文档字符串：

```python
def calculate_surprisal(probability: float) -> float:
    """计算给定概率的信息惊奇度。

    使用 Shannon 公式: I(x) = -log2(P(x))。

    Args:
        probability: 事件概率，必须在 (0, 1] 范围内。

    Returns:
        以 bit 为单位的惊奇度。

    Raises:
        ValueError: 如果 probability 不在 (0, 1] 范围内。
    """
```

---

## 测试要求

### 覆盖率

- 所有新代码必须有测试
- 目标：新模块 **90%+ 行覆盖率**
- 关键路径（执行、风险管理）要求 **100% 覆盖率**

### 测试结构

```
tests/
├── unit/              # 快速、隔离的测试（无 I/O）
│   ├── test_bayesian.py
│   └── test_causal_graph.py
├── integration/       # 使用真实（mock）数据流的测试
│   ├── test_perception_pipeline.py
│   └── test_world_model_update.py
├── plugins/           # 插件专属测试
│   ├── test_defillama.py
│   └── test_binance_ws.py
└── conftest.py        # 共享 fixtures
```

### 运行测试

```bash
# 运行所有测试
python -m pytest tests/ -v

# 运行并生成覆盖率报告
python -m pytest tests/ -v --cov=ty --cov-report=html

# 运行特定测试文件
python -m pytest tests/unit/test_bayesian.py -v

# 运行匹配模式的测试
python -m pytest tests/ -k "test_order_book" -v
```

### 测试指南

- 使用 `pytest` fixtures 进行 setup/teardown
- Mock 外部 API -- 测试中绝不调用真实 API
- 异步测试使用 `pytest.mark.asyncio`
- 尽可能参数化测试以覆盖边界情况
- 每个测试应独立且幂等

---

## 沟通渠道

| 渠道 | 用途 | 链接 |
|---|---|---|
| **GitHub Issues** | Bug 报告、功能请求 | [Issues](https://github.com/ty-trading/ty/issues) |
| **GitHub Discussions** | 架构讨论、问答 | [Discussions](https://github.com/ty-trading/ty/discussions) |
| **Discord** | 实时聊天、社区 | 即将上线 |
| **微信群** | 中文社区 | 即将上线 |

### 报告 Bug

使用 GitHub Issues 模板。请包含：
- 复现步骤
- 预期行为 vs 实际行为
- Python 版本、操作系统、相关配置

### 提议功能

在实现大型功能前，请先发起 GitHub Discussion 收集反馈。请包含：
- 问题陈述
- 建议方案
- 考虑过的替代方案

---

## 许可证

通过贡献，你同意你的贡献将在 MIT 许可证下授权。

---

感谢你帮助构建算法交易的未来！
