"""Health check router."""

from __future__ import annotations

import time
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from backend.database import get_session
from backend.models import Market, MarketSnapshot
from backend.schemas import HealthResponse

router = APIRouter(tags=["health"])


class EnhancedHealthResponse(BaseModel):
    status: str = "ok"
    version: str = "2.1.0"
    uptime_seconds: int = 0
    last_cycle_time: Optional[str] = None
    total_markets: int = 0
    markets_with_recent_data: int = 0
    memory_mb: Optional[float] = None
    plugins: dict[str, dict[str, bool]] = {}
    data_source_latency: dict[str, dict] = {}


@router.get("/health", response_model=EnhancedHealthResponse)
async def health_check(
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> EnhancedHealthResponse:
    """Return system health status including plugin health checks and system info."""
    pm = request.app.state.plugin_manager
    plugin_health = await pm.health_check_all()

    # Uptime
    start_time = getattr(request.app.state, "start_time", None)
    uptime = int(time.time() - start_time) if start_time else 0

    # Last cycle time
    last_cycle = getattr(request.app.state, "last_cycle_time", None)
    last_cycle_str = None
    if last_cycle is not None:
        last_cycle_str = datetime.utcfromtimestamp(last_cycle).isoformat() + "Z"

    # Total markets
    total_result = await session.execute(
        select(func.count()).select_from(Market).where(Market.is_active == True)
    )
    total_markets = total_result.scalar() or 0

    # Markets with recent data (snapshot < 24h old)
    cutoff = datetime.utcnow() - timedelta(hours=24)
    recent_result = await session.execute(
        select(func.count(func.distinct(MarketSnapshot.market_id))).where(
            MarketSnapshot.captured_at >= cutoff
        )
    )
    markets_with_recent = recent_result.scalar() or 0

    # Memory usage
    memory_mb = None
    try:
        import resource
        usage = resource.getrusage(resource.RUSAGE_SELF)
        memory_mb = round(usage.ru_maxrss / 1024 / 1024, 1)  # macOS: bytes; Linux: KB
    except Exception:
        try:
            import psutil
            proc = psutil.Process()
            memory_mb = round(proc.memory_info().rss / 1024 / 1024, 1)
        except Exception:
            pass

    # Data source latency stats
    ds_latency: dict[str, dict] = {}
    try:
        from backend.services.judgment_service import get_ds_latency_stats
        ds_latency = get_ds_latency_stats()
    except Exception:
        pass

    return EnhancedHealthResponse(
        status="ok",
        version="2.1.0",
        uptime_seconds=uptime,
        last_cycle_time=last_cycle_str,
        total_markets=total_markets,
        markets_with_recent_data=markets_with_recent,
        memory_mb=memory_mb,
        plugins=plugin_health,
        data_source_latency=ds_latency,
    )
