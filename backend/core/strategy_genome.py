"""Strategy Genome — L4 Self-Evolution via parameter natural selection.

Maintains a pool of strategy genomes (parameter sets) that evolve over time.
The best-performing genome's weights influence AI judgment prompts.
The worst-performing genome mutates every 24 hours.
"""

from __future__ import annotations

import json
import logging
import random
import uuid
from dataclasses import dataclass, asdict, field
from datetime import datetime, timedelta
from typing import Optional

from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from backend.models import Plugin

logger = logging.getLogger(__name__)

GENOME_PLUGIN_PREFIX = "strategy-genome-"


@dataclass
class StrategyConfig:
    """Tunable strategy parameters — weights that influence AI judgment emphasis."""
    momentum_weight: float = 0.5      # 24h动量权重
    contrarian_weight: float = 0.3    # 均值回归权重
    volume_weight: float = 0.4        # 成交量确认权重
    cross_market_weight: float = 0.3  # 跨市场相关性权重
    history_weight: float = 0.4       # 7日趋势权重

    def normalize(self) -> None:
        """Clamp all weights to [0.05, 1.0]."""
        self.momentum_weight = max(0.05, min(1.0, self.momentum_weight))
        self.contrarian_weight = max(0.05, min(1.0, self.contrarian_weight))
        self.volume_weight = max(0.05, min(1.0, self.volume_weight))
        self.cross_market_weight = max(0.05, min(1.0, self.cross_market_weight))
        self.history_weight = max(0.05, min(1.0, self.history_weight))

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> StrategyConfig:
        return cls(
            momentum_weight=d.get("momentum_weight", 0.5),
            contrarian_weight=d.get("contrarian_weight", 0.3),
            volume_weight=d.get("volume_weight", 0.4),
            cross_market_weight=d.get("cross_market_weight", 0.3),
            history_weight=d.get("history_weight", 0.4),
        )


@dataclass
class Genome:
    """A strategy genome with fitness tracking."""
    id: str
    name: str
    config: StrategyConfig
    fitness: float = 0.0          # 历史准确率 (0-1)
    total_judgments: int = 0
    correct_judgments: int = 0
    generation: int = 1
    created_at: Optional[datetime] = None
    last_mutated_at: Optional[datetime] = None


# ── Default seed genomes ──────────────────────────────────────────

SEED_GENOMES = [
    Genome(
        id="genome-alpha",
        name="Alpha (动量派)",
        config=StrategyConfig(
            momentum_weight=0.8,
            contrarian_weight=0.2,
            volume_weight=0.5,
            cross_market_weight=0.3,
            history_weight=0.5,
        ),
        generation=1,
    ),
    Genome(
        id="genome-beta",
        name="Beta (均衡派)",
        config=StrategyConfig(
            momentum_weight=0.5,
            contrarian_weight=0.5,
            volume_weight=0.5,
            cross_market_weight=0.5,
            history_weight=0.5,
        ),
        generation=1,
    ),
    Genome(
        id="genome-gamma",
        name="Gamma (逆势派)",
        config=StrategyConfig(
            momentum_weight=0.2,
            contrarian_weight=0.8,
            volume_weight=0.3,
            cross_market_weight=0.6,
            history_weight=0.6,
        ),
        generation=1,
    ),
]


async def ensure_genomes_exist(session: AsyncSession) -> None:
    """Create seed genomes in the Plugin table if they don't exist."""
    for seed in SEED_GENOMES:
        plugin_name = f"{GENOME_PLUGIN_PREFIX}{seed.id}"
        stmt = select(Plugin).where(Plugin.name == plugin_name)
        result = await session.execute(stmt)
        existing = result.scalar_one_or_none()
        if not existing:
            plugin = Plugin(
                id=uuid.uuid4(),
                name=plugin_name,
                display_name=seed.name,
                plugin_type="strategy-genome",
                version="1.0.0",
                is_active=True,
                config={
                    "weights": seed.config.to_dict(),
                    "fitness": 0.0,
                    "total_judgments": 0,
                    "correct_judgments": 0,
                    "generation": 1,
                    "last_mutated_at": None,
                },
                registered_at=datetime.utcnow(),
            )
            session.add(plugin)
            logger.info("创建策略基因组: %s", seed.name)
    await session.commit()


async def load_genomes(session: AsyncSession) -> list[Genome]:
    """Load all strategy genomes from the database."""
    stmt = (
        select(Plugin)
        .where(Plugin.plugin_type == "strategy-genome", Plugin.is_active == True)
    )
    result = await session.execute(stmt)
    plugins = result.scalars().all()

    genomes = []
    for p in plugins:
        cfg = p.config or {}
        genome = Genome(
            id=p.name.replace(GENOME_PLUGIN_PREFIX, ""),
            name=p.display_name,
            config=StrategyConfig.from_dict(cfg.get("weights", {})),
            fitness=cfg.get("fitness", 0.0),
            total_judgments=cfg.get("total_judgments", 0),
            correct_judgments=cfg.get("correct_judgments", 0),
            generation=cfg.get("generation", 1),
            created_at=p.registered_at,
            last_mutated_at=(
                datetime.fromisoformat(cfg["last_mutated_at"])
                if cfg.get("last_mutated_at")
                else None
            ),
        )
        genomes.append(genome)
    return genomes


