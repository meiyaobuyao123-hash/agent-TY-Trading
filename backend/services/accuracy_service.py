"""Accuracy service — query and aggregate accuracy metrics."""

from __future__ import annotations

import logging
from typing import Optional

from sqlalchemy import Integer, select, and_, func
from sqlalchemy.ext.asyncio import AsyncSession

from backend.models import AccuracyStat, Judgment, Market, Settlement

logger = logging.getLogger(__name__)


async def get_accuracy_stats(
    session: AsyncSession,
    market_type: Optional[str] = None,
    period: str = "all",
) -> list[AccuracyStat]:
    """Query the latest accuracy stats, optionally filtered by market type."""
    stmt = select(AccuracyStat).where(AccuracyStat.period == period)

    if market_type:
        stmt = stmt.where(AccuracyStat.market_type == market_type)

    stmt = stmt.order_by(AccuracyStat.calculated_at.desc())

    # Get only the latest for each market_type
    result = await session.execute(stmt)
    stats = result.scalars().all()

    # Deduplicate: keep only the latest per market_type
    seen = set()
    unique = []
    for s in stats:
        if s.market_type not in seen:
            seen.add(s.market_type)
            unique.append(s)
    return unique


async def get_calibration_data(
    session: AsyncSession,
    market_type: Optional[str] = None,
) -> list[dict]:
    """Build calibration curve data: predicted confidence vs actual accuracy.

    Groups settled judgments into confidence buckets and computes actual accuracy
    for each bucket.
    """
    # Define confidence buckets
    buckets = [
        ("0-20%", 0.0, 0.2),
        ("20-40%", 0.2, 0.4),
        ("40-60%", 0.4, 0.6),
        ("60-80%", 0.6, 0.8),
        ("80-100%", 0.8, 1.01),
    ]

    points = []
    for label, lo, hi in buckets:
        stmt = (
            select(
                func.count(Settlement.id),
                func.sum(Settlement.is_correct.cast(Integer)),
            )
            .join(Judgment, Judgment.id == Settlement.judgment_id)
        )

        conditions = [
            Judgment.confidence_score >= lo,
            Judgment.confidence_score < hi,
        ]

        if market_type:
            stmt = stmt.join(Market, Market.id == Judgment.market_id)
            conditions.append(Market.market_type == market_type)

        stmt = stmt.where(and_(*conditions))
        result = await session.execute(stmt)
        row = result.one()
        total = row[0] or 0
        correct = row[1] or 0

        predicted_pct = (lo + hi) / 2 * 100
        actual_pct = (correct / total * 100) if total > 0 else 0.0

        points.append({
            "confidence_bucket": label,
            "predicted_pct": round(predicted_pct, 1),
            "actual_pct": round(actual_pct, 1),
            "count": total,
        })

    return points
