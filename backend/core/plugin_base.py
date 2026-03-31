"""Abstract base classes for all plugin types — adapted from open-architecture.md."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import AsyncIterator, Optional

from backend.core.types import (
    BiasSignal,
    DataQuery,
    MarketData,
    MarketTick,
    MarketType,
)


class DataSourcePlugin(ABC):
    """Base class for all Layer 1 data source plugins."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Unique plugin identifier."""
        ...

    @property
    @abstractmethod
    def display_name(self) -> str:
        """Human-readable display name."""
        ...

    @property
    @abstractmethod
    def markets(self) -> list[MarketType]:
        """Markets this plugin covers."""
        ...

    @property
    def requires_auth(self) -> bool:
        return False

    @abstractmethod
    async def initialize(self, config: dict) -> None:
        """Initialize the plugin. Called once on load."""
        ...

    @abstractmethod
    async def fetch(self, query: DataQuery) -> list[MarketData]:
        """Fetch historical or snapshot data."""
        ...

    async def subscribe(self, symbols: list[str]) -> AsyncIterator[MarketTick]:
        """Subscribe to real-time ticks. Override if supported."""
        raise NotImplementedError("This data source does not support streaming.")

    async def unsubscribe(self, symbols: list[str]) -> None:
        """Unsubscribe from real-time ticks."""
        pass

    @abstractmethod
    async def health_check(self) -> bool:
        """Return True if data source is reachable."""
        ...

    async def list_symbols(self, market: MarketType) -> list[str]:
        """Return available symbols. Override if supported."""
        return []

    async def destroy(self) -> None:
        """Clean up resources. Override if needed."""
        pass

    async def fetch_ticks(self, symbols: list[str]) -> list[MarketTick]:
        """Convenience: fetch current ticks for given symbols.

        Default implementation builds a DataQuery and converts. Override for
        a more efficient path.
        """
        return []


class ReasoningPlugin(ABC):
    """Base class for all Layer 2 reasoning plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def analyze(self, context: dict) -> dict: ...

    async def destroy(self) -> None:
        pass


class BiasDetectorPlugin(ABC):
    """Base class for all Layer 3 bias detector plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @property
    @abstractmethod
    def bias_type(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def detect(
        self,
        symbol: str,
        market_price: float,
        rational_price: Optional[float],
    ) -> Optional[BiasSignal]: ...

    async def destroy(self) -> None:
        pass


class EvolutionPlugin(ABC):
    """Base class for all Layer 4 evolution plugins."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @property
    @abstractmethod
    def display_name(self) -> str: ...

    @abstractmethod
    async def initialize(self, config: dict) -> None: ...

    @abstractmethod
    async def evaluate(self, data: dict) -> dict: ...

    async def destroy(self) -> None:
        pass
