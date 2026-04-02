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
