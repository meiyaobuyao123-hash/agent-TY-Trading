"""Tests for all 5 data source plugins (with mocked HTTP)."""

from __future__ import annotations

import json
import time

import httpx
import pytest
import pytest_asyncio

from backend.core.types import DataQuery, MarketType, Timeframe


def _mock_response(status_code: int, json_data) -> httpx.Response:
    """Create a properly formed httpx.Response for mocking."""
    request = httpx.Request("GET", "http://mock")
    return httpx.Response(status_code, json=json_data, request=request)


# ── Binance ──────────────────────────────────────────────────────

class TestBinanceDataSource:

    @pytest_asyncio.fixture
    async def plugin(self):
        from backend.plugins.data_sources.binance_ws import BinanceDataSource
        p = BinanceDataSource()
        await p.initialize({})
        yield p
        await p.destroy()

    @pytest.mark.asyncio
    async def test_fetch_ticks_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {
                "lastPrice": "67000.50",
                "volume": "12345.67",
                "priceChangePercent": "2.34",
            })

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        ticks = await plugin.fetch_ticks(["BTC-USD"])
        assert len(ticks) == 1
        assert ticks[0].symbol == "BTC-USD"
        assert ticks[0].price == 67000.50
        assert ticks[0].change_pct == 2.34

    @pytest.mark.asyncio
    async def test_health_check_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {})

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        assert await plugin.health_check() is True

    @pytest.mark.asyncio
    async def test_health_check_failure(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            raise httpx.ConnectError("Connection refused")

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        assert await plugin.health_check() is False

    @pytest.mark.asyncio
    async def test_fetch_mock(self, plugin, monkeypatch):
        kline_data = [
            [int(time.time() * 1000), "67000", "67500", "66500", "67200", "100"],
        ]

        async def mock_get(self, url, **kwargs):
            return _mock_response(200, kline_data)

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        now = int(time.time() * 1000)
        query = DataQuery(
            symbols=["BTC-USD"],
            market=MarketType.CRYPTO,
            timeframe=Timeframe.H1,
            start=now - 3600000,
            end=now,
        )
        results = await plugin.fetch(query)
        assert len(results) == 1
        assert results[0].symbol == "BTC-USD"
        assert len(results[0].candles) == 1

    @pytest.mark.asyncio
    async def test_fetch_ticks_error_graceful(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            raise httpx.ConnectError("fail")

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        ticks = await plugin.fetch_ticks(["BTC-USD"])
        assert len(ticks) == 0


# ── Frankfurter FX ───────────────────────────────────────────────

class TestFrankfurterFXDataSource:

    @pytest_asyncio.fixture
    async def plugin(self):
        from backend.plugins.data_sources.frankfurter_fx import FrankfurterFXDataSource
        p = FrankfurterFXDataSource()
        await p.initialize({})
        yield p
        await p.destroy()

    @pytest.mark.asyncio
    async def test_fetch_ticks_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {
                "rates": {"CNY": 7.24}, "base": "USD", "date": "2026-03-31",
            })

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        ticks = await plugin.fetch_ticks(["USD/CNY"])
        assert len(ticks) == 1
        assert ticks[0].price == 7.24
        assert ticks[0].source == "frankfurter"

    @pytest.mark.asyncio
    async def test_fetch_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {
                "rates": {"CNY": 7.24}, "base": "USD", "date": "2026-03-31",
            })

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        now = int(time.time() * 1000)
        query = DataQuery(
            symbols=["USD/CNY"],
            market=MarketType.FOREX,
            timeframe=Timeframe.D1,
            start=now - 86400000,
            end=now,
        )
        results = await plugin.fetch(query)
        assert len(results) == 1
        assert results[0].candles[0].close == 7.24

    @pytest.mark.asyncio
    async def test_health_check_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {"rates": {}})

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        assert await plugin.health_check() is True

    @pytest.mark.asyncio
    async def test_unknown_pair(self, plugin):
        ticks = await plugin.fetch_ticks(["XXX/YYY"])
        assert len(ticks) == 0


# ── FRED Macro ───────────────────────────────────────────────────

