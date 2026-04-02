"""Cross-asset signal propagation system (L2 causal reasoning).

When a "source" asset has significant movement, propagate signals
to all correlated assets in the same market segment.
"""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ── Signal propagation chains ──────────────────────────────────
# source_symbol -> (threshold_pct, target_market_types, description_template)
PROPAGATION_CHAINS: list[dict] = [
    {
        "source": "BTC-USD",
        "threshold_pct": 3.0,
        "target_market_type": "crypto",
        "label": "BTC",
        "history_follow_rate": 85,
        "description_up": "BTC今日上涨{change:.1f}%，加密市场整体偏多，历史上{rate}%的altcoin会跟随上涨",
        "description_down": "BTC今日下跌{change:.1f}%，加密市场整体承压，历史上{rate}%的altcoin会跟随下跌",
    },
    {
        "source": "SPX",
        "threshold_pct": 1.0,
        "target_market_type": "us-equities",
        "label": "标普500",
        "history_follow_rate": 78,
        "description_up": "标普500今日上涨{change:.1f}%，美股整体走强，{rate}%的美股会跟随指数方向",
        "description_down": "标普500今日下跌{change:.1f}%，美股整体承压，{rate}%的美股会跟随指数方向",
    },
    {
        "source": "SPX",
        "threshold_pct": 1.5,
        "target_market_type": "etf",
        "label": "标普500",
        "history_follow_rate": 82,
        "description_up": "标普500今日上涨{change:.1f}%，多数ETF跟随走强",
        "description_down": "标普500今日下跌{change:.1f}%，多数ETF承压",
    },
    {
        "source": "EUR/USD",
        "threshold_pct": 0.5,
        "target_market_type": "forex",
        "label": "美元",
        "history_follow_rate": 72,
        "description_up": "欧元/美元上涨{change:.1f}%(美元走弱)，其他非美货币可能跟随走强",
        "description_down": "欧元/美元下跌{change:.1f}%(美元走强)，其他非美货币可能承压",
    },
    {
        "source": "GOLD",
        "threshold_pct": 1.5,
        "target_market_type": "commodities",
        "label": "黄金",
        "history_follow_rate": 65,
        "description_up": "黄金今日上涨{change:.1f}%，避险需求升温，贵金属板块可能联动走强",
        "description_down": "黄金今日下跌{change:.1f}%，风险偏好回升，贵金属可能承压",
    },
    {
        "source": "000001.SS",
        "threshold_pct": 1.5,
        "target_market_type": "cn-equities",
        "label": "上证指数",
        "history_follow_rate": 80,
        "description_up": "上证指数今日上涨{change:.1f}%，A股整体走强，{rate}%的A股会跟随指数",
        "description_down": "上证指数今日下跌{change:.1f}%，A股整体承压，{rate}%的A股会跟随指数",
    },
    {
        "source": "HSI",
        "threshold_pct": 1.5,
        "target_market_type": "hk-equities",
        "label": "恒生指数",
        "history_follow_rate": 76,
        "description_up": "恒生指数今日上涨{change:.1f}%，港股整体走强",
        "description_down": "恒生指数今日下跌{change:.1f}%，港股整体承压",
    },
    {
        "source": "005930.KR",
        "threshold_pct": 2.0,
        "target_market_type": "kr-equities",
        "label": "三星电子",
        "history_follow_rate": 70,
        "description_up": "三星电子今日上涨{change:.1f}%，韩国市场偏多",
        "description_down": "三星电子今日下跌{change:.1f}%，韩国市场承压",
    },
    {
        "source": "RELIANCE.IN",
        "threshold_pct": 2.0,
        "target_market_type": "in-equities",
        "label": "信实工业",
        "history_follow_rate": 68,
        "description_up": "信实工业今日上涨{change:.1f}%，印度市场偏多",
        "description_down": "信实工业今日下跌{change:.1f}%，印度市场承压",
    },
]


def detect_propagation_signals(
    current_symbol: str,
    current_market_type: str,
    tick_cache: dict[str, dict],
) -> Optional[str]:
    """Check if any source asset has triggered a propagation signal
    that affects the current market.

    Returns a Chinese-language signal text for inclusion in the AI prompt,
    or None if no propagation signal applies.
    """
    signals: list[str] = []

    for chain in PROPAGATION_CHAINS:
        source = chain["source"]
        # Don't propagate to the source itself
        if current_symbol == source:
            continue
        # Only propagate to matching market types
        if current_market_type != chain["target_market_type"]:
            continue

        source_tick = tick_cache.get(source)
        if not source_tick:
            continue

        change_pct = source_tick.get("change_pct")
        if change_pct is None:
            continue

        threshold = chain["threshold_pct"]
        if abs(change_pct) < threshold:
            continue

        # Signal triggered
        rate = chain["history_follow_rate"]
        if change_pct > 0:
            desc = chain["description_up"].format(change=abs(change_pct), rate=rate)
        else:
            desc = chain["description_down"].format(change=abs(change_pct), rate=rate)

        signals.append(desc)

    if not signals:
        return None

    return "信号传导: " + "; ".join(signals)
