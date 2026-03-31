"""APScheduler setup with all cron jobs for the TY system."""

from __future__ import annotations

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)


def create_scheduler() -> AsyncIOScheduler:
    """Create and configure the scheduler (does NOT start it)."""
    scheduler = AsyncIOScheduler(timezone="UTC")
    return scheduler


def register_jobs(
    scheduler: AsyncIOScheduler,
    judgment_trigger_fn,
    settlement_fn,
    accuracy_fn,
) -> None:
    """Register all recurring jobs.

    Parameters
    ----------
    judgment_trigger_fn : async callable — runs full AI judgment cycle
    settlement_fn       : async callable — settles expired judgments
    accuracy_fn         : async callable — recalculates accuracy stats
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

    logger.info(
        "Registered %d scheduled jobs", len(scheduler.get_jobs())
    )
