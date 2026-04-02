"""Pydantic request/response schemas for the TY API."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, Field


# ── Health ────────────────────────────────────────────────────────

class HealthResponse(BaseModel):
    status: str = "ok"
    version: str = "0.1.0"
    plugins: dict[str, dict[str, bool]] = {}


# ── Markets ───────────────────────────────────────────────────────

class MarketCreate(BaseModel):
    symbol: str
    name: str
    market_type: str
    source: str
    is_active: bool = True


class MarketSnapshotOut(BaseModel):
    id: UUID
    price: Optional[float] = None
    volume: Optional[float] = None
    change_pct: Optional[float] = None
    captured_at: datetime

    model_config = {"from_attributes": True}


class MarketOut(BaseModel):
    id: UUID
    symbol: str
    name: str
    market_type: str
    source: str
    is_active: bool
    created_at: datetime
    latest_snapshot: Optional[MarketSnapshotOut] = None

    model_config = {"from_attributes": True}


# ── Judgments ─────────────────────────────────────────────────────

class ModelVoteOut(BaseModel):
    model_name: str
    direction: str
    confidence: float
    rational_price: Optional[float] = None
    reasoning: str


class JudgmentOut(BaseModel):
    id: UUID
    market_id: UUID
    symbol: Optional[str] = None
    direction: str
    confidence: str
    confidence_score: float
    rational_price: Optional[float] = None
    deviation_pct: Optional[float] = None
    reasoning: Optional[str] = None
    model_votes: Optional[list[dict]] = None
    quality_score: Optional[float] = None
    up_probability: Optional[float] = None
    down_probability: Optional[float] = None
    flat_probability: Optional[float] = None
    bias_flags: Optional[list[dict]] = None
    is_low_confidence: bool = False
    horizon_hours: int = 4
    expires_at: Optional[datetime] = None
    created_at: datetime
    is_settled: bool = False
    is_correct: Optional[bool] = None

    model_config = {"from_attributes": True}


class JudgmentTriggerRequest(BaseModel):
    symbols: Optional[list[str]] = None  # None = all active markets
    horizon_hours: int = 4


class JudgmentTriggerResponse(BaseModel):
    triggered: int
    judgments: list[JudgmentOut]


# ── Accuracy ──────────────────────────────────────────────────────

class AccuracyStatOut(BaseModel):
    id: UUID
    market_type: str
    period: str
    total_judgments: int
    correct_judgments: int
    accuracy_pct: float
    calibration_err: float
    high_conf_accuracy: Optional[float] = None
    medium_conf_accuracy: Optional[float] = None
    low_conf_accuracy: Optional[float] = None
    calculated_at: datetime

    model_config = {"from_attributes": True}


class CalibrationPoint(BaseModel):
    confidence_bucket: str
    predicted_pct: float
    actual_pct: float
    count: int


class CalibrationResponse(BaseModel):
    points: list[CalibrationPoint]


# ── Plugins ───────────────────────────────────────────────────────

class PluginOut(BaseModel):
    name: str
    display_name: str
    type: str
    markets: Optional[list[str]] = None
    bias_type: Optional[str] = None


# ── Pagination ────────────────────────────────────────────────────

class PaginatedResponse(BaseModel):
    items: list[Any]
    total: int
    page: int
    page_size: int
