"""Tests for PluginManager — registration, lookup, lifecycle."""

from __future__ import annotations

import pytest
import pytest_asyncio

from backend.core.plugin_manager import PluginManager
from backend.core.plugin_base import DataSourcePlugin, ReasoningPlugin, BiasDetectorPlugin
from backend.core.types import DataQuery, MarketData, MarketType, BiasSignal
from typing import Optional


class MockDataSource(DataSourcePlugin):
    @property
    def name(self) -> str:
        return "mock-ds"

    @property
    def display_name(self) -> str:
        return "Mock Data Source"

    @property
    def markets(self) -> list[MarketType]:
        return [MarketType.CRYPTO]

    async def initialize(self, config: dict) -> None:
        self._initialized = True

    async def fetch(self, query: DataQuery) -> list[MarketData]:
        return []

    async def health_check(self) -> bool:
        return True

    async def destroy(self) -> None:
        self._destroyed = True


class MockReasoning(ReasoningPlugin):
    @property
    def name(self) -> str:
        return "mock-reasoning"

    @property
    def display_name(self) -> str:
        return "Mock Reasoning"

    async def initialize(self, config: dict) -> None:
        pass

    async def analyze(self, context: dict) -> dict:
        return {"direction": "up", "confidence": "high"}


class MockBiasDetector(BiasDetectorPlugin):
    @property
    def name(self) -> str:
        return "mock-bias"

    @property
    def display_name(self) -> str:
        return "Mock Bias"

    @property
    def bias_type(self) -> str:
        return "test-bias"

    async def initialize(self, config: dict) -> None:
        pass

    async def detect(self, symbol: str, market_price: float, rational_price: Optional[float]) -> Optional[BiasSignal]:
        return None


@pytest.fixture
def pm() -> PluginManager:
    return PluginManager()


class TestPluginRegistration:

    def test_register_data_source(self, pm: PluginManager):
        ds = MockDataSource()
        pm.register_data_source(ds)
        assert pm.get_data_source("mock-ds") is ds

    def test_register_reasoning(self, pm: PluginManager):
        r = MockReasoning()
        pm.register_reasoning(r)
        assert pm.get_reasoning("mock-reasoning") is r

    def test_register_bias_detector(self, pm: PluginManager):
        bd = MockBiasDetector()
        pm.register_bias_detector(bd)
        assert pm.get_bias_detector("mock-bias") is bd

    def test_get_nonexistent_returns_none(self, pm: PluginManager):
        assert pm.get_data_source("nonexistent") is None

    def test_list_all(self, pm: PluginManager):
        pm.register_data_source(MockDataSource())
        pm.register_reasoning(MockReasoning())
        pm.register_bias_detector(MockBiasDetector())
        plugins = pm.list_all()
        assert len(plugins) == 3
        names = {p["name"] for p in plugins}
        assert names == {"mock-ds", "mock-reasoning", "mock-bias"}

    def test_data_sources_property(self, pm: PluginManager):
        ds = MockDataSource()
        pm.register_data_source(ds)
        sources = pm.data_sources
        assert "mock-ds" in sources


class TestPluginLifecycle:

    @pytest.mark.asyncio
    async def test_initialize_all(self, pm: PluginManager):
        ds = MockDataSource()
        pm.register_data_source(ds)
        await pm.initialize_all({})
        assert ds._initialized is True

    @pytest.mark.asyncio
    async def test_destroy_all(self, pm: PluginManager):
        ds = MockDataSource()
        pm.register_data_source(ds)
        await pm.initialize_all({})
        await pm.destroy_all()
        assert ds._destroyed is True

    @pytest.mark.asyncio
    async def test_health_check_all(self, pm: PluginManager):
        ds = MockDataSource()
        pm.register_data_source(ds)
        await pm.initialize_all({})
        health = await pm.health_check_all()
        assert health["data_sources"]["mock-ds"] is True
