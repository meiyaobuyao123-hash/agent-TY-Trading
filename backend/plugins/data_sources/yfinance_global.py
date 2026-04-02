"""YFinance Global data source — US stocks, global indices, HK stocks, commodities.

Uses stooq.com CSV API as primary (works globally including China),
with yfinance as fallback.
"""

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

# ── Symbol mapping: our symbol -> stooq symbol ──
STOOQ_MAP = {
    # US Stocks (append .US) — existing 35
    "AAPL": "aapl.us", "TSLA": "tsla.us", "NVDA": "nvda.us", "MSFT": "msft.us",
    "GOOGL": "googl.us", "AMZN": "amzn.us", "META": "meta.us", "AMD": "amd.us",
    "INTC": "intc.us", "JPM": "jpm.us", "GS": "gs.us", "BAC": "bac.us",
    "V": "v.us", "MA": "ma.us", "JNJ": "jnj.us", "PFE": "pfe.us",
    "XOM": "xom.us", "CVX": "cvx.us", "WMT": "wmt.us", "COST": "cost.us",
    "HD": "hd.us", "DIS": "dis.us", "NFLX": "nflx.us", "CRM": "crm.us",
    "ORCL": "orcl.us", "CSCO": "csco.us", "QCOM": "qcom.us", "AVGO": "avgo.us",
    "MU": "mu.us", "PYPL": "pypl.us", "SQ": "sq.us", "COIN": "coin.us",
    "PLTR": "pltr.us", "UBER": "uber.us", "ABNB": "abnb.us",
    # US Stocks — Round 9 expansion (tech)
    "SHOP": "shop.us", "SNOW": "snow.us", "NET": "net.us", "DDOG": "ddog.us",
    "ZS": "zs.us", "CRWD": "crwd.us", "PANW": "panw.us",
    # US Stocks — healthcare
    "ABBV": "abbv.us", "LLY": "lly.us", "UNH": "unh.us", "MRK": "mrk.us",
    "TMO": "tmo.us",
    # US Stocks — energy
    "SLB": "slb.us", "EOG": "eog.us", "OXY": "oxy.us",
    # US Stocks — consumer
    "SBUX": "sbux.us", "NKE": "nke.us", "MCD": "mcd.us", "KO": "ko.us",
    "PEP": "pep.us",
    # US Stocks — financials
    "BRK-B": "brk-b.us", "C": "c.us", "WFC": "wfc.us", "AXP": "axp.us",
    "BLK": "blk.us", "SCHW": "schw.us",
    # ETFs
    "SPY": "spy.us", "QQQ": "qqq.us", "IWM": "iwm.us", "DIA": "dia.us",
    "GLD": "gld.us", "SLV": "slv.us", "USO": "uso.us", "TLT": "tlt.us",
    "HYG": "hyg.us", "EEM": "eem.us", "VWO": "vwo.us", "FXI": "fxi.us",
    # HK Stocks (append .HK)
    "0700.HK": "0700.hk", "9988.HK": "9988.hk", "3690.HK": "3690.hk",
    "9618.HK": "9618.hk", "1810.HK": "1810.hk", "2318.HK": "2318.hk",
    "0005.HK": "0005.hk", "1299.HK": "1299.hk", "9888.HK": "9888.hk",
    "0941.HK": "0941.hk",
    # Global Indices
    "SPX": "^spx", "IXIC": "^ndq", "DJI": "^dji",
    "HSI": "^hsi", "N225": "^nkx", "FTSE": "^ukx",
    "DAX": "^dax", "CAC40": "^cac", "ASX200": "^xjo",
    # Commodities
    "GOLD": "gc.f", "OIL": "cl.f", "SILVER": "si.f",
    "NATGAS": "ng.f", "COPPER": "hg.f",
    # R12 expansion — more commodities
    "PLATINUM": "pl.f", "PALLADIUM": "pa.f",
    "WHEAT": "zw.f", "CORN": "zc.f", "SOYBEANS": "zs.f",
    "COFFEE": "kc.f", "COTTON": "ct.f",
    # R15 — Japanese stocks
    "7203.JP": "7203.jp", "6758.JP": "6758.jp", "6861.JP": "6861.jp",
    "9984.JP": "9984.jp", "8306.JP": "8306.jp",
    # R15 — European stocks
    "SAP.DE": "sap.de", "SIE.DE": "sie.de", "BMW.DE": "bmw.de",
    "ASML.NL": "asml.nl", "MC.PA": "mc.fr", "TTE.PA": "tte.fr",
    # R17 — Korean stocks
    "005930.KR": "005930.kr", "000660.KR": "000660.kr", "373220.KR": "373220.kr",
    "005380.KR": "005380.kr", "035420.KR": "035420.kr",
    # R17 — Indian stocks
    "RELIANCE.IN": "reliance.in", "TCS.IN": "tcs.in", "INFY.IN": "infy.in",
    "HDFCBANK.IN": "hdfcbank.in", "BHARTIARTL.IN": "bhartiartl.in",
}

