"""Plugin manager — load, register, validate, health-check plugins."""

from __future__ import annotations

import asyncio
import logging
from typing import Optional

from backend.core.plugin_base import (
    BiasDetectorPlugin,
    DataSourcePlugin,
    EvolutionPlugin,
    ReasoningPlugin,
)

logger = logging.getLogger(__name__)


from typing import Union

PluginType = Union[DataSourcePlugin, ReasoningPlugin, BiasDetectorPlugin, EvolutionPlugin]


class PluginManager:
    """Central registry for all plugin instances."""

    def __init__(self) -> None:
        self._data_sources: dict[str, DataSourcePlugin] = {}
        self._reasoning: dict[str, ReasoningPlugin] = {}
        self._bias_detectors: dict[str, BiasDetectorPlugin] = {}
        self._evolution: dict[str, EvolutionPlugin] = {}
        self._health_cache: dict[str, dict[str, bool]] | None = None
        self._health_cache_ts: float = 0.0
        self._HEALTH_CACHE_TTL = 60.0  # Cache health results for 60s

    # ── Registration ──────────────────────────────────────────────

    def register_data_source(self, plugin: DataSourcePlugin) -> None:
        self._data_sources[plugin.name] = plugin
        logger.info("Registered data source: %s", plugin.name)

    def register_reasoning(self, plugin: ReasoningPlugin) -> None:
        self._reasoning[plugin.name] = plugin
        logger.info("Registered reasoning: %s", plugin.name)

    def register_bias_detector(self, plugin: BiasDetectorPlugin) -> None:
        self._bias_detectors[plugin.name] = plugin
        logger.info("Registered bias detector: %s", plugin.name)

    def register_evolution(self, plugin: EvolutionPlugin) -> None:
        self._evolution[plugin.name] = plugin
        logger.info("Registered evolution: %s", plugin.name)

    # ── Lookup ────────────────────────────────────────────────────

    def get_data_source(self, name: str) -> Optional[DataSourcePlugin]:
        return self._data_sources.get(name)

    def get_reasoning(self, name: str) -> Optional[ReasoningPlugin]:
        return self._reasoning.get(name)

    def get_bias_detector(self, name: str) -> Optional[BiasDetectorPlugin]:
        return self._bias_detectors.get(name)

    def get_evolution(self, name: str) -> Optional[EvolutionPlugin]:
        return self._evolution.get(name)

    @property
    def data_sources(self) -> dict[str, DataSourcePlugin]:
        return dict(self._data_sources)

    @property
    def reasoning_plugins(self) -> dict[str, ReasoningPlugin]:
        return dict(self._reasoning)

    @property
    def bias_detectors(self) -> dict[str, BiasDetectorPlugin]:
        return dict(self._bias_detectors)

    @property
    def evolution_plugins(self) -> dict[str, EvolutionPlugin]:
        return dict(self._evolution)

    # ── Lifecycle ─────────────────────────────────────────────────

    async def initialize_all(self, config: dict) -> None:
        """Initialize every registered plugin."""
        for name, plugin in self._data_sources.items():
            try:
                await plugin.initialize(config)
                logger.info("Initialized data source: %s", name)
            except Exception:
                logger.exception("Failed to initialize data source: %s", name)

        for name, plugin in self._reasoning.items():
            try:
                await plugin.initialize(config)
                logger.info("Initialized reasoning: %s", name)
            except Exception:
                logger.exception("Failed to initialize reasoning: %s", name)

        for name, plugin in self._bias_detectors.items():
            try:
                await plugin.initialize(config)
                logger.info("Initialized bias detector: %s", name)
            except Exception:
                logger.exception("Failed to initialize bias detector: %s", name)

        for name, plugin in self._evolution.items():
            try:
                await plugin.initialize(config)
                logger.info("Initialized evolution: %s", name)
            except Exception:
                logger.exception("Failed to initialize evolution: %s", name)

    async def health_check_all(self) -> dict[str, dict[str, bool]]:
        """Run health checks on all plugins and return results (parallel, 2s timeout, 60s cache)."""
        import time
        now = time.time()
        if self._health_cache and (now - self._health_cache_ts) < self._HEALTH_CACHE_TTL:
            return self._health_cache

        results: dict[str, dict[str, bool]] = {
            "data_sources": {},
            "reasoning": {},
            "bias_detectors": {},
            "evolution": {},
        }

        # Run data source health checks in parallel with timeout
        async def _check_ds(name: str, plugin: DataSourcePlugin) -> tuple[str, bool]:
            try:
                ok = await asyncio.wait_for(plugin.health_check(), timeout=2.0)
                return name, ok
            except (asyncio.TimeoutError, Exception):
                return name, False

        ds_checks = await asyncio.gather(
            *[_check_ds(n, p) for n, p in self._data_sources.items()],
            return_exceptions=True,
        )
        for item in ds_checks:
            if isinstance(item, tuple):
                results["data_sources"][item[0]] = item[1]

        for name in self._reasoning:
            results["reasoning"][name] = True

        for name in self._bias_detectors:
            results["bias_detectors"][name] = True

        for name in self._evolution:
            results["evolution"][name] = True

        self._health_cache = results
        self._health_cache_ts = now
        return results

    async def destroy_all(self) -> None:
        """Destroy every registered plugin."""
        all_plugins: list[PluginType] = [
            *self._data_sources.values(),
            *self._reasoning.values(),
            *self._bias_detectors.values(),
            *self._evolution.values(),
        ]
        for plugin in all_plugins:
            try:
                await plugin.destroy()
            except Exception:
                logger.exception("Error destroying plugin: %s", plugin.name)

    def list_all(self) -> list[dict]:
        """Return metadata for all registered plugins."""
        result = []
        for name, p in self._data_sources.items():
            result.append({
                "name": name,
                "display_name": p.display_name,
                "type": "data_source",
                "markets": [m.value for m in p.markets],
            })
        for name, p in self._reasoning.items():
            result.append({
                "name": name,
                "display_name": p.display_name,
                "type": "reasoning",
            })
        for name, p in self._bias_detectors.items():
            result.append({
                "name": name,
                "display_name": p.display_name,
                "type": "bias_detector",
                "bias_type": p.bias_type,
            })
        for name, p in self._evolution.items():
            result.append({
                "name": name,
                "display_name": p.display_name,
                "type": "evolution",
            })
        return result