async def get_best_genome(session: AsyncSession) -> Optional[StrategyConfig]:
    """Get the best-performing genome's strategy config."""
    genomes = await load_genomes(session)
    if not genomes:
        return None

    # Among genomes with at least 5 judgments, pick highest fitness
    qualified = [g for g in genomes if g.total_judgments >= 5]
    if not qualified:
        # All are new; return the balanced one
        return SEED_GENOMES[1].config

    best = max(qualified, key=lambda g: g.fitness)
    logger.info(
        "最佳基因组: %s (适应度=%.1f%%, 代数=%d)",
        best.name, best.fitness * 100, best.generation,
    )
    return best.config


async def update_genome_fitness(
    session: AsyncSession,
    genome_id: str,
    total: int,
    correct: int,
) -> None:
    """Update a genome's fitness based on its judgment results."""
    plugin_name = f"{GENOME_PLUGIN_PREFIX}{genome_id}"
    stmt = select(Plugin).where(Plugin.name == plugin_name)
    result = await session.execute(stmt)
    plugin = result.scalar_one_or_none()
    if not plugin:
        return

    cfg = dict(plugin.config or {})
    cfg["total_judgments"] = total
    cfg["correct_judgments"] = correct
    cfg["fitness"] = correct / total if total > 0 else 0.0
    plugin.config = cfg
    await session.commit()


async def evolve_genomes(session: AsyncSession) -> Optional[str]:
    """Natural selection: mutate the worst-performing genome.

    Called every 24 hours by the scheduler.
    Returns the name of the mutated genome, or None if no mutation happened.
    """
    genomes = await load_genomes(session)
    if len(genomes) < 2:
        return None

    # Only evolve if genomes have enough data
    qualified = [g for g in genomes if g.total_judgments >= 3]
    if len(qualified) < 2:
        logger.info("基因组数据不足，跳过进化")
        return None

    # Find worst performer
    worst = min(qualified, key=lambda g: g.fitness)

    # Mutate: randomly adjust each weight by +-20%
    old_config = worst.config
    new_config = StrategyConfig(
        momentum_weight=old_config.momentum_weight * (1 + random.uniform(-0.2, 0.2)),
        contrarian_weight=old_config.contrarian_weight * (1 + random.uniform(-0.2, 0.2)),
        volume_weight=old_config.volume_weight * (1 + random.uniform(-0.2, 0.2)),
        cross_market_weight=old_config.cross_market_weight * (1 + random.uniform(-0.2, 0.2)),
        history_weight=old_config.history_weight * (1 + random.uniform(-0.2, 0.2)),
    )
    new_config.normalize()

    # Save mutation
    plugin_name = f"{GENOME_PLUGIN_PREFIX}{worst.id}"
    stmt = select(Plugin).where(Plugin.name == plugin_name)
    result = await session.execute(stmt)
    plugin = result.scalar_one_or_none()
    if plugin:
        cfg = dict(plugin.config or {})
        cfg["weights"] = new_config.to_dict()
        cfg["generation"] = worst.generation + 1
        cfg["last_mutated_at"] = datetime.utcnow().isoformat()
        # Reset fitness for the new generation
        cfg["total_judgments"] = 0
        cfg["correct_judgments"] = 0
        cfg["fitness"] = 0.0
        plugin.config = cfg
        await session.commit()

    logger.info(
        "基因组进化: %s 变异 (代数 %d -> %d)",
        worst.name, worst.generation, worst.generation + 1,
    )
    return worst.name


def build_genome_prompt_hint(config: StrategyConfig) -> str:
    """Build a prompt hint string from the strategy genome weights.

    This tells the AI which factors to emphasize based on evolved weights.
    """
    hints = []

    # Describe emphasis levels
    def level(w: float) -> str:
        if w >= 0.7:
            return "重点关注"
        elif w >= 0.4:
            return "适度考虑"
        else:
            return "少量参考"

    hints.append(f"- 24h动量: {level(config.momentum_weight)} (权重{config.momentum_weight:.2f})")
    hints.append(f"- 均值回归: {level(config.contrarian_weight)} (权重{config.contrarian_weight:.2f})")
    hints.append(f"- 成交量确认: {level(config.volume_weight)} (权重{config.volume_weight:.2f})")
    hints.append(f"- 跨市场联动: {level(config.cross_market_weight)} (权重{config.cross_market_weight:.2f})")
    hints.append(f"- 7日趋势: {level(config.history_weight)} (权重{config.history_weight:.2f})")

    return "【策略基因组指导】请按以下权重分配你的分析重点:\n" + "\n".join(hints)
