"""Judgment service — orchestrate: fetch data -> AI judge -> bias calc -> record judgment."""

from __future__ import annotations

import asyncio
import logging
import time
import uuid
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Optional

import httpx

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from backend.core.correlations import MARKET_BENCHMARKS, compute_quality_score
from backend.core.plugin_manager import PluginManager
from backend.core.types import DataQuery, MarketType, Timeframe
from backend.models import Judgment, Market, MarketSnapshot, Settlement, AccuracyStat
from backend.core.strategy_genome import get_best_genome, build_genome_prompt_hint
from backend.plugins.bias_detectors.deviation_calc import calculate_deviation_pct
from backend.plugins.bias_detectors.cognitive_bias import detect_all_biases
from backend.plugins.data_sources.fear_greed import get_fear_greed_index

logger = logging.getLogger(__name__)

# ── Crypto market cap ranking cache ──────────────────────────────
_mcap_cache: dict = {}
_mcap_cache_ts: float = 0.0
MCAP_CACHE_TTL = 3600  # 1 hour


async def _fetch_crypto_mcap_rankings() -> dict[str, dict]:
    """Fetch crypto market cap rankings from CoinGecko free API.

    Returns dict mapping symbol (e.g. 'BTC-USD') to {rank, market_cap, tier}.
    """
    global _mcap_cache, _mcap_cache_ts
    now = time.time()
    if _mcap_cache and (now - _mcap_cache_ts) < MCAP_CACHE_TTL:
        return _mcap_cache

    # CoinGecko symbol to our symbol mapping
    coingecko_id_map = {
        "bitcoin": "BTC-USD", "ethereum": "ETH-USD", "solana": "SOL-USD",
        "binancecoin": "BNB-USD", "ripple": "XRP-USD", "cardano": "ADA-USD",
        "dogecoin": "DOGE-USD", "avalanche-2": "AVAX-USD", "polkadot": "DOT-USD",
        "chainlink": "LINK-USD", "matic-network": "MATIC-USD", "uniswap": "UNI-USD",
        "cosmos": "ATOM-USD", "litecoin": "LTC-USD", "sui": "SUI-USD",
        "arbitrum": "ARB-USD", "optimism": "OP-USD", "aptos": "APT-USD",
        "near": "NEAR-USD", "filecoin": "FIL-USD", "tron": "TRX-USD",
        "the-open-network": "TON-USD", "shiba-inu": "SHIB-USD",
        "pepe": "PEPE-USD", "aave": "AAVE-USD",
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(
                "https://api.coingecko.com/api/v3/coins/markets",
                params={
                    "vs_currency": "usd",
                    "order": "market_cap_desc",
                    "per_page": 100,
                    "page": 1,
                },
            )
            if resp.status_code == 200:
                data = resp.json()
                result = {}
                for coin in data:
                    cg_id = coin.get("id", "")
                    our_sym = coingecko_id_map.get(cg_id)
                    if our_sym:
                        rank = coin.get("market_cap_rank", 999)
                        if rank <= 10:
                            tier = "前10"
                        elif rank <= 30:
                            tier = "前30"
                        elif rank <= 50:
                            tier = "前50"
                        elif rank <= 100:
                            tier = "前100"
                        else:
                            tier = "100名后"
                        result[our_sym] = {
                            "rank": rank,
                            "market_cap": coin.get("market_cap"),
                            "tier": tier,
                        }
                _mcap_cache = result
                _mcap_cache_ts = now
                return result
    except Exception:
        logger.debug("Failed to fetch CoinGecko market cap rankings")

    return _mcap_cache  # Return stale cache if available

# Map market_type to data source plugin name
DATA_SOURCE_MAP = {
    "crypto": "binance-rest",
    "cn-equities": "akshare-cn",
    "hk-equities": "akshare-cn",
    "us-equities": "yfinance-global",
    "global-indices": "yfinance-global",
    "commodities": "yfinance-global",
    "macro": "fred-macro",
    "forex": "frankfurter-fx",
    "prediction-markets": "polymarket-gamma",
    "etf": "yfinance-global",
}

# Different prediction horizons per market type
HORIZON_MAP = {
    "crypto": 4,
    "forex": 4,
    "us-equities": 24,
    "cn-equities": 24,
    "hk-equities": 24,
    "global-indices": 24,
    "commodities": 24,
    "macro": 168,  # 7 days for macro indicators
    "prediction-markets": 24,
    "etf": 24,
}

# Map market_type string to MarketType enum for DataQuery
_MARKET_TYPE_ENUM = {
    "crypto": MarketType.CRYPTO,
    "cn-equities": MarketType.CN_EQUITIES,
    "hk-equities": MarketType.HK_EQUITIES,
    "us-equities": MarketType.US_EQUITIES,
    "global-indices": MarketType.GLOBAL_INDICES,
    "commodities": MarketType.COMMODITIES,
    "macro": MarketType.MACRO,
    "forex": MarketType.FOREX,
    "prediction-markets": MarketType.PREDICTION_MARKETS,
    "etf": MarketType.ETF,
}


def _format_price(price: float) -> str:
    """Format price for display — avoid unnecessary decimals for large values."""
    if price >= 1000:
        return f"${price:,.0f}"
    elif price >= 1:
        return f"${price:.2f}"
    else:
        return f"${price:.4f}"


def _build_history_text(candles: list) -> str:
    """Build a '7日价格走势' string from the last 7 daily candles."""
    if not candles:
        return ""
    # Take the last 7 candles (close prices)
    recent = candles[-7:] if len(candles) >= 7 else candles
    prices = [_format_price(c.close) for c in recent]
    return " → ".join(prices)


def _compute_technical_indicators(candles: list) -> dict:
    """Compute technical indicators from historical candles.

    Returns dict with:
      - rsi_7: 7-period RSI (0-100)
      - change_7d_pct: 7-day price change percentage
      - sma_7_trend: 'above' or 'below' (current price vs 7-day SMA)
      - volatility_7d: 7-day price volatility (std dev of daily returns)
    """
    if not candles or len(candles) < 3:
        return {}

    closes = [c.close for c in candles if c.close is not None]
    if len(closes) < 3:
        return {}

    result = {}

    # 7-day price change %
    recent = closes[-7:] if len(closes) >= 7 else closes
    if len(recent) >= 2 and recent[0] != 0:
        result["change_7d_pct"] = round((recent[-1] - recent[0]) / recent[0] * 100, 2)

    # 7-day SMA
    sma_7 = sum(recent) / len(recent)
    current_price = closes[-1]
    result["sma_7"] = round(sma_7, 4)
    result["sma_7_trend"] = "above" if current_price > sma_7 else "below"

    # RSI(7) — Relative Strength Index
    if len(closes) >= 8:
        rsi_data = closes[-(min(14, len(closes))):]  # Use up to 14 periods
        gains = []
        losses = []
        for i in range(1, len(rsi_data)):
            delta = rsi_data[i] - rsi_data[i - 1]
            if delta > 0:
                gains.append(delta)
                losses.append(0)
            else:
                gains.append(0)
                losses.append(abs(delta))
        if gains:
            avg_gain = sum(gains[-7:]) / 7
            avg_loss = sum(losses[-7:]) / 7
            if avg_loss == 0:
                result["rsi_7"] = 100.0
            else:
                rs = avg_gain / avg_loss
                result["rsi_7"] = round(100 - (100 / (1 + rs)), 1)

    # 7-day volatility (annualized std dev of daily returns)
    if len(recent) >= 3:
        daily_returns = []
        for i in range(1, len(recent)):
            if recent[i - 1] != 0:
                daily_returns.append((recent[i] - recent[i - 1]) / recent[i - 1])
        if daily_returns:
            mean_ret = sum(daily_returns) / len(daily_returns)
            variance = sum((r - mean_ret) ** 2 for r in daily_returns) / len(daily_returns)
            result["volatility_7d"] = round((variance ** 0.5) * 100, 2)  # as percentage

    return result


def _format_technical_indicators(indicators: dict) -> str:
    """Format technical indicators as a Chinese-language string for AI prompt."""
    if not indicators:
        return ""

    parts = []

    rsi = indicators.get("rsi_7")
    if rsi is not None:
        if rsi >= 70:
            rsi_label = "超买"
        elif rsi <= 30:
            rsi_label = "超卖"
        else:
            rsi_label = "中性"
        parts.append(f"RSI(7)={rsi:.0f}({rsi_label})")

    change_7d = indicators.get("change_7d_pct")
    if change_7d is not None:
        parts.append(f"7日涨幅={change_7d:+.1f}%")

    sma_trend = indicators.get("sma_7_trend")
    if sma_trend:
        trend_cn = "高于" if sma_trend == "above" else "低于"
        parts.append(f"价格{trend_cn}7日均线")

    vol = indicators.get("volatility_7d")
    if vol is not None:
        if vol > 3:
            vol_label = "高波动"
        elif vol > 1.5:
            vol_label = "中等波动"
        else:
            vol_label = "低波动"
        parts.append(f"7日波动率={vol:.1f}%({vol_label})")

    return "技术指标: " + ", ".join(parts) if parts else ""


async def _fetch_history_for_market(
    data_source,
    symbol: str,
    market_type_str: str,
) -> tuple[str, dict]:
    """Fetch last 7+ daily candles for a symbol.

    Returns (history_text, technical_indicators_dict).
    """
    try:
        now_ms = int(time.time() * 1000)
        start_ms = now_ms - (15 * 24 * 3600 * 1000)  # 15 days back for RSI
        mt_enum = _MARKET_TYPE_ENUM.get(market_type_str, MarketType.CRYPTO)
        query = DataQuery(
            symbols=[symbol],
            market=mt_enum,
            timeframe=Timeframe.D1,
            start=start_ms,
            end=now_ms,
        )
        results = await data_source.fetch(query)
        if results and results[0].candles:
            candles = results[0].candles
            history_text = _build_history_text(candles)
            tech_indicators = _compute_technical_indicators(candles)
            return history_text, tech_indicators
    except Exception:
        logger.debug("Failed to fetch history for %s — will proceed without", symbol)
    return "", {}


async def _build_market_context(
    market_type: str,
    current_symbol: str,
    tick_cache: dict,
) -> dict:
    """Build cross-market context dict for L2 causal reasoning."""
    benchmarks = MARKET_BENCHMARKS.get(market_type, [])
    context: dict = {}
    for bm_symbol in benchmarks:
        if bm_symbol == current_symbol:
            continue
        tick = tick_cache.get(bm_symbol)
        if tick:
            context[bm_symbol] = {
                "price": tick.get("price"),
                "change_pct": tick.get("change_pct"),
            }

    # Compute overall market sentiment summary (market breadth)
    up_count = 0
    down_count = 0
    flat_count = 0
    for sym, data in tick_cache.items():
        change = data.get("change_pct")
        if change is not None:
            if change > 0.5:
                up_count += 1
            elif change < -0.5:
                down_count += 1
            else:
                flat_count += 1
    total = up_count + down_count + flat_count
    if total > 0:
        up_pct = up_count / total * 100
        if up_pct > 70:
            mood = "贪婪"
        elif up_pct < 30:
            mood = "恐慌"
        else:
            mood = "中性"
        context["_sentiment"] = f"{up_count}/{total}个市场上涨, {down_count}/{total}个下跌"
        context["_market_breadth"] = {
            "up_pct": round(up_pct, 1),
            "mood": mood,
            "up_count": up_count,
            "down_count": down_count,
            "total": total,
        }

    return context


async def _process_single_market(
    market: Market,
    plugin_manager: PluginManager,
    session: AsyncSession,
    reasoning,
    horizon_hours: int,
    tick_cache: dict,
) -> Optional[Judgment]:
    """Process a single market: fetch data, call AI, record judgment."""
    try:
        # 1. Get tick data (from cache or fetch)
        ds_name = DATA_SOURCE_MAP.get(market.market_type, "binance-rest")
        data_source = plugin_manager.get_data_source(ds_name)

        tick_data = tick_cache.get(market.symbol, {})

        if not tick_data and data_source:
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

        if not tick_data.get("market_type"):
            tick_data["market_type"] = market.market_type

        # 2. Save snapshot
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

        # Skip AI call if no price data
        if tick_data.get("price") is None:
            logger.warning("Skipping AI judgment for %s — no price data", market.symbol)
            return None

        # 3. Fetch historical data for AI context + technical indicators
        history_text = ""
        tech_indicators = {}
        if data_source:
            history_text, tech_indicators = await _fetch_history_for_market(
                data_source, market.symbol, market.market_type
            )

        # Use market-type-specific horizon
        market_horizon = HORIZON_MAP.get(market.market_type, horizon_hours)

        # 3b. Self-evolution: fetch last settled judgment for this market
        last_judgment_ctx = None
        try:
            last_j_stmt = (
                select(Judgment)
                .where(Judgment.market_id == market.id)
                .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
                .options(joinedload(Judgment.settlement))
                .order_by(desc(Judgment.created_at))
                .limit(1)
            )
            last_j_result = await session.execute(last_j_stmt)
            last_j = last_j_result.unique().scalar_one_or_none()
            if last_j and last_j.settlement is not None:
                last_judgment_ctx = {
                    "direction": last_j.direction,
                    "confidence_score": last_j.confidence_score,
                    "reasoning": last_j.reasoning,
                    "is_correct": last_j.settlement.is_correct,
                }
        except Exception:
            logger.debug("Failed to fetch last judgment for %s", market.symbol)

        # 4. Build cross-market context (L2 causal reasoning)
        market_context = await _build_market_context(
            market.market_type, market.symbol, tick_cache
        )

        # 4b. Fetch fear & greed index for crypto markets
        fear_greed_ctx = None
        if market.market_type == "crypto":
            try:
                fg = await get_fear_greed_index()
                if fg:
                    fear_greed_ctx = fg
            except Exception:
                logger.debug("Failed to fetch fear & greed index")

        # 4c. Market breadth sentiment
        market_breadth_ctx = None
        if market_context and "_market_breadth" in market_context:
            market_breadth_ctx = market_context["_market_breadth"]

        # 4d. Load best strategy genome for prompt guidance (L4)
        genome_hint = ""
        try:
            best_genome = await get_best_genome(session)
            if best_genome:
                genome_hint = build_genome_prompt_hint(best_genome)
        except Exception:
            logger.debug("Failed to load strategy genome for %s", market.symbol)

        # 4e. AI consensus
        # 4f. Format technical indicators text
        tech_text = _format_technical_indicators(tech_indicators)

        # 4g. Crypto market cap ranking
        mcap_text = ""
        if market.market_type == "crypto":
            try:
                mcap_data = await _fetch_crypto_mcap_rankings()
                coin_mcap = mcap_data.get(market.symbol)
                if coin_mcap:
                    mcap_text = f"该币种市值排名: 第{coin_mcap['rank']}名 ({coin_mcap['tier']})"
            except Exception:
                logger.debug("Failed to get mcap for %s", market.symbol)

        context = {
            "symbol": market.symbol,
            "market_data": tick_data,
            "horizon_hours": market_horizon,
            "history_text": history_text,
            "tech_indicators_text": tech_text,
            "last_judgment": last_judgment_ctx,
            "market_context": market_context if market_context else None,
            "fear_greed": fear_greed_ctx,
            "market_breadth": market_breadth_ctx,
            "genome_hint": genome_hint,
            "mcap_text": mcap_text,
        }
        ai_result = await reasoning.analyze(context)

        # 5. Calculate deviation
        market_price = tick_data.get("price")
        rational_price = ai_result.get("rational_price")
        deviation_pct = calculate_deviation_pct(
            market_price, rational_price
        ) if market_price else None

        # 5a2. Quality score
        quality_score = compute_quality_score(
            rational_price=rational_price,
            reasoning=ai_result.get("reasoning"),
            confidence_score=ai_result.get("confidence_score", 0.3),
            history_text=history_text,
            market_context=market_context if market_context else None,
        )

        # 5b. Cognitive bias detection (L3)
        bias_flags = []
        try:
            # Fetch recent directions for consensus bias detection
            recent_dirs_stmt = (
                select(Judgment.direction)
                .where(Judgment.market_id == market.id)
                .order_by(desc(Judgment.created_at))
                .limit(10)
            )
            recent_dirs_result = await session.execute(recent_dirs_stmt)
            recent_directions = [r[0] for r in recent_dirs_result.all()]

            bias_flags = detect_all_biases(
                direction=ai_result.get("direction", "flat"),
                confidence_score=ai_result.get("confidence_score", 0.3),
                market_price=market_price or 0,
                rational_price=rational_price,
                change_pct=tick_data.get("change_pct"),
                market_type=market.market_type,
                recent_directions=recent_directions,
            )
            if bias_flags:
                logger.info(
                    "Bias flags for %s: %s",
                    market.symbol,
                    [f["type"] for f in bias_flags],
                )
        except Exception:
            logger.debug("Failed bias detection for %s", market.symbol)

        # 5c. Confidence calibration based on historical accuracy
        raw_confidence = ai_result.get("confidence_score", 0.3)
        calibrated_confidence = raw_confidence
        try:
            acc_stmt = (
                select(AccuracyStat)
                .where(
                    AccuracyStat.market_type == market.market_type,
                    AccuracyStat.period == "all",
                )
                .order_by(desc(AccuracyStat.calculated_at))
                .limit(1)
            )
            acc_result = await session.execute(acc_stmt)
            acc_stat = acc_result.scalar_one_or_none()
            if acc_stat and acc_stat.total_judgments >= 5:
                accuracy = acc_stat.accuracy_pct
                if accuracy > 70:
                    calibrated_confidence = min(1.0, raw_confidence * 1.1)
                elif accuracy < 40:
                    # Gentle dampening — don't crush confidence too much
                    # Map accuracy 0-40% to multiplier 0.8-1.0
                    dampen_factor = 0.8 + (accuracy / 40.0) * 0.2
                    calibrated_confidence = raw_confidence * dampen_factor
                logger.info(
                    "Confidence calibration for %s (%s): %.2f -> %.2f (accuracy=%.1f%%)",
                    market.symbol, market.market_type, raw_confidence,
                    calibrated_confidence, accuracy,
                )
        except Exception:
            logger.debug("Failed confidence calibration for %s", market.symbol)

        # 5d. Low-confidence gate (L4 meta-cognition)
        is_low_confidence = calibrated_confidence < 0.2

        # 6. Record judgment
        now = datetime.utcnow()
        judgment = Judgment(
            id=uuid.uuid4(),
            market_id=market.id,
            snapshot_id=snapshot.id,
            direction=ai_result.get("direction", "flat"),
            confidence=ai_result.get("confidence", "low"),
            confidence_score=round(calibrated_confidence, 3),
            rational_price=rational_price,
            deviation_pct=deviation_pct,
            quality_score=quality_score,
            reasoning=ai_result.get("reasoning"),
            model_votes=ai_result.get("model_votes"),
            up_probability=ai_result.get("up_probability"),
            down_probability=ai_result.get("down_probability"),
            flat_probability=ai_result.get("flat_probability"),
            bias_flags=bias_flags if bias_flags else None,
            is_low_confidence=is_low_confidence,
            horizon_hours=market_horizon,
            expires_at=now + timedelta(hours=market_horizon),
            created_at=now,
        )
        session.add(judgment)
        logger.info(
            "Judgment for %s: %s (%s, %.1f%%)",
            market.symbol,
            ai_result.get("direction"),
            ai_result.get("confidence"),
            ai_result.get("confidence_score", 0) * 100,
        )
        return judgment
    except Exception:
        logger.exception("Failed judgment for market %s", market.symbol)
        return None


async def trigger_judgment_cycle(
    session: AsyncSession,
    plugin_manager: PluginManager,
    symbols: Optional[list[str]] = None,
    horizon_hours: int = 4,
) -> list[Judgment]:
    """Run the full AI judgment cycle for specified or all active markets.

    Steps:
    1. Get target markets
    2. Batch-fetch ticks per data source (group markets by source)
    3. For each market concurrently (semaphore=3): fetch history, call AI, record
    """
    # 1. Get target markets
    cycle_start = time.time()

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

    # 2. Batch-fetch ticks: group markets by data source
    source_groups: dict[str, list[Market]] = defaultdict(list)
    for market in markets:
        ds_name = DATA_SOURCE_MAP.get(market.market_type, "binance-rest")
        source_groups[ds_name].append(market)

    tick_cache: dict[str, dict] = {}
    data_source_errors: dict[str, str] = {}

    async def _batch_fetch_ticks(ds_name: str, group_markets: list[Market]):
        fetch_start = time.time()
        data_source = plugin_manager.get_data_source(ds_name)
        if not data_source:
            data_source_errors[ds_name] = "plugin not found"
            return
        syms = [m.symbol for m in group_markets]
        try:
            ticks = await data_source.fetch_ticks(syms)
            for tick in ticks:
                tick_cache[tick.symbol] = {
                    "price": tick.price,
                    "volume": tick.volume,
                    "change_pct": tick.change_pct,
                    "market_type": next(
                        (m.market_type for m in group_markets if m.symbol == tick.symbol),
                        "unknown",
                    ),
                }
            fetch_duration = time.time() - fetch_start
            logger.info(
                "Data source fetch complete",
                extra={
                    "data_source": ds_name,
                    "symbols_requested": len(syms),
                    "symbols_returned": len(ticks),
                    "duration_sec": round(fetch_duration, 2),
                },
            )
        except Exception as exc:
            data_source_errors[ds_name] = str(exc)
            logger.exception("Batch tick fetch failed for data source %s", ds_name)

    # Fetch ticks in parallel per data source
    await asyncio.gather(
        *[_batch_fetch_ticks(ds, mks) for ds, mks in source_groups.items()],
        return_exceptions=True,
    )
    logger.info("Batch tick fetch complete: %d/%d symbols have data", len(tick_cache), len(markets))

    # 3. Process markets sequentially (SQLAlchemy async session is not safe for concurrent flushes)
    judgments: list[Judgment] = []
    skipped_count = 0

    for market in markets:
        try:
            j = await _process_single_market(
                market, plugin_manager, session, reasoning, horizon_hours, tick_cache
            )
            if j:
                judgments.append(j)
            else:
                skipped_count += 1
        except Exception:
            logger.exception("Error processing market %s", market.symbol)
            skipped_count += 1

    if judgments:
        await session.commit()

    cycle_duration = time.time() - cycle_start
    logger.info(
        "Judgment cycle complete",
        extra={
            "total_markets": len(markets),
            "judgments_created": len(judgments),
            "skipped_no_data": skipped_count,
            "cycle_duration_sec": round(cycle_duration, 2),
            "data_source_errors": data_source_errors,
        },
    )

    return judgments
