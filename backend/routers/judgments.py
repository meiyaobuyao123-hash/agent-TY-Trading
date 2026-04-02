"""Judgments router — query and trigger AI judgments."""

from __future__ import annotations

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from backend.database import get_session
from backend.models import Judgment, Market, Settlement
from backend.schemas import JudgmentOut, JudgmentTriggerRequest, JudgmentTriggerResponse
from backend.services.judgment_service import trigger_judgment_cycle

router = APIRouter(prefix="/judgments", tags=["judgments"])


def _judgment_to_out(j: Judgment, symbol: Optional[str] = None) -> JudgmentOut:
    """Convert a Judgment ORM object to the response schema."""
    return JudgmentOut(
        id=j.id,
        market_id=j.market_id,
        symbol=symbol,
        direction=j.direction,
        confidence=j.confidence,
        confidence_score=j.confidence_score,
        rational_price=j.rational_price,
        deviation_pct=j.deviation_pct,
        reasoning=j.reasoning,
        model_votes=j.model_votes,
        quality_score=j.quality_score if hasattr(j, "quality_score") else None,
        up_probability=j.up_probability if hasattr(j, "up_probability") else None,
        down_probability=j.down_probability if hasattr(j, "down_probability") else None,
        flat_probability=j.flat_probability if hasattr(j, "flat_probability") else None,
        bias_flags=j.bias_flags if hasattr(j, "bias_flags") else None,
        is_low_confidence=j.is_low_confidence if hasattr(j, "is_low_confidence") else False,
        horizon_hours=j.horizon_hours,
        expires_at=j.expires_at,
        created_at=j.created_at,
        is_settled=j.settlement is not None if hasattr(j, "settlement") and j.settlement is not None else False,
        is_correct=j.settlement.is_correct if hasattr(j, "settlement") and j.settlement is not None else None,
    )


@router.get("", response_model=list[JudgmentOut])
async def list_judgments(
    market_type: Optional[str] = Query(None),
    symbol: Optional[str] = Query(None),
    direction: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    session: AsyncSession = Depends(get_session),
) -> list[JudgmentOut]:
    """List judgments with filtering and pagination."""
    stmt = (
        select(Judgment)
        .join(Market, Market.id == Judgment.market_id)
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
    )

    if market_type:
        stmt = stmt.where(Market.market_type == market_type)
    if symbol:
        stmt = stmt.where(Market.symbol == symbol)
    if direction:
        stmt = stmt.where(Judgment.direction == direction)

    stmt = stmt.order_by(Judgment.created_at.desc())
    stmt = stmt.offset((page - 1) * page_size).limit(page_size)

    result = await session.execute(stmt)
    judgments = result.unique().scalars().all()

    # Fetch symbols
    market_ids = {j.market_id for j in judgments}
    if market_ids:
        m_result = await session.execute(
            select(Market).where(Market.id.in_(market_ids))
        )
        market_map = {m.id: m.symbol for m in m_result.scalars().all()}
    else:
        market_map = {}

    return [_judgment_to_out(j, market_map.get(j.market_id)) for j in judgments]


@router.get("/latest", response_model=list[JudgmentOut])
async def latest_judgments(
    brief: bool = Query(False, description="Truncate reasoning to 100 chars for list view"),
    session: AsyncSession = Depends(get_session),
) -> list[JudgmentOut]:
    """Get the latest judgment for each active market — single query."""
    # Subquery: max created_at per market_id (only active markets)
    latest_sub = (
        select(
            Judgment.market_id,
            func.max(Judgment.created_at).label("max_at"),
        )
        .join(Market, Market.id == Judgment.market_id)
        .where(Market.is_active == True)
        .group_by(Judgment.market_id)
        .subquery()
    )

    stmt = (
        select(Judgment)
        .join(
            latest_sub,
            (Judgment.market_id == latest_sub.c.market_id)
            & (Judgment.created_at == latest_sub.c.max_at),
        )
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
        .order_by(Judgment.created_at.desc())
    )
    result = await session.execute(stmt)
    judgments = result.unique().scalars().all()

    # Batch-fetch market symbols
    market_ids = {j.market_id for j in judgments}
    market_map: dict = {}
    if market_ids:
        m_result = await session.execute(
            select(Market).where(Market.id.in_(market_ids))
        )
        market_map = {m.id: m.symbol for m in m_result.scalars().all()}

    out = [_judgment_to_out(j, market_map.get(j.market_id)) for j in judgments]

    # Truncate reasoning for brief mode to reduce response size
    if brief:
        for item in out:
            if item.reasoning and len(item.reasoning) > 100:
                item.reasoning = item.reasoning[:100] + "..."
            # Strip model_votes in brief mode to save bandwidth
            item.model_votes = None

    return out


@router.get("/{judgment_id}", response_model=JudgmentOut)
async def get_judgment(
    judgment_id: UUID,
    session: AsyncSession = Depends(get_session),
) -> JudgmentOut:
    """Get a single judgment by ID."""
    stmt = (
        select(Judgment)
        .where(Judgment.id == judgment_id)
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .options(joinedload(Judgment.settlement))
    )
    result = await session.execute(stmt)
    j = result.unique().scalar_one_or_none()
    if not j:
        raise HTTPException(status_code=404, detail="Judgment not found")

    m_result = await session.execute(
        select(Market).where(Market.id == j.market_id)
    )
    market = m_result.scalar_one_or_none()
    symbol = market.symbol if market else None

    return _judgment_to_out(j, symbol)


_last_trigger_time: float = 0.0


@router.post("/trigger", response_model=JudgmentTriggerResponse)
async def trigger_judgments(
    body: JudgmentTriggerRequest,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> JudgmentTriggerResponse:
    """Manually trigger an AI judgment cycle."""
    import time
    global _last_trigger_time
    now = time.time()
    # Rate limit only for full triggers (no symbols specified)
    if not body.symbols and now - _last_trigger_time < 300:
        raise HTTPException(status_code=429, detail="请等待5分钟后再触发")
    _last_trigger_time = now

    pm = request.app.state.plugin_manager
    judgments = await trigger_judgment_cycle(
        session=session,
        plugin_manager=pm,
        symbols=body.symbols,
        horizon_hours=body.horizon_hours,
    )

    # Fetch symbols for output
    market_ids = {j.market_id for j in judgments}
    if market_ids:
        m_result = await session.execute(
            select(Market).where(Market.id.in_(market_ids))
        )
        market_map = {m.id: m.symbol for m in m_result.scalars().all()}
    else:
        market_map = {}

    return JudgmentTriggerResponse(
        triggered=len(judgments),
        judgments=[_judgment_to_out(j, market_map.get(j.market_id)) for j in judgments],
    )
