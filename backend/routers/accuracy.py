"""Accuracy router — query accuracy statistics and calibration data."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from backend.database import get_session
from backend.schemas import AccuracyStatOut, CalibrationPoint, CalibrationResponse
from backend.services.accuracy_service import get_accuracy_stats, get_calibration_data

router = APIRouter(prefix="/accuracy", tags=["accuracy"])


@router.get("", response_model=list[AccuracyStatOut])
async def get_accuracy(
    period: str = Query("all"),
    session: AsyncSession = Depends(get_session),
) -> list[AccuracyStatOut]:
    """Get accuracy stats across all market types."""
    stats = await get_accuracy_stats(session, period=period)
    return [AccuracyStatOut.model_validate(s) for s in stats]


@router.get("/calibration", response_model=CalibrationResponse)
async def get_calibration(
    market_type: Optional[str] = Query(None),
    session: AsyncSession = Depends(get_session),
) -> CalibrationResponse:
    """Get calibration curve data."""
    points = await get_calibration_data(session, market_type=market_type)
    return CalibrationResponse(
        points=[CalibrationPoint(**p) for p in points]
    )


@router.get("/{market_type}", response_model=list[AccuracyStatOut])
async def get_accuracy_by_market(
    market_type: str,
    period: str = Query("all"),
    session: AsyncSession = Depends(get_session),
) -> list[AccuracyStatOut]:
    """Get accuracy stats for a specific market type."""
    stats = await get_accuracy_stats(session, market_type=market_type, period=period)
    return [AccuracyStatOut.model_validate(s) for s in stats]
