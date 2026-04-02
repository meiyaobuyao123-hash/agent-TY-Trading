"""APScheduler setup with all cron jobs for the TY system."""

from __future__ import annotations

import logging
import time

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

# Staleness threshold: warn if judgment cycle hasn't run in 5 hours
CYCLE_STALE_THRESHOLD_SEC = 5 * 3600


def create_scheduler() -> AsyncIOScheduler:
    """Create and configure the scheduler (does NOT start it)."""
    scheduler = AsyncIOScheduler(timezone="UTC")
    return scheduler


def register_jobs(
    scheduler: AsyncIOScheduler,
    judgment_trigger_fn,
    settlement_fn,
    accuracy_fn,
    genome_evolution_fn=None,
) -> None:
    """Register all recurring jobs.

    Parameters
    ----------
    judgment_trigger_fn : async callable — runs full AI judgment cycle
    settlement_fn       : async callable — settles expired judgments
    accuracy_fn         : async callable — recalculates accuracy stats
    genome_evolution_fn : async callable — evolves strategy genomes (L4)
    """

    # AI judgment every 4 hours
    scheduler.add_job(
        judgment_trigger_fn,
        "interval",
        hours=4,
        id="ai_judgment_cycle",
        name="AI Judgment Cycle",
        replace_existing=True,
    )

    # Settlement every 1 hour
    scheduler.add_job(
        settlement_fn,
        "interval",
        hours=1,
        id="settlement",
        name="Judgment Settlement",
        replace_existing=True,
    )

    # Accuracy recalculation every 1 hour
    scheduler.add_job(
        accuracy_fn,
        "interval",
        hours=1,
        id="accuracy_calc",
        name="Accuracy Calculation",
        replace_existing=True,
    )

    # L4: Strategy genome evolution every 24 hours
    if genome_evolution_fn:
        scheduler.add_job(
            genome_evolution_fn,
            "interval",
            hours=24,
            id="genome_evolution",
            name="Strategy Genome Evolution (L4)",
            replace_existing=True,
        )

    logger.info(
        "Registered %d scheduled jobs", len(scheduler.get_jobs())
    )


async def check_cycle_staleness(app) -> None:
    """Periodic health check: warn if judgment cycle hasn't run recently."""
    last_cycle = getattr(app.state, "last_cycle_time", None)
    if last_cycle is None:
        # Never run yet — only warn if app has been up > 5 hours
        start_time = getattr(app.state, "start_time", None)
        if start_time and (time.time() - start_time) > CYCLE_STALE_THRESHOLD_SEC:
            logger.warning(
                "判断周期从未执行！服务已运行 %.1f 小时，但调度器可能失败。",
                (time.time() - start_time) / 3600,
            )
        return

    elapsed = time.time() - last_cycle
    if elapsed > CYCLE_STALE_THRESHOLD_SEC:
        logger.warning(
            "判断周期已过期！距上次运行 %.1f 小时（阈值 %.0f 小时），调度器可能卡住。",
            elapsed / 3600,
            CYCLE_STALE_THRESHOLD_SEC / 3600,
        )