# yfinance symbol map (fallback)
YFINANCE_MAP = {
    "AAPL": "AAPL", "TSLA": "TSLA", "NVDA": "NVDA", "MSFT": "MSFT",
    "GOOGL": "GOOGL", "AMZN": "AMZN", "META": "META", "AMD": "AMD",
    "INTC": "INTC", "JPM": "JPM", "GS": "GS", "BAC": "BAC",
    "V": "V", "MA": "MA", "JNJ": "JNJ", "PFE": "PFE",
    "XOM": "XOM", "CVX": "CVX", "WMT": "WMT", "COST": "COST",
    "HD": "HD", "DIS": "DIS", "NFLX": "NFLX", "CRM": "CRM",
    "ORCL": "ORCL", "CSCO": "CSCO", "QCOM": "QCOM", "AVGO": "AVGO",
    "MU": "MU", "PYPL": "PYPL", "SQ": "SQ", "COIN": "COIN",
    "PLTR": "PLTR", "UBER": "UBER", "ABNB": "ABNB",
    # Round 9 expansion
    "SHOP": "SHOP", "SNOW": "SNOW", "NET": "NET", "DDOG": "DDOG",
    "ZS": "ZS", "CRWD": "CRWD", "PANW": "PANW",
    "ABBV": "ABBV", "LLY": "LLY", "UNH": "UNH", "MRK": "MRK", "TMO": "TMO",
    "SLB": "SLB", "EOG": "EOG", "OXY": "OXY",
    "SBUX": "SBUX", "NKE": "NKE", "MCD": "MCD", "KO": "KO", "PEP": "PEP",
    "BRK-B": "BRK-B", "C": "C", "WFC": "WFC", "AXP": "AXP",
    "BLK": "BLK", "SCHW": "SCHW",
    # ETFs
    "SPY": "SPY", "QQQ": "QQQ", "IWM": "IWM", "DIA": "DIA",
    "GLD": "GLD", "SLV": "SLV", "USO": "USO", "TLT": "TLT",
    "HYG": "HYG", "EEM": "EEM", "VWO": "VWO", "FXI": "FXI",
    # HK
    "0700.HK": "0700.HK", "9988.HK": "9988.HK", "3690.HK": "3690.HK",
    "9618.HK": "9618.HK", "1810.HK": "1810.HK", "2318.HK": "2318.HK",
    "0005.HK": "0005.HK", "1299.HK": "1299.HK", "9888.HK": "9888.HK",
    "0941.HK": "0941.HK",
    "SPX": "^GSPC", "IXIC": "^IXIC", "DJI": "^DJI",
    "HSI": "^HSI", "N225": "^N225", "FTSE": "^FTSE",
    "DAX": "^GDAXI", "CAC40": "^FCHI", "ASX200": "^AXJO",
    "GOLD": "GC=F", "OIL": "CL=F", "SILVER": "SI=F",
    "NATGAS": "NG=F", "COPPER": "HG=F",
    # R12 expansion
    "PLATINUM": "PL=F", "PALLADIUM": "PA=F",
    "WHEAT": "ZW=F", "CORN": "ZC=F", "SOYBEANS": "ZS=F",
    "COFFEE": "KC=F", "COTTON": "CT=F",
    # R15 — Japanese stocks
    "7203.JP": "7203.T", "6758.JP": "6758.T", "6861.JP": "6861.T",
    "9984.JP": "9984.T", "8306.JP": "8306.T",
    # R15 — European stocks
    "SAP.DE": "SAP.DE", "SIE.DE": "SIE.DE", "BMW.DE": "BMW.DE",
    "ASML.NL": "ASML.AS", "MC.PA": "MC.PA", "TTE.PA": "TTE.PA",
    # R17 — Korean stocks
    "005930.KR": "005930.KS", "000660.KR": "000660.KS", "373220.KR": "373220.KS",
    "005380.KR": "005380.KS", "035420.KR": "035420.KS",
    # R17 — Indian stocks
    "RELIANCE.IN": "RELIANCE.NS", "TCS.IN": "TCS.NS", "INFY.IN": "INFY.NS",
    "HDFCBANK.IN": "HDFCBANK.NS", "BHARTIARTL.IN": "BHARTIARTL.NS",
}

