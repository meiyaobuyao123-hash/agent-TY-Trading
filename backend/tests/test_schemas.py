"""Tests for Pydantic schemas — validation and serialization."""

from __future__ import annotations

import uuid
from datetime import datetime

import pytest

from backend.schemas import (
    AccuracyStatOut,
    CalibrationPoint,
    CalibrationResponse,
    HealthResponse,
    JudgmentOut,
    JudgmentTriggerRequest,
    MarketCreate,
    MarketOut,
    MarketSnapshotOut,
    PluginOut,
)


class TestHealthSchema:

    def test_default_values(self):
        h = HealthResponse()
        assert h.status == "ok"
        assert h.version == "0.1.0"
        assert h.plugins == {}

    def test_with_plugins(self):
        h = HealthResponse(plugins={"data_sources": {"binance": True}})
        assert h.plugins["data_sources"]["binance"] is True


class TestMarketSchemas:

    def test_market_create(self):
        mc = MarketCreate(
            symbol="BTC-USD",
            name="Bitcoin",
            market_type="crypto",
            source="binance",
        )
        assert mc.symbol == "BTC-USD"
        assert mc.is_active is True  # default

    def test_market_out(self):
        mo = MarketOut(
            id=uuid.uuid4(),
            symbol="BTC-USD",
            name="Bitcoin",
            market_type="crypto",
            source="binance",
            is_active=True,
            created_at=datetime.utcnow(),
        )
        assert mo.latest_snapshot is None

    def test_snapshot_out(self):
        so = MarketSnapshotOut(
            id=uuid.uuid4(),
            price=67000.0,
            volume=1234.0,
            change_pct=2.5,
            captured_at=datetime.utcnow(),
        )
        assert so.price == 67000.0


class TestJudgmentSchemas:

    def test_judgment_out(self):
        jo = JudgmentOut(
            id=uuid.uuid4(),
            market_id=uuid.uuid4(),
            direction="up",
            confidence="high",
            confidence_score=0.85,
            rational_price=68000.0,
            deviation_pct=1.49,
            horizon_hours=4,
            created_at=datetime.utcnow(),
        )
        assert jo.is_settled is False
        assert jo.is_correct is None

    def test_trigger_request_defaults(self):
        req = JudgmentTriggerRequest()
        assert req.symbols is None
        assert req.horizon_hours == 4

    def test_trigger_request_with_symbols(self):
        req = JudgmentTriggerRequest(symbols=["BTC-USD", "ETH-USD"], horizon_hours=8)
        assert len(req.symbols) == 2
        assert req.horizon_hours == 8


class TestAccuracySchemas:

    def test_accuracy_stat_out(self):
        aso = AccuracyStatOut(
            id=uuid.uuid4(),
            market_type="crypto",
            period="7d",
            total_judgments=100,
            correct_judgments=65,
            accuracy_pct=65.0,
            calibration_err=5.0,
            calculated_at=datetime.utcnow(),
        )
        assert aso.accuracy_pct == 65.0

    def test_calibration_point(self):
        cp = CalibrationPoint(
            confidence_bucket="60-80%",
            predicted_pct=70.0,
            actual_pct=68.5,
            count=50,
        )
        assert cp.count == 50

    def test_calibration_response(self):
        cr = CalibrationResponse(points=[
            CalibrationPoint(confidence_bucket="0-20%", predicted_pct=10, actual_pct=12, count=5),
        ])
        assert len(cr.points) == 1


class TestPluginSchema:

    def test_plugin_out(self):
        po = PluginOut(name="binance-rest", display_name="Binance", type="data_source")
        assert po.markets is None
        assert po.bias_type is None
