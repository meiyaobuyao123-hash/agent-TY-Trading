<!-- Badges -->
[![Build Status](https://img.shields.io/github/actions/workflow/status/ty-trading/ty/ci.yml?branch=main&style=flat-square)](https://github.com/ty-trading/ty/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Contributors](https://img.shields.io/github/contributors/ty-trading/ty?style=flat-square)](https://github.com/ty-trading/ty/graphs/contributors)
[![Stars](https://img.shields.io/github/stars/ty-trading/ty?style=flat-square)](https://github.com/ty-trading/ty/stargazers)

<div align="center">

# TY (天演) -- Self-Evolving Financial World Model

**An open-source, self-evolving AI system that perceives, reasons about, and trades across ALL financial markets from mathematical first principles.**

[Architecture Blueprint](docs/world-model-blueprint.md) | [Plugin Architecture](docs/open-architecture.md) | [Free Data Sources](docs/free-data-sources-research.md) | [Contributing](CONTRIBUTING.md) | [中文文档](README_zh.md)

</div>

---

## Why TY?

Most trading systems are curve-fitted pipelines: scrape data, train model, deploy, watch it decay. TY takes a fundamentally different approach.

**Markets are information processing systems.** A price is not a fact -- it is the compressed output of millions of agents updating beliefs under uncertainty. TY models this from first principles using three mathematical frameworks:

- **Information Theory** -- Profit comes from correctly estimating surprisal before the market does. Your edge is the KL-divergence between your posterior and the market's.
- **Game Theory** -- Prices are Nash equilibria of strategic behavior under incomplete information, not "correct" values. The system models recursive belief structures (what others believe about what others believe).
- **Bayesian Inference** -- Explicit probability distributions, never point estimates. Priors over model uncertainty. Beliefs updated via Bayes' rule as evidence arrives.

TY does not predict prices. It maintains a **world model** -- a causal graph of how economies, markets, and participants interact -- and continuously evolves that model as the world changes. When the model's beliefs diverge from market prices, that divergence is edge.

The name "天演" (Tianyan) means "Natural Evolution" -- the system evolves its understanding just as nature evolves organisms: through variation, selection, and adaptation.

---

## 4-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Layer 4: SELF-EVOLVER                                  │
│  Strategy genome · Natural selection · Meta-cognition   │
│  Calibration tracking · Fitness evaluation              │
├─────────────────────────────────────────────────────────┤
│  Layer 3: COGNITIVE BIAS HUNTER                         │
│  Herding detection · Anchoring bias · Recency bias ·    │
│  Overconfidence · Rational price divergence analysis    │
├─────────────────────────────────────────────────────────┤
│  Layer 2: CAUSAL REASONING ENGINE                       │
│  Causal DAGs · Bayesian updating · Game-theoretic       │
│  modeling · Regime detection · Reflexivity analysis     │
├─────────────────────────────────────────────────────────┤
│  Layer 1: WORLD PERCEIVER                               │
│  On-chain data · Order flow · Social sentiment ·        │
│  Economic indicators · News · Prediction markets        │
└─────────────────────────────────────────────────────────┘
```

| Layer | Purpose | Key Technologies |
|---|---|---|
| **World Perceiver** | Ingest and normalize data from all markets | DeFiLlama, Binance WS, FRED, AKShare, Polymarket, Dune |
| **Causal Reasoning Engine** | Maintain causal understanding and generate hypotheses | Bayesian networks, causal DAGs, probabilistic programming |
| **Cognitive Bias Hunter** | Detect cognitive biases in market pricing | Bias detectors, rational price models, divergence analysis |
| **Self-Evolver** | Evolve strategies and self-improve over time | Genetic algorithms, meta-cognition, calibration tracking |

---

## Quick Start

### Prerequisites

- Python 3.11+ (core engine)
- Node.js 20+ (optional, for TypeScript plugins)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/ty-trading/ty.git
cd ty

# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Copy environment template
cp .env.example .env
# Edit .env with your API keys (most data sources are free)
```

### Run Your First Analysis

```bash
# Start the perception layer (data ingestion)
python -m ty.perception.start

# Run the world model update
python -m ty.world_model.update

# Generate trading signals
python -m ty.reasoning.signals
```

### Configuration

All configuration lives in `config/`. Key files:

| File | Purpose |
|---|---|
| `config/data_sources.yaml` | Enable/disable data sources, set API keys |
| `config/world_model.yaml` | Causal graph structure, prior distributions |
| `config/risk.yaml` | Position limits, drawdown thresholds, kill switches |
| `config/execution.yaml` | Venue configuration, order types, slippage models |

---

## Documentation

| Document | Description |
|---|---|
| [Architecture Blueprint](docs/world-model-blueprint.md) | Complete system design with mathematical foundations |
| [Architecture Blueprint (中文)](docs/world-model-blueprint-zh.md) | 完整系统设计与数学基础 |
| [Free Data Sources Research](docs/free-data-sources-research.md) | Deep research on 30+ free data APIs |
| [Free Data Sources (中文)](docs/free-data-sources-research-zh.md) | 30+ 免费数据 API 深度调研 |
| [Open Plugin Architecture](docs/open-architecture.md) | Plugin system design (Python + TypeScript) |
| [Contributing Guide](CONTRIBUTING.md) | How to contribute to TY |
| [Contributing Guide (中文)](CONTRIBUTING_zh.md) | 如何贡献 TY 项目 |

---

## How to Contribute

We welcome contributions from traders, researchers, and engineers. See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

Quick overview:

1. Fork the repo and create a feature branch
2. Write tests for your changes
3. Submit a PR with a clear description
4. Respond to code review feedback

Areas where we especially need help:

- **Data plugins** -- connectors for new data sources
- **Causal models** -- domain expertise in specific markets
- **Backtesting** -- historical validation of strategies
- **Documentation** -- tutorials, examples, translations

---

## Roadmap

- [x] Architecture blueprint
- [x] Free data source research
- [ ] World Perceiver (data ingestion framework)
- [ ] Causal Reasoning Engine core (causal graph engine)
- [ ] Cognitive Bias Hunter (bias detection system)
- [ ] Self-Evolver (strategy evolution & paper trading)
- [ ] Plugin system (community extensions)
- [ ] Live trading (with safety guards)

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

**TY (天演)** -- Because markets evolve. Your trading system should too.

</div>
