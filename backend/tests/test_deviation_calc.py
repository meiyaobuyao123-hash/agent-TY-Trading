"""Tests for the deviation calculator bias detector."""

from __future__ import annotations

import pytest

from backend.plugins.bias_detectors.deviation_calc import (
    DeviationCalculator,
    calculate_deviation_pct,
)


class TestCalculateDeviationPct:

    def test_positive_deviation(self):
        result = calculate_deviation_pct(100.0, 105.0)
        assert result == 5.0

    def test_negative_deviation(self):
        result = calculate_deviation_pct(100.0, 95.0)
        assert result == -5.0

    def test_zero_deviation(self):
        result = calculate_deviation_pct(100.0, 100.0)
        assert result == 0.0

    def test_none_rational_price(self):
        result = calculate_deviation_pct(100.0, None)
        assert result is None

    def test_zero_market_price(self):
        result = calculate_deviation_pct(0.0, 100.0)
        assert result is None


class TestDeviationCalculator:

    @pytest.fixture
    def calc(self):
        c = DeviationCalculator()
        return c

    @pytest.mark.asyncio
    async def test_detect_above_threshold(self, calc):
        await calc.initialize({"deviation_threshold_pct": 2.0})
        signal = await calc.detect("BTC-USD", 67000.0, 70000.0)
        assert signal is not None
        assert signal.direction == "long"
        assert signal.mispricing_pct > 0

    @pytest.mark.asyncio
    async def test_detect_below_threshold(self, calc):
        await calc.initialize({"deviation_threshold_pct": 2.0})
        signal = await calc.detect("BTC-USD", 67000.0, 67500.0)
        assert signal is None  # Only ~0.75% deviation, below 2% threshold

    @pytest.mark.asyncio
    async def test_detect_no_rational_price(self, calc):
        await calc.initialize({})
        signal = await calc.detect("BTC-USD", 67000.0, None)
        assert signal is None

    @pytest.mark.asyncio
    async def test_detect_negative_deviation(self, calc):
        await calc.initialize({"deviation_threshold_pct": 2.0})
        signal = await calc.detect("BTC-USD", 67000.0, 64000.0)
        assert signal is not None
        assert signal.direction == "short"
        assert signal.mispricing_pct < 0

    @pytest.mark.asyncio
    async def test_plugin_properties(self, calc):
        assert calc.name == "deviation-calc"
        assert calc.bias_type == "mispricing"
