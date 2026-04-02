"""Fear & Greed Index data source — fetches crypto fear & greed from alternative.me."""

from __future__ import annotations

import logging
import time
from typing import Optional

import httpx

from backend.core.plugin_base import DataSourcePlugin
from backend.core.types import DataQuery, MarketData, MarketTick, MarketType

logger = logging.getLogger(__name__)

# Cache for 10 minutes
_cache: dict = {"value": None, "label": None, "fetched_at": 0}
_CACHE_TTL = 600  # seconds


async def get_fear_greed_index() -> Optional[dict]:
    """Fetch the current crypto fear & greed index. Returns {"value": int, "label": str} or None."""
    now = time.time()
    if _cache["value"] is not None and (now - _cache["fetched_at"]) < _CACHE_TTL:
        return {"value": _cache["value"], "label": _cache["label"]}

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get("https://api.alternative.me/fng/?limit=1")
            resp.raise_for_status()
            data = resp.json()
            entry = data.get("data", [{}])[0]
            value = int(entry.get("value", 50))
            label_en = entry.get("value_classification", "Neutral")

            # Translate to Chinese
            label_map = {
                "Extreme Fear": "极度恐慌",
                "Fear": "恐慌",
                "Neutral": "中性",
                "Greed": "贪婪",
                "Extreme Greed": "极度贪婪",
            }
            label_cn = label_map.get(label_en, label_en)

            _cache["value"] = value
            _cache["label"] = label_cn
            _cache["fetched_at"] = now

            logger.info("Fear & Greed Index: %d (%s)", value, label_cn)
            return {"value": value, "label": label_cn}
    except Exception:
        logger.warning("Failed to fetch Fear & Greed Index")
        if _cache["value"] is not None:
            return {"value": _cache["value"], "label": _cache["label"]}
        return None


class FearGreedDataSource(DataSourcePlugin):
    """Crypto Fear & Greed Index from alternative.me (free, no auth)."""

    @property
    def name(self) -> str:
        return "fear-greed"

    @property
    def display_name(self) -> str:
        return "加密市场恐慌贪婪指数"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        pass

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        return []

    async def health_check(self) -> bool:
        result = await get_fear_greed_index()
        return result is not None
