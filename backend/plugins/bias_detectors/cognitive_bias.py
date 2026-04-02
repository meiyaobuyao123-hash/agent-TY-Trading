"""Cognitive Bias Hunter — detect momentum, consensus, and anchoring biases in AI judgments.

This is the L3 advanced bias detection system for Project TY.
"""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)


def detect_momentum_bias(
    direction: str,
    confidence_score: float,
    change_pct: Optional[float],
    market_type: str,
) -> Optional[dict]:
    """Detect momentum bias: AI predicts continuation of strong recent trend with high confidence.

    When the 24h trend is strong and AI confidently predicts it will continue,
    this may be momentum/recency bias — momentum traders often cause overshoot.
    """
    if change_pct is None or confidence_score < 0.5:
        return None

    # Thresholds per market type
    thresholds = {
        "crypto": 3.0,
        "us-equities": 1.5,
        "cn-equities": 1.5,
        "hk-equities": 1.5,
        "global-indices": 1.0,
        "forex": 0.5,
        "commodities": 1.5,
        "etf": 1.0,
    }
    threshold = thresholds.get(market_type, 2.0)

    # Check if AI direction matches the trend AND the trend is strong
    trend_is_up = change_pct > threshold
    trend_is_down = change_pct < -threshold
    ai_follows_trend = (
        (trend_is_up and direction == "up") or
        (trend_is_down and direction == "down")
    )

    if ai_follows_trend and confidence_score >= 0.5:
        trend_dir = "上涨" if trend_is_up else "下跌"
        return {
            "type": "momentum",
            "label": "动量偏差",
            "detail": f"AI可能过度追涨杀跌 — 24h已{trend_dir}{abs(change_pct):.1f}%，AI仍高置信预测继续{trend_dir}",
            "severity": "medium" if confidence_score < 0.7 else "high",
        }

    return None


def detect_consensus_bias(
    direction: str,
    recent_directions: list[str],
) -> Optional[dict]:
    """Detect consensus/herding bias: multiple consecutive judgments in the same direction.

    When all recent judgments agree, this may be herding behavior rather than independent analysis.
    """
    if len(recent_directions) < 3:
        return None

    # Check if last N judgments are all in the same direction
    same_count = 0
    for d in recent_directions:
        if d == direction:
            same_count += 1
        else:
            break

    if same_count >= 3:
        dir_cn = {"up": "看涨", "down": "看跌", "flat": "观望"}.get(direction, direction)
        return {
            "type": "consensus",
            "label": "共识偏差",
            "detail": f"连续{same_count}次同方向判断({dir_cn}) — 可能存在羊群效应，请独立思考",
            "severity": "medium" if same_count < 5 else "high",
        }

    return None


def detect_anchoring_bias(
    market_price: float,
    rational_price: Optional[float],
    market_type: str,
) -> Optional[dict]:
    """Detect anchoring bias: AI rational price is too close to current price.

    When the AI's "rational price" is within 1% of the current market price,
    the AI may be anchored to the current price rather than doing independent analysis.
    """
    if rational_price is None or market_price <= 0:
        return None

    deviation_pct = abs((rational_price - market_price) / market_price) * 100

    # Threshold depends on market type
    anchor_thresholds = {
        "crypto": 1.0,
        "us-equities": 0.5,
        "cn-equities": 0.5,
        "hk-equities": 0.5,
        "global-indices": 0.3,
        "forex": 0.15,
        "commodities": 0.5,
        "etf": 0.3,
    }
    threshold = anchor_thresholds.get(market_type, 0.5)

    if deviation_pct < threshold:
        return {
            "type": "anchoring",
            "label": "锚定偏差",
            "detail": f"AI合理价格({rational_price:.2f})过于接近当前价({market_price:.2f})，偏差仅{deviation_pct:.2f}% — 可能锚定于当前价格",
            "severity": "low",
        }

    return None


def detect_all_biases(
    direction: str,
    confidence_score: float,
    market_price: float,
    rational_price: Optional[float],
    change_pct: Optional[float],
    market_type: str,
    recent_directions: list[str],
) -> list[dict]:
    """Run all bias detectors and return a list of detected bias flags."""
    flags = []

    momentum = detect_momentum_bias(direction, confidence_score, change_pct, market_type)
    if momentum:
        flags.append(momentum)

    consensus = detect_consensus_bias(direction, recent_directions)
    if consensus:
        flags.append(consensus)

    anchoring = detect_anchoring_bias(market_price, rational_price, market_type)
    if anchoring:
        flags.append(anchoring)

    return flags
