"""Binance REST data source — fetches crypto prices (BTC-USD, ETH-USD)."""

from __future__ import annotations

import logging
import time
from typing import Optional

import httpx

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

# Map our symbols to Binance symbols
SYMBOL_MAP = {
    # Top 20 (existing)
    "BTC-USD": "BTCUSDT",
    "ETH-USD": "ETHUSDT",
    "SOL-USD": "SOLUSDT",
    "BNB-USD": "BNBUSDT",
    "XRP-USD": "XRPUSDT",
    "ADA-USD": "ADAUSDT",
    "DOGE-USD": "DOGEUSDT",
    "AVAX-USD": "AVAXUSDT",
    "DOT-USD": "DOTUSDT",
    "LINK-USD": "LINKUSDT",
    "MATIC-USD": "MATICUSDT",
    "UNI-USD": "UNIUSDT",
    "ATOM-USD": "ATOMUSDT",
    "LTC-USD": "LTCUSDT",
    "SUI-USD": "SUIUSDT",
    "ARB-USD": "ARBUSDT",
    "OP-USD": "OPUSDT",
    "APT-USD": "APTUSDT",
    "NEAR-USD": "NEARUSDT",
    "FIL-USD": "FILUSDT",
    # Round 9 expansion — top 50 coverage
    "TRX-USD": "TRXUSDT",
    "TON-USD": "TONUSDT",
    "SHIB-USD": "SHIBUSDT",
    "PEPE-USD": "PEPEUSDT",
    "WIF-USD": "WIFUSDT",
    "BONK-USD": "BONKUSDT",
    "RENDER-USD": "RENDERUSDT",
    "FET-USD": "FETUSDT",
    "INJ-USD": "INJUSDT",
    "SEI-USD": "SEIUSDT",
    "TIA-USD": "TIAUSDT",
    "JUP-USD": "JUPUSDT",
    "WLD-USD": "WLDUSDT",
    "AAVE-USD": "AAVEUSDT",
    "MKR-USD": "MKRUSDT",
    "SNX-USD": "SNXUSDT",
    "COMP-USD": "COMPUSDT",
    "CRV-USD": "CRVUSDT",
    "ALGO-USD": "ALGOUSDT",
    "HBAR-USD": "HBARUSDT",
    # Round 16 — meme coins & DeFi
    "FLOKI-USD": "FLOKIUSDT",
    "CAKE-USD": "CAKEUSDT",
    "SUSHI-USD": "SUSHIUSDT",
    "1INCH-USD": "1INCHUSDT",
    "YFI-USD": "YFIUSDT",
    "BAL-USD": "BALUSDT",
    "MEME-USD": "MEMEUSDT",
}

REVERSE_MAP = {v: k for k, v in SYMBOL_MAP.items()}


class BinanceDataSource(DataSourcePlugin):
    """Fetch crypto market data from Binance REST API."""

    BASE_URL = "https://api.binance.com/api/v3"

    @property
    def name(self) -> str:
        return "binance-rest"

    @property
    def display_name(self) -> str:
        return "Binance REST API"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        self._client = httpx.AsyncClient(timeout=15)

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        for symbol in query.symbols:
            binance_sym = SYMBOL_MAP.get(symbol, symbol.replace("-", ""))
            try:
                resp = await self._client.get(
                    f"{self.BASE_URL}/klines",
                    params={
                        "symbol": binance_sym,
                        "interval": "1h",
                        "startTime": query.start,
                        "endTime": query.end,
                        "limit": 100,
                    },
                )
                resp.raise_for_status()
                raw = resp.json()
                candles = [
                    OHLCV(
                        timestamp=int(k[0]),
                        open=float(k[1]),
                        high=float(k[2]),
                        low=float(k[3]),
                        close=float(k[4]),
                        volume=float(k[5]),
                    )
                    for k in raw
                ]
                results.append(
                    MarketData(
                        symbol=symbol,
                        market=MarketType.CRYPTO,
                        timeframe=query.timeframe,
                        candles=candles,
                    )
                )
            except Exception:
                logger.exception("Binance fetch failed for %s", symbol)
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current price ticks for given symbols."""
        ticks = []
        for symbol in symbols:
            binance_sym = SYMBOL_MAP.get(symbol, symbol.replace("-", ""))
            try:
                resp = await self._client.get(
                    f"{self.BASE_URL}/ticker/24hr",
                    params={"symbol": binance_sym},
                )
                resp.raise_for_status()
                data = resp.json()
                ticks.append(
                    MarketTick(
                        symbol=symbol,
                        price=float(data["lastPrice"]),
                        volume=float(data["volume"]),
                        timestamp=int(time.time() * 1000),
                        source="binance",
                        change_pct=float(data.get("priceChangePercent", 0)),
                    )
                )
            except Exception:
                logger.exception("Binance tick fetch failed for %s", symbol)
        return ticks

    async def health_check(self) -> bool:
        try:
            resp = await self._client.get(f"{self.BASE_URL}/ping")
            return resp.status_code == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._client.aclose()