class TestFredMacroDataSource:

    @pytest_asyncio.fixture
    async def plugin(self):
        from backend.plugins.data_sources.fred_macro import FredMacroDataSource
        p = FredMacroDataSource()
        await p.initialize({"fred_api_key": "test-key"})
        yield p
        await p.destroy()

    @pytest.mark.asyncio
    async def test_fetch_ticks_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {
                "observations": [
                    {"date": "2026-03-01", "value": "3.2"},
                    {"date": "2026-02-01", "value": "3.1"},
                ]
            })

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        ticks = await plugin.fetch_ticks(["US-CPI"])
        assert len(ticks) == 1
        assert ticks[0].price == 3.2

    @pytest.mark.asyncio
    async def test_fetch_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {
                "observations": [
                    {"date": "2026-03-01", "value": "3.2"},
                ]
            })

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        now = int(time.time() * 1000)
        query = DataQuery(
            symbols=["US-CPI"],
            market=MarketType.MACRO,
            timeframe=Timeframe.MO1,
            start=now - 86400000 * 30,
            end=now,
        )
        results = await plugin.fetch(query)
        assert len(results) == 1
        assert results[0].candles[0].close == 3.2

    @pytest.mark.asyncio
    async def test_no_api_key(self):
        from backend.plugins.data_sources.fred_macro import FredMacroDataSource
        p = FredMacroDataSource()
        await p.initialize({})
        ticks = await p.fetch_ticks(["US-GDP"])
        assert len(ticks) == 0
        await p.destroy()

    @pytest.mark.asyncio
    async def test_health_check_no_key(self):
        from backend.plugins.data_sources.fred_macro import FredMacroDataSource
        p = FredMacroDataSource()
        await p.initialize({})
        assert await p.health_check() is False
        await p.destroy()

    @pytest.mark.asyncio
    async def test_health_check_with_key(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, {})

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        assert await plugin.health_check() is True


# ── Polymarket ───────────────────────────────────────────────────

class TestPolymarketDataSource:

    @pytest_asyncio.fixture
    async def plugin(self):
        from backend.plugins.data_sources.polymarket_gamma import PolymarketGammaDataSource
        p = PolymarketGammaDataSource()
        await p.initialize({})
        yield p
        await p.destroy()

    @pytest.mark.asyncio
    async def test_fetch_mock(self, plugin, monkeypatch):
        market_data = [
            {
                "slug": "us-2028-election",
                "question": "Who will win the 2028 presidential election?",
                "outcomePrices": json.dumps([0.55, 0.45]),
                "volume": "1234567",
            }
        ]

        async def mock_get(self, url, **kwargs):
            return _mock_response(200, market_data)

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        now = int(time.time() * 1000)
        query = DataQuery(
            symbols=["us-2028-election"],
            market=MarketType.PREDICTION_MARKETS,
            timeframe=Timeframe.D1,
            start=now - 86400000,
            end=now,
        )
        results = await plugin.fetch(query)
        assert len(results) == 1
        assert results[0].candles[0].close == 0.55

    @pytest.mark.asyncio
    async def test_health_check_mock(self, plugin, monkeypatch):
        async def mock_get(self, url, **kwargs):
            return _mock_response(200, [])

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        assert await plugin.health_check() is True

    @pytest.mark.asyncio
    async def test_fetch_ticks_mock(self, plugin, monkeypatch):
        market_data = [
            {
                "slug": "us-2028-election",
                "question": "2028 election",
                "outcomePrices": json.dumps([0.55, 0.45]),
                "volume": "1234567",
            }
        ]

        async def mock_get(self, url, **kwargs):
            return _mock_response(200, market_data)

        monkeypatch.setattr(httpx.AsyncClient, "get", mock_get)
        ticks = await plugin.fetch_ticks(["us-2028-election"])
        assert len(ticks) == 1
        assert ticks[0].price == 0.55


# ── AKShare ──────────────────────────────────────────────────────

class TestAKShareDataSource:

    @pytest_asyncio.fixture
    async def plugin(self):
        from backend.plugins.data_sources.akshare_cn import AKShareDataSource
        p = AKShareDataSource()
        await p.initialize({})
        yield p

    @pytest.mark.asyncio
    async def test_health_check_import(self, plugin):
        result = await plugin.health_check()
        assert isinstance(result, bool)

    @pytest.mark.asyncio
    async def test_fetch_empty_symbols(self, plugin):
        now = int(time.time() * 1000)
        query = DataQuery(
            symbols=[],
            market=MarketType.CN_EQUITIES,
            timeframe=Timeframe.D1,
            start=now - 86400000,
            end=now,
        )
        results = await plugin.fetch(query)
        assert results == []

    @pytest.mark.asyncio
    async def test_plugin_properties(self, plugin):
        assert plugin.name == "akshare-cn"
        assert MarketType.CN_EQUITIES in plugin.markets