# Market type classification
US_STOCKS = {
    "AAPL", "TSLA", "NVDA", "MSFT", "GOOGL", "AMZN", "META", "AMD", "INTC",
    "JPM", "GS", "BAC", "V", "MA", "JNJ", "PFE", "XOM", "CVX", "WMT",
    "COST", "HD", "DIS", "NFLX", "CRM", "ORCL", "CSCO", "QCOM", "AVGO",
    "MU", "PYPL", "SQ", "COIN", "PLTR", "UBER", "ABNB",
    # Round 9 expansion
    "SHOP", "SNOW", "NET", "DDOG", "ZS", "CRWD", "PANW",
    "ABBV", "LLY", "UNH", "MRK", "TMO",
    "SLB", "EOG", "OXY",
    "SBUX", "NKE", "MCD", "KO", "PEP",
    "BRK-B", "C", "WFC", "AXP", "BLK", "SCHW",
}
ETFS = {
    "SPY", "QQQ", "IWM", "DIA", "GLD", "SLV", "USO", "TLT",
    "HYG", "EEM", "VWO", "FXI",
}
HK_STOCKS = {
    "0700.HK", "9988.HK", "3690.HK", "9618.HK", "1810.HK",
    "2318.HK", "0005.HK", "1299.HK", "9888.HK", "0941.HK",
}
INDICES = {"SPX", "IXIC", "DJI", "HSI", "N225", "FTSE", "DAX", "CAC40", "ASX200"}
COMMODITIES = {
    "GOLD", "OIL", "SILVER", "NATGAS", "COPPER",
    "PLATINUM", "PALLADIUM", "WHEAT", "CORN", "SOYBEANS", "COFFEE", "COTTON",
}
JP_STOCKS = {"7203.JP", "6758.JP", "6861.JP", "9984.JP", "8306.JP"}
EU_STOCKS = {"SAP.DE", "SIE.DE", "BMW.DE", "ASML.NL", "MC.PA", "TTE.PA"}
KR_STOCKS = {"005930.KR", "000660.KR", "373220.KR", "005380.KR", "035420.KR"}
IN_STOCKS = {"RELIANCE.IN", "TCS.IN", "INFY.IN", "HDFCBANK.IN", "BHARTIARTL.IN"}


def _market_type_for(symbol: str) -> MarketType:
    if symbol in ETFS:
        return MarketType.ETF
    if symbol in US_STOCKS:
        return MarketType.US_EQUITIES
    if symbol in HK_STOCKS:
        return MarketType.HK_EQUITIES
    if symbol in JP_STOCKS:
        return MarketType.JP_EQUITIES
    if symbol in EU_STOCKS:
        return MarketType.EU_EQUITIES
    if symbol in KR_STOCKS:
        return MarketType.KR_EQUITIES
    if symbol in IN_STOCKS:
        return MarketType.IN_EQUITIES
    if symbol in INDICES:
        return MarketType.GLOBAL_INDICES
    if symbol in COMMODITIES:
        return MarketType.COMMODITIES
    return MarketType.US_EQUITIES


STOOQ_BASE = "https://stooq.com/q/l/"


