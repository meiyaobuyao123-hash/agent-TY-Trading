"""Markets router — CRUD for tracked markets."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.correlations import get_related_symbols
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
    """List all tracked markets with optional filters — single query for snapshots."""
    stmt = select(Market)
    if is_active is not None:
        stmt = stmt.where(Market.is_active == is_active)
    if market_type:
        stmt = stmt.where(Market.market_type == market_type)
    stmt = stmt.order_by(Market.symbol)

    result = await session.execute(stmt)
    markets = result.scalars().all()

    # Batch-fetch latest snapshot per market in ONE query using a subquery
    market_ids = [m.id for m in markets]
    snap_map: dict = {}
    if market_ids:
        # Subquery: max captured_at per market_id
        latest_sub = (
            select(
                MarketSnapshot.market_id,
                func.max(MarketSnapshot.captured_at).label("max_at"),
            )
            .where(MarketSnapshot.market_id.in_(market_ids))
            .group_by(MarketSnapshot.market_id)
            .subquery()
        )
        snap_stmt = (
            select(MarketSnapshot)
            .join(
                latest_sub,
                (MarketSnapshot.market_id == latest_sub.c.market_id)
                & (MarketSnapshot.captured_at == latest_sub.c.max_at),
            )
        )
        snap_result = await session.execute(snap_stmt)
        for snap in snap_result.scalars().all():
            snap_map[snap.market_id] = snap

    out = []
    for m in markets:
        snap = snap_map.get(m.id)
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


@router.get("/{symbol}/snapshots", response_model=list[MarketSnapshotOut])
async def get_market_snapshots(
    symbol: str,
    limit: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> list[MarketSnapshotOut]:
    """Get the last N price snapshots for a market."""
    stmt = select(Market).where(Market.symbol == symbol)
    result = await session.execute(stmt)
    market = result.scalar_one_or_none()
    if not market:
        raise HTTPException(status_code=404, detail=f"Market {symbol} not found")

    snap_stmt = (
        select(MarketSnapshot)
        .where(MarketSnapshot.market_id == market.id)
        .order_by(MarketSnapshot.captured_at.desc())
        .limit(limit)
    )
    snap_result = await session.execute(snap_stmt)
    snaps = snap_result.scalars().all()

    # Return in chronological order (oldest first)
    snaps = list(reversed(snaps))
    return [
        MarketSnapshotOut(
            id=s.id,
            price=s.price,
            volume=s.volume,
            change_pct=s.change_pct,
            captured_at=s.captured_at,
        )
        for s in snaps
    ]


@router.get("/{symbol}/related")
async def get_related_markets(
    symbol: str,
    session: AsyncSession = Depends(get_session),
):
    """Get correlated markets for a given symbol with their latest snapshots."""
    related_symbols = get_related_symbols(symbol)
    if not related_symbols:
        return []

    stmt = select(Market).where(Market.symbol.in_(related_symbols))
    result = await session.execute(stmt)
    markets = result.scalars().all()

    if not markets:
        return []

    # Fetch latest snapshots
    market_ids = [m.id for m in markets]
    from sqlalchemy import func as sqlfunc
    latest_sub = (
        select(
            MarketSnapshot.market_id,
            sqlfunc.max(MarketSnapshot.captured_at).label("max_at"),
        )
        .where(MarketSnapshot.market_id.in_(market_ids))
        .group_by(MarketSnapshot.market_id)
        .subquery()
    )
    snap_stmt = (
        select(MarketSnapshot)
        .join(
            latest_sub,
            (MarketSnapshot.market_id == latest_sub.c.market_id)
            & (MarketSnapshot.captured_at == latest_sub.c.max_at),
        )
    )
    snap_result = await session.execute(snap_stmt)
    snap_map = {s.market_id: s for s in snap_result.scalars().all()}

    out = []
    for m in markets:
        snap = snap_map.get(m.id)
        out.append({
            "symbol": m.symbol,
            "name": m.name,
            "market_type": m.market_type,
            "price": snap.price if snap else None,
            "change_pct": snap.change_pct if snap else None,
        })
    return out


@router.post("/cleanup-inactive", status_code=200)
async def cleanup_inactive_markets(
    session: AsyncSession = Depends(get_session),
):
    """Deactivate markets that have NEVER had a successful price fetch.

    Finds markets where ALL snapshots have price=NULL or no snapshots exist,
    and sets is_active=False.
    """
    # Find all active markets
    active_stmt = select(Market).where(Market.is_active == True)
    result = await session.execute(active_stmt)
    active_markets = result.scalars().all()

    deactivated = []
    for market in active_markets:
        # Check if this market has ANY snapshot with a non-null price
        has_data_stmt = (
            select(func.count())
            .select_from(MarketSnapshot)
            .where(
                MarketSnapshot.market_id == market.id,
                MarketSnapshot.price.isnot(None),
            )
        )
        has_data_result = await session.execute(has_data_stmt)
        count = has_data_result.scalar() or 0

        if count == 0:
            market.is_active = False
            deactivated.append(market.symbol)

    await session.commit()

    return {
        "deactivated_count": len(deactivated),
        "deactivated_symbols": deactivated,
        "message": f"已停用 {len(deactivated)} 个无数据的市场",
    }


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
