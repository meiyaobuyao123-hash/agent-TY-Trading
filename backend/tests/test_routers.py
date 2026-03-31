"""Tests for API routers — health, markets, judgments, accuracy."""

from __future__ import annotations

import uuid
from contextlib import asynccontextmanager
from datetime import datetime

import pytest
import pytest_asyncio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from backend.core.plugin_manager import PluginManager
from backend.models import Base, Market

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


def _create_test_app(session_maker, pm: PluginManager) -> FastAPI:
    """Build a minimal FastAPI app wired to the test DB."""
    from backend.database import get_session
    from backend.routers.health import router as health_router
    from backend.routers.markets import router as markets_router
    from backend.routers.judgments import router as judgments_router
    from backend.routers.accuracy import router as accuracy_router

    @asynccontextmanager
    async def _noop_lifespan(app):
        yield

    app = FastAPI(lifespan=_noop_lifespan)
    app.state.plugin_manager = pm

    async def override_get_session():
        async with session_maker() as sess:
            yield sess

    app.dependency_overrides[get_session] = override_get_session

    app.include_router(health_router)
    app.include_router(markets_router)
    app.include_router(judgments_router)
    app.include_router(accuracy_router)
    return app


@pytest_asyncio.fixture
async def test_app():
    """Create a test app with in-memory DB."""
    engine = create_async_engine(TEST_DB_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_maker = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    pm = PluginManager()

    app = _create_test_app(session_maker, pm)

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        yield client, session_maker

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


class TestHealthRouter:

    @pytest.mark.asyncio
    async def test_health(self, test_app):
        client, _ = test_app
        resp = await client.get("/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert "version" in data


class TestMarketsRouter:

    @pytest.mark.asyncio
    async def test_list_markets_empty(self, test_app):
        client, _ = test_app
        resp = await client.get("/markets")
        assert resp.status_code == 200
        assert resp.json() == []

    @pytest.mark.asyncio
    async def test_create_market(self, test_app):
        client, _ = test_app
        resp = await client.post("/markets", json={
            "symbol": "BTC-USD",
            "name": "Bitcoin",
            "market_type": "crypto",
            "source": "binance",
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["symbol"] == "BTC-USD"
        assert data["is_active"] is True

    @pytest.mark.asyncio
    async def test_create_duplicate_market(self, test_app):
        client, _ = test_app
        body = {
            "symbol": "ETH-USD",
            "name": "Ethereum",
            "market_type": "crypto",
            "source": "binance",
        }
        await client.post("/markets", json=body)
        resp = await client.post("/markets", json=body)
        assert resp.status_code == 409

    @pytest.mark.asyncio
    async def test_get_market_by_symbol(self, test_app):
        client, _ = test_app
        await client.post("/markets", json={
            "symbol": "USD-CNY",
            "name": "Dollar/Yuan",
            "market_type": "forex",
            "source": "frankfurter",
        })
        resp = await client.get("/markets/USD-CNY")
        assert resp.status_code == 200
        assert resp.json()["symbol"] == "USD-CNY"

    @pytest.mark.asyncio
    async def test_get_market_not_found(self, test_app):
        client, _ = test_app
        resp = await client.get("/markets/NONEXISTENT")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_filter_by_market_type(self, test_app):
        client, _ = test_app
        await client.post("/markets", json={
            "symbol": "SOL-USD", "name": "Solana", "market_type": "crypto", "source": "binance",
        })
        resp = await client.get("/markets?market_type=crypto")
        assert resp.status_code == 200
        data = resp.json()
        for m in data:
            assert m["market_type"] == "crypto"


class TestJudgmentsRouter:

    @pytest.mark.asyncio
    async def test_list_judgments_empty(self, test_app):
        client, _ = test_app
        resp = await client.get("/judgments")
        assert resp.status_code == 200
        assert resp.json() == []

    @pytest.mark.asyncio
    async def test_latest_judgments_empty(self, test_app):
        client, _ = test_app
        resp = await client.get("/judgments/latest")
        assert resp.status_code == 200
        assert resp.json() == []

    @pytest.mark.asyncio
    async def test_get_judgment_not_found(self, test_app):
        client, _ = test_app
        fake_id = str(uuid.uuid4())
        resp = await client.get(f"/judgments/{fake_id}")
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_trigger_no_reasoning_plugin(self, test_app):
        client, _ = test_app
        resp = await client.post("/judgments/trigger", json={"symbols": ["BTC-USD"]})
        assert resp.status_code == 200
        data = resp.json()
        assert data["triggered"] == 0


class TestAccuracyRouter:

    @pytest.mark.asyncio
    async def test_get_accuracy_empty(self, test_app):
        client, _ = test_app
        resp = await client.get("/accuracy")
        assert resp.status_code == 200
        assert resp.json() == []

    @pytest.mark.asyncio
    async def test_get_calibration(self, test_app):
        client, _ = test_app
        resp = await client.get("/accuracy/calibration")
        assert resp.status_code == 200
        data = resp.json()
        assert "points" in data
        assert len(data["points"]) == 5  # 5 confidence buckets

    @pytest.mark.asyncio
    async def test_get_accuracy_by_market_type(self, test_app):
        client, _ = test_app
        resp = await client.get("/accuracy/crypto")
        assert resp.status_code == 200
        assert resp.json() == []
