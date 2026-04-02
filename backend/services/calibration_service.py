"""概率校准服务 — 基于历史表现的直方图分桶校准。

分析历史判断中AI预测概率与实际结果的对应关系，
构建校准映射表，用于修正新判断的概率分布。

核心思路：
- 将AI预测概率分为若干桶 (0-0.2, 0.2-0.4, 0.4-0.6, 0.6-0.8, 0.8-1.0)
- 统计每个桶中预测为某方向的实际命中率
- 用实际命中率替代AI原始概率，使校准后的概率更贴近真实
"""

from __future__ import annotations

import logging
from collections import defaultdict
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select, and_, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from backend.models import Judgment, Settlement, Market

logger = logging.getLogger(__name__)

# 校准表缓存 — 按 market_type 分别缓存
_calibration_cache: dict[str, dict] = {}
_calibration_cache_ts: float = 0.0
CALIBRATION_CACHE_TTL = 3600  # 1小时刷新一次

# 概率分桶边界
PROB_BUCKETS = [
    (0.0, 0.2),
    (0.2, 0.35),
    (0.35, 0.5),
    (0.5, 0.65),
    (0.65, 0.8),
    (0.8, 1.0),
]

# 最少需要多少个样本才使用校准（避免小样本偏差）
MIN_SAMPLES_PER_BUCKET = 3


def _bucket_index(prob: float) -> int:
    """将概率值映射到桶索引。"""
    for i, (lo, hi) in enumerate(PROB_BUCKETS):
        if lo <= prob < hi:
            return i
    return len(PROB_BUCKETS) - 1  # 概率=1.0时归入最后一个桶


async def build_calibration_table(
    session: AsyncSession,
    lookback_days: int = 30,
) -> dict[str, dict]:
    """构建校准映射表。

    返回:
        {
            market_type: {
                "up": [(bucket_lo, bucket_hi, actual_hit_rate, sample_count), ...],
                "down": [...],
                "flat": [...],
            }
        }
    """
    import time
    global _calibration_cache, _calibration_cache_ts

    now = time.time()
    if _calibration_cache and (now - _calibration_cache_ts) < CALIBRATION_CACHE_TTL:
        return _calibration_cache

    cutoff = datetime.utcnow() - timedelta(days=lookback_days)

    stmt = (
        select(Judgment, Settlement, Market.market_type)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .join(Market, Market.id == Judgment.market_id)
        .where(
            Settlement.is_correct.isnot(None),
            Judgment.created_at >= cutoff,
            Judgment.up_probability.isnot(None),
        )
    )
    result = await session.execute(stmt)
    rows = result.all()

    if not rows:
        logger.info("校准表构建: 无足够历史数据")
        return {}

    # 按 market_type 和方向分桶统计
    # stats[market_type][direction][bucket_idx] = {"total": int, "correct": int}
    stats: dict[str, dict[str, dict[int, dict]]] = defaultdict(
        lambda: defaultdict(lambda: defaultdict(lambda: {"total": 0, "correct": 0}))
    )

    for j, s, mt in rows:
        actual_dir = s.actual_direction
        if actual_dir is None:
            continue

        # 对每个方向的概率进行分桶统计
        for direction, prob in [
            ("up", j.up_probability),
            ("down", j.down_probability),
            ("flat", j.flat_probability),
        ]:
            if prob is None:
                continue
            bucket_idx = _bucket_index(prob)
            stats[mt][direction][bucket_idx]["total"] += 1
            if actual_dir == direction:
                stats[mt][direction][bucket_idx]["correct"] += 1

    # 构建校准表
    calibration: dict[str, dict] = {}
    for mt, direction_stats in stats.items():
        calibration[mt] = {}
        for direction, bucket_stats in direction_stats.items():
            buckets = []
            for i, (lo, hi) in enumerate(PROB_BUCKETS):
                s = bucket_stats.get(i, {"total": 0, "correct": 0})
                total = s["total"]
                correct = s["correct"]
                if total >= MIN_SAMPLES_PER_BUCKET:
                    hit_rate = correct / total
                else:
                    hit_rate = None  # 样本不足，不校准
                buckets.append((lo, hi, hit_rate, total))
            calibration[mt][direction] = buckets

    _calibration_cache = calibration
    _calibration_cache_ts = now
    logger.info(
        "校准表已构建: %d 个市场类型, %d 条历史数据",
        len(calibration), len(rows),
    )
    return calibration


