# Project TY (天演) — Open Plugin Architecture

## A Self-Evolving World Model for Financial Intelligence

> *"Standing on the shoulders of a global community, not a single team."*

**Version**: 1.0.0
**Status**: Draft
**Last Updated**: 2026-03-31
**License**: MIT

---

## Table of Contents

1. [Vision](#1-vision)
2. [Plugin System Design](#2-plugin-system-design)
3. [Standard Interfaces](#3-standard-interfaces-with-code-examples)
4. [Contributor Guide](#4-contributor-guide)
5. [Strategy Arena (竞技场)](#5-strategy-arena-竞技场)
6. [Project Structure](#6-project-structure)
7. [API & SDK](#7-api--sdk)
8. [Governance](#8-governance)

---

## 1. Vision

Project TY (天演 — Natural Evolution) is built on a single conviction: **no single person or team can model all of the world's financial complexity**. The system's architecture reflects this — every layer is a plugin slot, every component is swappable, and every contributor anywhere in the world can participate.

The 4-layer architecture from the [World Model Blueprint](./world-model-blueprint.md) maps directly to four plugin categories:

| Layer | Name | Plugin Type | What Contributors Build |
|-------|------|-------------|------------------------|
| L1 | World Perceiver (世界感知器) | `DataSourcePlugin` | Connectors to any data source on Earth |
| L2 | Causal Reasoning Engine (因果推理引擎) | `ReasoningPlugin` | Causal models, Bayesian networks, SCMs |
| L3 | Cognitive Bias Hunter (认知偏差猎手) | `BiasDetectorPlugin` | Detectors for specific cognitive biases |
| L4 | Self-Evolver (自我进化器) | `EvolutionPlugin` | Selection algorithms, mutation operators, fitness functions |

A **StrategyPlugin** is a higher-order composite that wires together plugins from all four layers into a tradeable signal.

---

## 2. Plugin System Design

### 2.1 Core Principles

1. **Zero coupling** — Plugins communicate only through defined interfaces. A data source plugin knows nothing about which reasoning plugin will consume its output.
2. **Fail-safe isolation** — A crashing plugin never takes down the core engine. Each plugin runs in its own sandboxed context with resource limits.
3. **Hot-reload** — Plugins can be registered, updated, or retired at runtime without restarting the system. The plugin registry uses a versioned slot model: a new version is loaded alongside the old one, traffic is shifted, and the old version is retired.
4. **Polyglot** — Plugin interfaces are defined in both TypeScript and Python. The runtime bridges them via gRPC. Contributors pick the language they prefer.

### 2.2 Plugin Lifecycle

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ REGISTER │───>│ VALIDATE │───>│   TEST   │───>│  DEPLOY  │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘
                                                       │
                  ┌──────────┐    ┌──────────┐         │
                  │  RETIRE  │<───│ MONITOR  │<────────┘
                  └──────────┘    └──────────┘
```

| Phase | What Happens | Automated? |
|-------|-------------|-----------|
| **Register** | Developer submits plugin with metadata manifest. CLI validates manifest schema. | Yes |
| **Validate** | Static analysis: type checks, dependency audit, security scan (no network calls in constructors, no filesystem writes outside sandbox). | Yes |
| **Test** | Plugin test suite runs + integration tests against mock data. Must pass 100% before proceeding. | Yes |
| **Deploy** | Plugin is loaded into a staging slot. For strategy plugins, a 30-day paper-trading trial begins. | Yes |
| **Monitor** | Health checks run every 60s. Latency, error rate, and data quality metrics are tracked. Alerts fire if SLA is breached. | Yes |
| **Retire** | Plugin is gracefully unloaded. Existing subscriptions drain. The slot is freed. | Manual trigger, automated execution |

### 2.3 Plugin Metadata Manifest

Every plugin ships with a `plugin.manifest.json`:

```json
{
  "name": "yahoo-finance-data",
  "displayName": "Yahoo Finance Data Source",
  "description": "Free market data via Yahoo Finance API — equities, ETFs, indices, forex, crypto.",
  "version": "1.2.0",
  "author": {
    "name": "Jane Smith",
    "github": "janesmith",
    "email": "jane@example.com"
  },
  "type": "data-source",
  "layer": 1,
  "markets": ["us-equities", "global-indices", "forex", "crypto"],
  "languages": ["python"],
  "entrypoint": "src/yahoo_plugin.py",
  "dependencies": {
    "python": ["yfinance>=0.2.0", "pandas>=2.0"],
    "system": []
  },
  "config": {
    "rateLimit": { "requests": 2000, "perSeconds": 3600 },
    "requiresApiKey": false
  },
  "backtest": {
    "sharpRatio": null,
    "maxDrawdown": null,
    "paperTradeDays": 0
  },
  "tags": ["free", "equities", "no-auth"],
  "license": "MIT"
}
```

### 2.4 Hot-Reload Mechanism

The plugin runtime uses a **versioned slot model**:

```
                    ┌──────────────────────────┐
                    │     Plugin Registry       │
                    │                          │
  load(v2) ───────> │  slot: "yahoo-finance"   │
                    │    v1.2.0  [active]      │
                    │    v1.3.0  [staging]     │
                    │                          │
  promote(v1.3.0)──>│    v1.2.0  [draining]   │
                    │    v1.3.0  [active]      │
                    └──────────────────────────┘
```

```typescript
// Core engine hot-reload API
interface PluginRegistry {
  /** Load a new plugin version into a staging slot */
  load(manifest: PluginManifest, module: PluginModule): Promise<SlotHandle>;

  /** Promote a staged version to active, draining the previous */
  promote(slotId: string, version: string): Promise<void>;

  /** Force-retire a version (emergency use) */
  retire(slotId: string, version: string): Promise<void>;

  /** List all slots and their versions */
  list(): Promise<SlotInfo[]>;

  /** Health check across all active plugins */
  healthCheckAll(): Promise<Map<string, HealthStatus>>;
}
```

### 2.5 Sandboxing & Resource Limits

Every plugin runs within enforced constraints:

```yaml
# Default resource limits per plugin
resources:
  memory_mb: 512
  cpu_seconds_per_call: 30
  max_concurrent_calls: 10
  network:
    allowed_domains: []        # Populated from manifest
    max_bandwidth_mbps: 10
  storage:
    max_disk_mb: 100
    allowed_paths: ["./plugin-data/${plugin_name}/"]
```

---

## 3. Standard Interfaces (with Code Examples)

### 3.1 Common Types

These shared types are used across all plugin interfaces.

#### TypeScript

```typescript
// ─── Common Types ─────────────────────────────────────────────

type MarketType =
  | "us-equities"
  | "cn-equities"
  | "hk-equities"
  | "eu-equities"
  | "jp-equities"
  | "crypto"
  | "forex"
  | "commodities"
  | "bonds"
  | "options"
  | "futures"
  | "prediction-markets"
  | "global-indices"
  | "defi";

type Timeframe = "1m" | "5m" | "15m" | "1h" | "4h" | "1d" | "1w" | "1M";

interface OHLCV {
  timestamp: number; // Unix ms
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

interface MarketTick {
  symbol: string;
  price: number;
  volume: number;
  timestamp: number;
  bid?: number;
  ask?: number;
  source: string;
}

interface MarketData {
  symbol: string;
  market: MarketType;
  timeframe: Timeframe;
  candles: OHLCV[];
  metadata?: Record<string, unknown>;
}

interface DataQuery {
  symbols: string[];
  market: MarketType;
  timeframe: Timeframe;
  start: number; // Unix ms
  end: number;   // Unix ms
  fields?: string[];
}

interface Signal {
  symbol: string;
  direction: "long" | "short" | "neutral";
  strength: number;      // 0.0 to 1.0
  confidence: number;    // 0.0 to 1.0
  timeHorizon: Timeframe;
  reasoning: string;
  metadata?: Record<string, unknown>;
}

interface MarketContext {
  timestamp: number;
  symbols: string[];
  marketData: Map<string, MarketData>;
  sentiment?: SentimentData;
  onChainData?: OnChainData;
  macroData?: MacroData;
  newsEvents?: NewsEvent[];
}

interface BacktestResult {
  strategyName: string;
  startDate: number;
  endDate: number;
  totalReturn: number;
  annualizedReturn: number;
  sharpeRatio: number;
  sortinoRatio: number;
  maxDrawdown: number;
  maxDrawdownDuration: number; // days
  winRate: number;
  profitFactor: number;
  totalTrades: number;
  avgTradeReturn: number;
  calmarRatio: number;
  equityCurve: { timestamp: number; equity: number }[];
}

interface HistoricalData {
  symbol: string;
  market: MarketType;
  candles: OHLCV[];
  splits?: { date: number; ratio: number }[];
  dividends?: { date: number; amount: number }[];
}

interface SentimentData {
  symbol: string;
  fearGreedIndex?: number;    // 0-100
  socialVolume?: number;
  socialSentiment?: number;   // -1.0 to 1.0
  newssentiment?: number;     // -1.0 to 1.0
  source: string;
  timestamp: number;
}

interface OnChainData {
  protocol?: string;
  chain?: string;
  tvl?: number;
  volume24h?: number;
  activeAddresses?: number;
  whaleTransactions?: WhaleTransaction[];
  timestamp: number;
}

interface WhaleTransaction {
  from: string;
  to: string;
  amount: number;
  token: string;
  usdValue: number;
  timestamp: number;
}

interface NewsEvent {
  headline: string;
  source: string;
  timestamp: number;
  sentiment: number;     // -1.0 to 1.0
  relevanceScore: number; // 0.0 to 1.0
  symbols: string[];
  category: string;
  url?: string;
}

interface MacroData {
  indicator: string;     // "CPI", "GDP", "PMI", "NFP", etc.
  actual: number;
  expected: number;
  previous: number;
  surprise: number;      // actual - expected
  timestamp: number;
  country: string;
}
```

#### Python

```python
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Optional


class MarketType(str, Enum):
    US_EQUITIES = "us-equities"
    CN_EQUITIES = "cn-equities"
    HK_EQUITIES = "hk-equities"
    EU_EQUITIES = "eu-equities"
    JP_EQUITIES = "jp-equities"
    CRYPTO = "crypto"
    FOREX = "forex"
    COMMODITIES = "commodities"
    BONDS = "bonds"
    OPTIONS = "options"
    FUTURES = "futures"
    PREDICTION_MARKETS = "prediction-markets"
    GLOBAL_INDICES = "global-indices"
    DEFI = "defi"


class Timeframe(str, Enum):
    M1 = "1m"
    M5 = "5m"
    M15 = "15m"
    H1 = "1h"
    H4 = "4h"
    D1 = "1d"
    W1 = "1w"
    MO1 = "1M"


@dataclass
class OHLCV:
    timestamp: int  # Unix ms
    open: float
    high: float
    low: float
    close: float
    volume: float


@dataclass
class MarketTick:
    symbol: str
    price: float
    volume: float
    timestamp: int
    bid: Optional[float] = None
    ask: Optional[float] = None
    source: str = ""


@dataclass
class MarketData:
    symbol: str
    market: MarketType
    timeframe: Timeframe
    candles: list[OHLCV]
    metadata: dict = field(default_factory=dict)


@dataclass
class DataQuery:
    symbols: list[str]
    market: MarketType
    timeframe: Timeframe
    start: int  # Unix ms
    end: int    # Unix ms
    fields: list[str] = field(default_factory=list)


@dataclass
class Signal:
    symbol: str
    direction: str   # "long" | "short" | "neutral"
    strength: float  # 0.0 to 1.0
    confidence: float
    time_horizon: Timeframe
    reasoning: str
    metadata: dict = field(default_factory=dict)


@dataclass
class BacktestResult:
    strategy_name: str
    start_date: int
    end_date: int
    total_return: float
    annualized_return: float
    sharpe_ratio: float
    sortino_ratio: float
    max_drawdown: float
    max_drawdown_duration: int  # days
    win_rate: float
    profit_factor: float
    total_trades: int
    avg_trade_return: float
    calmar_ratio: float
    equity_curve: list[dict] = field(default_factory=list)
```

---

### 3.2 Layer 1 — Data Source Plugin

#### TypeScript Interface

```typescript
interface DataSourcePlugin {
  /** Unique plugin identifier */
  readonly name: string;

  /** Human-readable display name */
  readonly displayName: string;

  /** Markets this plugin covers */
  readonly markets: MarketType[];

  /** Whether this source requires an API key */
  readonly requiresAuth: boolean;

  /**
   * Initialize the plugin with configuration.
   * Called once when the plugin is loaded.
   */
  initialize(config: Record<string, unknown>): Promise<void>;

  /**
   * Fetch historical or snapshot data for given symbols.
   */
  fetch(query: DataQuery): Promise<MarketData[]>;

  /**
   * Subscribe to real-time ticks. Optional — not all sources support streaming.
   */
  subscribe?(symbols: string[]): AsyncIterable<MarketTick>;

  /**
   * Unsubscribe from real-time ticks.
   */
  unsubscribe?(symbols: string[]): Promise<void>;

  /**
   * Health check — returns true if the data source is reachable and responsive.
   */
  healthCheck(): Promise<boolean>;

  /**
   * Return the list of symbols available from this source.
   */
  listSymbols?(market: MarketType): Promise<string[]>;

  /**
   * Clean up resources when the plugin is being retired.
   */
  destroy(): Promise<void>;
}
```

#### Python Abstract Base Class

```python
from abc import ABC, abstractmethod
from typing import AsyncIterator


class DataSourcePlugin(ABC):
    """Base class for all Layer 1 data source plugins."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Unique plugin identifier."""
        ...

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Human-readable display name."""
        ...

    @property
    @abstractmethod
    def markets(self) -> list[MarketType]:
        """Markets this plugin covers."""
        ...

    @property
    def requires_auth(self) -> bool:
        return False

    @abstractmethod
    async def initialize(self, config: dict) -> None:
        """Initialize the plugin. Called once on load."""
        ...

    @abstractmethod
    async def fetch(self, query: DataQuery) -> list[MarketData]:
        """Fetch historical or snapshot data."""
        ...

    async def subscribe(self, symbols: list[str]) -> AsyncIterator[MarketTick]:
        """Subscribe to real-time ticks. Override if supported."""
        raise NotImplementedError("This data source does not support streaming.")

    async def unsubscribe(self, symbols: list[str]) -> None:
        """Unsubscribe from real-time ticks."""
        pass

    @abstractmethod
    async def health_check(self) -> bool:
        """Return True if data source is reachable."""
        ...

    async def list_symbols(self, market: MarketType) -> list[str]:
        """Return available symbols. Override if supported."""
        return []

    async def destroy(self) -> None:
        """Clean up resources. Override if needed."""
        pass
```

#### Hello World Example: Fear & Greed Index Plugin

```python
"""
Plugin: Fear & Greed Index Data Source
Source: alternative.me (free, no auth)
Layer: 1 (World Perceiver)

Install: pip install aiohttp
"""

import aiohttp

from ty_sdk.plugins import DataSourcePlugin
from ty_sdk.types import (
    DataQuery, MarketData, MarketType, OHLCV, Timeframe,
)


class FearGreedPlugin(DataSourcePlugin):
    """Fetches the Crypto Fear & Greed Index from alternative.me."""

    API_URL = "https://api.alternative.me/fng/"

    @property
    def name(self) -> str:
        return "fear-greed-index"

    @property
    def display_name(self) -> str:
        return "Crypto Fear & Greed Index"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        self._session = aiohttp.ClientSession()

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        # Calculate number of days requested
        days = max(1, (query.end - query.start) // (86400 * 1000))

        async with self._session.get(
            self.API_URL, params={"limit": days, "format": "json"}
        ) as resp:
            data = await resp.json()

        candles = []
        for entry in data.get("data", []):
            ts = int(entry["timestamp"]) * 1000
            value = float(entry["value"])
            candles.append(OHLCV(
                timestamp=ts,
                open=value,
                high=value,
                low=value,
                close=value,   # Index value stored as "close"
                volume=0.0,
            ))

        return [MarketData(
            symbol="FEAR_GREED",
            market=MarketType.CRYPTO,
            timeframe=Timeframe.D1,
            candles=sorted(candles, key=lambda c: c.timestamp),
            metadata={"source": "alternative.me", "index_range": "0-100"},
        )]

    async def health_check(self) -> bool:
        try:
            async with self._session.get(
                self.API_URL, params={"limit": 1}
            ) as resp:
                return resp.status == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._session.close()
```

#### Testing Harness

```python
"""
tests/test_fear_greed_plugin.py

Run: pytest tests/test_fear_greed_plugin.py -v
"""

import pytest
from ty_sdk.testing import PluginTestHarness
from plugins.data_sources.fear_greed import FearGreedPlugin


@pytest.fixture
async def plugin():
    harness = PluginTestHarness(FearGreedPlugin)
    plugin = await harness.setup()
    yield plugin
    await harness.teardown()


@pytest.mark.asyncio
async def test_health_check(plugin):
    assert await plugin.health_check() is True


@pytest.mark.asyncio
async def test_fetch_returns_data(plugin):
    from ty_sdk.types import DataQuery, MarketType, Timeframe
    import time

    query = DataQuery(
        symbols=["FEAR_GREED"],
        market=MarketType.CRYPTO,
        timeframe=Timeframe.D1,
        start=int((time.time() - 7 * 86400) * 1000),
        end=int(time.time() * 1000),
    )
    results = await plugin.fetch(query)

    assert len(results) == 1
    assert results[0].symbol == "FEAR_GREED"
    assert len(results[0].candles) >= 1

    for candle in results[0].candles:
        assert 0 <= candle.close <= 100  # Index range


@pytest.mark.asyncio
async def test_manifest_valid(plugin):
    """Verify the plugin manifest is well-formed."""
    from ty_sdk.testing import validate_manifest

    assert validate_manifest("plugins/data-sources/fear-greed/plugin.manifest.json")
```

---

### 3.3 Layer 2 — Reasoning Plugin

#### TypeScript Interface

```typescript
interface CausalLink {
  from: string;
  to: string;
  mechanism: string;
  strength: number;     // 0.0 to 1.0
  timelag: string;      // e.g. "2d", "1w"
  confidence: number;
}

interface Hypothesis {
  id: string;
  statement: string;
  prior: number;
  posterior: number;
  evidenceLog: { evidence: string; likelihoodRatio: number; timestamp: number }[];
}

interface ReasoningOutput {
  hypotheses: Hypothesis[];
  causalLinks: CausalLink[];
  scenarios: Scenario[];
  signals: Signal[];
}

interface Scenario {
  name: string;
  probability: number;
  description: string;
  priceTarget: number;
  timeHorizon: Timeframe;
  triggerConditions: string[];
}

interface ReasoningPlugin {
  readonly name: string;
  readonly displayName: string;
  readonly description: string;

  /**
   * Initialize with configuration and reference to data layer.
   */
  initialize(config: Record<string, unknown>): Promise<void>;

  /**
   * Run causal/Bayesian analysis on the given market context.
   * Returns hypotheses, causal links, scenarios, and optional signals.
   */
  analyze(context: MarketContext): Promise<ReasoningOutput>;

  /**
   * Update beliefs given new evidence.
   */
  updateBeliefs(evidence: NewsEvent | MacroData): Promise<Hypothesis[]>;

  /**
   * Answer a counterfactual: "What would happen to Y if X changed to value?"
   */
  counterfactual?(
    intervention: { variable: string; value: number },
    query: string
  ): Promise<Scenario[]>;

  /**
   * Return the current causal graph as an adjacency list.
   */
  getCausalGraph?(): Promise<CausalLink[]>;

  destroy(): Promise<void>;
}
```

#### Python Abstract Base Class

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class CausalLink:
    from_var: str
    to_var: str
    mechanism: str
    strength: float
    time_lag: str
    confidence: float


@dataclass
class Hypothesis:
    id: str
    statement: str
    prior: float
    posterior: float
    evidence_log: list[dict]


@dataclass
class Scenario:
    name: str
    probability: float
    description: str
    price_target: float
    time_horizon: Timeframe
    trigger_conditions: list[str]


@dataclass
class ReasoningOutput:
    hypotheses: list[Hypothesis]
    causal_links: list[CausalLink]
    scenarios: list[Scenario]
    signals: list[Signal]


class ReasoningPlugin(ABC):
    """Base class for all Layer 2 reasoning/causal engine plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def analyze(self, context: "MarketContext") -> ReasoningOutput: ...

    @abstractmethod
    async def update_beliefs(self, evidence: dict) -> list[Hypothesis]: ...

    async def counterfactual(
        self, intervention: dict, query: str
    ) -> list[Scenario]:
        raise NotImplementedError

    async def get_causal_graph(self) -> list[CausalLink]:
        raise NotImplementedError

    async def destroy(self) -> None:
        pass
```

#### Hello World Example: Simple Momentum Reasoning

```python
"""
Plugin: Simple Momentum Reasoning
Layer: 2 (Causal Reasoning Engine)

A minimal reasoning plugin that generates a momentum-based hypothesis:
"If price > 20-day SMA and volume is rising, trend is bullish."
"""

import statistics

from ty_sdk.plugins import ReasoningPlugin
from ty_sdk.types import (
    CausalLink, Hypothesis, MarketContext, ReasoningOutput,
    Scenario, Signal, Timeframe,
)


class MomentumReasoningPlugin(ReasoningPlugin):

    @property
    def name(self) -> str:
        return "simple-momentum-reasoning"

    @property
    def display_name(self) -> str:
        return "Simple Momentum Reasoning"

    async def initialize(self, config: dict) -> None:
        self.sma_period = config.get("sma_period", 20)

    async def analyze(self, context: MarketContext) -> ReasoningOutput:
        signals = []
        hypotheses = []

        for symbol, data in context.market_data.items():
            closes = [c.close for c in data.candles]
            volumes = [c.volume for c in data.candles]

            if len(closes) < self.sma_period:
                continue

            sma = statistics.mean(closes[-self.sma_period :])
            current_price = closes[-1]
            vol_trend = statistics.mean(volumes[-5:]) / max(
                statistics.mean(volumes[-20:]), 1
            )

            # Hypothesis: momentum is positive
            is_bullish = current_price > sma and vol_trend > 1.0
            strength = min(abs(current_price - sma) / sma * 10, 1.0)

            hypotheses.append(Hypothesis(
                id=f"momentum-{symbol}",
                statement=f"{symbol} momentum is {'bullish' if is_bullish else 'bearish'}",
                prior=0.5,
                posterior=0.5 + (0.3 * strength if is_bullish else -0.3 * strength),
                evidence_log=[],
            ))

            if strength > 0.3:
                signals.append(Signal(
                    symbol=symbol,
                    direction="long" if is_bullish else "short",
                    strength=strength,
                    confidence=min(strength * 0.8, 0.7),  # Conservative
                    time_horizon=Timeframe.D1,
                    reasoning=(
                        f"Price {'above' if is_bullish else 'below'} {self.sma_period}-SMA "
                        f"by {abs(current_price - sma) / sma:.1%}, "
                        f"volume trend: {vol_trend:.2f}x"
                    ),
                ))

        return ReasoningOutput(
            hypotheses=hypotheses,
            causal_links=[
                CausalLink(
                    from_var="price_vs_sma",
                    to_var="trend_direction",
                    mechanism="momentum",
                    strength=0.6,
                    time_lag="1d",
                    confidence=0.5,
                ),
            ],
            scenarios=[],
            signals=signals,
        )

    async def update_beliefs(self, evidence: dict) -> list[Hypothesis]:
        return []  # Stateless in this simple version
```

---

### 3.4 Layer 3 — Bias Detector Plugin

#### TypeScript Interface

```typescript
interface BiasSignal {
  biasType: string;
  symbol: string;
  strength: number;        // 0.0 to 1.0
  direction: "long" | "short" | "neutral";
  evidence: string;
  rationalPriceEstimate?: number;
  currentPrice: number;
  mispricing?: number;     // rational - current
  mispricingPct?: number;
  timestamp: number;
}

interface BiasDetectorPlugin {
  readonly name: string;
  readonly displayName: string;
  readonly biasType: string;  // e.g. "anchoring", "herding", "recency"

  initialize(config: Record<string, unknown>): Promise<void>;

  /**
   * Scan an asset for this specific cognitive bias.
   * Returns null if no bias detected.
   */
  detect(
    symbol: string,
    marketData: MarketData,
    context: MarketContext
  ): Promise<BiasSignal | null>;

  /**
   * Batch scan multiple assets.
   */
  batchDetect(context: MarketContext): Promise<BiasSignal[]>;

  destroy(): Promise<void>;
}
```

#### Python Abstract Base Class

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional


@dataclass
class BiasSignal:
    bias_type: str
    symbol: str
    strength: float
    direction: str
    evidence: str
    rational_price_estimate: Optional[float] = None
    current_price: float = 0.0
    mispricing: Optional[float] = None
    mispricing_pct: Optional[float] = None
    timestamp: int = 0


class BiasDetectorPlugin(ABC):
    """Base class for all Layer 3 bias detector plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @property
    @abstractmethod
    def bias_type(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def detect(
        self, symbol: str, market_data: "MarketData", context: "MarketContext"
    ) -> Optional[BiasSignal]: ...

    async def batch_detect(self, context: "MarketContext") -> list[BiasSignal]:
        """Default: iterate over all symbols. Override for efficiency."""
        signals = []
        for symbol, data in context.market_data.items():
            signal = await self.detect(symbol, data, context)
            if signal is not None:
                signals.append(signal)
        return signals

    async def destroy(self) -> None:
        pass
```

#### Hello World Example: Recency Bias Detector

```python
"""
Plugin: Recency Bias Detector
Layer: 3 (Cognitive Bias Hunter)

Detects when market participants are overweighting recent price action,
creating mean-reversion opportunities.
"""

import statistics
from typing import Optional

from ty_sdk.plugins import BiasDetectorPlugin
from ty_sdk.types import BiasSignal, MarketContext, MarketData


class RecencyBiasDetector(BiasDetectorPlugin):

    @property
    def name(self) -> str:
        return "recency-bias-detector"

    @property
    def display_name(self) -> str:
        return "Recency Bias Detector"

    @property
    def bias_type(self) -> str:
        return "recency"

    async def initialize(self, config: dict) -> None:
        self.short_window = config.get("short_window", 5)
        self.long_window = config.get("long_window", 60)
        self.z_threshold = config.get("z_threshold", 2.0)

    async def detect(
        self, symbol: str, market_data: MarketData, context: MarketContext
    ) -> Optional[BiasSignal]:
        closes = [c.close for c in market_data.candles]

        if len(closes) < self.long_window:
            return None

        # Short-term return vs long-term distribution
        short_return = (closes[-1] - closes[-self.short_window]) / closes[-self.short_window]
        long_returns = [
            (closes[i] - closes[i - self.short_window]) / closes[i - self.short_window]
            for i in range(self.short_window, len(closes))
        ]

        mean_return = statistics.mean(long_returns)
        std_return = statistics.stdev(long_returns)

        if std_return == 0:
            return None

        z_score = (short_return - mean_return) / std_return

        if abs(z_score) < self.z_threshold:
            return None

        # Extreme recent returns suggest participants are extrapolating
        return BiasSignal(
            bias_type="recency",
            symbol=symbol,
            strength=min(abs(z_score) / 4.0, 1.0),
            direction="short" if z_score > 0 else "long",  # Fade the bias
            evidence=(
                f"Recent {self.short_window}-bar return ({short_return:.1%}) is "
                f"{abs(z_score):.1f} std devs from the {self.long_window}-bar mean. "
                f"Market likely overweighting recent price action."
            ),
            current_price=closes[-1],
            timestamp=market_data.candles[-1].timestamp,
        )
```

---

### 3.5 Layer 4 — Evolution Plugin

#### TypeScript Interface

```typescript
interface StrategyGenome {
  id: string;
  name: string;
  generation: number;
  parentIds: string[];
  genes: Record<string, unknown>;  // Strategy parameters
  fitness?: number;
  backtestResult?: BacktestResult;
}

interface EvolutionPlugin {
  readonly name: string;
  readonly displayName: string;

  initialize(config: Record<string, unknown>): Promise<void>;

  /**
   * Compute fitness for a genome given its backtest results.
   */
  fitness(genome: StrategyGenome, result: BacktestResult): number;

  /**
   * Select parents from a population for reproduction.
   */
  select(population: StrategyGenome[], count: number): StrategyGenome[];

  /**
   * Create a child genome by crossing two parents.
   */
  crossover(parentA: StrategyGenome, parentB: StrategyGenome): StrategyGenome;

  /**
   * Mutate a genome with given mutation rate.
   */
  mutate(genome: StrategyGenome, mutationRate: number): StrategyGenome;

  /**
   * Run one full generation of evolution.
   */
  evolveGeneration(population: StrategyGenome[]): Promise<StrategyGenome[]>;

  destroy(): Promise<void>;
}
```

#### Python Abstract Base Class

```python
from abc import ABC, abstractmethod


class EvolutionPlugin(ABC):
    """Base class for all Layer 4 evolution algorithm plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    def fitness(self, genome: dict, result: "BacktestResult") -> float: ...

    @abstractmethod
    def select(self, population: list[dict], count: int) -> list[dict]: ...

    @abstractmethod
    def crossover(self, parent_a: dict, parent_b: dict) -> dict: ...

    @abstractmethod
    def mutate(self, genome: dict, mutation_rate: float) -> dict: ...

    @abstractmethod
    async def evolve_generation(self, population: list[dict]) -> list[dict]: ...

    async def destroy(self) -> None:
        pass
```

#### Hello World Example: Tournament Selection Evolution

```python
"""
Plugin: Tournament Selection Evolution
Layer: 4 (Self-Evolver)

A straightforward genetic algorithm using tournament selection,
uniform crossover, and Gaussian mutation.
"""

import copy
import random
import uuid

from ty_sdk.plugins import EvolutionPlugin
from ty_sdk.types import BacktestResult


class TournamentEvolution(EvolutionPlugin):

    @property
    def name(self) -> str:
        return "tournament-evolution"

    @property
    def display_name(self) -> str:
        return "Tournament Selection GA"

    async def initialize(self, config: dict) -> None:
        self.tournament_size = config.get("tournament_size", 5)
        self.elite_fraction = config.get("elite_fraction", 0.1)
        self.crossover_rate = config.get("crossover_rate", 0.7)
        self.default_mutation_rate = config.get("mutation_rate", 0.1)

    def fitness(self, genome: dict, result: BacktestResult) -> float:
        """Multi-objective fitness emphasizing risk-adjusted returns."""
        sharpe = result.sharpe_ratio
        sortino = result.sortino_ratio
        dd = abs(result.max_drawdown)
        win = result.win_rate
        pf = result.profit_factor

        return (
            0.30 * max(sharpe, -2.0)
            + 0.20 * max(sortino, -2.0)
            - 0.20 * dd
            + 0.15 * win
            + 0.15 * min(pf, 5.0) / 5.0   # Normalize profit factor
        )

    def select(self, population: list[dict], count: int) -> list[dict]:
        """Tournament selection: pick the best from random subsets."""
        selected = []
        for _ in range(count):
            tournament = random.sample(
                population, min(self.tournament_size, len(population))
            )
            winner = max(tournament, key=lambda g: g.get("fitness", 0))
            selected.append(winner)
        return selected

    def crossover(self, parent_a: dict, parent_b: dict) -> dict:
        """Uniform crossover: each gene randomly from one parent."""
        child_genes = {}
        all_keys = set(parent_a.get("genes", {}).keys()) | set(
            parent_b.get("genes", {}).keys()
        )
        for key in all_keys:
            if random.random() < 0.5:
                child_genes[key] = copy.deepcopy(
                    parent_a.get("genes", {}).get(key)
                )
            else:
                child_genes[key] = copy.deepcopy(
                    parent_b.get("genes", {}).get(key)
                )

        return {
            "id": str(uuid.uuid4()),
            "name": f"child-{parent_a.get('name', '?')}x{parent_b.get('name', '?')}",
            "generation": max(
                parent_a.get("generation", 0), parent_b.get("generation", 0)
            )
            + 1,
            "parentIds": [parent_a["id"], parent_b["id"]],
            "genes": child_genes,
        }

    def mutate(self, genome: dict, mutation_rate: float) -> dict:
        """Gaussian mutation on numeric genes, random flip on booleans."""
        mutated = copy.deepcopy(genome)
        mutated["id"] = str(uuid.uuid4())
        mutated["generation"] = genome.get("generation", 0) + 1
        mutated["parentIds"] = [genome["id"]]

        for key, value in mutated.get("genes", {}).items():
            if random.random() > mutation_rate:
                continue
            if isinstance(value, (int, float)):
                # Gaussian perturbation (10% std dev)
                noise = random.gauss(0, abs(value) * 0.1 + 1e-6)
                mutated["genes"][key] = type(value)(value + noise)
            elif isinstance(value, bool):
                mutated["genes"][key] = not value

        return mutated

    async def evolve_generation(self, population: list[dict]) -> list[dict]:
        """Run one full generation: select, crossover, mutate."""
        pop_size = len(population)
        sorted_pop = sorted(
            population, key=lambda g: g.get("fitness", 0), reverse=True
        )

        # Elitism
        elite_count = max(1, int(pop_size * self.elite_fraction))
        new_pop = sorted_pop[:elite_count]

        # Fill rest via crossover + mutation
        while len(new_pop) < pop_size:
            if random.random() < self.crossover_rate:
                parents = self.select(sorted_pop, 2)
                child = self.crossover(parents[0], parents[1])
            else:
                [parent] = self.select(sorted_pop, 1)
                child = self.mutate(parent, self.default_mutation_rate)
            new_pop.append(child)

        return new_pop
```

---

### 3.6 Strategy Plugin (Composite)

A strategy plugin is a higher-order plugin that wires layers together into a tradeable signal.

#### TypeScript Interface

```typescript
interface StrategyPlugin {
  readonly name: string;
  readonly author: string;
  readonly version: string;
  readonly description: string;
  readonly markets: MarketType[];
  readonly timeframes: Timeframe[];

  initialize(config: Record<string, unknown>): Promise<void>;

  /**
   * Analyze market context and produce trading signals.
   */
  analyze(context: MarketContext): Promise<Signal[]>;

  /**
   * Run backtest on historical data. Required for Arena submission.
   */
  backtest(historicalData: HistoricalData[]): Promise<BacktestResult>;

  /**
   * Return the strategy's current state for inspection/debugging.
   */
  getState?(): Promise<Record<string, unknown>>;

  destroy(): Promise<void>;
}
```

#### Python Abstract Base Class

```python
class StrategyPlugin(ABC):
    """
    Composite plugin that wires data sources, reasoning,
    bias detection, and evolution into a tradeable signal.
    """

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def author(self) -> str: ...

    @property
    @abstractmethod
    def version(self) -> str: ...

    @property
    @abstractmethod
    def markets(self) -> list[MarketType]: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def analyze(self, context: "MarketContext") -> list[Signal]: ...

    @abstractmethod
    async def backtest(self, historical_data: list["HistoricalData"]) -> BacktestResult: ...

    async def get_state(self) -> dict:
        return {}

    async def destroy(self) -> None:
        pass
```

---

### 3.7 Plugin Testing Harness

Every plugin type has a standardized testing harness provided by the SDK.

```python
"""ty_sdk/testing.py — Testing utilities for all plugin types."""

import json
import time
from pathlib import Path


class PluginTestHarness:
    """
    Lifecycle manager for plugin tests.
    Handles initialization, mock data injection, and teardown.
    """

    def __init__(self, plugin_class, config: dict = None):
        self.plugin_class = plugin_class
        self.config = config or {}
        self.instance = None

    async def setup(self):
        self.instance = self.plugin_class()
        await self.instance.initialize(self.config)
        return self.instance

    async def teardown(self):
        if self.instance:
            await self.instance.destroy()

    @staticmethod
    def mock_market_context(symbols: list[str], bars: int = 100):
        """Generate synthetic market data for testing."""
        import random

        from ty_sdk.types import MarketContext, MarketData, MarketType, OHLCV, Timeframe

        now = int(time.time() * 1000)
        market_data = {}

        for symbol in symbols:
            price = random.uniform(10, 1000)
            candles = []
            for i in range(bars):
                change = random.gauss(0, price * 0.02)
                price = max(price + change, 0.01)
                candles.append(OHLCV(
                    timestamp=now - (bars - i) * 86400000,
                    open=price,
                    high=price * (1 + abs(random.gauss(0, 0.01))),
                    low=price * (1 - abs(random.gauss(0, 0.01))),
                    close=price + random.gauss(0, price * 0.005),
                    volume=random.uniform(1e6, 1e8),
                ))
            market_data[symbol] = MarketData(
                symbol=symbol,
                market=MarketType.US_EQUITIES,
                timeframe=Timeframe.D1,
                candles=candles,
            )

        return MarketContext(
            timestamp=now,
            symbols=symbols,
            market_data=market_data,
        )


def validate_manifest(path: str) -> bool:
    """Validate a plugin.manifest.json against the required schema."""
    required_fields = [
        "name", "version", "author", "type", "layer",
        "markets", "entrypoint", "license",
    ]
    with open(path) as f:
        manifest = json.load(f)
    for field in required_fields:
        if field not in manifest:
            raise ValueError(f"Missing required field: {field}")
    if manifest["layer"] not in [1, 2, 3, 4]:
        raise ValueError(f"Invalid layer: {manifest['layer']}. Must be 1-4.")
    valid_types = ["data-source", "reasoning", "bias-detector", "evolution", "strategy"]
    if manifest["type"] not in valid_types:
        raise ValueError(f"Invalid type: {manifest['type']}. Must be one of {valid_types}.")
    return True
```

---

## 4. Contributor Guide

### 4.1 Quickstart: Your First Plugin in 5 Minutes

**Prerequisites**: Python 3.11+ or Node.js 20+, Git.

```bash
# 1. Clone the repo
git clone https://github.com/ty-project/agent-TY-Trading.git
cd agent-TY-Trading

# 2. Install the SDK
pip install -e ./sdk/python    # or: npm install ./sdk/typescript

# 3. Scaffold a new plugin
ty-cli plugin create \
  --name "my-awesome-source" \
  --type data-source \
  --language python

# This creates:
#   plugins/data-sources/my-awesome-source/
#   ├── plugin.manifest.json
#   ├── src/my_awesome_source.py    (skeleton with TODOs)
#   ├── tests/test_plugin.py        (pre-written test stubs)
#   └── README.md

# 4. Implement your plugin (fill in the TODOs)
$EDITOR plugins/data-sources/my-awesome-source/src/my_awesome_source.py

# 5. Run tests
ty-cli plugin test my-awesome-source

# 6. Submit
git checkout -b plugin/my-awesome-source
git add plugins/data-sources/my-awesome-source
git commit -m "feat: add my-awesome-source data plugin"
git push -u origin plugin/my-awesome-source
# Open PR on GitHub
```

### 4.2 Types of Contributions

| Type | Difficulty | Layer | Example |
|------|-----------|-------|---------|
| **Data Source** | Beginner | L1 | Connect a free API (Yahoo Finance, CoinGecko, FRED) |
| **Bias Detector** | Intermediate | L3 | Detect anchoring bias in earnings reactions |
| **Reasoning Model** | Advanced | L2 | Build a Bayesian network for Fed policy impact |
| **Evolution Algorithm** | Advanced | L4 | Implement CMA-ES or differential evolution |
| **Strategy** | Any level | All | Combine existing plugins into a trading strategy |
| **Bug Fix** | Any level | Core | Fix issues in the core engine or existing plugins |
| **Documentation** | Beginner | — | Improve docs, translate to another language |
| **Translation** | Beginner | — | Translate UI/docs (priority: EN, ZH, JA, KO, ES) |
| **Backtest Data** | Beginner | — | Curate and contribute clean historical datasets |

### 4.3 Contribution Workflow

```
  You                     GitHub                     CI/CD
  ───                     ──────                     ─────
   │                        │                          │
   ├─── Fork repo ─────────>│                          │
   │                        │                          │
   ├─── Implement ──────────│                          │
   │    interface            │                          │
   │                        │                          │
   ├─── Write tests ────────│                          │
   │                        │                          │
   ├─── Submit PR ─────────>│                          │
   │                        ├── Lint & type check ────>│
   │                        ├── Unit tests ───────────>│
   │                        ├── Integration tests ────>│
   │                        ├── Security scan ────────>│
   │                        ├── Automated backtest* ──>│
   │                        │                          │
   │<── Review comments ────│                          │
   │                        │                          │
   ├─── Address feedback ──>│                          │
   │                        │                          │
   │<── Merge + deploy ─────│                          │
   │                        │                          │
   * Backtest runs only for strategy plugins
```

### 4.4 PR Checklist

Before submitting, make sure:

- [ ] `plugin.manifest.json` is valid (`ty-cli plugin validate`)
- [ ] All interface methods are implemented (no `NotImplementedError` in required methods)
- [ ] `health_check()` returns `True` against the live source (for data plugins)
- [ ] Unit tests pass locally (`ty-cli plugin test <name>`)
- [ ] No hardcoded API keys or secrets in code
- [ ] Dependencies are declared in manifest
- [ ] README.md explains what the plugin does and any required configuration

### 4.5 Code of Conduct

This project follows the [Contributor Covenant v2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

Core principles:

- **Be welcoming.** We want contributors from every country, background, and skill level.
- **Be respectful.** Disagree with ideas, not people. No personal attacks.
- **Be constructive.** Every PR review comment should include a suggestion for improvement.
- **No financial advice.** This project builds tools, not investment recommendations. Never claim that a strategy "will make money."
- **Responsible disclosure.** If you find a security vulnerability, email security@ty-project.org. Do not open a public issue.

### 4.6 Communication Channels

| Channel | Purpose | Link |
|---------|---------|------|
| GitHub Discussions | Design proposals, questions, show-and-tell | `github.com/ty-project/agent-TY-Trading/discussions` |
| Discord | Real-time chat, help, community | `discord.gg/ty-project` |
| GitHub Issues | Bug reports, feature requests | `github.com/ty-project/agent-TY-Trading/issues` |
| Monthly Call | Architecture decisions, roadmap review | Announced in Discord |

---

## 5. Strategy Arena (竞技场)

The Arena is where strategies compete, evolve, and prove themselves.

### 5.1 How It Works

```
  ┌─────────────────────────────────────────────────────────┐
  │                    STRATEGY ARENA                        │
  │                                                         │
  │  ┌──────────┐    ┌──────────────┐    ┌──────────────┐  │
  │  │ SUBMIT   │───>│  BACKTEST    │───>│ PAPER TRADE  │  │
  │  │ Strategy │    │  (automated) │    │ (30 days)    │  │
  │  └──────────┘    └──────────────┘    └──────────────┘  │
  │                                             │           │
  │                  ┌──────────────┐            │           │
  │                  │ LEADERBOARD  │<───────────┘           │
  │                  │ (public)     │                        │
  │                  └──────────────┘                        │
  │                         │                               │
  │                  ┌──────v───────┐                        │
  │                  │  EVOLUTION   │                        │
  │                  │  (crossover) │                        │
  │                  └──────────────┘                        │
  └─────────────────────────────────────────────────────────┘
```

### 5.2 Automated Backtesting Pipeline

When a strategy plugin PR is submitted, the CI pipeline automatically runs:

```yaml
# .github/workflows/arena-backtest.yml
name: Arena Backtest

on:
  pull_request:
    paths: ["plugins/strategies/**"]

jobs:
  backtest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: pip install -e ./sdk/python -e ./arena

      - name: Run backtest suite
        run: |
          ty-cli arena backtest \
            --strategy ${{ github.event.pull_request.head.ref }} \
            --datasets standard-suite \
            --start 2020-01-01 \
            --end 2025-12-31 \
            --output results.json

      - name: Post results to PR
        uses: actions/github-script@v7
        with:
          script: |
            const results = require('./results.json');
            const body = `## Arena Backtest Results

            | Metric | Value |
            |--------|-------|
            | Sharpe Ratio | ${results.sharpe_ratio.toFixed(2)} |
            | Sortino Ratio | ${results.sortino_ratio.toFixed(2)} |
            | Max Drawdown | ${(results.max_drawdown * 100).toFixed(1)}% |
            | Win Rate | ${(results.win_rate * 100).toFixed(1)}% |
            | Profit Factor | ${results.profit_factor.toFixed(2)} |
            | Total Trades | ${results.total_trades} |
            | Calmar Ratio | ${results.calmar_ratio.toFixed(2)} |
            | Annual Return | ${(results.annualized_return * 100).toFixed(1)}% |

            *Backtest period: 2020-01-01 to 2025-12-31*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

### 5.3 Standard Backtest Datasets

Every strategy is tested against the same standardized datasets to ensure fair comparison:

| Dataset | Period | Markets | Regime Coverage |
|---------|--------|---------|----------------|
| `standard-suite` | 2020-2025 | US equities, crypto, forex | COVID crash, bull run, rate hikes, AI rally |
| `black-swan` | Selected events | All | Flash crashes, depegs, circuit breakers |
| `sideways` | Selected periods | US equities | Low-volatility, range-bound markets |
| `emerging` | 2020-2025 | CN, IN, BR equities | Emerging market specific dynamics |
| `crypto-cycles` | 2017-2025 | Crypto | Full bull-bear cycles |

### 5.4 Leaderboard & Ranking

The live leaderboard at `arena.ty-project.org` ranks strategies by composite score:

```
Composite Score = 0.30 * Sharpe
               + 0.20 * Sortino
               + 0.15 * (1 - |MaxDrawdown|)
               + 0.15 * WinRate
               + 0.10 * ProfitFactor_normalized
               + 0.10 * Consistency
```

Where `Consistency` = ratio of positive months to total months.

**Leaderboard tiers**:

| Tier | Badge | Requirement |
|------|-------|-------------|
| Gold | :1st_place_medal: | Top 10% after 90 days paper trading, Sharpe > 1.5 |
| Silver | :2nd_place_medal: | Top 25%, Sharpe > 1.0, max DD < 20% |
| Bronze | :3rd_place_medal: | Passed 30-day paper trading, Sharpe > 0.5 |
| Unranked | — | Submitted but not yet through paper trading |

### 5.5 Genetic Crossover Mechanism

The Arena's evolution engine periodically combines top-performing strategies:

```python
class ArenaCrossover:
    """
    Combine "genes" from top Arena strategies to discover
    novel combinations that no single contributor imagined.
    """

    def run_evolution_cycle(self, leaderboard: list[StrategyGenome]) -> list[StrategyGenome]:
        """Called weekly by the Arena scheduler."""

        # Take top 20 strategies
        top = leaderboard[:20]

        children = []
        for _ in range(50):
            parent_a, parent_b = random.sample(top, 2)

            child = StrategyGenome.crossover(parent_a, parent_b)
            child = child.mutate(mutation_rate=0.05)

            # Immediately backtest the child
            result = self.backtest_engine.run(child)
            child.fitness = self.fitness_function(child, result)

            children.append(child)

        # Only survivors replace the weakest on the leaderboard
        children.sort(key=lambda c: c.fitness, reverse=True)
        return children[:10]  # Top 10 children enter the arena
```

Children that outperform their parents on the leaderboard are labeled with a special `evolved` badge and their lineage (parent strategies) is publicly visible.

### 5.6 Revenue Sharing Model

When a strategy (or its evolved descendant) is used in production and generates profit:

| Recipient | Share | Condition |
|-----------|-------|-----------|
| Strategy Author | 40% | Original contributor of a strategy that enters Gold tier |
| Parent Strategy Authors | 10% each | If the strategy was evolved from existing strategies (max 2 parents) |
| Core Team | 20% | Maintenance and infrastructure |
| Community Fund | 20% | Funds bounties, grants, and infrastructure |

Revenue is distributed monthly. All calculations are transparent and auditable on the public dashboard.

---

## 6. Project Structure

```
agent-TY-Trading/
├── README.md                        # Project overview (English)
├── README_zh.md                     # Project overview (中文)
├── CONTRIBUTING.md                  # Contributor guide (English)
├── CONTRIBUTING_zh.md               # Contributor guide (中文)
├── LICENSE                          # MIT
├── CODE_OF_CONDUCT.md               # Contributor Covenant
│
├── docs/
│   ├── world-model-blueprint.md     # Architecture blueprint
│   ├── free-data-sources-research.md# Data sources research
│   ├── open-architecture.md         # This document
│   ├── api-reference/               # Auto-generated API docs
│   └── rfcs/                        # Design proposals (RFC-0001, etc.)
│
├── core/                            # Core engine (maintained by core team)
│   ├── engine/                      # Plugin orchestration, lifecycle
│   │   ├── registry.ts              # Plugin registry with hot-reload
│   │   ├── scheduler.ts             # Execution scheduling
│   │   ├── sandbox.ts               # Plugin isolation & resource limits
│   │   └── health.ts                # Health monitoring
│   ├── bus/                         # Inter-plugin message bus
│   │   ├── event_bus.ts             # Pub/sub event system
│   │   └── data_pipeline.ts         # L1 → L2 → L3 → L4 data flow
│   ├── storage/                     # Persistence layer
│   │   ├── timeseries.ts            # Time-series database interface
│   │   ├── graph.ts                 # Causal graph storage
│   │   └── vector.ts               # Embedding/vector store
│   └── config/                      # System configuration
│       ├── defaults.yaml
│       └── schema.ts
│
├── plugins/
│   ├── data-sources/                # Layer 1: Data source plugins
│   │   ├── yahoo-finance/
│   │   ├── defi-llama/
│   │   ├── fear-greed/
│   │   ├── fred-economic/
│   │   ├── coinGecko/
│   │   └── ...
│   ├── reasoning/                   # Layer 2: Reasoning/causal plugins
│   │   ├── simple-momentum/
│   │   ├── bayesian-macro/
│   │   ├── cross-market-causal/
│   │   └── ...
│   ├── bias-detectors/              # Layer 3: Bias detection plugins
│   │   ├── recency-bias/
│   │   ├── anchoring-bias/
│   │   ├── herding-detector/
│   │   └── ...
│   ├── evolution/                   # Layer 4: Evolution algorithm plugins
│   │   ├── tournament-ga/
│   │   ├── cma-es/
│   │   ├── differential-evolution/
│   │   └── ...
│   ├── strategies/                  # Composite strategy plugins
│   │   ├── momentum-value-hybrid/
│   │   ├── bias-contrarian/
│   │   └── ...
│   └── _template/                   # Plugin template for new contributors
│       ├── plugin.manifest.json
│       ├── src/
│       │   ├── plugin_template.py
│       │   └── plugin_template.ts
│       ├── tests/
│       │   ├── test_plugin.py
│       │   └── test_plugin.ts
│       └── README.md
│
├── sdk/
│   ├── python/                      # Python SDK
│   │   ├── ty_sdk/
│   │   │   ├── __init__.py
│   │   │   ├── types.py             # All shared types
│   │   │   ├── plugins.py           # Abstract base classes
│   │   │   └── testing.py           # Test harness
│   │   ├── setup.py
│   │   └── pyproject.toml
│   └── typescript/                  # TypeScript SDK
│       ├── src/
│       │   ├── index.ts
│       │   ├── types.ts
│       │   ├── plugins.ts
│       │   └── testing.ts
│       ├── package.json
│       └── tsconfig.json
│
├── arena/                           # Strategy Arena
│   ├── backtest/                    # Backtesting engine
│   │   ├── engine.py
│   │   ├── datasets/               # Standard backtest datasets
│   │   └── metrics.py
│   ├── paper-trading/               # Paper trading simulator
│   │   ├── simulator.py
│   │   └── recorder.py
│   ├── leaderboard/                 # Ranking system
│   │   ├── ranker.py
│   │   └── api.py
│   └── evolution/                   # Arena genetic crossover
│       ├── crossover.py
│       └── scheduler.py
│
├── dashboard/                       # Public performance dashboard
│   ├── web/                         # Next.js dashboard app
│   │   ├── src/
│   │   ├── package.json
│   │   └── next.config.js
│   └── api/                         # Dashboard API
│       └── server.py
│
├── cli/                             # ty-cli command-line tool
│   ├── src/
│   │   ├── commands/
│   │   │   ├── plugin.ts            # create, test, validate, submit
│   │   │   ├── arena.ts             # backtest, rank, evolve
│   │   │   └── config.ts            # system configuration
│   │   └── index.ts
│   ├── package.json
│   └── tsconfig.json
│
├── tests/
│   ├── unit/                        # Unit tests per module
│   ├── integration/                 # Cross-plugin integration tests
│   ├── e2e/                         # End-to-end system tests
│   └── fixtures/                    # Shared test data
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                   # Lint, type check, unit tests
│   │   ├── integration.yml          # Integration tests
│   │   ├── arena-backtest.yml       # Auto-backtest on strategy PRs
│   │   └── security.yml             # Dependency & plugin security scan
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── feature_request.yml
│   │   └── plugin_proposal.yml
│   └── PULL_REQUEST_TEMPLATE.md
│
├── docker-compose.yml               # Local development environment
├── Makefile                         # Common tasks
└── .env.example                     # Environment variables template
```

---

## 7. API & SDK

### 7.1 REST API

The core engine exposes a REST API for external integrations (dashboards, mobile apps, third-party tools).

**Base URL**: `http://localhost:8080/api/v1` (local) or `https://api.ty-project.org/v1` (hosted)

#### Endpoints

```
# ─── Plugins ────────────────────────────────────────────────
GET    /plugins                         # List all active plugins
GET    /plugins/:id                     # Get plugin details & health
POST   /plugins/:id/reload              # Trigger hot-reload
GET    /plugins/:id/metrics             # Get plugin performance metrics

# ─── Data ───────────────────────────────────────────────────
GET    /data/quote?symbol=AAPL          # Latest quote from best available source
GET    /data/candles?symbol=BTC-USD&tf=1d&start=...&end=...
POST   /data/query                      # Flexible data query (JSON body)
GET    /data/sources                    # List available data sources

# ─── Signals ────────────────────────────────────────────────
GET    /signals                         # Latest signals from all strategies
GET    /signals/:strategy               # Signals from a specific strategy
GET    /signals/history?since=...       # Historical signals

# ─── Arena ──────────────────────────────────────────────────
GET    /arena/leaderboard               # Current rankings
GET    /arena/strategy/:id              # Strategy details + equity curve
GET    /arena/strategy/:id/backtest     # Full backtest results
POST   /arena/submit                    # Submit a strategy for evaluation

# ─── System ─────────────────────────────────────────────────
GET    /health                          # System health check
GET    /metrics                         # Prometheus-compatible metrics
GET    /config                          # Current system configuration (non-sensitive)
```

#### Example: Fetching Signals

```bash
curl -s https://api.ty-project.org/v1/signals | jq '.signals[:2]'
```

```json
[
  {
    "strategy": "bias-contrarian-v2",
    "symbol": "NVDA",
    "direction": "short",
    "strength": 0.72,
    "confidence": 0.65,
    "timeHorizon": "1w",
    "reasoning": "Recency bias detected: 5-day return 2.3 std devs above 60-day mean. Herding signal from extreme call/put ratio.",
    "timestamp": 1743379200000
  },
  {
    "strategy": "macro-causal-v1",
    "symbol": "GLD",
    "direction": "long",
    "strength": 0.58,
    "confidence": 0.71,
    "timeHorizon": "1M",
    "reasoning": "Causal chain: rising fiscal deficit -> bond supply increase -> real yield pressure -> gold bid. Fed dot plot revision probability 68%.",
    "timestamp": 1743379200000
  }
]
```

### 7.2 Python SDK

```bash
pip install ty-sdk
```

```python
"""Example: Build and test a plugin entirely with the Python SDK."""

from ty_sdk import TYClient
from ty_sdk.plugins import DataSourcePlugin
from ty_sdk.testing import PluginTestHarness, validate_manifest
from ty_sdk.types import DataQuery, MarketType, Timeframe


# ─── Use the client to interact with a running TY instance ──

client = TYClient(base_url="http://localhost:8080")

# Get latest signals
signals = client.get_signals()
for s in signals:
    print(f"{s.symbol}: {s.direction} (strength={s.strength:.0%})")

# Fetch data through any loaded data source
candles = client.get_candles(
    symbol="ETH-USD",
    timeframe=Timeframe.H1,
    start="2026-03-01",
    end="2026-03-31",
)

# Check system health
health = client.health_check()
print(f"System healthy: {health.ok}, Plugins loaded: {health.plugins_active}")


# ─── Scaffold and test a new plugin ─────────────────────────

from ty_sdk.scaffold import create_plugin

create_plugin(
    name="my-new-source",
    plugin_type="data-source",
    language="python",
    output_dir="./plugins/data-sources/my-new-source",
)
```

### 7.3 TypeScript SDK

```bash
npm install @ty-project/sdk
```

```typescript
import { TYClient, PluginTestHarness } from "@ty-project/sdk";
import type { DataSourcePlugin, MarketType, Signal } from "@ty-project/sdk";

// ─── Use the client to interact with a running TY instance ──

const client = new TYClient({ baseUrl: "http://localhost:8080" });

const signals: Signal[] = await client.getSignals();
for (const s of signals) {
  console.log(`${s.symbol}: ${s.direction} (${(s.strength * 100).toFixed(0)}%)`);
}

const leaderboard = await client.arena.getLeaderboard();
console.table(leaderboard.slice(0, 10));

// ─── Test a plugin locally ──────────────────────────────────

import { MyDataSource } from "./my-data-source";

const harness = new PluginTestHarness(MyDataSource);
const plugin = await harness.setup();

const healthy = await plugin.healthCheck();
console.log(`Health: ${healthy}`);

const data = await plugin.fetch({
  symbols: ["AAPL"],
  market: "us-equities" as MarketType,
  timeframe: "1d",
  start: Date.now() - 30 * 86400000,
  end: Date.now(),
});
console.log(`Fetched ${data[0].candles.length} candles`);

await harness.teardown();
```

### 7.4 CLI Tool (`ty-cli`)

```bash
npm install -g @ty-project/cli
```

```
ty-cli — The TY Project command-line tool

USAGE:
  ty-cli <command> [options]

COMMANDS:

  plugin create     Scaffold a new plugin from template
    --name          Plugin name (kebab-case)
    --type          Plugin type: data-source | reasoning | bias-detector | evolution | strategy
    --language      Language: python | typescript
    --output-dir    Output directory (default: ./plugins/<type>/<name>)

  plugin validate   Validate plugin manifest and structure
    <path>          Path to plugin directory

  plugin test       Run plugin test suite
    <name>          Plugin name
    --coverage      Show coverage report
    --verbose       Verbose output

  plugin submit     Package and prepare for PR submission
    <name>          Plugin name

  arena backtest    Run backtests for a strategy
    --strategy      Strategy name or path
    --datasets      Dataset names (comma-separated) or "all"
    --start         Start date (YYYY-MM-DD)
    --end           End date (YYYY-MM-DD)
    --output        Output file for results (JSON)

  arena rank        Show current leaderboard
    --top           Number of entries (default: 20)
    --market        Filter by market type

  arena evolve      Trigger manual evolution cycle
    --parents       Parent strategy IDs (comma-separated)
    --children      Number of children to generate (default: 10)

  config show       Show current system configuration
  config set        Set a configuration value

EXAMPLES:
  ty-cli plugin create --name binance-ws --type data-source --language typescript
  ty-cli plugin test binance-ws --coverage
  ty-cli arena backtest --strategy momentum-value-hybrid --datasets standard-suite
  ty-cli arena rank --top 10 --market crypto
```

---

## 8. Governance

### 8.1 Decision Making: RFC Process

Major architectural decisions follow a Request for Comments (RFC) process:

```
  1. Author drafts RFC          →  docs/rfcs/RFC-XXXX-title.md
  2. Discussion period (14 days) →  GitHub Discussion thread
  3. Core team review           →  Approve / Request changes / Reject
  4. Final comment period (7 d) →  Last chance for community input
  5. Merge or close             →  Decision is recorded permanently
```

**RFC template** (`docs/rfcs/RFC-0000-template.md`):

```markdown
# RFC-XXXX: [Title]

- **Author**: [Name]
- **Status**: Draft | Discussion | Accepted | Rejected
- **Created**: YYYY-MM-DD
- **Discussion**: [link to GitHub Discussion]

## Summary
One paragraph.

## Motivation
Why is this change needed?

## Detailed Design
Technical specification.

## Alternatives Considered
What else was considered and why was it rejected.

## Backwards Compatibility
Does this break existing plugins?

## Implementation Plan
Phases and timeline.
```

### 8.2 Roles

| Role | Responsibilities | How to Become One |
|------|-----------------|------------------|
| **Core Maintainer** | Merge PRs, approve RFCs, release versions, security response | Invitation after sustained high-quality contributions |
| **Module Owner** | Own a specific plugin or core module, review PRs in that area | Propose via RFC after contributing 3+ PRs to the module |
| **Contributor** | Submit PRs, report bugs, participate in discussions | Anyone who submits a merged PR |
| **Community Member** | Discuss, suggest, test | Anyone |

### 8.3 Plugin Quality Tiers

Plugins progress through quality tiers based on demonstrated reliability:

```
  ┌───────────────┐    ┌───────────────┐    ┌───────────────┐
  │   COMMUNITY   │───>│   VERIFIED    │───>│     CORE      │
  │               │    │               │    │               │
  │ - PR merged   │    │ - 90+ days    │    │ - 180+ days   │
  │ - Tests pass  │    │ - 99% uptime  │    │ - Core team   │
  │ - Basic review│    │ - Security    │    │   maintains   │
  │               │    │   audit pass  │    │ - SLA backed  │
  │ No SLA        │    │ - Module owner│    │ - Production  │
  │               │    │   assigned    │    │   grade       │
  └───────────────┘    └───────────────┘    └───────────────┘
```

| Tier | Badge | Requirements | SLA |
|------|-------|-------------|-----|
| **Community** | `community` | Merged PR, tests pass, basic code review | None |
| **Verified** | `verified` | 90+ days in production, 99%+ uptime, security audit passed, module owner assigned | Best effort |
| **Core** | `core` | 180+ days, maintained by core team, full test coverage, documentation complete | 99.9% uptime |

### 8.4 Security Review Process

All plugins undergo security review before reaching `verified` tier:

**Automated checks (every PR)**:
- Dependency vulnerability scan (Snyk/Dependabot)
- Static analysis for common security issues
- No hardcoded credentials or API keys
- Network access restricted to declared domains in manifest
- No filesystem access outside sandbox

**Manual review (for `verified` promotion)**:
- Code review by a core maintainer with security focus
- Verify that the plugin does only what it claims
- Check for data exfiltration vectors
- Verify rate limiting compliance
- Review error handling (no sensitive data in error messages)

**Ongoing monitoring**:
- Runtime anomaly detection (unusual network patterns, memory usage)
- Dependency CVE monitoring with automated alerts
- Quarterly re-review for `core` tier plugins

### 8.5 Versioning & Compatibility

The project follows [Semantic Versioning 2.0.0](https://semver.org/):

- **Core interfaces**: Breaking changes require a major version bump and a 6-month deprecation period. Old interface versions are supported for at least 2 major releases.
- **Plugins**: Follow their own semver independently. The manifest declares which core interface version the plugin targets.
- **SDK**: Tracks core interface versions. SDK v2.x works with core interface v2.x.

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "coreInterfaceVersion": "^2.0.0"
}
```

---

## Appendix A: Quick Reference — "What Should I Build?"

Not sure where to start? Here are high-impact contributions the community needs right now:

### Data Sources (Layer 1) — Most Needed

| Source | Market | Difficulty | Notes |
|--------|--------|-----------|-------|
| Yahoo Finance | US/Global equities | Easy | Free, no auth, yfinance library |
| CoinGecko | Crypto | Easy | Free tier, 30 calls/min |
| FRED | US macro | Easy | Free API key, economic data |
| DeFiLlama | DeFi/crypto | Easy | Free, no auth, TVL/yields |
| Binance WebSocket | Crypto | Medium | Real-time streaming |
| Polygon.io | US equities | Medium | Free tier, real-time delayed |
| Finnhub | Global | Medium | Free tier, news + quotes |
| Alternative.me | Crypto sentiment | Easy | Already has example above |
| Etherscan | On-chain | Medium | Free tier, 5 calls/sec |
| Polymarket | Prediction markets | Medium | API access, event outcomes |

### Bias Detectors (Layer 3) — High Value

| Bias | Difficulty | Key Data Needed |
|------|-----------|----------------|
| Anchoring (earnings) | Medium | Price + earnings surprise data |
| Herding (positioning) | Medium | COT data, fund flows |
| Loss aversion | Medium | Price + volume around 52-week highs/lows |
| Narrative fallacy | Hard | News sentiment + fundamental divergence |
| Overconfidence (retail) | Medium | Options flow, social sentiment |

### Strategies (Composite) — Community Favorites

| Strategy | Complexity | Markets |
|----------|-----------|---------|
| Mean reversion + bias detection | Medium | Equities |
| Cross-chain DeFi yield | Medium | DeFi |
| Macro causal chains | Hard | Multi-asset |
| Sentiment contrarian | Medium | Crypto |
| Event-driven (earnings, FOMC) | Medium | US equities |

---

## Appendix B: Architecture Decision Records

| ADR | Decision | Rationale |
|-----|----------|-----------|
| ADR-001 | Polyglot plugin support (Python + TypeScript) | Python dominates quant/data science; TypeScript dominates web/real-time. Supporting both maximizes contributor pool. |
| ADR-002 | gRPC bridge between Python and TypeScript plugins | Efficient binary serialization, bidirectional streaming, auto-generated types from protobuf. |
| ADR-003 | Plugin sandbox with resource limits | A single misbehaving plugin must never crash the system. Defense in depth. |
| ADR-004 | Mandatory backtest for strategy plugins | Prevents untested strategies from entering the Arena. Ensures minimum quality bar. |
| ADR-005 | MIT license | Maximally permissive, simple, widely adopted in open-source — lowers barrier for contributors and enterprise adoption. |

---

*This document is a living specification. Propose changes via RFC or GitHub Discussion.*

*Built with conviction that the best financial intelligence comes from the collective wisdom of a global community, not a closed team.*
