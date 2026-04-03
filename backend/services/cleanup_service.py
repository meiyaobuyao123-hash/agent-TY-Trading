"""清理服务 — 定期清除旧的快照数据，保持数据库精简。

保留判断和结算数据（更有价值），只清理原始快照。
不删除仍被判断引用的快照（通过 snapshot_id 外键关联）。
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta

from sqlalchemy import delete, select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from backend.models import MarketSnapshot, Judgment

logger = logging.getLogger(__name__)


async def cleanup_old_snapshots(
    session: AsyncSession,
    days: int = 14,
) -> int:
    """删除 N 天前的快照数据。

    跳过仍被判断引用的快照 (通过 Judgment.snapshot_id)。
    返回删除的记录数。
    """
    cutoff = datetime.utcnow() - timedelta(days=days)

    # 找出仍被判断引用的快照 ID
    referenced_ids_stmt = (
        select(Judgment.snapshot_id)
        .where(Judgment.snapshot_id.isnot(None))
        .distinct()
    )
    referenced_result = await session.execute(referenced_ids_stmt)
    referenced_ids = {row[0] for row in referenced_result.all()}

    # 找出符合删除条件的快照
    old_snaps_stmt = (
        select(MarketSnapshot.id)
        .where(MarketSnapshot.captured_at < cutoff)
    )
    old_result = await session.execute(old_snaps_stmt)
    old_ids = [row[0] for row in old_result.all()]

    # 过滤掉被引用的
    to_delete = [sid for sid in old_ids if sid not in referenced_ids]

    if not to_delete:
        return 0

    # 分批删除（每批500条）
    total_deleted = 0
    batch_size = 500
    for i in range(0, len(to_delete), batch_size):
        batch = to_delete[i:i + batch_size]
        stmt = delete(MarketSnapshot).where(MarketSnapshot.id.in_(batch))
        result = await session.execute(stmt)
        total_deleted += result.rowcount

    await session.commit()
    logger.info(
        "快照清理: 删除 %d 条 %d 天前的旧快照 (保留 %d 条被引用快照)",
        total_deleted, days, len(referenced_ids),
    )
    return total_deleted


async def expire_stale_judgments(session: AsyncSession) -> int:
    """将已过期但未结算的判断标记为 expired。

    如果 judgment.expires_at 已过但没有对应 settlement，
    创建一个 settlement 记录标记为过期（is_correct=None）。
    返回过期处理的记录数。
    """
    from backend.models import Settlement
    import uuid

    now = datetime.utcnow()

    # 找出已过期且未结算的判断
    expired_stmt = (
        select(Judgment)
        .outerjoin(Settlement, Settlement.judgment_id == Judgment.id)
        .where(
            Judgment.expires_at.isnot(None),
            Judgment.expires_at < now,
            Settlement.id.is_(None),
        )
    )
    result = await session.execute(expired_stmt)
    expired_judgments = result.scalars().all()

    if not expired_judgments:
        return 0

    count = 0
    for j in expired_judgments:
        settlement = Settlement(
            id=uuid.uuid4(),
            judgment_id=j.id,
            actual_price=None,
            actual_direction="expired",
            is_correct=None,
            brier_score=None,
            settled_at=now,
        )
        session.add(settlement)
        count += 1

    await session.commit()
    logger.info("过期清理: 标记 %d 条过期判断", count)
    return count
