"""Tests for the accuracy tracker evolution plugin."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from backend.models import (
    AccuracyStat,
    Judgment,
    Market,
    MarketSnapshot,
    Settlement,
)
from backend.plugins.evolution.accuracy_tracker import (
    AccuracyTrackerPlugin,
    settle_judgments,
)


class TestAccuracyTrackerPlugin:

    def test_plugin_properties(self):
        plugin = AccuracyTrackerPlugin()
        assert plugin.name == "accuracy-tracker"
        assert plugin.display_name == "Judgment Accuracy Tracker"

    @pytest.mark.asyncio
    async def test_evaluate(self):
        plugin = AccuracyTrackerPlugin()
        await plugin.initialize({})
        result = await plugin.evaluate({})
        assert result["status"] == "ok"


class TestSettleJudgments:

    @pytest.mark.asyncio
    async def test_settle_expired_judgment(self, session: AsyncSession, sample_market, sample_snapshot):
        """An expired judgment should be settled when a newer snapshot exists."""
        # Create a judgment that has expired
        j = Judgment(
            id=uuid.uuid4(),
            market_id=sample_market.id,
            snapshot_id=sample_snapshot.id,
            direction="up",
            confidence="high",
            confidence_score=0.85,
            rational_price=68000.0,
            horizon_hours=4,
            expires_at=datetime.utcnow() - timedelta(hours=1),
            created_at=datetime.utcnow() - timedelta(hours=5),
        )
        session.add(j)

        # Create a newer snapshot with higher price (direction was "up", so this should be correct)
        new_snap = MarketSnapshot(
            id=uuid.uuid4(),
            market_id=sample_market.id,
            price=68000.0,  # Higher than the 67000 in sample_snapshot
            volume=1500000.0,
            change_pct=1.5,
            captured_at=datetime.utcnow(),
        )
        session.add(new_snap)
        await session.commit()

        count = await settle_judgments(session)
        assert count >= 1

    @pytest.mark.asyncio
    async def test_no_expired_judgments(self, session: AsyncSession, sample_market, sample_snapshot):
        """Judgments that haven't expired should not be settled."""
        j = Judgment(
            id=uuid.uuid4(),
            market_id=sample_market.id,
            snapshot_id=sample_snapshot.id,
            direction="up",
            confidence="medium",
            confidence_score=0.6,
            horizon_hours=4,
            expires_at=datetime.utcnow() + timedelta(hours=3),  # Not expired
            created_at=datetime.utcnow(),
        )
        session.add(j)
        await session.commit()

        count = await settle_judgments(session)
        assert count == 0

    @pytest.mark.asyncio
    async def test_already_settled_not_resettled(self, session: AsyncSession, sample_judgment):
        """A judgment with an existing settlement should not be resettled."""
        # Add a settlement
        s = Settlement(
            id=uuid.uuid4(),
            judgment_id=sample_judgment.id,
            actual_price=68000.0,
            actual_direction="up",
            is_correct=True,
            settled_at=datetime.utcnow(),
        )
        session.add(s)
        await session.commit()

        count = await settle_judgments(session)
        assert count == 0
