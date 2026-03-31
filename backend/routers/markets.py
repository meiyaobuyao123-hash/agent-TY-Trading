"""Markets router — CRUD for tracked markets."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.database import get_session
from backend.models import Market, MarketSnapshot
from backend.schemas import MarketCreate, MarketOut, MarketSnapshotOut

router = APIRouter(prefix="/markets", tags=["markets"])


@router.get("", response_model=list[MarketOut])
async def list_markets(
    is_active: Optional[bool] = Query(None),
    market_type: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_session),
) -> list[MarketOut]:
    """List all tracked markets with optional filters."""
    stmt = select(Market)
    if is_active is not None:
        stmt = stmt.where(Market.is_active == is_active)
    if market_type:
        stmt = stmt.where(Market.market_type == market_type)
    stmt = stmt.order_by(Market.symbol)

    result = await session.execute(stmt)
    markets = result.scalars().all()

    out = []
    for m in markets:
        # Get latest snapshot
        snap_stmt = (
            select(MarketSnapshot)
            .where(MarketSnapshot.market_id == m.id)
            .order_by(MarketSnapshot.captured_at.desc())
            .limit(1)
        )
        snap_result = await session.execute(snap_stmt)
        snap = snap_result.scalar_one_or_none()

        latest = None
        if snap:
            latest = MarketSnapshotOut(
                id=snap.id,
                price=snap.price,
                volume=snap.volume,
                change_pct=snap.change_pct,
                captured_at=snap.captured_at,
            )

        out.append(
            MarketOut(
                id=m.id,
                symbol=m.symbol,
                name=m.name,
                market_type=m.market_type,
                source=m.source,
                is_active=m.is_active,
                created_at=m.created_at,
                latest_snapshot=latest,
            )
        )
    return out


@router.get("/{symbol}", response_model=MarketOut)
async def get_market(
    symbol: str,
    session: AsyncSession = Depends(get_session),
) -> MarketOut:
    """Get a single market by symbol."""
    stmt = select(Market).where(Market.symbol == symbol)
    result = await session.execute(stmt)
    market = result.scalar_one_or_none()
    if not market:
        raise HTTPException(status_code=404, detail=f"Market {symbol} not found")

    snap_stmt = (
        select(MarketSnapshot)
        .where(MarketSnapshot.market_id == market.id)
        .order_by(MarketSnapshot.captured_at.desc())
        .limit(1)
    )
    snap_result = await session.execute(snap_stmt)
    snap = snap_result.scalar_one_or_none()

    latest = None
    if snap:
        latest = MarketSnapshotOut(
            id=snap.id,
            price=snap.price,
            volume=snap.volume,
            change_pct=snap.change_pct,
            captured_at=snap.captured_at,
        )

    return MarketOut(
        id=market.id,
        symbol=market.symbol,
        name=market.name,
        market_type=market.market_type,
        source=market.source,
        is_active=market.is_active,
        created_at=market.created_at,
        latest_snapshot=latest,
    )


@router.post("", response_model=MarketOut, status_code=201)
async def create_market(
    body: MarketCreate,
    session: AsyncSession = Depends(get_session),
) -> MarketOut:
    """Create a new tracked market."""
    # Check for duplicate
    existing = await session.execute(
        select(Market).where(Market.symbol == body.symbol)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail=f"Market {body.symbol} already exists")

    market = Market(
        id=uuid.uuid4(),
        symbol=body.symbol,
        name=body.name,
        market_type=body.market_type,
        source=body.source,
        is_active=body.is_active,
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )
    session.add(market)
    await session.commit()

    return MarketOut(
        id=market.id,
        symbol=market.symbol,
        name=market.name,
        market_type=market.market_type,
        source=market.source,
        is_active=market.is_active,
        created_at=market.created_at,
    )
