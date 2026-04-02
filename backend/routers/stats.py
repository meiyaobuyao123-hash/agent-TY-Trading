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


class MarketBreadth(BaseModel):
    up_count: int = 0
    down_count: int = 0
    flat_count: int = 0
    total: int = 0
    up_pct: float = 50.0
    mood: str = "中性"


class BrierScoreByType(BaseModel):
    market_type: str
    brier_score: float
    count: int


class OverviewResponse(BaseModel):
    days_running: int
    total_judgments: int
    settled_judgments: int
    overall_accuracy: float
    brier_score: Optional[float] = None
    brier_by_type: list[BrierScoreByType] = []
    markets_tracked: int
    markets_with_data: int
    active_models: list[str]
    active_data_sources: int
    market_breadth: Optional[MarketBreadth] = None


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

    # Settled judgments (total)
    settled_result = await session.execute(
        select(func.count()).select_from(Settlement)
    )
    settled_judgments = settled_result.scalar() or 0

    # Meaningful settled judgments (exclude trivial flat-flat with is_correct=NULL)
    meaningful_result = await session.execute(
        select(func.count()).select_from(Settlement).where(Settlement.is_correct.isnot(None))
    )
    meaningful_judgments = meaningful_result.scalar() or 0

    # Correct judgments
    correct_result = await session.execute(
        select(func.count()).select_from(Settlement).where(Settlement.is_correct == True)
    )
    correct_judgments = correct_result.scalar() or 0

    # Overall accuracy — based on meaningful judgments only
    overall_accuracy = 0.0
    if meaningful_judgments > 0:
        overall_accuracy = round((correct_judgments / meaningful_judgments) * 100, 1)

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
    active_data_sources = 6  # +1 for fear & greed

    # Market breadth: compute from latest snapshots
    breadth = None
    try:
        # Get the latest snapshot per market with change_pct
        latest_snap_sub = (
            select(
                MarketSnapshot.market_id,
                func.max(MarketSnapshot.captured_at).label("max_at"),
            )
            .group_by(MarketSnapshot.market_id)
            .subquery()
        )
        snap_stmt = (
            select(MarketSnapshot.change_pct)
            .join(
                latest_snap_sub,
                and_(
                    MarketSnapshot.market_id == latest_snap_sub.c.market_id,
                    MarketSnapshot.captured_at == latest_snap_sub.c.max_at,
                ),
            )
            .where(MarketSnapshot.change_pct.isnot(None))
        )
        snap_result = await session.execute(snap_stmt)
        changes = [r[0] for r in snap_result.all()]
        if changes:
            up_c = sum(1 for c in changes if c > 0.5)
            down_c = sum(1 for c in changes if c < -0.5)
            flat_c = len(changes) - up_c - down_c
            up_pct = up_c / len(changes) * 100
            mood = "贪婪" if up_pct > 70 else ("恐慌" if up_pct < 30 else "中性")
            breadth = MarketBreadth(
                up_count=up_c,
                down_count=down_c,
                flat_count=flat_c,
                total=len(changes),
                up_pct=round(up_pct, 1),
                mood=mood,
            )
    except Exception:
        pass

    # Brier score calculation (R13) — measures calibration quality
    brier_score = None
    brier_by_type: list[BrierScoreByType] = []
    try:
        brier_stmt = (
            select(Judgment, Settlement, Market.market_type)
            .join(Settlement, Settlement.judgment_id == Judgment.id)
            .join(Market, Market.id == Judgment.market_id)
            .where(Settlement.is_correct.isnot(None))
        )
        brier_result = await session.execute(brier_stmt)
        brier_rows = brier_result.all()

        if brier_rows:
            total_brier = 0.0
            count_brier = 0
            type_brier: dict[str, list[float]] = {}

            for j, s, mt in brier_rows:
                # Get the predicted probability for the actual outcome
                actual_dir = s.actual_direction or ("up" if s.is_correct else "down")
                # Map actual direction to the predicted probability
                if actual_dir == "up":
                    pred_prob = j.up_probability if j.up_probability is not None else (
                        j.confidence_score if j.direction == "up" else (1.0 - j.confidence_score) * 0.5
                    )
                elif actual_dir == "down":
                    pred_prob = j.down_probability if j.down_probability is not None else (
                        j.confidence_score if j.direction == "down" else (1.0 - j.confidence_score) * 0.5
                    )
                else:
                    pred_prob = j.flat_probability if j.flat_probability is not None else (
                        j.confidence_score if j.direction == "flat" else (1.0 - j.confidence_score) * 0.5
                    )

                # Brier score: (predicted_probability - actual_outcome)^2
                # actual_outcome = 1.0 (the event happened)
                brier_val = (pred_prob - 1.0) ** 2
                total_brier += brier_val
                count_brier += 1

                type_brier.setdefault(mt, []).append(brier_val)

            if count_brier > 0:
                brier_score = round(total_brier / count_brier, 4)

            for mt, vals in sorted(type_brier.items()):
                brier_by_type.append(BrierScoreByType(
                    market_type=mt,
                    brier_score=round(sum(vals) / len(vals), 4),
                    count=len(vals),
                ))
    except Exception:
        pass

    return OverviewResponse(
        days_running=days_running,
        total_judgments=total_judgments,
        settled_judgments=settled_judgments,
        overall_accuracy=overall_accuracy,
        brier_score=brier_score,
        brier_by_type=brier_by_type,
        markets_tracked=markets_tracked,
        markets_with_data=markets_with_data,
        active_models=active_models,
        active_data_sources=active_data_sources,
        market_breadth=breadth,
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


# ── Bias Report ─────────────────────────────────────────────────────────


class BiasTypeStats(BaseModel):
    type: str
    label: str
    count: int
    pct_of_judgments: float
    accuracy_when_biased: Optional[float] = None
    accuracy_when_unbiased: Optional[float] = None


class BiasReportResponse(BaseModel):
    total_judgments_with_bias: int
    total_judgments: int
    bias_rate: float
    bias_types: list[BiasTypeStats]
    insight: str


@router.get("/bias-report", response_model=BiasReportResponse)
async def get_bias_report(
    session: AsyncSession = Depends(get_session),
) -> BiasReportResponse:
    """Return aggregate bias detection statistics and correlation with accuracy."""

    # Get all judgments with bias_flags
    all_stmt = (
        select(Judgment)
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
        .order_by(desc(Judgment.created_at))
        .limit(500)
    )
    result = await session.execute(all_stmt)
    judgments = result.unique().scalars().all()

    total = len(judgments)
    if total == 0:
        return BiasReportResponse(
            total_judgments_with_bias=0,
            total_judgments=0,
            bias_rate=0.0,
            bias_types=[],
            insight="暂无判断数据，无法生成偏差报告。",
        )

    # Count bias types
    bias_counts: dict[str, int] = {}
    bias_labels: dict[str, str] = {}
    biased_correct: dict[str, int] = {}
    biased_settled: dict[str, int] = {}
    unbiased_correct = 0
    unbiased_settled = 0
    judgments_with_bias = 0

    for j in judgments:
        flags = j.bias_flags or []
        has_bias = len(flags) > 0
        if has_bias:
            judgments_with_bias += 1

        is_settled = j.settlement is not None
        is_correct = j.settlement.is_correct if is_settled and j.settlement else None

        if has_bias:
            for flag in flags:
                bt = flag.get("type", "unknown")
                bias_counts[bt] = bias_counts.get(bt, 0) + 1
                bias_labels[bt] = flag.get("label", bt)
                if is_settled and is_correct is not None:
                    biased_settled[bt] = biased_settled.get(bt, 0) + 1
                    if is_correct:
                        biased_correct[bt] = biased_correct.get(bt, 0) + 1
        else:
            if is_settled and is_correct is not None:
                unbiased_settled += 1
                if is_correct:
                    unbiased_correct += 1

    unbiased_accuracy = None
    if unbiased_settled > 0:
        unbiased_accuracy = round(unbiased_correct / unbiased_settled * 100, 1)

    bias_type_stats = []
    for bt, count in sorted(bias_counts.items(), key=lambda x: -x[1]):
        biased_acc = None
        if biased_settled.get(bt, 0) > 0:
            biased_acc = round(biased_correct.get(bt, 0) / biased_settled[bt] * 100, 1)
        bias_type_stats.append(BiasTypeStats(
            type=bt,
            label=bias_labels.get(bt, bt),
            count=count,
            pct_of_judgments=round(count / total * 100, 1),
            accuracy_when_biased=biased_acc,
            accuracy_when_unbiased=unbiased_accuracy,
        ))

    bias_rate = round(judgments_with_bias / total * 100, 1) if total > 0 else 0.0

    # Generate insight
    if not bias_type_stats:
        insight = "近期判断中未检测到明显的认知偏差。"
    else:
        most_common = bias_type_stats[0]
        insight = f"最常见的偏差是「{most_common.label}」，出现{most_common.count}次 ({most_common.pct_of_judgments}%)。"
        if most_common.accuracy_when_biased is not None and unbiased_accuracy is not None:
            diff = most_common.accuracy_when_biased - unbiased_accuracy
            if diff < -5:
                insight += f" 存在该偏差时准确率降低 {abs(diff):.1f}%，建议关注。"
            elif diff > 5:
                insight += f" 但该偏差标记时准确率反而提高 {diff:.1f}%。"

    return BiasReportResponse(
        total_judgments_with_bias=judgments_with_bias,
        total_judgments=total,
        bias_rate=bias_rate,
        bias_types=bias_type_stats,
        insight=insight,
    )


# ── Accuracy by Hour ──────────────────────────────────────────────


class AccuracyByHourItem(BaseModel):
    hour: int
    total: int
    correct: int
    accuracy_pct: float


class AccuracyByHourResponse(BaseModel):
    items: list[AccuracyByHourItem]
    insight: str


@router.get("/accuracy-by-hour", response_model=AccuracyByHourResponse)
async def get_accuracy_by_hour(
    session: AsyncSession = Depends(get_session),
) -> AccuracyByHourResponse:
    """Return accuracy broken down by hour of day (0-23 UTC).

    Reveals time-of-day patterns: e.g. AI predicts better during Asian trading hours.
    """
    # Get all settled judgments with their creation hour
    stmt = (
        select(Judgment, Settlement)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .where(Settlement.is_correct.isnot(None))
    )
    result = await session.execute(stmt)
    rows = result.all()

    # Aggregate by hour
    hour_stats: dict[int, dict] = {h: {"total": 0, "correct": 0} for h in range(24)}
    for j, s in rows:
        hour = j.created_at.hour
        hour_stats[hour]["total"] += 1
        if s.is_correct:
            hour_stats[hour]["correct"] += 1

    items = []
    for h in range(24):
        total = hour_stats[h]["total"]
        correct = hour_stats[h]["correct"]
        pct = round((correct / total * 100), 1) if total > 0 else 0.0
        items.append(AccuracyByHourItem(
            hour=h, total=total, correct=correct, accuracy_pct=pct,
        ))

    # Generate insight
    active_hours = [i for i in items if i.total >= 3]
    if not active_hours:
        insight = "数据不足，暂无时段分析。需要更多已结算的判断才能发现时间规律。"
    else:
        best = max(active_hours, key=lambda x: x.accuracy_pct)
        worst = min(active_hours, key=lambda x: x.accuracy_pct)
        # Map hour to trading session
        def _session_label(h: int) -> str:
            if 0 <= h < 7:
                return "亚洲盘前"
            elif 7 <= h < 10:
                return "亚洲盘"
            elif 10 <= h < 14:
                return "欧洲盘"
            elif 14 <= h < 21:
                return "美洲盘"
            else:
                return "亚洲盘前"

        insight = (
            f"最佳预测时段: {best.hour}:00 UTC ({_session_label(best.hour)}) "
            f"准确率 {best.accuracy_pct:.1f}% ({best.correct}/{best.total})。"
            f"最差时段: {worst.hour}:00 UTC ({_session_label(worst.hour)}) "
            f"准确率 {worst.accuracy_pct:.1f}%。"
        )

    return AccuracyByHourResponse(items=items, insight=insight)


# ── Strategy Genome Status ─────────────────────────────────────────


class GenomeStatusItem(BaseModel):
    id: str
    name: str
    generation: int
    fitness: float
    total_judgments: int
    weights: dict


class GenomeStatusResponse(BaseModel):
    genomes: list[GenomeStatusItem]
    active_genome: Optional[str] = None


@router.get("/genome-status", response_model=GenomeStatusResponse)
async def get_genome_status(
    session: AsyncSession = Depends(get_session),
) -> GenomeStatusResponse:
    """Return the current status of all strategy genomes (L4 Self-Evolution)."""
    from backend.core.strategy_genome import load_genomes, get_best_genome

    genomes = await load_genomes(session)
    best_config = await get_best_genome(session)

    items = []
    active_name = None
    for g in genomes:
        items.append(GenomeStatusItem(
            id=g.id,
            name=g.name,
            generation=g.generation,
            fitness=round(g.fitness, 4),
            total_judgments=g.total_judgments,
            weights=g.config.to_dict(),
        ))
        # Determine which is the active genome
        if best_config and g.config.to_dict() == best_config.to_dict():
            active_name = g.name

    return GenomeStatusResponse(genomes=items, active_genome=active_name)


# ── AI Discoveries (Smart Market Scanner) ────────────────────────


class DiscoveryItem(BaseModel):
    type: str  # "divergence" | "volume_spike" | "direction_change"
    description: str
    severity: str  # "high" | "medium" | "low"


@router.get("/discoveries", response_model=list[DiscoveryItem])
async def get_discoveries(
    session: AsyncSession = Depends(get_session),
) -> list[DiscoveryItem]:
    """AI发现 — surface interesting cross-market patterns.

    1. Divergence detection: correlated pairs moving in opposite directions
    2. Unusual volume: volume > 2x average
    3. Consensus shift: AI changed direction from previous judgment
    """
    from backend.core.correlations import CORRELATIONS

    discoveries: list[DiscoveryItem] = []

    # ── Fetch latest snapshot per market with change_pct, volume ──
    latest_snap_sub = (
        select(
            MarketSnapshot.market_id,
            func.max(MarketSnapshot.captured_at).label("max_at"),
        )
        .group_by(MarketSnapshot.market_id)
        .subquery()
    )
    snap_stmt = (
        select(MarketSnapshot, Market.symbol)
        .join(
            latest_snap_sub,
            and_(
                MarketSnapshot.market_id == latest_snap_sub.c.market_id,
                MarketSnapshot.captured_at == latest_snap_sub.c.max_at,
            ),
        )
        .join(Market, Market.id == MarketSnapshot.market_id)
        .where(Market.is_active == True)
    )
    snap_result = await session.execute(snap_stmt)
    snap_rows = snap_result.all()

    # Build lookup maps
    symbol_change: dict[str, float] = {}
    symbol_volume: dict[str, float] = {}
    for snap, sym in snap_rows:
        if snap.change_pct is not None:
            symbol_change[sym] = snap.change_pct
        if snap.volume is not None:
            symbol_volume[sym] = snap.volume

    # ── 1. Divergence detection ──
    checked_pairs: set[tuple[str, str]] = set()
    for sym_a, related_list in CORRELATIONS.items():
        change_a = symbol_change.get(sym_a)
        if change_a is None:
            continue
        for sym_b in related_list:
            pair = tuple(sorted([sym_a, sym_b]))
            if pair in checked_pairs:
                continue
            checked_pairs.add(pair)

            change_b = symbol_change.get(sym_b)
            if change_b is None:
                continue

            # Divergence: one up significantly, one down significantly
            if (change_a > 1.0 and change_b < -1.0) or (change_a < -1.0 and change_b > 1.0):
                up_sym = sym_a if change_a > change_b else sym_b
                down_sym = sym_b if change_a > change_b else sym_a
                up_change = max(change_a, change_b)
                down_change = min(change_a, change_b)
                severity = "high" if abs(up_change - down_change) > 4.0 else "medium"
                discoveries.append(DiscoveryItem(
                    type="divergence",
                    description=(
                        f"{up_sym}和{down_sym}出现罕见分歧："
                        f"{up_sym}上涨{up_change:+.1f}%但{down_sym}下跌{down_change:.1f}%"
                    ),
                    severity=severity,
                ))

    # ── 2. Unusual volume ──
    # Compare current volume to average volume (batch approach)
    # Get markets with volume data
    vol_markets_stmt = (
        select(Market.id, Market.symbol)
        .where(Market.is_active == True, Market.symbol.in_(list(symbol_volume.keys())))
    )
    vol_markets_result = await session.execute(vol_markets_stmt)
    vol_markets = vol_markets_result.all()

    for market_id, sym in vol_markets:
        current_vol = symbol_volume.get(sym, 0)
        if current_vol <= 0:
            continue

        # Average volume from last 10 snapshots (subquery for LIMIT)
        recent_vols_sub = (
            select(MarketSnapshot.volume)
            .where(
                MarketSnapshot.market_id == market_id,
                MarketSnapshot.volume.isnot(None),
                MarketSnapshot.volume > 0,
            )
            .order_by(desc(MarketSnapshot.captured_at))
            .limit(10)
            .subquery()
        )
        avg_vol_stmt = select(func.avg(recent_vols_sub.c.volume))
        avg_result = await session.execute(avg_vol_stmt)
        avg_vol = avg_result.scalar()

        if avg_vol and avg_vol > 0 and current_vol > avg_vol * 2.0:
            ratio = current_vol / avg_vol
            severity = "high" if ratio > 3.0 else "medium"
            discoveries.append(DiscoveryItem(
                type="volume_spike",
                description=f"{sym}成交量异常放大，超过平均{ratio:.1f}倍",
                severity=severity,
            ))

    # ── 3. Consensus shift — direction changed from previous judgment ──
    # Get latest 2 judgments per market to detect direction change
    shift_stmt = (
        select(Judgment, Market.symbol)
        .join(Market, Market.id == Judgment.market_id)
        .where(Market.is_active == True)
        .order_by(Market.symbol, desc(Judgment.created_at))
    )
    shift_result = await session.execute(shift_stmt)
    shift_rows = shift_result.all()

    # Group by symbol, take first 2
    symbol_judgments: dict[str, list] = {}
    for j, sym in shift_rows:
        symbol_judgments.setdefault(sym, [])
        if len(symbol_judgments[sym]) < 2:
            symbol_judgments[sym].append(j)

    direction_cn = {"up": "看涨", "down": "看跌", "flat": "观望"}
    for sym, jlist in symbol_judgments.items():
        if len(jlist) < 2:
            continue
        curr_dir = jlist[0].direction.lower()
        prev_dir = jlist[1].direction.lower()
        # Only flag meaningful shifts (not flat->flat)
        if curr_dir != prev_dir and not (curr_dir == "flat" and prev_dir == "flat"):
            # Skip flat transitions (less interesting)
            if curr_dir == "flat" or prev_dir == "flat":
                severity = "low"
            else:
                severity = "high"  # e.g., up->down or down->up
            discoveries.append(DiscoveryItem(
                type="direction_change",
                description=(
                    f"{sym}从{direction_cn.get(prev_dir, prev_dir)}"
                    f"转为{direction_cn.get(curr_dir, curr_dir)}，可能趋势反转"
                ),
                severity=severity,
            ))

    # Sort: high > medium > low, then by type priority
    severity_order = {"high": 0, "medium": 1, "low": 2}
    type_order = {"divergence": 0, "direction_change": 1, "volume_spike": 2}
    discoveries.sort(key=lambda d: (severity_order.get(d.severity, 9), type_order.get(d.type, 9)))

    return discoveries[:5]


# ── Meta-Learning Insights (L4) ─────────────────────────────────────


class MetaInsightsResponse(BaseModel):
    by_regime: dict = {}
    by_confidence_bucket: dict = {}
    by_volatility: dict = {}
    by_time_gap: dict = {}
    by_horizon: dict = {}
    meta_insight_text: str = ""
    recommendations: list[str] = []
    total_analyzed: int = 0


@router.get("/meta-insights", response_model=MetaInsightsResponse)
async def get_meta_insights(
    session: AsyncSession = Depends(get_session),
) -> MetaInsightsResponse:
    """Return meta-learning insights — patterns in what makes predictions correct vs wrong."""
    from backend.core.meta_learner import analyze_success_patterns

    result = await analyze_success_patterns(session)
    return MetaInsightsResponse(**result)
