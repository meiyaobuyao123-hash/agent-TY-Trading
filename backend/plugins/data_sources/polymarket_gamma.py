"""Polymarket Gamma data source — fetches prediction market data."""

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


class PolymarketGammaDataSource(DataSourcePlugin):
    """Fetch prediction market data from Polymarket's Gamma API."""

    BASE_URL = "https://gamma-api.polymarket.com"

    @property
    def name(self) -> str:
        return "polymarket-gamma"

    @property
    def display_name(self) -> str:
        return "Polymarket (Prediction Markets)"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.PREDICTION_MARKETS]

    async def initialize(self, config: dict) -> None:
        self._client = httpx.AsyncClient(timeout=15)

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        try:
            resp = await self._client.get(
                f"{self.BASE_URL}/markets",
                params={"limit": 20, "active": True, "closed": False},
            )
            resp.raise_for_status()
            markets = resp.json()

            for mkt in markets:
                slug = mkt.get("slug", mkt.get("conditionId", ""))
                question = mkt.get("question", "")
                # Use outcomePrices if available
                outcome_prices = mkt.get("outcomePrices", "[]")
                try:
                    if isinstance(outcome_prices, str):
                        import json
                        prices = json.loads(outcome_prices)
                    else:
                        prices = outcome_prices
                    price = float(prices[0]) if prices else 0.5
                except (ValueError, IndexError):
                    price = 0.5

                volume = float(mkt.get("volume", 0) or 0)
                candle = OHLCV(
                    timestamp=int(time.time() * 1000),
                    open=price,
                    high=price,
                    low=price,
                    close=price,
                    volume=volume,
                )
                results.append(
                    MarketData(
                        symbol=slug or question[:30],
                        market=MarketType.PREDICTION_MARKETS,
                        timeframe=Timeframe.D1,
                        candles=[candle],
                        metadata={
                            "question": question,
                            "slug": slug,
                        },
                    )
                )
        except Exception:
            logger.exception("Polymarket fetch failed")
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current prediction market prices as ticks."""
        ticks = []
        try:
            resp = await self._client.get(
                f"{self.BASE_URL}/markets",
                params={"limit": 50, "active": True, "closed": False},
            )
            resp.raise_for_status()
            markets = resp.json()
            slug_lookup = {m.get("slug", ""): m for m in markets}

            for symbol in symbols:
                mkt = slug_lookup.get(symbol)
                if not mkt:
                    continue
                outcome_prices = mkt.get("outcomePrices", "[]")
                try:
                    import json
                    if isinstance(outcome_prices, str):
                        prices = json.loads(outcome_prices)
                    else:
                        prices = outcome_prices
                    price = float(prices[0]) if prices else 0.5
                except (ValueError, IndexError):
                    price = 0.5

                ticks.append(
                    MarketTick(
                        symbol=symbol,
                        price=price,
                        volume=float(mkt.get("volume", 0) or 0),
                        timestamp=int(time.time() * 1000),
                        source="polymarket",
                    )
                )
        except Exception:
            logger.exception("Polymarket tick fetch failed")
        return ticks

    async def health_check(self) -> bool:
        try:
            resp = await self._client.get(
                f"{self.BASE_URL}/markets", params={"limit": 1}
            )
            return resp.status_code == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._client.aclose()
