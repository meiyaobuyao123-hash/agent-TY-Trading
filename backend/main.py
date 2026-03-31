"""FastAPI application entry point for Project TY (天演)."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.config import settings
from backend.core.plugin_manager import PluginManager
from backend.core.scheduler import create_scheduler, register_jobs

# Plugins
from backend.plugins.data_sources.binance_ws import BinanceDataSource
from backend.plugins.data_sources.akshare_cn import AKShareDataSource
from backend.plugins.data_sources.fred_macro import FredMacroDataSource
from backend.plugins.data_sources.frankfurter_fx import FrankfurterFXDataSource
from backend.plugins.data_sources.polymarket_gamma import PolymarketGammaDataSource
from backend.plugins.reasoning.ai_consensus import AIConsensusPlugin
from backend.plugins.bias_detectors.deviation_calc import DeviationCalculator
from backend.plugins.evolution.accuracy_tracker import AccuracyTrackerPlugin

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan: initialize DB, plugins, scheduler on startup; clean up on shutdown."""
    logger.info("Starting TY backend...")

    # ── Plugin Manager ──
    pm = PluginManager()

    # Register data sources
    pm.register_data_source(BinanceDataSource())
    pm.register_data_source(AKShareDataSource())
    pm.register_data_source(FredMacroDataSource())
    pm.register_data_source(FrankfurterFXDataSource())
    pm.register_data_source(PolymarketGammaDataSource())

    # Register reasoning
    pm.register_reasoning(AIConsensusPlugin())

    # Register bias detector
    pm.register_bias_detector(DeviationCalculator())

    # Register evolution
    pm.register_evolution(AccuracyTrackerPlugin())

    # Initialize all plugins
    config = {
        "fred_api_key": settings.FRED_API_KEY,
    }
    await pm.initialize_all(config)
    app.state.plugin_manager = pm

    # ── Scheduler ──
    if settings.SCHEDULER_ENABLED:
        scheduler = create_scheduler()

        async def _judgment_cycle():
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.services.judgment_service import trigger_judgment_cycle
                await trigger_judgment_cycle(session, pm)

        async def _settlement():
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.plugins.evolution.accuracy_tracker import settle_judgments
                await settle_judgments(session)

        async def _accuracy():
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.plugins.evolution.accuracy_tracker import recalculate_accuracy
                await recalculate_accuracy(session)

        register_jobs(scheduler, _judgment_cycle, _settlement, _accuracy)
        scheduler.start()
        app.state.scheduler = scheduler
        logger.info("Scheduler started with %d jobs", len(scheduler.get_jobs()))

    logger.info("TY backend started successfully")
    yield

    # ── Shutdown ──
    logger.info("Shutting down TY backend...")
    if hasattr(app.state, "scheduler"):
        app.state.scheduler.shutdown(wait=False)
    await pm.destroy_all()
    logger.info("TY backend shut down")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    app = FastAPI(
        title="Project TY (天演) API",
        description="AI Financial World Model — Self-evolving judgment tracker",
        version="0.1.0",
        lifespan=lifespan,
    )

    # CORS
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Routers
    from backend.routers.health import router as health_router
    from backend.routers.markets import router as markets_router
    from backend.routers.judgments import router as judgments_router
    from backend.routers.accuracy import router as accuracy_router

    app.include_router(health_router)
    app.include_router(markets_router)
    app.include_router(judgments_router)
    app.include_router(accuracy_router)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=settings.PORT, reload=settings.DEBUG)
