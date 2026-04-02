"""AKShare data source — fetches A-share stock data."""

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

# AKShare column name mapping — AKShare may use Chinese or English column names
# depending on the version. We try both.
COLUMN_MAPS = {
    "date": ["日期", "date", "Date"],
    "open": ["开盘", "open", "Open", "开盘价"],
    "high": ["最高", "high", "High", "最高价"],
    "low": ["最低", "low", "Low", "最低价"],
    "close": ["收盘", "close", "Close", "收盘价"],
    "volume": ["成交量", "volume", "Volume", "vol"],
}

# Spot quote column maps
SPOT_COLUMN_MAPS = {
    "code": ["代码", "code", "Code", "symbol"],
    "price": ["最新价", "price", "Price", "last", "最新"],
    "volume": ["成交量", "volume", "Volume", "vol"],
    "change_pct": ["涨跌幅", "change_pct", "pct_chg", "changepercent"],
}


def _find_col(df, candidates: list[str]) -> Optional[str]:
    """Find the first matching column name from candidates."""
    for c in candidates:
        if c in df.columns:
            return c
    return None


class AKShareDataSource(DataSourcePlugin):
    """Fetch A-share and HK stock data via AKShare library."""

    @property
    def name(self) -> str:
        return "akshare-cn"

    @property
    def display_name(self) -> str:
        return "AKShare (A股/港股)"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CN_EQUITIES, MarketType.HK_EQUITIES]

    async def initialize(self, config: dict) -> None:
        pass  # akshare is imported on demand

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        try:
            import akshare as ak
            import asyncio

            loop = asyncio.get_event_loop()

            for symbol in query.symbols:
                try:
                    is_hk = symbol.endswith(".HK")

                    if is_hk:
                        # HK stock: strip .HK suffix, pad to 5 digits
                        clean = symbol.replace(".HK", "").zfill(5)
                    else:
                        # A-share: strip .SH / .SZ suffix
                        clean = symbol.split(".")[0]
                        if not (clean.startswith("0") or clean.startswith("6") or clean.startswith("3")):
                            logger.info("AKShare skipping non A-share symbol: %s", symbol)
                            continue

                    def _fetch_hist(s=clean, hk=is_hk):
                        logger.info("AKShare fetching history for symbol=%s (HK=%s)", s, hk)
                        if hk:
                            df = ak.stock_hk_hist(symbol=s, period="daily", adjust="qfq")
                        else:
                            df = ak.stock_zh_a_hist(symbol=s, period="daily", adjust="qfq")
                        if df is not None:
                            logger.info(
                                "AKShare history for %s: shape=%s, columns=%s",
                                s, df.shape, list(df.columns),
                            )
                            if not df.empty:
                                logger.info("AKShare last row for %s: %s", s, df.tail(1).to_dict("records"))
                        else:
                            logger.warning("AKShare returned None for %s", s)
                        return df

                    df = await loop.run_in_executor(None, _fetch_hist)

                    if df is None or df.empty:
                        logger.warning("AKShare returned empty data for %s", symbol)
                        continue

                    # Dynamic column lookup
                    date_col = _find_col(df, COLUMN_MAPS["date"])
                    open_col = _find_col(df, COLUMN_MAPS["open"])
                    high_col = _find_col(df, COLUMN_MAPS["high"])
                    low_col = _find_col(df, COLUMN_MAPS["low"])
                    close_col = _find_col(df, COLUMN_MAPS["close"])
                    vol_col = _find_col(df, COLUMN_MAPS["volume"])

                    logger.info(
                        "AKShare column mapping for %s: date=%s open=%s high=%s low=%s close=%s vol=%s",
                        symbol, date_col, open_col, high_col, low_col, close_col, vol_col,
                    )

                    if not close_col:
                        logger.error(
                            "AKShare: cannot find close column for %s, available columns: %s",
                            symbol, list(df.columns),
                        )
                        continue

                    candles = []
                    for _, row in df.tail(100).iterrows():
                        # Parse timestamp
                        ts = 0
                        if date_col and date_col in row.index:
                            date_val = row[date_col]
                            if hasattr(date_val, "timestamp"):
                                ts = int(date_val.timestamp() * 1000)
                            else:
                                try:
                                    import pandas as pd
                                    ts = int(pd.Timestamp(str(date_val)).timestamp() * 1000)
                                except Exception:
                                    pass

                        candles.append(
                            OHLCV(
                                timestamp=ts,
                                open=float(row[open_col]) if open_col else 0,
                                high=float(row[high_col]) if high_col else 0,
                                low=float(row[low_col]) if low_col else 0,
                                close=float(row[close_col]) if close_col else 0,
                                volume=float(row[vol_col]) if vol_col else 0,
                            )
                        )

                    mtype = MarketType.HK_EQUITIES if is_hk else MarketType.CN_EQUITIES
                    results.append(
                        MarketData(
                            symbol=symbol,
                            market=mtype,
                            timeframe=query.timeframe,
                            candles=candles,
                        )
                    )
                    logger.info("AKShare successfully fetched %d candles for %s", len(candles), symbol)
                except Exception:
                    logger.exception("AKShare fetch failed for %s", symbol)
        except ImportError:
            logger.warning("akshare not installed — skipping AKShare data source")
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current ticks for A-share and HK symbols."""
        ticks = []
        try:
            import akshare as ak
            import asyncio
            import math

            loop = asyncio.get_event_loop()

            # Split symbols into A-share and HK
            a_share_symbols = [s for s in symbols if not s.endswith(".HK")]
            hk_symbols = [s for s in symbols if s.endswith(".HK")]

            # ── A-share ticks via spot table ──
            if a_share_symbols:
                def _fetch_spot():
                    logger.info("AKShare fetching A-share spot data (stock_zh_a_spot_em)")
                    df = ak.stock_zh_a_spot_em()
                    if df is not None:
                        logger.info("AKShare spot data: shape=%s, columns=%s", df.shape, list(df.columns))
                    else:
                        logger.warning("AKShare spot data returned None")
                    return df

                try:
                    df = await loop.run_in_executor(None, _fetch_spot)
                except Exception:
                    logger.exception("AKShare: failed to fetch A-share spot data")
                    df = None

                if df is not None and not df.empty:
                    code_col = _find_col(df, SPOT_COLUMN_MAPS["code"])
                    price_col = _find_col(df, SPOT_COLUMN_MAPS["price"])
                    vol_col = _find_col(df, SPOT_COLUMN_MAPS["volume"])
                    chg_col = _find_col(df, SPOT_COLUMN_MAPS["change_pct"])

                    if code_col and price_col:
                        for symbol in a_share_symbols:
                            try:
                                clean = symbol.split(".")[0]
                                row = df[df[code_col] == clean]
                                if row.empty:
                                    logger.warning("AKShare: symbol %s not in spot data", symbol)
                                    continue

                                r = row.iloc[0]
                                price = r.get(price_col, 0)
                                volume = r.get(vol_col, 0) if vol_col else 0
                                change_pct = r.get(chg_col, 0) if chg_col else 0

                                if price is None or (isinstance(price, float) and math.isnan(price)):
                                    logger.warning("AKShare: null price for %s, trying history fallback", symbol)
                                    try:
                                        def _fb(s=clean):
                                            h = ak.stock_zh_a_hist(symbol=s, period="daily", adjust="qfq")
                                            if h is not None and not h.empty:
                                                cc = _find_col(h, COLUMN_MAPS["close"])
                                                return float(h.iloc[-1][cc]) if cc else None
                                            return None
                                        price = await loop.run_in_executor(None, _fb)
                                        if not price:
                                            continue
                                    except Exception:
                                        logger.exception("AKShare: fallback failed for %s", symbol)
                                        continue

                                ticks.append(
                                    MarketTick(
                                        symbol=symbol,
                                        price=float(price),
                                        volume=float(volume) if volume else 0,
                                        timestamp=int(time.time() * 1000),
                                        source="akshare",
                                        change_pct=float(change_pct) if change_pct else 0,
                                    )
                                )
                            except Exception:
                                logger.exception("AKShare tick failed for %s", symbol)

            # ── HK ticks via history (faster than full spot table) ──
            for symbol in hk_symbols:
                try:
                    clean = symbol.replace(".HK", "").zfill(5)

                    def _hk_hist(s=clean):
                        logger.info("AKShare fetching HK history tick for %s", s)
                        h = ak.stock_hk_hist(symbol=s, period="daily", adjust="qfq")
                        if h is not None and not h.empty:
                            close_c = _find_col(h, COLUMN_MAPS["close"])
                            chg_c = _find_col(h, ["涨跌幅", "change_pct", "pct_chg"])
                            vol_c = _find_col(h, COLUMN_MAPS["volume"])
                            last = h.iloc[-1]
                            return {
                                "price": float(last[close_c]) if close_c else None,
                                "change_pct": float(last[chg_c]) if chg_c else 0,
                                "volume": float(last[vol_c]) if vol_c else 0,
                            }
                        return None

                    info = await loop.run_in_executor(None, _hk_hist)
                    if info and info.get("price"):
                        ticks.append(
                            MarketTick(
                                symbol=symbol,
                                price=info["price"],
                                volume=info.get("volume", 0),
                                timestamp=int(time.time() * 1000),
                                source="akshare",
                                change_pct=info.get("change_pct", 0),
                            )
                        )
                    else:
                        logger.warning("AKShare: no HK price for %s", symbol)
                except Exception:
                    logger.exception("AKShare HK tick failed for %s", symbol)

        except ImportError:
            logger.warning("akshare not installed")
        return ticks

    async def health_check(self) -> bool:
        try:
            import akshare  # noqa: F401
            return True
        except ImportError:
            return False
