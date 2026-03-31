"""AI Consensus Reasoning — multi-model judgment with graceful degradation.

Calls Claude + GPT-4o + Gemini in parallel, parses direction/confidence/reasoning
from each, then produces a consensus result.
"""

from __future__ import annotations

import logging
from typing import Optional

from backend.core.ai_client import call_all_models
from backend.core.plugin_base import ReasoningPlugin
from backend.core.types import (
    Confidence,
    ConsensusResult,
    Direction,
    ModelVote,
)

logger = logging.getLogger(__name__)

SYSTEM_PROMPT = """You are a financial analyst AI. Given market data, provide your judgment.

Respond ONLY with valid JSON (no markdown, no code fences):
{
  "direction": "up" | "down" | "flat",
  "confidence": 0.0 to 1.0,
  "rational_price": <number or null>,
  "reasoning": "<one paragraph>"
}"""


def _build_prompt(symbol: str, market_data: dict) -> str:
    """Build the prompt for AI models given market data."""
    price = market_data.get("price", "N/A")
    change = market_data.get("change_pct", "N/A")
    volume = market_data.get("volume", "N/A")
    market_type = market_data.get("market_type", "unknown")

    return f"""Analyze the following market and predict the direction for the next 4 hours.

Symbol: {symbol}
Market Type: {market_type}
Current Price: {price}
24h Change: {change}%
Volume: {volume}

What is your directional judgment (up/down/flat), confidence (0-1), rational price estimate, and reasoning?"""


def _parse_vote(raw: dict, model_name: str) -> ModelVote:
    """Parse a raw AI response dict into a ModelVote."""
    direction_str = str(raw.get("direction", "flat")).lower().strip()
    if direction_str in ("up", "long", "bullish"):
        direction = Direction.UP
    elif direction_str in ("down", "short", "bearish"):
        direction = Direction.DOWN
    else:
        direction = Direction.FLAT

    confidence = float(raw.get("confidence", 0.3))
    confidence = max(0.0, min(1.0, confidence))

    rational_price = raw.get("rational_price")
    if rational_price is not None:
        try:
            rational_price = float(rational_price)
        except (TypeError, ValueError):
            rational_price = None

    reasoning = str(raw.get("reasoning", "No reasoning provided."))

    return ModelVote(
        model_name=raw.get("_model", model_name),
        direction=direction,
        confidence=confidence,
        rational_price=rational_price,
        reasoning=reasoning,
    )


def _compute_consensus(votes: list[ModelVote]) -> ConsensusResult:
    """Compute consensus from model votes.

    3/3 agree = high confidence
    2/3 agree = medium confidence
    all disagree = flat with low confidence
    """
    if not votes:
        return ConsensusResult(
            direction=Direction.FLAT,
            confidence=Confidence.LOW,
            confidence_score=0.0,
            rational_price=None,
            reasoning="No AI models responded.",
            model_votes=[],
        )

    # Count direction votes
    direction_counts: dict[Direction, int] = {}
    for v in votes:
        direction_counts[v.direction] = direction_counts.get(v.direction, 0) + 1

    # Find majority direction
    majority_dir = max(direction_counts, key=direction_counts.get)  # type: ignore[arg-type]
    majority_count = direction_counts[majority_dir]
    total = len(votes)

    # Determine confidence level
    if majority_count == total and total >= 3:
        conf = Confidence.HIGH
        conf_score = sum(v.confidence for v in votes) / total
    elif majority_count >= 2:
        conf = Confidence.MEDIUM
        conf_score = sum(v.confidence for v in votes if v.direction == majority_dir) / majority_count * 0.8
    elif total == 1:
        # Only one model responded — use its judgment with LOW confidence
        conf = Confidence.LOW
        conf_score = votes[0].confidence * 0.5
    else:
        # All disagree
        majority_dir = Direction.FLAT
        conf = Confidence.LOW
        conf_score = 0.3

    # Average rational price from agreeing models
    agreeing = [v for v in votes if v.direction == majority_dir]
    rational_prices = [v.rational_price for v in agreeing if v.rational_price is not None]
    avg_rational = sum(rational_prices) / len(rational_prices) if rational_prices else None

    # Combine reasoning
    reasonings = [f"[{v.model_name}] {v.reasoning}" for v in votes]
    combined_reasoning = " | ".join(reasonings)

    return ConsensusResult(
        direction=majority_dir,
        confidence=conf,
        confidence_score=round(conf_score, 3),
        rational_price=round(avg_rational, 4) if avg_rational is not None else None,
        reasoning=combined_reasoning,
        model_votes=votes,
    )


class AIConsensusPlugin(ReasoningPlugin):
    """Multi-model AI consensus reasoning plugin."""

    @property
    def name(self) -> str:
        return "ai-consensus"

    @property
    def display_name(self) -> str:
        return "AI Multi-Model Consensus"

    async def initialize(self, config: dict) -> None:
        pass

    async def analyze(self, context: dict) -> dict:
        """Analyze a single market and return consensus result.

        context should contain:
          - symbol: str
          - market_data: dict with price, change_pct, volume, market_type
        """
        symbol = context.get("symbol", "UNKNOWN")
        market_data = context.get("market_data", {})

        prompt = _build_prompt(symbol, market_data)
        raw_results = await call_all_models(prompt, system=SYSTEM_PROMPT)

        votes = []
        for i, raw in enumerate(raw_results):
            model = raw.get("_model", f"model-{i}")
            vote = _parse_vote(raw, model)
            votes.append(vote)

        consensus = _compute_consensus(votes)

        return {
            "symbol": symbol,
            "direction": consensus.direction.value,
            "confidence": consensus.confidence.value,
            "confidence_score": consensus.confidence_score,
            "rational_price": consensus.rational_price,
            "reasoning": consensus.reasoning,
            "model_votes": [
                {
                    "model_name": v.model_name,
                    "direction": v.direction.value,
                    "confidence": v.confidence,
                    "rational_price": v.rational_price,
                    "reasoning": v.reasoning,
                }
                for v in consensus.model_votes
            ],
            "deviation_pct": consensus.deviation_pct,
        }
