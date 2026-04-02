"""Meta-Learner (L4) — analyze ALL settled judgments to find patterns in prediction accuracy.

Generates meta-insights that feed back into the AI prompt for self-improvement.
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select, desc, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from backend.models import Judgment, Settlement, Market

logger = logging.getLogger(__name__)


async def analyze_success_patterns(session: AsyncSession) -> dict:
    """Analyze all settled judgments and compute accuracy across multiple dimensions.

    Returns a dict with:
      - by_regime: accuracy per market regime
      - by_confidence_bucket: accuracy per confidence level bucket
      - by_volatility: accuracy for high/low volatility
      - by_time_gap: accuracy by time since last judgment
      - by_horizon: accuracy by horizon_hours per market_type
      - meta_insight_text: Chinese summary of key patterns
      - recommendations: list of actionable suggestions
    """
    # Fetch all settled judgments with market info
    stmt = (
        select(Judgment, Settlement, Market)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .join(Market, Market.id == Judgment.market_id)
        .where(Settlement.is_correct.isnot(None))
        .order_by(Judgment.created_at)
    )
    result = await session.execute(stmt)
    rows = result.all()

    if not rows:
        return {
            "by_regime": {},
            "by_confidence_bucket": {},
            "by_volatility": {},
            "by_time_gap": {},
            "by_horizon": {},
            "meta_insight_text": "暂无已结算判断，无法生成元学习洞察。",
            "recommendations": [],
            "total_analyzed": 0,
        }

    # ── 1. Accuracy by market regime ──
    regime_stats: dict[str, dict] = defaultdict(lambda: {"total": 0, "correct": 0})
    for j, s, m in rows:
        regime_info = j.regime or {}
        regime_name = regime_info.get("regime", "未知")
        regime_stats[regime_name]["total"] += 1
        if s.is_correct:
            regime_stats[regime_name]["correct"] += 1

    by_regime = {}
    for regime, stats in regime_stats.items():
        acc = round(stats["correct"] / stats["total"] * 100, 1) if stats["total"] > 0 else 0
        by_regime[regime] = {
            "total": stats["total"],
            "correct": stats["correct"],
            "accuracy_pct": acc,
        }

    # ── 2. Accuracy by confidence bucket ──
    conf_buckets = {
        "低 (0-30%)": (0.0, 0.3),
        "中 (30-60%)": (0.3, 0.6),
        "高 (60-100%)": (0.6, 1.01),
    }
    bucket_stats: dict[str, dict] = {k: {"total": 0, "correct": 0} for k in conf_buckets}
    for j, s, m in rows:
        for label, (lo, hi) in conf_buckets.items():
            if lo <= j.confidence_score < hi:
                bucket_stats[label]["total"] += 1
                if s.is_correct:
                    bucket_stats[label]["correct"] += 1
                break

    by_confidence_bucket = {}
    for label, stats in bucket_stats.items():
        acc = round(stats["correct"] / stats["total"] * 100, 1) if stats["total"] > 0 else 0
        by_confidence_bucket[label] = {
            "total": stats["total"],
            "correct": stats["correct"],
            "accuracy_pct": acc,
        }

    # ── 3. Accuracy by volatility (from regime / raw_data) ──
    vol_stats: dict[str, dict] = defaultdict(lambda: {"total": 0, "correct": 0})
    for j, s, m in rows:
        # Use regime as proxy: overbought/oversold = high vol market condition
        regime_name = (j.regime or {}).get("regime", "")
        if regime_name in ("超买", "超卖", "趋势上行", "趋势下行"):
            vol_label = "高波动"
        else:
            vol_label = "低波动"
        vol_stats[vol_label]["total"] += 1
        if s.is_correct:
            vol_stats[vol_label]["correct"] += 1

    by_volatility = {}
    for label, stats in vol_stats.items():
        acc = round(stats["correct"] / stats["total"] * 100, 1) if stats["total"] > 0 else 0
        by_volatility[label] = {
            "total": stats["total"],
            "correct": stats["correct"],
            "accuracy_pct": acc,
        }

    # ── 4. Accuracy by time since last judgment (gap analysis) ──
    # Group judgments by market, sort by time, compute gaps
    market_judgments: dict[str, list] = defaultdict(list)
    for j, s, m in rows:
        market_judgments[str(j.market_id)].append((j, s))

    gap_stats: dict[str, dict] = defaultdict(lambda: {"total": 0, "correct": 0})
    for mid, jlist in market_judgments.items():
        jlist.sort(key=lambda x: x[0].created_at)
        for i, (j, s) in enumerate(jlist):
            if i == 0:
                gap_label = "首次判断"
            else:
                prev_time = jlist[i - 1][0].created_at
                gap_hours = (j.created_at - prev_time).total_seconds() / 3600
                if gap_hours < 6:
                    gap_label = "< 6小时"
                elif gap_hours < 24:
                    gap_label = "6-24小时"
                else:
                    gap_label = "> 24小时"
            gap_stats[gap_label]["total"] += 1
            if s.is_correct:
                gap_stats[gap_label]["correct"] += 1

    by_time_gap = {}
    for label, stats in gap_stats.items():
        acc = round(stats["correct"] / stats["total"] * 100, 1) if stats["total"] > 0 else 0
        by_time_gap[label] = {
            "total": stats["total"],
            "correct": stats["correct"],
            "accuracy_pct": acc,
        }

    # ── 5. Accuracy by horizon_hours per market_type ──
    horizon_stats: dict[str, dict] = defaultdict(lambda: defaultdict(lambda: {"total": 0, "correct": 0}))
    for j, s, m in rows:
        h = j.horizon_hours or 4
        horizon_stats[m.market_type][h]["total"] += 1
        if s.is_correct:
            horizon_stats[m.market_type][h]["correct"] += 1

    by_horizon = {}
    for mt, horizons in horizon_stats.items():
        by_horizon[mt] = {}
        for h, stats in horizons.items():
            acc = round(stats["correct"] / stats["total"] * 100, 1) if stats["total"] > 0 else 0
            by_horizon[mt][str(h)] = {
                "total": stats["total"],
                "correct": stats["correct"],
                "accuracy_pct": acc,
            }

    # ── Generate meta-insight text ──
    insights_parts = []
    recommendations = []

    # Find best and worst regime
    if by_regime:
        sorted_regimes = sorted(
            [(k, v) for k, v in by_regime.items() if v["total"] >= 3],
            key=lambda x: x[1]["accuracy_pct"],
            reverse=True,
        )
        if sorted_regimes:
            best_regime = sorted_regimes[0]
            worst_regime = sorted_regimes[-1]
            insights_parts.append(
                f"AI在{best_regime[0]}市场预测最准({best_regime[1]['accuracy_pct']}%)，"
                f"在{worst_regime[0]}市场最差({worst_regime[1]['accuracy_pct']}%)"
            )
            if worst_regime[1]["accuracy_pct"] < 40:
                recommendations.append(
                    f"建议: 在{worst_regime[0]}市场降低置信度，考虑反向信号"
                )
            if best_regime[1]["accuracy_pct"] > 60:
                recommendations.append(
                    f"建议: 提高{best_regime[0]}市场的置信度"
                )

    # Volatility insight
    if by_volatility:
        high_vol = by_volatility.get("高波动", {})
        low_vol = by_volatility.get("低波动", {})
        if high_vol.get("total", 0) >= 3 and low_vol.get("total", 0) >= 3:
            diff = high_vol.get("accuracy_pct", 0) - low_vol.get("accuracy_pct", 0)
            if abs(diff) > 5:
                better = "高波动" if diff > 0 else "低波动"
                worse = "低波动" if diff > 0 else "高波动"
                insights_parts.append(
                    f"{better}资产的判断比{worse}好{abs(diff):.1f}个百分点"
                )

    # Confidence bucket insight
    if by_confidence_bucket:
        high_conf = by_confidence_bucket.get("高 (60-100%)", {})
        low_conf = by_confidence_bucket.get("低 (0-30%)", {})
        if high_conf.get("total", 0) >= 3:
            insights_parts.append(
                f"高置信判断准确率{high_conf.get('accuracy_pct', 0)}%"
            )
            if high_conf.get("accuracy_pct", 0) < 50:
                recommendations.append("建议: 高置信判断表现不佳，需要更严格的信号确认")

    # Horizon insight
    for mt, horizons in by_horizon.items():
        if len(horizons) >= 2:
            sorted_h = sorted(
                [(h, v) for h, v in horizons.items() if v["total"] >= 3],
                key=lambda x: x[1]["accuracy_pct"],
                reverse=True,
            )
            if sorted_h and len(sorted_h) >= 2:
                best_h = sorted_h[0]
                recommendations.append(
                    f"建议: {mt}市场使用{best_h[0]}小时预测周期效果更好"
                    f"({best_h[1]['accuracy_pct']}%准确率)"
                )

    meta_insight_text = "。".join(insights_parts) + "。" if insights_parts else "数据积累中，暂无显著规律。"

    return {
        "by_regime": by_regime,
        "by_confidence_bucket": by_confidence_bucket,
        "by_volatility": by_volatility,
        "by_time_gap": by_time_gap,
        "by_horizon": by_horizon,
        "meta_insight_text": meta_insight_text,
        "recommendations": recommendations,
        "total_analyzed": len(rows),
    }


def build_meta_insight_prompt(meta_insights: dict) -> str:
    """Build a prompt hint from meta-learning insights for the AI.

    This makes the AI self-aware of its strengths and weaknesses.
    """
    text = meta_insights.get("meta_insight_text", "")
    recommendations = meta_insights.get("recommendations", [])

    if not text or text == "暂无已结算判断，无法生成元学习洞察。":
        return ""

    parts = [f"【系统自我认知 — 元学习】{text}"]

    # Add regime accuracy table
    by_regime = meta_insights.get("by_regime", {})
    if by_regime:
        regime_lines = []
        for regime, data in sorted(by_regime.items(), key=lambda x: -x[1]["accuracy_pct"]):
            if data["total"] >= 2:
                regime_lines.append(
                    f"  {regime}: {data['accuracy_pct']}% ({data['correct']}/{data['total']})"
                )
        if regime_lines:
            parts.append("各市场状态准确率:\n" + "\n".join(regime_lines))

    # Add recommendations
    if recommendations:
        parts.append("\n".join(recommendations))

    return "\n".join(parts)


async def get_optimal_horizon(session: AsyncSession, market_type: str) -> Optional[int]:
    """Check if a different horizon performs better for this market type.

    Returns the optimal horizon_hours if significantly better, else None.
    """
    meta = await analyze_success_patterns(session)
    by_horizon = meta.get("by_horizon", {})

    horizons = by_horizon.get(market_type, {})
    if len(horizons) < 2:
        return None

    qualified = [(int(h), v) for h, v in horizons.items() if v["total"] >= 5]
    if len(qualified) < 2:
        return None

    # Find the horizon with highest accuracy
    best = max(qualified, key=lambda x: x[1]["accuracy_pct"])
    # Only switch if the best is significantly better (>10% gap)
    current_accs = [v["accuracy_pct"] for _, v in qualified]
    avg_acc = sum(current_accs) / len(current_accs)

    if best[1]["accuracy_pct"] > avg_acc + 10:
        logger.info(
            "元学习建议 %s 使用 %d小时 预测周期 (准确率 %.1f%% vs 平均 %.1f%%)",
            market_type, best[0], best[1]["accuracy_pct"], avg_acc,
        )
        return best[0]

    return None
