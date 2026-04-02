"""FastAPI application entry point for Project TY (天演)."""

from __future__ import annotations

import logging
import time
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
from backend.plugins.data_sources.yfinance_global import YFinanceDataSource
from backend.plugins.data_sources.fear_greed import FearGreedDataSource
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
    pm.register_data_source(YFinanceDataSource())
    pm.register_data_source(FearGreedDataSource())

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
    app.state.start_time = time.time()
    app.state.last_cycle_time = None

    # ── Strategy Genomes (L4 Self-Evolution) ──
    try:
        from backend.database import async_session_maker
        from backend.core.strategy_genome import ensure_genomes_exist
        async with async_session_maker() as session:
            await ensure_genomes_exist(session)
        logger.info("Strategy genomes initialized")
    except Exception:
        logger.warning("Failed to initialize strategy genomes — will retry later")

    # ── Scheduler ──
    if settings.SCHEDULER_ENABLED:
        scheduler = create_scheduler()

        async def _judgment_cycle():
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.services.judgment_service import trigger_judgment_cycle
                await trigger_judgment_cycle(session, pm)
            app.state.last_cycle_time = time.time()

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

        async def _genome_evolution():
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.core.strategy_genome import evolve_genomes
                result = await evolve_genomes(session)
                if result:
                    logger.info("Genome evolution completed: mutated %s", result)

        async def _snapshot_cleanup():
            """清理14天前的快照数据，保持系统精简。"""
            from backend.database import async_session_maker
            async with async_session_maker() as session:
                from backend.services.cleanup_service import cleanup_old_snapshots
                deleted = await cleanup_old_snapshots(session, days=14)
                if deleted > 0:
                    logger.info("快照清理完成: 删除了 %d 条旧记录", deleted)

        register_jobs(scheduler, _judgment_cycle, _settlement, _accuracy, _genome_evolution)

        # 每天凌晨3点清理旧快照
        scheduler.add_job(
            _snapshot_cleanup,
            "cron",
            hour=3,
            minute=0,
            id="snapshot_cleanup",
            name="Old Snapshot Cleanup",
            replace_existing=True,
        )

        # Staleness monitor: check every 30 minutes if judgment cycle is stale
        from backend.core.scheduler import check_cycle_staleness

        async def _check_staleness():
            await check_cycle_staleness(app)

        scheduler.add_job(
            _check_staleness,
            "interval",
            minutes=30,
            id="cycle_staleness_check",
            name="Cycle Staleness Monitor",
            replace_existing=True,
        )

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
        version="3.0.0",
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
    from backend.routers.stats import router as stats_router

    app.include_router(health_router)
    app.include_router(markets_router)
    app.include_router(judgments_router)
    app.include_router(accuracy_router)
    app.include_router(stats_router)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="0.0.0.0", port=settings.PORT, reload=settings.DEBUG)
