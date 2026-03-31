"""Judgment service — orchestrate: fetch data -> AI judge -> bias calc -> record judgment."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.plugin_manager import PluginManager
from backend.core.types import MarketType
from backend.models import Judgment, Market, MarketSnapshot
from backend.plugins.bias_detectors.deviation_calc import calculate_deviation_pct

logger = logging.getLogger(__name__)

# Map market_type to data source plugin name
DATA_SOURCE_MAP = {
    "crypto": "binance-rest",
    "cn-equities": "akshare-cn",
    "hk-equities": "akshare-cn",
    "global-indices": "akshare-cn",
    "macro": "fred-macro",
    "forex": "frankfurter-fx",
    "prediction-markets": "polymarket-gamma",
}


async def trigger_judgment_cycle(
    session: AsyncSession,
    plugin_manager: PluginManager,
    symbols: Optional[list[str]] = None,
    horizon_hours: int = 4,
) -> list[Judgment]:
    """Run the full AI judgment cycle for specified or all active markets.

    Steps:
    1. Get target markets
    2. For each market, fetch latest data from the appropriate data source
    3. Save a market snapshot
    4. Call AI consensus reasoning
    5. Calculate deviation
    6. Record judgment
    """
    # 1. Get target markets
    if symbols:
        stmt = select(Market).where(Market.symbol.in_(symbols), Market.is_active == True)
    else:
        stmt = select(Market).where(Market.is_active == True)

    result = await session.execute(stmt)
    markets = result.scalars().all()

    if not markets:
        logger.warning("No active markets found for judgment cycle")
        return []

    # Get reasoning plugin
    reasoning = plugin_manager.get_reasoning("ai-consensus")
    if reasoning is None:
        logger.error("ai-consensus reasoning plugin not found")
        return []

    judgments = []

    for market in markets:
        try:
            # 2. Fetch latest data
            ds_name = DATA_SOURCE_MAP.get(market.market_type, "binance-rest")
            data_source = plugin_manager.get_data_source(ds_name)

            tick_data = {}
            if data_source:
                try:
                    ticks = await data_source.fetch_ticks([market.symbol])
                    if ticks:
                        tick = ticks[0]
                        tick_data = {
                            "price": tick.price,
                            "volume": tick.volume,
                            "change_pct": tick.change_pct,
                            "market_type": market.market_type,
                        }
                except Exception:
                    logger.exception("Failed to fetch tick for %s", market.symbol)

            # 3. Save snapshot
            snapshot = MarketSnapshot(
                id=uuid.uuid4(),
                market_id=market.id,
                price=tick_data.get("price"),
                volume=tick_data.get("volume"),
                change_pct=tick_data.get("change_pct"),
                raw_data=tick_data,
                captured_at=datetime.utcnow(),
            )
            session.add(snapshot)
            await session.flush()

            # 4. AI consensus
            context = {
                "symbol": market.symbol,
                "market_data": tick_data,
            }
            ai_result = await reasoning.analyze(context)

            # 5. Calculate deviation
            market_price = tick_data.get("price")
            rational_price = ai_result.get("rational_price")
            deviation_pct = calculate_deviation_pct(
                market_price, rational_price
            ) if market_price else None

            # 6. Record judgment
            now = datetime.utcnow()
            judgment = Judgment(
                id=uuid.uuid4(),
                market_id=market.id,
                snapshot_id=snapshot.id,
                direction=ai_result.get("direction", "flat"),
                confidence=ai_result.get("confidence", "low"),
                confidence_score=ai_result.get("confidence_score", 0.3),
                rational_price=rational_price,
                deviation_pct=deviation_pct,
                reasoning=ai_result.get("reasoning"),
                model_votes=ai_result.get("model_votes"),
                horizon_hours=horizon_hours,
                expires_at=now + timedelta(hours=horizon_hours),
                created_at=now,
            )
            session.add(judgment)
            judgments.append(judgment)
            logger.info(
                "Judgment for %s: %s (%s, %.1f%%)",
                market.symbol,
                ai_result.get("direction"),
                ai_result.get("confidence"),
                ai_result.get("confidence_score", 0) * 100,
            )
        except Exception:
            logger.exception("Failed judgment for market %s", market.symbol)

    if judgments:
        await session.commit()
    return judgments
