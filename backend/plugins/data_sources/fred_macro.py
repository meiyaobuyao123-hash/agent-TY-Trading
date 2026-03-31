"""FRED data source — fetches US macro data (GDP, CPI, Fed funds rate)."""

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

# FRED series IDs for key macro indicators
SERIES_MAP = {
    "US-GDP": "GDP",
    "US-CPI": "CPIAUCSL",
    "US-FED-RATE": "FEDFUNDS",
    "US-UNEMPLOYMENT": "UNRATE",
}


class FredMacroDataSource(DataSourcePlugin):
    """Fetch US macroeconomic data from the FRED API."""

    BASE_URL = "https://api.stlouisfed.org/fred/series/observations"

    @property
    def name(self) -> str:
        return "fred-macro"

    @property
    def display_name(self) -> str:
        return "FRED US Macro Data"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.MACRO]

    @property
    def requires_auth(self) -> bool:
        return True

    async def initialize(self, config: dict) -> None:
        from backend.config import settings
        self._api_key = config.get("fred_api_key") or settings.FRED_API_KEY
        self._client = httpx.AsyncClient(timeout=15)

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        if not self._api_key:
            logger.warning("FRED_API_KEY not set — skipping FRED fetch")
            return []

        results = []
        for symbol in query.symbols:
            series_id = SERIES_MAP.get(symbol, symbol)
            try:
                resp = await self._client.get(
                    self.BASE_URL,
                    params={
                        "series_id": series_id,
                        "api_key": self._api_key,
                        "file_type": "json",
                        "sort_order": "desc",
                        "limit": 50,
                    },
                )
                resp.raise_for_status()
                data = resp.json()
                candles = []
                for obs in data.get("observations", []):
                    try:
                        val = float(obs["value"])
                    except (ValueError, TypeError):
                        continue
                    candles.append(
                        OHLCV(
                            timestamp=0,  # FRED dates are strings, not ms
                            open=val,
                            high=val,
                            low=val,
                            close=val,
                            volume=0.0,
                        )
                    )
                results.append(
                    MarketData(
                        symbol=symbol,
                        market=MarketType.MACRO,
                        timeframe=Timeframe.MO1,
                        candles=candles,
                        metadata={"series_id": series_id},
                    )
                )
            except Exception:
                logger.exception("FRED fetch failed for %s", symbol)
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch latest macro values as ticks."""
        if not self._api_key:
            return []

        ticks = []
        for symbol in symbols:
            series_id = SERIES_MAP.get(symbol, symbol)
            try:
                resp = await self._client.get(
                    self.BASE_URL,
                    params={
                        "series_id": series_id,
                        "api_key": self._api_key,
                        "file_type": "json",
                        "sort_order": "desc",
                        "limit": 2,
                    },
                )
                resp.raise_for_status()
                obs = resp.json().get("observations", [])
                if obs:
                    val = float(obs[0]["value"])
                    prev = float(obs[1]["value"]) if len(obs) > 1 else val
                    change_pct = ((val - prev) / prev * 100) if prev else 0
                    ticks.append(
                        MarketTick(
                            symbol=symbol,
                            price=val,
                            volume=0.0,
                            timestamp=int(time.time() * 1000),
                            source="fred",
                            change_pct=change_pct,
                        )
                    )
            except Exception:
                logger.exception("FRED tick failed for %s", symbol)
        return ticks

    async def health_check(self) -> bool:
        if not self._api_key:
            return False
        try:
            resp = await self._client.get(
                "https://api.stlouisfed.org/fred/series",
                params={
                    "series_id": "GDP",
                    "api_key": self._api_key,
                    "file_type": "json",
                },
            )
            return resp.status_code == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._client.aclose()
