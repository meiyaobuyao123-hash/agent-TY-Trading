"""Stats router — overview statistics for the AI evolution dashboard."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import select, func, desc, and_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from backend.database import get_session
from backend.models import Market, MarketSnapshot, Judgment, Settlement, AccuracyStat

router = APIRouter(prefix="/stats", tags=["stats"])


class OverviewResponse(BaseModel):
    days_running: int
    total_judgments: int
    settled_judgments: int
    overall_accuracy: float
    markets_tracked: int
    markets_with_data: int
    active_models: list[str]
    active_data_sources: int


@router.get("/overview", response_model=OverviewResponse)
async def get_overview(
    session: AsyncSession = Depends(get_session),
) -> OverviewResponse:
    """Return high-level stats for the AI evolution dashboard."""

    # Total markets
    total_markets_result = await session.execute(
        select(func.count()).select_from(Market).where(Market.is_active == True)
    )
    markets_tracked = total_markets_result.scalar() or 0

    # Markets with at least one snapshot
    markets_with_data_result = await session.execute(
        select(func.count(func.distinct(MarketSnapshot.market_id)))
    )
    markets_with_data = markets_with_data_result.scalar() or 0

    # Total judgments
    total_judgments_result = await session.execute(
        select(func.count()).select_from(Judgment)
    )
    total_judgments = total_judgments_result.scalar() or 0

    # Settled judgments
    settled_result = await session.execute(
        select(func.count()).select_from(Settlement)
    )
    settled_judgments = settled_result.scalar() or 0

    # Correct judgments
    correct_result = await session.execute(
        select(func.count()).select_from(Settlement).where(Settlement.is_correct == True)
    )
    correct_judgments = correct_result.scalar() or 0

    # Overall accuracy
    overall_accuracy = 0.0
    if settled_judgments > 0:
        overall_accuracy = round((correct_judgments / settled_judgments) * 100, 1)

    # Days running — from the earliest judgment
    earliest_result = await session.execute(
        select(func.min(Judgment.created_at))
    )
    earliest = earliest_result.scalar()
    days_running = 0
    if earliest is not None:
        from datetime import datetime, timezone
        now = datetime.utcnow()
        delta = now - earliest
        days_running = max(1, delta.days)

    # Active models — extract from model_votes JSON
    active_models = ["deepseek"]

    # Active data sources count
    active_data_sources = 5

    return OverviewResponse(
        days_running=days_running,
        total_judgments=total_judgments,
        settled_judgments=settled_judgments,
        overall_accuracy=overall_accuracy,
        markets_tracked=markets_tracked,
        markets_with_data=markets_with_data,
        active_models=active_models,
        active_data_sources=active_data_sources,
    )


class AccuracyHistoryItem(BaseModel):
    calculated_at: str
    accuracy_pct: float
    total_judgments: int
    correct_judgments: int


@router.get("/accuracy-history", response_model=list[AccuracyHistoryItem])
async def get_accuracy_history(
    session: AsyncSession = Depends(get_session),
) -> list[AccuracyHistoryItem]:
    """Return the last 30 accuracy snapshots aggregated across market types."""

    # Single query: aggregate by calculated_at, order desc, limit 30
    stmt = (
        select(
            AccuracyStat.calculated_at,
            func.sum(AccuracyStat.total_judgments).label("total"),
            func.sum(AccuracyStat.correct_judgments).label("correct"),
        )
        .group_by(AccuracyStat.calculated_at)
        .order_by(desc(AccuracyStat.calculated_at))
        .limit(30)
    )
    rows = await session.execute(stmt)
    items = rows.fetchall()

    if not items:
        return []

    # Reverse to chronological order
    result = []
    for row in reversed(items):
        ts, total, correct = row[0], row[1] or 0, row[2] or 0
        pct = round((correct / total * 100), 1) if total > 0 else 0.0
        result.append(AccuracyHistoryItem(
            calculated_at=ts.isoformat() if isinstance(ts, datetime) else str(ts),
            accuracy_pct=pct,
            total_judgments=total,
            correct_judgments=correct,
        ))

    return result


# ── AI Insights ─────────────────────────────────────────────────────────


class HighestConfidenceInsight(BaseModel):
    symbol: str
    direction: str
    confidence_score: float


class BiggestDeviationInsight(BaseModel):
    symbol: str
    deviation_pct: float
    direction: str


class StreakInsight(BaseModel):
    symbol: str
    correct_streak: int


class InsightsResponse(BaseModel):
    highest_confidence: Optional[HighestConfidenceInsight] = None
    biggest_deviation: Optional[BiggestDeviationInsight] = None
    streaks: list[StreakInsight] = []


@router.get("/insights", response_model=InsightsResponse)
async def get_insights(
    session: AsyncSession = Depends(get_session),
) -> InsightsResponse:
    """Return AI insight highlights for the dashboard."""

    # 1. Highest confidence: latest judgment per market, pick the one with max confidence_score
    latest_sub = (
        select(
            Judgment.market_id,
            func.max(Judgment.created_at).label("max_at"),
        )
        .join(Market, Market.id == Judgment.market_id)
        .where(Market.is_active == True)
        .group_by(Judgment.market_id)
        .subquery()
    )
    latest_stmt = (
        select(Judgment, Market.symbol)
        .join(
            latest_sub,
            and_(
                Judgment.market_id == latest_sub.c.market_id,
                Judgment.created_at == latest_sub.c.max_at,
            ),
        )
        .join(Market, Market.id == Judgment.market_id)
        .order_by(desc(Judgment.confidence_score))
    )
    latest_result = await session.execute(latest_stmt)
    latest_rows = latest_result.all()

    highest_confidence = None
    biggest_deviation = None

    if latest_rows:
        # Highest confidence
        top = latest_rows[0]
        highest_confidence = HighestConfidenceInsight(
            symbol=top[1],
            direction=top[0].direction,
            confidence_score=top[0].confidence_score,
        )

        # Biggest deviation
        max_dev_row = None
        max_dev_abs = 0.0
        for row in latest_rows:
            j = row[0]
            if j.deviation_pct is not None and abs(j.deviation_pct) > max_dev_abs:
                max_dev_abs = abs(j.deviation_pct)
                max_dev_row = row
        if max_dev_row is not None:
            biggest_deviation = BiggestDeviationInsight(
                symbol=max_dev_row[1],
                deviation_pct=round(max_dev_row[0].deviation_pct, 2),
                direction=max_dev_row[0].direction,
            )

    # 2. Streaks: find markets with 3+ consecutive correct predictions
    streaks: list[StreakInsight] = []

    # Get all settled judgments ordered by market and time
    settled_stmt = (
        select(Judgment, Market.symbol)
        .join(Market, Market.id == Judgment.market_id)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
        .where(Market.is_active == True)
        .order_by(Market.symbol, desc(Judgment.created_at))
    )
    settled_result = await session.execute(settled_stmt)
    settled_rows = settled_result.unique().all()

    # Group by symbol and count consecutive correct from most recent
    from itertools import groupby
    symbol_groups: dict[str, list] = {}
    for row in settled_rows:
        sym = row[1]
        if sym not in symbol_groups:
            symbol_groups[sym] = []
        symbol_groups[sym].append(row[0])

    for sym, judgments_list in symbol_groups.items():
        streak = 0
        for j in judgments_list:
            if j.settlement and j.settlement.is_correct:
                streak += 1
            else:
                break
        if streak >= 3:
            streaks.append(StreakInsight(symbol=sym, correct_streak=streak))

    streaks.sort(key=lambda s: s.correct_streak, reverse=True)

    return InsightsResponse(
        highest_confidence=highest_confidence,
        biggest_deviation=biggest_deviation,
        streaks=streaks,
    )


# ── Alerts ─────────────────────────────────────────────────────────


class AlertItem(BaseModel):
    type: str  # "high_confidence" | "large_deviation" | "accuracy_milestone" | "streak"
    title: str
    detail: str
    symbol: Optional[str] = None
    timestamp: str


class AlertsResponse(BaseModel):
    alerts: list[AlertItem]


@router.get("/alerts", response_model=AlertsResponse)
async def get_alerts(
    hours: int = Query(24, ge=1, le=168),
    session: AsyncSession = Depends(get_session),
) -> AlertsResponse:
    """Return notable events from the last N hours for notification-ready infrastructure."""
    cutoff = datetime.utcnow() - timedelta(hours=hours)
    alerts: list[AlertItem] = []

    # 1. High-confidence signals (>0.7)
    high_conf_stmt = (
        select(Judgment, Market.symbol)
        .join(Market, Market.id == Judgment.market_id)
        .where(Judgment.created_at >= cutoff, Judgment.confidence_score > 0.7)
        .order_by(desc(Judgment.confidence_score))
        .limit(5)
    )
    high_conf_result = await session.execute(high_conf_stmt)
    for j, sym in high_conf_result.all():
        dir_cn = {"up": "看涨", "down": "看跌", "flat": "观望"}.get(j.direction, j.direction)
        alerts.append(AlertItem(
            type="high_confidence",
            title=f"高置信信号: {sym}",
            detail=f"{dir_cn} 置信度 {j.confidence_score * 100:.0f}%",
            symbol=sym,
            timestamp=j.created_at.isoformat(),
        ))

    # 2. Large deviations (>5%)
    dev_stmt = (
        select(Judgment, Market.symbol)
        .join(Market, Market.id == Judgment.market_id)
        .where(Judgment.created_at >= cutoff)
        .order_by(desc(Judgment.created_at))
    )
    dev_result = await session.execute(dev_stmt)
    for j, sym in dev_result.all():
        if j.deviation_pct is not None and abs(j.deviation_pct) > 5.0:
            direction = "被低估" if j.deviation_pct > 0 else "被高估"
            alerts.append(AlertItem(
                type="large_deviation",
                title=f"大偏差: {sym}",
                detail=f"偏差 {j.deviation_pct:+.1f}% ({direction})",
                symbol=sym,
                timestamp=j.created_at.isoformat(),
            ))

    # 3. Accuracy milestones — check if any market type crossed 60% (latest per type only)
    acc_stmt = (
        select(AccuracyStat)
        .where(AccuracyStat.calculated_at >= cutoff, AccuracyStat.period == "all")
        .order_by(desc(AccuracyStat.calculated_at))
    )
    acc_result = await session.execute(acc_stmt)
    seen_types: set[str] = set()
    for stat in acc_result.scalars().all():
        if stat.market_type in seen_types:
            continue
        seen_types.add(stat.market_type)
        if stat.accuracy_pct >= 60 and stat.total_judgments >= 10:
            alerts.append(AlertItem(
                type="accuracy_milestone",
                title=f"准确率里程碑: {stat.market_type}",
                detail=f"准确率达 {stat.accuracy_pct:.1f}% ({stat.correct_judgments}/{stat.total_judgments})",
                timestamp=stat.calculated_at.isoformat(),
            ))

    # 4. Streaks (5+) — reuse streak logic
    settled_stmt = (
        select(Judgment, Market.symbol)
        .join(Market, Market.id == Judgment.market_id)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
        .where(Market.is_active == True)
        .order_by(Market.symbol, desc(Judgment.created_at))
    )
    settled_result = await session.execute(settled_stmt)
    settled_rows = settled_result.unique().all()

    symbol_groups_alert: dict[str, list] = {}
    for row in settled_rows:
        sym = row[1]
        symbol_groups_alert.setdefault(sym, []).append(row[0])

    for sym, jlist in symbol_groups_alert.items():
        streak = 0
        for j in jlist:
            if j.settlement and j.settlement.is_correct:
                streak += 1
            else:
                break
        if streak >= 5:
            alerts.append(AlertItem(
                type="streak",
                title=f"连续命中: {sym}",
                detail=f"已连续正确 {streak} 次",
                symbol=sym,
                timestamp=jlist[0].created_at.isoformat(),
            ))

    # Sort by timestamp descending
    alerts.sort(key=lambda a: a.timestamp, reverse=True)

    # Limit to 20 alerts
    return AlertsResponse(alerts=alerts[:20])
