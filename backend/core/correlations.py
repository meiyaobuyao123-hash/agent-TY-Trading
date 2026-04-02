"""Cross-market correlation map and market context utilities for L2 causal reasoning."""

from __future__ import annotations

# Static correlation map: symbol -> list of related symbols
CORRELATIONS: dict[str, list[str]] = {
    # Crypto
    "BTC-USD": ["ETH-USD", "SOL-USD", "BNB-USD"],
    "ETH-USD": ["BTC-USD", "SOL-USD", "BNB-USD"],
    "SOL-USD": ["BTC-USD", "ETH-USD"],
    "BNB-USD": ["BTC-USD", "ETH-USD"],
    "XRP-USD": ["BTC-USD", "ETH-USD"],
    "DOGE-USD": ["BTC-USD", "SHIB-USD"],
    # US equities
    "TSLA": ["NVDA", "SPX", "IXIC"],
    "NVDA": ["TSLA", "AMD", "SPX"],
    "AAPL": ["MSFT", "GOOGL", "SPX"],
    "MSFT": ["AAPL", "GOOGL", "SPX"],
    "GOOGL": ["MSFT", "AAPL", "SPX"],
    "AMD": ["NVDA", "INTC", "SPX"],
    "META": ["GOOGL", "AAPL", "SPX"],
    "AMZN": ["GOOGL", "MSFT", "SPX"],
    # CN equities
    "600519.SH": ["000858.SZ", "000001.SS"],
    "000858.SZ": ["600519.SH", "000001.SS"],
    # Global indices
    "SPX": ["IXIC", "DJI", "VIX"],
    "IXIC": ["SPX", "DJI"],
    "DJI": ["SPX", "IXIC"],
    "000001.SS": ["399001.SZ", "HSI"],
    "HSI": ["000001.SS", "399001.SZ"],
    # Forex
    "USD/CNY": ["EUR/USD", "USD/JPY", "GBP/USD"],
    "EUR/USD": ["USD/CNY", "GBP/USD", "USD/JPY"],
    "USD/JPY": ["EUR/USD", "USD/CNY", "GBP/USD"],
    "GBP/USD": ["EUR/USD", "USD/JPY"],
    # Commodities
    "GC=F": ["SI=F", "DX-Y.NYB"],
    "CL=F": ["BZ=F", "NG=F"],
    # New crypto (Round 9) — all correlated with BTC
    "TRX-USD": ["BTC-USD", "ETH-USD"],
    "TON-USD": ["BTC-USD", "ETH-USD"],
    "SHIB-USD": ["BTC-USD", "DOGE-USD"],
    "PEPE-USD": ["BTC-USD", "SHIB-USD", "DOGE-USD"],
    "WIF-USD": ["BTC-USD", "SOL-USD", "BONK-USD"],
    "BONK-USD": ["BTC-USD", "SOL-USD", "WIF-USD"],
    "RENDER-USD": ["BTC-USD", "FET-USD"],
    "FET-USD": ["BTC-USD", "RENDER-USD"],
    "INJ-USD": ["BTC-USD", "ETH-USD"],
    "SEI-USD": ["BTC-USD", "SOL-USD"],
    "TIA-USD": ["BTC-USD", "ETH-USD"],
    "JUP-USD": ["BTC-USD", "SOL-USD"],
    "WLD-USD": ["BTC-USD", "ETH-USD"],
    "AAVE-USD": ["BTC-USD", "ETH-USD", "UNI-USD"],
    "MKR-USD": ["BTC-USD", "ETH-USD", "AAVE-USD"],
    "SNX-USD": ["BTC-USD", "ETH-USD"],
    "COMP-USD": ["BTC-USD", "ETH-USD", "AAVE-USD"],
    "CRV-USD": ["BTC-USD", "ETH-USD"],
    "ALGO-USD": ["BTC-USD", "ETH-USD"],
    "HBAR-USD": ["BTC-USD", "ETH-USD"],
    # New US stocks (Round 9) — sector peers
    "SHOP": ["AMZN", "SPX"],
    "SNOW": ["CRM", "PLTR", "SPX"],
    "NET": ["CRWD", "ZS", "SPX"],
    "DDOG": ["CRM", "SNOW", "SPX"],
    "ZS": ["CRWD", "NET", "PANW"],
    "CRWD": ["ZS", "PANW", "NET"],
    "PANW": ["CRWD", "ZS", "SPX"],
    "ABBV": ["LLY", "MRK", "JNJ"],
    "LLY": ["ABBV", "MRK", "UNH"],
    "UNH": ["LLY", "JNJ", "SPX"],
    "MRK": ["ABBV", "LLY", "PFE"],
    "TMO": ["ABBV", "LLY", "SPX"],
    "SLB": ["EOG", "OXY", "XOM"],
    "EOG": ["SLB", "OXY", "XOM"],
    "OXY": ["SLB", "EOG", "CVX"],
    "SBUX": ["MCD", "NKE", "SPX"],
    "NKE": ["SBUX", "DIS", "SPX"],
    "MCD": ["SBUX", "KO", "PEP"],
    "KO": ["PEP", "MCD", "SPX"],
    "PEP": ["KO", "MCD", "SPX"],
    "BRK-B": ["JPM", "SPX"],
    "C": ["BAC", "WFC", "JPM"],
    "WFC": ["BAC", "C", "JPM"],
    "AXP": ["V", "MA", "JPM"],
    "BLK": ["GS", "JPM", "SPX"],
    "SCHW": ["GS", "BAC", "SPX"],
    # ETFs — correlated with underlying
    "SPY": ["SPX", "QQQ", "DIA"],
    "QQQ": ["IXIC", "SPY", "SPX"],
    "IWM": ["SPY", "SPX"],
    "DIA": ["DJI", "SPY"],
    "GLD": ["GOLD", "SLV"],
    "SLV": ["SILVER", "GLD"],
    "USO": ["OIL", "XOM"],
    "TLT": ["SPY", "HYG"],
    "HYG": ["SPY", "TLT"],
    "EEM": ["VWO", "FXI", "SPY"],
    "VWO": ["EEM", "FXI", "SPY"],
    "FXI": ["HSI", "EEM", "VWO"],
}

# Benchmark symbols per market type (used for cross-market context)
MARKET_BENCHMARKS: dict[str, list[str]] = {
    "crypto": ["BTC-USD"],
    "us-equities": ["SPX"],
    "cn-equities": ["000001.SS"],
    "hk-equities": ["HSI"],
    "global-indices": ["SPX"],
    "forex": ["USD/CNY", "EUR/USD"],
    "commodities": ["GC=F", "CL=F"],
    "etf": ["SPY", "QQQ"],
}


def get_related_symbols(symbol: str) -> list[str]:
    """Return the list of correlated symbols for a given symbol."""
    return CORRELATIONS.get(symbol, [])


def compute_quality_score(
    rational_price: float | None,
    reasoning: str | None,
    confidence_score: float,
    history_text: str,
    market_context: dict | None,
) -> float:
    """Compute a 0-1 quality score for a judgment.

    Scoring:
    - Has rational_price? +0.3
    - Has non-trivial reasoning (>50 chars)? +0.2
    - Confidence > 0.4? +0.2
    - Has historical data context? +0.15
    - Has cross-market context? +0.15
    """
    score = 0.0
    if rational_price is not None:
        score += 0.3
    if reasoning and len(reasoning) > 50:
        score += 0.2
    if confidence_score > 0.4:
        score += 0.2
    if history_text:
        score += 0.15
    if market_context:
        score += 0.15
    return round(score, 2)
