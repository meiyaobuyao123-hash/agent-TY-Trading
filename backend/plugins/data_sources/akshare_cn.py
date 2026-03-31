"""AKShare data source — fetches A-share and HK stock data."""

from __future__ import annotations

import logging
import time
from typing import Optional

from backend.core.plugin_base import DataSourcePlugin
from backend.core.types import (
    DataQuery,
    MarketData,
    MarketTick,
    MarketType,
    OHLCV,
    Timeframe,
)

logger = logging.getLogger(__name__)


class AKShareDataSource(DataSourcePlugin):
    """Fetch A-share / Hong Kong stock data via AKShare library."""

    @property
    def name(self) -> str:
        return "akshare-cn"

    @property
    def display_name(self) -> str:
        return "AKShare (A股/港股)"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CN_EQUITIES, MarketType.HK_EQUITIES, MarketType.GLOBAL_INDICES]

    async def initialize(self, config: dict) -> None:
        pass  # akshare is imported on demand

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        try:
            import akshare as ak
            import asyncio

            for symbol in query.symbols:
                try:
                    # Run blocking akshare call in executor
                    loop = asyncio.get_event_loop()
                    if symbol.startswith("0") or symbol.startswith("6") or symbol.startswith("3"):
                        df = await loop.run_in_executor(
                            None,
                            lambda s=symbol: ak.stock_zh_a_hist(symbol=s, period="daily", adjust="qfq"),
                        )
                    else:
                        continue

                    if df is None or df.empty:
                        continue

                    candles = []
                    for _, row in df.tail(100).iterrows():
                        candles.append(
                            OHLCV(
                                timestamp=int(row.get("日期", row.name).timestamp() * 1000) if hasattr(row.get("日期", row.name), "timestamp") else 0,
                                open=float(row.get("开盘", 0)),
                                high=float(row.get("最高", 0)),
                                low=float(row.get("最低", 0)),
                                close=float(row.get("收盘", 0)),
                                volume=float(row.get("成交量", 0)),
                            )
                        )
                    results.append(
                        MarketData(
                            symbol=symbol,
                            market=MarketType.CN_EQUITIES,
                            timeframe=query.timeframe,
                            candles=candles,
                        )
                    )
                except Exception:
                    logger.exception("AKShare fetch failed for %s", symbol)
        except ImportError:
            logger.warning("akshare not installed — skipping AKShare data source")
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current ticks for A-share symbols."""
        ticks = []
        try:
            import akshare as ak
            import asyncio

            loop = asyncio.get_event_loop()
            for symbol in symbols:
                try:
                    # Get real-time quote
                    df = await loop.run_in_executor(
                        None,
                        lambda s=symbol: ak.stock_zh_a_spot_em(),
                    )
                    if df is not None and not df.empty:
                        row = df[df["代码"] == symbol]
                        if not row.empty:
                            r = row.iloc[0]
                            ticks.append(
                                MarketTick(
                                    symbol=symbol,
                                    price=float(r.get("最新价", 0)),
                                    volume=float(r.get("成交量", 0)),
                                    timestamp=int(time.time() * 1000),
                                    source="akshare",
                                    change_pct=float(r.get("涨跌幅", 0)),
                                )
                            )
                except Exception:
                    logger.exception("AKShare tick failed for %s", symbol)
        except ImportError:
            logger.warning("akshare not installed")
        return ticks

    async def health_check(self) -> bool:
        try:
            import akshare  # noqa: F401
            return True
        except ImportError:
            return False
