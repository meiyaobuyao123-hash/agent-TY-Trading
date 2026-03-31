# Contributing to TY (天演)

Thank you for your interest in contributing to TY! This guide will help you get set up and making meaningful contributions quickly.

---

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Create a Plugin in 5 Minutes](#create-a-plugin-in-5-minutes)
- [Pull Request Process](#pull-request-process)
- [Code Style](#code-style)
- [Testing Requirements](#testing-requirements)
- [Communication Channels](#communication-channels)

---

## Development Environment Setup

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Python | 3.11+ | Core runtime |
| Git | 2.30+ | Version control |
| Docker | 24+ | Optional: containerized development |

### Step-by-Step Setup

```bash
# 1. Fork and clone the repository
git clone https://github.com/<your-username>/ty.git
cd ty

# 2. Create a virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 3. Install dependencies (including dev tools)
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 4. Install pre-commit hooks
pre-commit install

# 5. Copy environment template and configure
cp .env.example .env
# Edit .env with your API keys

# 6. Verify installation
python -m pytest tests/ -v
```

### IDE Configuration

We recommend VS Code or PyCharm with the following extensions/plugins:

- **Ruff** -- linting and formatting
- **mypy** -- type checking
- **Python Test Explorer** -- test runner integration

---

## Create a Plugin in 5 Minutes

TY's perception layer is built on a plugin architecture. Each data source is a plugin that implements a simple interface.

### Step 1: Create the Plugin File

```bash
mkdir -p plugins/my_data_source
touch plugins/my_data_source/__init__.py
touch plugins/my_data_source/plugin.py
```

### Step 2: Implement the Interface

```python
# plugins/my_data_source/plugin.py

from ty.perception.base import DataSourcePlugin, DataPoint

class MyDataSourcePlugin(DataSourcePlugin):
    """Plugin for ingesting data from MyDataSource."""

    name = "my_data_source"
    version = "0.1.0"
    category = "on_chain"  # on_chain | sentiment | economic | order_flow

    async def setup(self, config: dict) -> None:
        """Initialize connections, validate API keys."""
        self.api_key = config.get("api_key")
        self.base_url = "https://api.example.com"

    async def fetch(self) -> list[DataPoint]:
        """Fetch latest data. Called on schedule."""
        # Your data fetching logic here
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
        """Clean up resources."""
        pass
```

### Step 3: Register the Plugin

```yaml
# config/data_sources.yaml
plugins:
  my_data_source:
    enabled: true
    schedule: "*/5 * * * *"  # Every 5 minutes
    config:
      api_key: "${MY_DATA_SOURCE_API_KEY}"
```

### Step 4: Write Tests

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
    # Should not raise, should return empty or log warning
    data = await plugin.fetch()
    assert isinstance(data, list)
```

### Step 5: Submit

```bash
git checkout -b feat/plugin-my-data-source
git add plugins/my_data_source/ tests/plugins/test_my_data_source.py
git commit -m "feat(plugin): add MyDataSource data connector"
git push origin feat/plugin-my-data-source
# Open a PR on GitHub
```

---

## Pull Request Process

### Before Submitting

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   # or: fix/bug-description, docs/topic, refactor/module
   ```

2. **Write or update tests** for all changes

3. **Run the full test suite** locally:
   ```bash
   python -m pytest tests/ -v --cov=ty --cov-report=term-missing
   ```

4. **Run linting and type checks**:
   ```bash
   ruff check .
   ruff format --check .
   mypy ty/
   ```

5. **Write a clear commit message** following conventional commits:
   ```
   feat(perception): add Binance WebSocket order book plugin
   fix(world-model): correct Bayesian update for multi-asset case
   docs(readme): add Chinese translation
   refactor(execution): simplify order routing logic
   test(reasoning): add edge case tests for regime detection
   ```

### PR Template

When opening a PR, include:

- **Summary**: 1-3 bullet points describing the change
- **Motivation**: Why this change is needed
- **Test plan**: How to verify the change works
- **Breaking changes**: Any backward-incompatible changes (if applicable)

### Review Process

1. All PRs require at least **1 approving review**
2. CI must pass (tests, linting, type checks)
3. Maintainers may request changes -- please address them promptly
4. Once approved, a maintainer will merge using squash-merge

---

## Code Style

### General Principles

- **Clarity over cleverness** -- Write code that reads like well-structured prose
- **Explicit over implicit** -- Type hints everywhere, no magic globals
- **Small functions** -- Each function does one thing, under 30 lines ideally

### Python Style

| Rule | Tool | Config |
|---|---|---|
| Formatting | Ruff (format) | `pyproject.toml` |
| Linting | Ruff (check) | `pyproject.toml` |
| Type checking | mypy (strict) | `mypy.ini` |
| Import sorting | Ruff (isort) | `pyproject.toml` |

### Naming Conventions

| Entity | Convention | Example |
|---|---|---|
| Files/modules | `snake_case` | `order_book_parser.py` |
| Classes | `PascalCase` | `BinanceWebSocketPlugin` |
| Functions/methods | `snake_case` | `fetch_order_book()` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_RETRY_COUNT` |
| Type variables | `PascalCase` | `DataPointT` |

### Docstrings

Use Google-style docstrings:

```python
def calculate_surprisal(probability: float) -> float:
    """Calculate information surprisal for a given probability.

    Uses Shannon's formula: I(x) = -log2(P(x)).

    Args:
        probability: Event probability, must be in (0, 1].

    Returns:
        Surprisal in bits.

    Raises:
        ValueError: If probability is not in (0, 1].
    """
```

---

## Testing Requirements

### Coverage

- All new code must have tests
- Target: **90%+ line coverage** for new modules
- Critical paths (execution, risk management) require **100% coverage**

### Test Structure

```
tests/
├── unit/              # Fast, isolated tests (no I/O)
│   ├── test_bayesian.py
│   └── test_causal_graph.py
├── integration/       # Tests with real (mocked) data flows
│   ├── test_perception_pipeline.py
│   └── test_world_model_update.py
├── plugins/           # Plugin-specific tests
│   ├── test_defillama.py
│   └── test_binance_ws.py
└── conftest.py        # Shared fixtures
```

### Running Tests

```bash
# Run all tests
python -m pytest tests/ -v

# Run with coverage
python -m pytest tests/ -v --cov=ty --cov-report=html

# Run specific test file
python -m pytest tests/unit/test_bayesian.py -v

# Run tests matching a pattern
python -m pytest tests/ -k "test_order_book" -v
```

### Test Guidelines

- Use `pytest` fixtures for setup/teardown
- Mock external APIs -- never call real APIs in tests
- Use `pytest.mark.asyncio` for async tests
- Parametrize tests where possible to cover edge cases
- Each test should be independent and idempotent

---

## Communication Channels

| Channel | Purpose | Link |
|---|---|---|
| **GitHub Issues** | Bug reports, feature requests | [Issues](https://github.com/ty-trading/ty/issues) |
| **GitHub Discussions** | Architecture discussions, Q&A | [Discussions](https://github.com/ty-trading/ty/discussions) |
| **Discord** | Real-time chat, community | Coming soon |
| **WeChat Group** | Chinese community | Coming soon |

### Reporting Bugs

Use the GitHub Issues template. Include:
- Steps to reproduce
- Expected vs actual behavior
- Python version, OS, relevant config

### Proposing Features

Open a GitHub Discussion first to gather feedback before implementing large features. Include:
- Problem statement
- Proposed solution
- Alternatives considered

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for helping build the future of algorithmic trading!
