"""Test fixtures — in-memory SQLite async DB + mock plugins."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from backend.core.plugin_manager import PluginManager
from backend.models import Base, Market, MarketSnapshot, Judgment, Settlement

# Use SQLite for tests (in-memory)
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest.fixture(scope="session")
def anyio_backend():
    return "asyncio"


@pytest_asyncio.fixture
async def engine():
    eng = create_async_engine(TEST_DB_URL, echo=False)

    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield eng

    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await eng.dispose()


@pytest_asyncio.fixture
async def session(engine) -> AsyncGenerator[AsyncSession, None]:
    async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with async_session() as sess:
        yield sess


@pytest_asyncio.fixture
async def plugin_manager() -> PluginManager:
    pm = PluginManager()
    return pm


@pytest_asyncio.fixture
async def sample_market(session: AsyncSession) -> Market:
    market = Market(
        id=uuid.uuid4(),
        symbol="BTC-USD",
        name="Bitcoin",
        market_type="crypto",
        source="binance",
        is_active=True,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    session.add(market)
    await session.commit()
    return market


@pytest_asyncio.fixture
async def sample_snapshot(session: AsyncSession, sample_market: Market) -> MarketSnapshot:
    snap = MarketSnapshot(
        id=uuid.uuid4(),
        market_id=sample_market.id,
        price=67000.0,
        volume=1234567.0,
        change_pct=2.5,
        captured_at=datetime.utcnow(),
    )
    session.add(snap)
    await session.commit()
    return snap


@pytest_asyncio.fixture
async def sample_judgment(
    session: AsyncSession, sample_market: Market, sample_snapshot: MarketSnapshot
) -> Judgment:
    j = Judgment(
        id=uuid.uuid4(),
        market_id=sample_market.id,
        snapshot_id=sample_snapshot.id,
        direction="up",
        confidence="high",
        confidence_score=0.85,
        rational_price=68000.0,
        deviation_pct=1.49,
        reasoning="Test reasoning",
        model_votes=[
            {"model_name": "claude", "direction": "up", "confidence": 0.9, "reasoning": "bullish"},
            {"model_name": "gpt-4o", "direction": "up", "confidence": 0.85, "reasoning": "bullish"},
            {"model_name": "gemini", "direction": "up", "confidence": 0.8, "reasoning": "bullish"},
        ],
        horizon_hours=4,
        expires_at=datetime.utcnow() - timedelta(hours=1),  # already expired
        created_at=datetime.utcnow() - timedelta(hours=5),
    )
    session.add(j)
    await session.commit()
    return j


@pytest_asyncio.fixture
async def app_client():
    """Create a test client with mocked dependencies."""
    from unittest.mock import AsyncMock, patch

    # Patch the database session
    from backend.main import create_app
    from backend.database import get_session

    test_app = create_app()

    # Override lifespan to skip real plugin initialization
    pm = PluginManager()
    test_app.state.plugin_manager = pm

    async with AsyncClient(
        transport=ASGITransport(app=test_app), base_url="http://test"
    ) as client:
        yield client
