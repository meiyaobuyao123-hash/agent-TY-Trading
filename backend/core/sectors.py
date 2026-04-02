"""Sector/industry classification for stocks — used for sector-level analysis in AI prompts."""

from __future__ import annotations

import logging
from typing import Optional

logger = logging.getLogger(__name__)

# ── Sector mapping: symbol -> sector name ──
SECTORS: dict[str, str] = {
    # 科技
    "AAPL": "科技", "MSFT": "科技", "GOOGL": "科技", "META": "科技",
    "AMZN": "科技", "CRM": "科技", "ORCL": "科技", "ADBE": "科技",
    "CSCO": "科技", "IBM": "科技", "INTC": "科技", "NFLX": "科技",
    "SHOP": "科技", "SNOW": "科技", "PLTR": "科技", "UBER": "科技",
    "ABNB": "科技", "SQ": "科技", "PYPL": "科技", "COIN": "科技",
    "NET": "科技", "DDOG": "科技", "ZS": "科技", "CRWD": "科技",
    # 半导体
    "NVDA": "半导体", "AMD": "半导体", "TSM": "半导体", "AVGO": "半导体",
    "QCOM": "半导体", "TXN": "半导体", "MU": "半导体", "MRVL": "半导体",
    "ASML": "半导体", "LRCX": "半导体", "AMAT": "半导体", "KLAC": "半导体",
    "ARM": "半导体", "ON": "半导体", "SMCI": "半导体",
    # 金融
    "JPM": "金融", "GS": "金融", "BAC": "金融", "MS": "金融",
    "WFC": "金融", "C": "金融", "BLK": "金融", "SCHW": "金融",
    "AXP": "金融", "V": "金融", "MA": "金融", "COF": "金融",
    "BRK-B": "金融",
    # 医疗
    "JNJ": "医疗", "PFE": "医疗", "LLY": "医疗", "UNH": "医疗",
    "ABBV": "医疗", "MRK": "医疗", "TMO": "医疗", "ABT": "医疗",
    "BMY": "医疗", "AMGN": "医疗", "GILD": "医疗", "ISRG": "医疗",
    "MRNA": "医疗", "REGN": "医疗", "VRTX": "医疗", "MDT": "医疗",
    # 能源
    "XOM": "能源", "CVX": "能源", "COP": "能源", "SLB": "能源",
    "EOG": "能源", "MPC": "能源", "PSX": "能源", "VLO": "能源",
    "OXY": "能源", "HAL": "能源",
    # 消费
    "WMT": "消费", "COST": "消费", "KO": "消费", "PEP": "消费",
    "PG": "消费", "NKE": "消费", "MCD": "消费", "SBUX": "消费",
    "TGT": "消费", "HD": "消费", "LOW": "消费", "DIS": "消费",
    "TSLA": "消费", "GM": "消费", "F": "消费", "LULU": "消费",
    "BABA": "消费",
    # 工业
    "BA": "工业", "CAT": "工业", "HON": "工业", "UPS": "工业",
    "GE": "工业", "RTX": "工业", "LMT": "工业", "NOC": "工业",
    "DE": "工业", "MMM": "工业",
    # 通信
    "T": "通信", "VZ": "通信", "TMUS": "通信", "CMCSA": "通信",
    # 房地产
    "AMT": "房地产", "PLD": "房地产", "CCI": "房地产", "EQIX": "房地产",
    "SPG": "房地产",
    # 公用事业
    "NEE": "公用事业", "DUK": "公用事业", "SO": "公用事业",
    "D": "公用事业", "AEP": "公用事业",
}

# ── Reverse mapping: sector -> list of symbols ──
SECTOR_SYMBOLS: dict[str, list[str]] = {}
for _sym, _sec in SECTORS.items():
    SECTOR_SYMBOLS.setdefault(_sec, []).append(_sym)


def get_sector(symbol: str) -> Optional[str]:
    """Get the sector for a given stock symbol."""
    return SECTORS.get(symbol)


def get_sector_symbols(sector: str) -> list[str]:
    """Get all stock symbols in a given sector."""
    return SECTOR_SYMBOLS.get(sector, [])


def get_all_sectors() -> list[str]:
    """Get list of all sector names."""
    return sorted(SECTOR_SYMBOLS.keys())


def compute_sector_performance(
    snapshots: dict[str, float | None],
) -> dict[str, dict]:
    """Compute average change_pct per sector from a dict of {symbol: change_pct}.

    Returns: {sector: {"avg_change": float, "up": int, "down": int, "total": int, "trend": str}}
    """
    sector_data: dict[str, list[float]] = {}
    for symbol, change_pct in snapshots.items():
        sector = get_sector(symbol)
        if sector and change_pct is not None:
            sector_data.setdefault(sector, []).append(change_pct)

    result: dict[str, dict] = {}
    for sector, changes in sorted(sector_data.items()):
        avg = sum(changes) / len(changes) if changes else 0.0
        up = sum(1 for c in changes if c > 0.3)
        down = sum(1 for c in changes if c < -0.3)
        total = len(changes)

        if down > up and down > total * 0.6:
            trend = "走弱"
        elif up > down and up > total * 0.6:
            trend = "走强"
        else:
            trend = "震荡"

        result[sector] = {
            "avg_change": round(avg, 2),
            "up": up,
            "down": down,
            "total": total,
            "trend": trend,
        }
    return result


def build_sector_prompt_context(
    symbol: str, sector_perf: dict[str, dict]
) -> str:
    """Build sector context string for AI prompt.

    Example: "该股票属于科技板块，当前科技板块整体走弱(平均-1.2%，5/7下跌)。"
    """
    sector = get_sector(symbol)
    if not sector or sector not in sector_perf:
        return ""

    perf = sector_perf[sector]
    avg = perf["avg_change"]
    trend = perf["trend"]
    up = perf["up"]
    down = perf["down"]
    total = perf["total"]

    sign = "+" if avg >= 0 else ""
    return (
        f"该股票属于{sector}板块，当前{sector}板块整体{trend}"
        f"(平均{sign}{avg}%，{up}/{total}上涨，{down}/{total}下跌)。"
    )
