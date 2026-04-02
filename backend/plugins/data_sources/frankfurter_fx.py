"""Frankfurter FX data source — fetches forex rates (USD/CNY, EUR/USD)."""

from __future__ import annotations

import logging
import time

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

# Map our symbols to Frankfurter base/target
FX_PAIRS = {
    "USD/CNY": ("USD", "CNY"),
    "EUR/USD": ("EUR", "USD"),
    "GBP/USD": ("GBP", "USD"),
    "USD/JPY": ("USD", "JPY"),
    "AUD/USD": ("AUD", "USD"),
    "NZD/USD": ("NZD", "USD"),
    "USD/CHF": ("USD", "CHF"),
    "EUR/GBP": ("EUR", "GBP"),
    "USD/CAD": ("USD", "CAD"),
    "USD/HKD": ("USD", "HKD"),
    "USD/SGD": ("USD", "SGD"),
    "EUR/JPY": ("EUR", "JPY"),
    # R12 expansion
    "USD/MXN": ("USD", "MXN"),
    "USD/BRL": ("USD", "BRL"),
    "USD/ZAR": ("USD", "ZAR"),
    "USD/TRY": ("USD", "TRY"),
    "EUR/CHF": ("EUR", "CHF"),
    "GBP/JPY": ("GBP", "JPY"),
    "AUD/JPY": ("AUD", "JPY"),
    "NZD/JPY": ("NZD", "JPY"),
}


class FrankfurterFXDataSource(DataSourcePlugin):
    """Fetch forex rates from api.frankfurter.app (free, no auth)."""

    BASE_URL = "https://api.frankfurter.app"

    @property
    def name(self) -> str:
        return "frankfurter-fx"

    @property
    def display_name(self) -> str:
        return "Frankfurter Forex"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.FOREX]

    async def initialize(self, config: dict) -> None:
        self._client = httpx.AsyncClient(timeout=15)

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        for symbol in query.symbols:
            pair = FX_PAIRS.get(symbol)
            if not pair:
                logger.warning("Unknown FX pair: %s", symbol)
                continue
            base, target = pair
            try:
                resp = await self._client.get(
                    f"{self.BASE_URL}/latest",
                    params={"from": base, "to": target},
                )
                resp.raise_for_status()
                data = resp.json()
                rate = data["rates"].get(target, 0.0)
                candle = OHLCV(
                    timestamp=int(time.time() * 1000),
                    open=rate,
                    high=rate,
                    low=rate,
                    close=rate,
                    volume=0.0,
                )
                results.append(
                    MarketData(
                        symbol=symbol,
                        market=MarketType.FOREX,
                        timeframe=Timeframe.D1,
                        candles=[candle],
                        metadata={"base": base, "target": target},
                    )
                )
            except Exception:
                logger.exception("Frankfurter fetch failed for %s", symbol)
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current FX rates as ticks."""
        ticks = []
        for symbol in symbols:
            pair = FX_PAIRS.get(symbol)
            if not pair:
                continue
            base, target = pair
            try:
                resp = await self._client.get(
                    f"{self.BASE_URL}/latest",
                    params={"from": base, "to": target},
                )
                resp.raise_for_status()
                data = resp.json()
                rate = data["rates"].get(target, 0.0)
                ticks.append(
                    MarketTick(
                        symbol=symbol,
                        price=rate,
                        volume=0.0,
                        timestamp=int(time.time() * 1000),
                        source="frankfurter",
                    )
                )
            except Exception:
                logger.exception("Frankfurter tick failed for %s", symbol)
        return ticks

    async def health_check(self) -> bool:
        try:
            resp = await self._client.get(f"{self.BASE_URL}/latest")
            return resp.status_code == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._client.aclose()