def calibrate_probabilities(
    up_prob: Optional[float],
    down_prob: Optional[float],
    flat_prob: Optional[float],
    market_type: str,
    calibration_table: dict[str, dict],
) -> tuple[Optional[float], Optional[float], Optional[float]]:
    """根据校准表调整概率分布。

    对每个方向的概率，查找其所在桶的历史命中率，
    用命中率替代原始概率，然后重新归一化使总和为1。

    如果某个桶样本不足，保留原始概率。
    """
    if up_prob is None or down_prob is None or flat_prob is None:
        return up_prob, down_prob, flat_prob

    mt_cal = calibration_table.get(market_type)
    if not mt_cal:
        return up_prob, down_prob, flat_prob

    calibrated = {}
    for direction, raw_prob in [("up", up_prob), ("down", down_prob), ("flat", flat_prob)]:
        dir_buckets = mt_cal.get(direction)
        if not dir_buckets:
            calibrated[direction] = raw_prob
            continue

        bucket_idx = _bucket_index(raw_prob)
        if bucket_idx < len(dir_buckets):
            _, _, hit_rate, sample_count = dir_buckets[bucket_idx]
            if hit_rate is not None:
                # 混合校准: 70%校准值 + 30%原始值（避免过度校准）
                calibrated[direction] = 0.7 * hit_rate + 0.3 * raw_prob
            else:
                calibrated[direction] = raw_prob
        else:
            calibrated[direction] = raw_prob

    # 归一化使总和为1
    cal_up = calibrated.get("up", up_prob)
    cal_down = calibrated.get("down", down_prob)
    cal_flat = calibrated.get("flat", flat_prob)
    total = cal_up + cal_down + cal_flat

    if total > 0:
        cal_up = round(cal_up / total, 4)
        cal_down = round(cal_down / total, 4)
        cal_flat = round(1.0 - cal_up - cal_down, 4)  # 确保精确求和为1
    else:
        cal_up, cal_down, cal_flat = 0.34, 0.33, 0.33

    return cal_up, cal_down, cal_flat


async def get_calibration_diagnostics(
    session: AsyncSession,
) -> dict:
    """生成校准诊断报告 — 分析各市场类型的概率校准偏差。

    返回:
        {
            market_type: {
                "avg_predicted_up": float,
                "actual_up_rate": float,
                "overconfidence": float,  # 正值=过度自信, 负值=过度保守
                "sample_count": int,
            }
        }
    """
    cutoff = datetime.utcnow() - timedelta(days=30)

    stmt = (
        select(Judgment, Settlement, Market.market_type)
        .join(Settlement, Settlement.judgment_id == Judgment.id)
        .join(Market, Market.id == Judgment.market_id)
        .where(
            Settlement.is_correct.isnot(None),
            Judgment.created_at >= cutoff,
        )
    )
    result = await session.execute(stmt)
    rows = result.all()

    # 按 market_type 聚合
    type_stats: dict[str, dict] = defaultdict(
        lambda: {
            "sum_pred_up": 0.0, "sum_pred_down": 0.0, "sum_pred_flat": 0.0,
            "actual_up": 0, "actual_down": 0, "actual_flat": 0,
            "total": 0,
            "correct": 0,
            "brier_sum": 0.0,
        }
    )

    for j, s, mt in rows:
        ts = type_stats[mt]
        ts["total"] += 1
        if s.is_correct:
            ts["correct"] += 1

        actual_dir = s.actual_direction or "flat"
        ts[f"actual_{actual_dir}"] += 1

        up_p = j.up_probability or 0.33
        down_p = j.down_probability or 0.33
        flat_p = j.flat_probability or 0.34
        ts["sum_pred_up"] += up_p
        ts["sum_pred_down"] += down_p
        ts["sum_pred_flat"] += flat_p

        # 计算Brier score
        actual_up = 1.0 if actual_dir == "up" else 0.0
        actual_down = 1.0 if actual_dir == "down" else 0.0
        actual_flat = 1.0 if actual_dir == "flat" else 0.0
        brier = ((up_p - actual_up) ** 2 + (down_p - actual_down) ** 2 + (flat_p - actual_flat) ** 2) / 3.0
        ts["brier_sum"] += brier

    diagnostics = {}
    for mt, ts in type_stats.items():
        n = ts["total"]
        if n == 0:
            continue
        avg_pred_up = ts["sum_pred_up"] / n
        actual_up_rate = ts["actual_up"] / n
        overconfidence = avg_pred_up - actual_up_rate  # AI平均预测看涨概率 vs 实际看涨率

        diagnostics[mt] = {
            "avg_predicted_up": round(avg_pred_up, 4),
            "actual_up_rate": round(actual_up_rate, 4),
            "avg_predicted_down": round(ts["sum_pred_down"] / n, 4),
            "actual_down_rate": round(ts["actual_down"] / n, 4),
            "overconfidence_up": round(overconfidence, 4),
            "avg_brier": round(ts["brier_sum"] / n, 4),
            "accuracy_pct": round(ts["correct"] / n * 100, 1),
            "sample_count": n,
        }

    return diagnostics
