"""Accuracy tracker — settles expired judgments and recalculates accuracy stats."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import Integer, select, func, and_, case
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.plugin_base import EvolutionPlugin
from backend.models import AccuracyStat, Judgment, Market, MarketSnapshot, Settlement

logger = logging.getLogger(__name__)


class AccuracyTrackerPlugin(EvolutionPlugin):
    """Settle expired judgments and track accuracy statistics."""

    @property
    def name(self) -> str:
        return "accuracy-tracker"

    @property
    def display_name(self) -> str:
        return "Judgment Accuracy Tracker"

    async def initialize(self, config: dict) -> None:
        pass

    async def evaluate(self, data: dict) -> dict:
        """Not used directly — use settle_judgments and recalculate_accuracy instead."""
        return {"status": "ok"}


async def settle_judgments(session: AsyncSession) -> int:
    """Find expired, unsettled judgments and settle them.

    A judgment is settled by comparing its predicted direction against the
    actual price movement since the judgment was created.

    Returns the number of settled judgments.
    """
    now = datetime.utcnow()

    # Find unsettled expired judgments
    stmt = (
        select(Judgment)
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .where(
            and_(
                Judgment.expires_at <= now,
                Settlement.id.is_(None),
            )
        )
        .limit(100)
    )
    result = await session.execute(stmt)
    judgments = result.scalars().all()

    settled_count = 0
    for j in judgments:
        try:
            # Get the latest snapshot for this market to determine actual price
            snap_stmt = (
                select(MarketSnapshot)
                .where(MarketSnapshot.market_id == j.market_id)
                .order_by(MarketSnapshot.captured_at.desc())
                .limit(1)
            )
            snap_result = await session.execute(snap_stmt)
            latest_snap = snap_result.scalar_one_or_none()

            if latest_snap is None or latest_snap.price is None:
                continue

            # Get the snapshot at judgment time
            orig_snap_stmt = (
                select(MarketSnapshot)
                .where(MarketSnapshot.id == j.snapshot_id)
            )
            orig_result = await session.execute(orig_snap_stmt)
            orig_snap = orig_result.scalar_one_or_none()

            if orig_snap is None or orig_snap.price is None:
                # Use a fallback: just mark as not determinable
                continue

            orig_price = orig_snap.price
            actual_price = latest_snap.price

            # Determine actual direction
            if actual_price > orig_price * 1.001:
                actual_direction = "up"
            elif actual_price < orig_price * 0.999:
                actual_direction = "down"
            else:
                actual_direction = "flat"

            is_correct = j.direction == actual_direction

            settlement = Settlement(
                id=uuid.uuid4(),
                judgment_id=j.id,
                actual_price=actual_price,
                actual_direction=actual_direction,
                is_correct=is_correct,
                settled_at=now,
            )
            session.add(settlement)
            settled_count += 1
        except Exception:
            logger.exception("Failed to settle judgment %s", j.id)

    if settled_count:
        await session.commit()
    return settled_count


async def recalculate_accuracy(session: AsyncSession) -> int:
    """Recalculate accuracy stats for all market types and periods.

    Returns the number of stat records upserted.
    """
    periods = {
        "7d": timedelta(days=7),
        "30d": timedelta(days=30),
        "all": timedelta(days=36500),  # ~100 years = "all time"
    }
    now = datetime.utcnow()
    count = 0

    # Get distinct market types from markets table
    market_types_stmt = select(Market.market_type).distinct()
    mt_result = await session.execute(market_types_stmt)
    market_types = [row[0] for row in mt_result.fetchall()]

    if not market_types:
        market_types = ["crypto", "cn-equities", "forex", "macro", "prediction-markets"]

    for mt in market_types:
        for period_name, delta in periods.items():
            cutoff = now - delta

            # Count total and correct settled judgments
            base_stmt = (
                select(
                    func.count(Settlement.id),
                    func.sum(Settlement.is_correct.cast(Integer)),
                )
                .join(Judgment, Judgment.id == Settlement.judgment_id)
                .join(Market, Market.id == Judgment.market_id)
                .where(
                    and_(
                        Market.market_type == mt,
                        Settlement.settled_at >= cutoff,
                    )
                )
            )

            result = await session.execute(base_stmt)
            row = result.one()
            total = row[0] or 0
            correct = row[1] or 0
            accuracy = (correct / total * 100) if total > 0 else 0.0

            # Per-confidence accuracy
            conf_accuracies = {}
            for conf_level in ("high", "medium", "low"):
                conf_stmt = (
                    select(
                        func.count(Settlement.id),
                        func.sum(Settlement.is_correct.cast(Integer)),
                    )
                    .join(Judgment, Judgment.id == Settlement.judgment_id)
                    .join(Market, Market.id == Judgment.market_id)
                    .where(
                        and_(
                            Market.market_type == mt,
                            Judgment.confidence == conf_level,
                            Settlement.settled_at >= cutoff,
                        )
                    )
                )
                conf_result = await session.execute(conf_stmt)
                conf_row = conf_result.one()
                ct = conf_row[0] or 0
                cc = conf_row[1] or 0
                conf_accuracies[conf_level] = (cc / ct * 100) if ct > 0 else None

            # Calibration error: |predicted_confidence - actual_accuracy|
            avg_conf_stmt = (
                select(func.avg(Judgment.confidence_score))
                .join(Settlement, Settlement.judgment_id == Judgment.id)
                .join(Market, Market.id == Judgment.market_id)
                .where(
                    and_(
                        Market.market_type == mt,
                        Settlement.settled_at >= cutoff,
                    )
                )
            )
            avg_conf_result = await session.execute(avg_conf_stmt)
            avg_conf = avg_conf_result.scalar() or 0.5
            calibration_err = abs(avg_conf * 100 - accuracy) if total > 0 else 0.0

            stat = AccuracyStat(
                id=uuid.uuid4(),
                market_type=mt,
                period=period_name,
                total_judgments=total,
                correct_judgments=correct,
                accuracy_pct=round(accuracy, 2),
                calibration_err=round(calibration_err, 2),
                high_conf_accuracy=conf_accuracies.get("high"),
                medium_conf_accuracy=conf_accuracies.get("medium"),
                low_conf_accuracy=conf_accuracies.get("low"),
                calculated_at=now,
            )
            session.add(stat)
            count += 1

    if count:
        await session.commit()
    return count
