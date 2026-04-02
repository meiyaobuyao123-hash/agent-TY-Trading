"""Shared types for the TY system — adapted from open-architecture.md."""

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
    MACRO = "macro"
    ETF = "etf"
    KR_EQUITIES = "kr-equities"
    IN_EQUITIES = "in-equities"
    LATAM_EQUITIES = "latam-equities"
    MENA_EQUITIES = "mena-equities"
    UK_EQUITIES = "uk-equities"
    AU_EQUITIES = "au-equities"
    SG_EQUITIES = "sg-equities"
    TW_EQUITIES = "tw-equities"


class Timeframe(str, Enum):
    M1 = "1m"
    M5 = "5m"
    M15 = "15m"
    H1 = "1h"
    H4 = "4h"
    D1 = "1d"
    W1 = "1w"
    MO1 = "1M"


class Direction(str, Enum):
    UP = "up"
    DOWN = "down"
    FLAT = "flat"


class Confidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


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
    change_pct: Optional[float] = None


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
class ModelVote:
    model_name: str
    direction: Direction
    confidence: float
    rational_price: Optional[float]
    reasoning: str


@dataclass
class ConsensusResult:
    direction: Direction
    confidence: Confidence
    confidence_score: float
    rational_price: Optional[float]
    reasoning: str
    model_votes: list[ModelVote]
    deviation_pct: Optional[float] = None


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
