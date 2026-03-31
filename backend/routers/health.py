"""Health check router."""

from __future__ import annotations

from fastapi import APIRouter, Request

from backend.schemas import HealthResponse

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def health_check(request: Request) -> HealthResponse:
    """Return system health status including plugin health checks."""
    pm = request.app.state.plugin_manager
    plugin_health = await pm.health_check_all()
    return HealthResponse(
        status="ok",
        version="0.1.0",
        plugins=plugin_health,
    )
