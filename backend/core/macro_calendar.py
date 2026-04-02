"""Macro event calendar awareness (L2 intelligence layer).

Static calendar of regular macro events. No external API needed.
Checks if today matches any event and returns relevant alerts for the AI prompt.
"""

from __future__ import annotations

import logging
from datetime import datetime, date
from typing import Optional

logger = logging.getLogger(__name__)

# ── Regular macro events ───────────────────────────────────────
# day_of_week: 0=Monday ... 6=Sunday
# day_of_month: list of days
# week_of_month + day_of_week: e.g., first Friday = week 1, day 4
REGULAR_EVENTS: list[dict] = [
    # Weekly events
    {
        "day_of_week": 3,  # Thursday
        "name": "美国初请失业金人数",
        "affects": ["us-equities", "forex", "etf", "global-indices"],
        "impact": "中等",
        "detail": "每周四公布，反映就业市场健康程度，影响美联储加息预期",
    },
    # Monthly events — fixed dates
    {
        "day_of_month": [1],
        "name": "中国官方制造业PMI",
        "affects": ["cn-equities", "hk-equities", "commodities"],
        "impact": "高",
        "detail": "月初公布上月PMI，50以上为扩张，50以下为收缩",
    },
    {
        "day_of_month": [15],
        "name": "中国经济数据集中公布日(工业增加值/零售/固投)",
        "affects": ["cn-equities", "hk-equities"],
        "impact": "高",
        "detail": "通常在每月15日左右公布上月主要经济数据",
    },
    # CPI — typically around 10th-13th
    {
        "day_of_month": [10, 11, 12, 13],
        "name": "美国CPI数据公布(可能)",
        "affects": ["us-equities", "forex", "commodities", "etf", "global-indices"],
        "impact": "高",
        "detail": "通常在每月10-13日公布，是美联储利率决策的关键参考",
    },
    # NFP — first Friday of month
    {
        "week_of_month": 1,
        "day_of_week": 4,  # Friday
        "name": "美国非农就业数据(NFP)",
        "affects": ["us-equities", "forex", "commodities", "etf", "global-indices"],
        "impact": "极高",
        "detail": "每月第一个周五公布，是最重要的就业数据，直接影响美联储政策",
    },
    # Fed meetings — roughly every 6 weeks (8 times/year)
    # FOMC months: Jan, Mar, May, Jun, Jul, Sep, Nov, Dec
    {
        "month_days": {
            1: [28, 29],   # Jan FOMC
            3: [18, 19],   # Mar FOMC
            5: [6, 7],     # May FOMC
            6: [17, 18],   # Jun FOMC
            7: [29, 30],   # Jul FOMC
            9: [16, 17],   # Sep FOMC
            11: [4, 5],    # Nov FOMC
            12: [16, 17],  # Dec FOMC
        },
        "name": "美联储FOMC议息会议",
        "affects": ["us-equities", "forex", "commodities", "crypto", "etf", "global-indices"],
        "impact": "极高",
        "detail": "利率决议和鲍威尔讲话，影响全球资产定价",
    },
    # ECB meetings
    {
        "month_days": {
            1: [25],
            3: [6],
            4: [17],
            6: [5],
            7: [24],
            9: [11],
            10: [30],
            12: [18],
        },
        "name": "欧央行利率决议",
        "affects": ["eu-equities", "forex"],
        "impact": "高",
        "detail": "欧洲央行利率决策，影响欧元和欧洲市场",
    },
    # BOJ meetings
    {
        "month_days": {
            1: [23, 24],
            3: [13, 14],
            4: [30],
            5: [1],
            6: [12, 13],
            7: [30, 31],
            9: [18, 19],
            10: [30, 31],
            12: [18, 19],
        },
        "name": "日本央行利率决议",
        "affects": ["jp-equities", "forex"],
        "impact": "高",
        "detail": "日银利率决策，影响日元汇率和日本股市",
    },
    # Options expiration — 3rd Friday
    {
        "week_of_month": 3,
        "day_of_week": 4,  # Friday
        "name": "美股期权到期日(三巫日)",
        "affects": ["us-equities", "etf", "global-indices"],
        "impact": "中等",
        "detail": "每月第三个周五期权到期，可能增加波动性，季度到期尤其显著",
    },
    # China LPR — 20th of month
    {
        "day_of_month": [20],
        "name": "中国LPR报价",
        "affects": ["cn-equities", "hk-equities", "forex"],
        "impact": "中等",
        "detail": "贷款市场报价利率，反映中国货币政策方向",
    },
    # US retail sales — around 15th
    {
        "day_of_month": [14, 15, 16],
        "name": "美国零售销售数据(可能)",
        "affects": ["us-equities", "forex"],
        "impact": "中等",
        "detail": "反映消费者支出趋势，是GDP的重要先行指标",
    },
]


def _get_week_of_month(d: date) -> int:
    """Return 1-based week of month (1st Friday = week 1, etc.)."""
    first_day = d.replace(day=1)
    # Find first occurrence of the same weekday
    first_same_weekday = first_day
    while first_same_weekday.weekday() != d.weekday():
        first_same_weekday = first_same_weekday.replace(day=first_same_weekday.day + 1)
    # Calculate which week
    return (d.day - first_same_weekday.day) // 7 + 1


def get_todays_events(
    market_type: str,
    today: Optional[date] = None,
) -> list[str]:
    """Check if today matches any macro events affecting the given market type.

    Returns a list of event description strings.
    """
    if today is None:
        today = datetime.utcnow().date()

    dow = today.weekday()  # 0=Mon
    dom = today.day
    month = today.month
    wom = _get_week_of_month(today)

    events: list[str] = []

    for event in REGULAR_EVENTS:
        # Check if this event affects the market type
        if market_type not in event.get("affects", []):
            continue

        matched = False

        # Check day_of_week
        if "day_of_week" in event and "week_of_month" not in event:
            if dow == event["day_of_week"]:
                matched = True

        # Check day_of_month
        if "day_of_month" in event:
            if dom in event["day_of_month"]:
                matched = True

        # Check week_of_month + day_of_week (e.g., first Friday)
        if "week_of_month" in event and "day_of_week" in event:
            if wom == event["week_of_month"] and dow == event["day_of_week"]:
                matched = True

        # Check month_days (specific days in specific months)
        if "month_days" in event:
            month_days = event["month_days"]
            if month in month_days and dom in month_days[month]:
                matched = True

        if matched:
            impact = event.get("impact", "中等")
            detail = event.get("detail", "")
            events.append(
                f"{event['name']} [影响: {impact}] — {detail}"
            )

    return events


def format_macro_events_for_prompt(
    market_type: str,
    today: Optional[date] = None,
) -> Optional[str]:
    """Format today's macro events as a prompt section.

    Returns None if no events match.
    """
    events = get_todays_events(market_type, today)
    if not events:
        return None

    lines = ["今日宏观事件:"]
    for ev in events:
        lines.append(f"  - {ev}")
    lines.append("请在分析中考虑以上事件对市场的可能影响。")

    return "\n".join(lines)
