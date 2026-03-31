"""Tests for the judgment orchestration service."""

from __future__ import annotations

import uuid
from datetime import datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.plugin_manager import PluginManager
from backend.core.plugin_base import DataSourcePlugin, ReasoningPlugin
from backend.core.types import DataQuery, MarketData, MarketTick, MarketType
from backend.models import Market
from backend.services.judgment_service import trigger_judgment_cycle


class MockDataSource(DataSourcePlugin):
    @property
    def name(self) -> str:
        return "binance-rest"

    @property
    def display_name(self) -> str:
        return "Mock Binance"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        pass

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        return []

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        return [
            MarketTick(
                symbol=s, price=67000.0, volume=100.0,
                timestamp=0, source="mock", change_pct=2.0,
            )
            for s in symbols
        ]

    async def health_check(self) -> bool:
        return True


class MockReasoning(ReasoningPlugin):
    @property
    def name(self) -> str:
        return "ai-consensus"

    @property
    def display_name(self) -> str:
        return "Mock AI Consensus"

    async def initialize(self, config: dict) -> None:
        pass

    async def analyze(self, context: dict) -> dict:
        return {
            "direction": "up",
            "confidence": "high",
            "confidence_score": 0.85,
            "rational_price": 68000.0,
            "reasoning": "Test reasoning",
            "model_votes": [
                {"model_name": "claude", "direction": "up", "confidence": 0.9, "reasoning": "bull"},
            ],
            "deviation_pct": 1.49,
        }


class TestJudgmentService:

    @pytest.mark.asyncio
    async def test_trigger_no_markets(self, session: AsyncSession):
        pm = PluginManager()
        pm.register_reasoning(MockReasoning())
        judgments = await trigger_judgment_cycle(session, pm, symbols=["NONEXISTENT"])
        assert len(judgments) == 0

    @pytest.mark.asyncio
    async def test_trigger_no_reasoning_plugin(self, session: AsyncSession, sample_market):
        pm = PluginManager()
        # No reasoning plugin registered
        judgments = await trigger_judgment_cycle(session, pm, symbols=["BTC-USD"])
        assert len(judgments) == 0

    @pytest.mark.asyncio
    async def test_trigger_success(self, session: AsyncSession, sample_market):
        pm = PluginManager()
        pm.register_data_source(MockDataSource())
        pm.register_reasoning(MockReasoning())

        judgments = await trigger_judgment_cycle(session, pm, symbols=["BTC-USD"])
        assert len(judgments) == 1
        j = judgments[0]
        assert j.direction == "up"
        assert j.confidence == "high"
        assert j.confidence_score == 0.85
        assert j.rational_price == 68000.0

    @pytest.mark.asyncio
    async def test_trigger_all_active_markets(self, session: AsyncSession, sample_market):
        pm = PluginManager()
        pm.register_data_source(MockDataSource())
        pm.register_reasoning(MockReasoning())

        # Trigger without specifying symbols => all active markets
        judgments = await trigger_judgment_cycle(session, pm)
        assert len(judgments) >= 1

    @pytest.mark.asyncio
    async def test_trigger_custom_horizon(self, session: AsyncSession, sample_market):
        pm = PluginManager()
        pm.register_data_source(MockDataSource())
        pm.register_reasoning(MockReasoning())

        judgments = await trigger_judgment_cycle(session, pm, symbols=["BTC-USD"], horizon_hours=8)
        assert len(judgments) == 1
        assert judgments[0].horizon_hours == 8
