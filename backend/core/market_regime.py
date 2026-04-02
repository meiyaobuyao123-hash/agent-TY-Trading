"""Market regime detection (L2 intelligence layer).

Classifies each market into a regime based on recent behavior:
- 趋势上行: 7-day change > 3% AND RSI < 70
- 趋势下行: 7-day change < -3% AND RSI > 30
- 超买: RSI > 70
- 超卖: RSI < 30
- 震荡: 7-day change within +/-3%
"""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# Regime definitions
REGIME_TREND_UP = "趋势上行"
REGIME_TREND_DOWN = "趋势下行"
REGIME_OVERBOUGHT = "超买"
REGIME_OVERSOLD = "超卖"
REGIME_RANGING = "震荡"

# Regime descriptions for AI prompt
REGIME_DESCRIPTIONS = {
    REGIME_TREND_UP: "价格处于健康上升趋势，RSI未进入超买区间，趋势可能延续",
    REGIME_TREND_DOWN: "价格处于下降趋势，RSI未进入超卖区间，下跌可能延续",
    REGIME_OVERBOUGHT: "RSI进入超买区间(>70)，存在回调风险，需警惕获利了结",
    REGIME_OVERSOLD: "RSI进入超卖区间(<30)，可能出现技术性反弹，关注抄底信号",
    REGIME_RANGING: "价格在区间内震荡，缺乏明确方向，建议观望或区间操作",
}

# Regime colors for frontend display
REGIME_COLORS = {
    REGIME_TREND_UP: "#22c55e",     # green
    REGIME_TREND_DOWN: "#ef4444",   # red
    REGIME_OVERBOUGHT: "#f97316",   # orange
    REGIME_OVERSOLD: "#3b82f6",     # blue
    REGIME_RANGING: "#6b7280",      # gray
}


def detect_regime(
    change_7d_pct: Optional[float],
    rsi_7: Optional[float],
) -> str:
    """Detect the current market regime based on 7-day change and RSI.

    Returns one of the REGIME_* constants.
    """
    if change_7d_pct is None and rsi_7 is None:
        return REGIME_RANGING  # default when no data

    # Priority: RSI extremes first (overbought/oversold are stronger signals)
    if rsi_7 is not None:
        if rsi_7 > 70:
            return REGIME_OVERBOUGHT
        if rsi_7 < 30:
            return REGIME_OVERSOLD

    # Then check trend based on 7-day change
    if change_7d_pct is not None:
        if change_7d_pct > 3.0:
            return REGIME_TREND_UP
        if change_7d_pct < -3.0:
            return REGIME_TREND_DOWN

    return REGIME_RANGING


def format_regime_for_prompt(regime: str) -> str:
    """Format regime information as text for the AI prompt."""
    desc = REGIME_DESCRIPTIONS.get(regime, "")
    return f"市场状态: {regime} — {desc}"


def regime_to_dict(regime: str) -> dict:
    """Return regime info as a dict for API responses."""
    return {
        "regime": regime,
        "description": REGIME_DESCRIPTIONS.get(regime, ""),
        "color": REGIME_COLORS.get(regime, "#6b7280"),
    }
