"""Deviation calculator — compares AI rational_price vs market_price."""

from __future__ import annotations

import logging
from typing import Optional

from backend.core.plugin_base import BiasDetectorPlugin
from backend.core.types import BiasSignal

logger = logging.getLogger(__name__)


class DeviationCalculator(BiasDetectorPlugin):
    """Compare AI-estimated rational price vs current market price.

    If the deviation exceeds a threshold, it signals a potential mispricing
    (which could indicate crowd bias).
    """

    @property
    def name(self) -> str:
        return "deviation-calc"

    @property
    def display_name(self) -> str:
        return "Price Deviation Calculator"

    @property
    def bias_type(self) -> str:
        return "mispricing"

    async def initialize(self, config: dict) -> None:
        self._threshold_pct = config.get("deviation_threshold_pct", 2.0)

    async def detect(
        self,
        symbol: str,
        market_price: float,
        rational_price: Optional[float],
    ) -> Optional[BiasSignal]:
        """Calculate deviation between rational and market price.

        Returns None if rational_price is not available or deviation is below threshold.
        """
        if rational_price is None or market_price <= 0:
            return None

        deviation = rational_price - market_price
        deviation_pct = (deviation / market_price) * 100

        if abs(deviation_pct) < self._threshold_pct:
            return None

        direction = "long" if deviation_pct > 0 else "short"
        strength = min(abs(deviation_pct) / 10.0, 1.0)  # Cap at 1.0

        return BiasSignal(
            bias_type=self.bias_type,
            symbol=symbol,
            strength=strength,
            direction=direction,
            evidence=(
                f"AI rational price ({rational_price:.2f}) deviates "
                f"{deviation_pct:+.2f}% from market price ({market_price:.2f})"
            ),
            rational_price_estimate=rational_price,
            current_price=market_price,
            mispricing=deviation,
            mispricing_pct=deviation_pct,
        )


def calculate_deviation_pct(
    market_price: float, rational_price: Optional[float]
) -> Optional[float]:
    """Standalone helper: compute deviation percentage."""
    if rational_price is None or market_price <= 0:
        return None
    return round(((rational_price - market_price) / market_price) * 100, 4)