class YFinanceDataSource(DataSourcePlugin):
    """Fetch US stocks, HK stocks, global indices, and commodities.

    Primary: stooq.com CSV API (no auth, works globally).
    Fallback: yfinance library.
    """

    @property
    def name(self) -> str:
        return "yfinance-global"

    @property
    def display_name(self) -> str:
        return "YFinance (美股/港股/指数/大宗商品)"

    @property
    def markets(self) -> list[MarketType]:
        return [
            MarketType.US_EQUITIES,
            MarketType.HK_EQUITIES,
            MarketType.JP_EQUITIES,
            MarketType.EU_EQUITIES,
            MarketType.KR_EQUITIES,
            MarketType.IN_EQUITIES,
            MarketType.GLOBAL_INDICES,
            MarketType.COMMODITIES,
        ]

    async def initialize(self, config: dict) -> None:
        self._client = httpx.AsyncClient(
            timeout=15,
            headers={"User-Agent": "Mozilla/5.0 (compatible; TY-Backend/1.0)"},
        )

    async def _fetch_stooq_tick(self, symbol: str) -> Optional[dict]:
        """Fetch a single tick from stooq.com CSV API with retry on disconnect."""
        import asyncio as _aio

        stooq_sym = STOOQ_MAP.get(symbol)
        if not stooq_sym:
            return None

        max_retries = 2
        for attempt in range(max_retries + 1):
            try:
                # f= fields: s=symbol d2=date t2=time o=open h=high l=low c=close v=volume
                resp = await self._client.get(
                    STOOQ_BASE,
                    params={"s": stooq_sym, "f": "sd2t2ohlcv", "h": "", "e": "csv"},
                    follow_redirects=True,
                )
                resp.raise_for_status()
                lines = resp.text.strip().split("\n")
                if len(lines) < 2:
                    return None

                # Parse CSV header and data
                header = [h.strip().lower() for h in lines[0].split(",")]
                values = [v.strip() for v in lines[1].split(",")]
                row = dict(zip(header, values))

                close_val = row.get("close", "")
                if not close_val or close_val == "N/D":
                    logger.warning("Stooq returned N/D for %s (%s)", symbol, stooq_sym)
                    return None

                return {
                    "price": float(close_val),
                    "open": float(row.get("open", 0) or 0),
                    "high": float(row.get("high", 0) or 0),
                    "low": float(row.get("low", 0) or 0),
                    "volume": float(row.get("volume", 0) or 0),
                    "date": row.get("date", ""),
                }
            except (httpx.RemoteProtocolError, httpx.ReadError, httpx.ConnectError) as exc:
                if attempt < max_retries:
                    wait = 0.5 * (attempt + 1)
                    logger.warning(
                        "Stooq connection error for %s (attempt %d/%d), retrying in %.1fs: %s",
                        symbol, attempt + 1, max_retries + 1, wait, exc,
                    )
                    await _aio.sleep(wait)
                else:
                    logger.error("Stooq fetch failed after %d attempts for %s (%s)", max_retries + 1, symbol, stooq_sym)
                    return None
            except Exception:
                logger.exception("Stooq fetch failed for %s (%s)", symbol, stooq_sym)
                return None
        return None

    async def _fetch_stooq_history(self, symbol: str) -> Optional[list[dict]]:
        """Fetch historical daily data from stooq.com."""
        stooq_sym = STOOQ_MAP.get(symbol)
        if not stooq_sym:
            return None
        try:
            resp = await self._client.get(
                "https://stooq.com/q/d/l/",
                params={"s": stooq_sym, "i": "d"},
                follow_redirects=True,
            )
            resp.raise_for_status()
            lines = resp.text.strip().split("\n")
            if len(lines) < 2:
                return None

            header = [h.strip().lower() for h in lines[0].split(",")]
            rows = []
            for line in lines[1:]:
                vals = [v.strip() for v in line.split(",")]
                if len(vals) < len(header):
                    continue
                row = dict(zip(header, vals))
                try:
                    close_val = row.get("close", "")
                    if not close_val or close_val == "N/D":
                        continue
                    rows.append({
                        "date": row.get("date", ""),
                        "open": float(row.get("open", 0) or 0),
                        "high": float(row.get("high", 0) or 0),
                        "low": float(row.get("low", 0) or 0),
                        "close": float(close_val),
                        "volume": float(row.get("volume", 0) or 0),
                    })
                except (ValueError, TypeError):
                    continue
            return rows[-100:] if rows else None  # last 100 days
        except Exception:
            logger.exception("Stooq history fetch failed for %s", symbol)
            return None

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        results = []
        for symbol in query.symbols:
            try:
                rows = await self._fetch_stooq_history(symbol)
                if not rows:
                    logger.warning("No history data for %s", symbol)
                    continue

                candles = []
                for row in rows:
                    ts = 0
                    if row.get("date"):
                        try:
                            from datetime import datetime
                            dt = datetime.strptime(row["date"], "%Y-%m-%d")
                            ts = int(dt.timestamp() * 1000)
                        except Exception:
                            pass
                    candles.append(
                        OHLCV(
                            timestamp=ts,
                            open=row["open"],
                            high=row["high"],
                            low=row["low"],
                            close=row["close"],
                            volume=row["volume"],
                        )
                    )

                results.append(
                    MarketData(
                        symbol=symbol,
                        market=_market_type_for(symbol),
                        timeframe=query.timeframe,
                        candles=candles,
                    )
                )
            except Exception:
                logger.exception("Fetch failed for %s", symbol)
        return results

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Fetch current price ticks for given symbols via stooq.com."""
        import asyncio as _aio

        ticks = []
        for idx, symbol in enumerate(symbols):
            try:
                # Rate limit: small delay between requests to avoid server disconnects
                if idx > 0 and idx % 5 == 0:
                    await _aio.sleep(0.3)
                data = await self._fetch_stooq_tick(symbol)
                if data and data.get("price"):
                    # Compute change_pct from history if available
                    change_pct = 0.0
                    if data.get("open") and data["open"] > 0:
                        change_pct = ((data["price"] - data["open"]) / data["open"]) * 100

                    ticks.append(
                        MarketTick(
                            symbol=symbol,
                            price=data["price"],
                            volume=data.get("volume", 0),
                            timestamp=int(time.time() * 1000),
                            source="stooq",
                            change_pct=change_pct,
                        )
                    )
                else:
                    logger.warning("No tick data for %s from stooq", symbol)

                    # Fallback: try yfinance (may work from non-China IPs)
                    yf_tick = await self._yfinance_fallback_tick(symbol)
                    if yf_tick:
                        ticks.append(yf_tick)
            except Exception:
                logger.exception("Tick fetch failed for %s", symbol)
        return ticks

    async def _yfinance_fallback_tick(self, symbol: str) -> Optional[MarketTick]:
        """Fallback: try yfinance library for a single symbol."""
        try:
            import yfinance as yf
            import asyncio

            yf_ticker = YFINANCE_MAP.get(symbol, symbol)
            loop = asyncio.get_event_loop()

            def _get():
                t = yf.Ticker(yf_ticker)
                h = t.history(period="2d", interval="1d")
                if h is not None and not h.empty:
                    price = float(h.iloc[-1]["Close"])
                    vol = float(h.iloc[-1].get("Volume", 0))
                    prev = float(h.iloc[-2]["Close"]) if len(h) >= 2 else price
                    chg = ((price - prev) / prev * 100) if prev else 0
                    return {"price": price, "volume": vol, "change_pct": chg}
                return None

            info = await loop.run_in_executor(None, _get)
            if info and info.get("price"):
                return MarketTick(
                    symbol=symbol,
                    price=info["price"],
                    volume=info.get("volume", 0),
                    timestamp=int(time.time() * 1000),
                    source="yfinance",
                    change_pct=info.get("change_pct", 0),
                )
        except Exception:
            logger.debug("yfinance fallback also failed for %s", symbol)
        return None

    async def health_check(self) -> bool:
        """Check if stooq.com is reachable."""
        try:
            resp = await self._client.get(
                STOOQ_BASE,
                params={"s": "aapl.us", "f": "sc", "h": "", "e": "csv"},
                follow_redirects=True,
            )
            return resp.status_code == 200
        except Exception:
            return False

    async def destroy(self) -> None:
        await self._client.aclose()
