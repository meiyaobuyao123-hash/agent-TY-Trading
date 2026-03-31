"""Tests for the AI consensus reasoning plugin."""

from __future__ import annotations

import pytest

from backend.core.types import Confidence, Direction, ModelVote
from backend.plugins.reasoning.ai_consensus import (
    AIConsensusPlugin,
    _build_prompt,
    _compute_consensus,
    _parse_vote,
)


class TestParseVote:

    def test_parse_up(self):
        raw = {"direction": "up", "confidence": 0.8, "rational_price": 68000, "reasoning": "bullish"}
        vote = _parse_vote(raw, "test-model")
        assert vote.direction == Direction.UP
        assert vote.confidence == 0.8
        assert vote.rational_price == 68000

    def test_parse_down(self):
        raw = {"direction": "short", "confidence": 0.7, "reasoning": "bearish"}
        vote = _parse_vote(raw, "test")
        assert vote.direction == Direction.DOWN

    def test_parse_flat(self):
        raw = {"direction": "neutral", "confidence": 0.5, "reasoning": "sideways"}
        vote = _parse_vote(raw, "test")
        assert vote.direction == Direction.FLAT

    def test_parse_invalid_confidence_clamped(self):
        raw = {"direction": "up", "confidence": 1.5, "reasoning": "test"}
        vote = _parse_vote(raw, "test")
        assert vote.confidence == 1.0

    def test_parse_missing_fields(self):
        raw = {}
        vote = _parse_vote(raw, "test")
        assert vote.direction == Direction.FLAT
        assert vote.confidence == 0.3

    def test_parse_invalid_rational_price(self):
        raw = {"direction": "up", "rational_price": "not-a-number", "reasoning": "test"}
        vote = _parse_vote(raw, "test")
        assert vote.rational_price is None


class TestComputeConsensus:

    def test_unanimous_up(self):
        votes = [
            ModelVote("claude", Direction.UP, 0.9, 68000, "bull"),
            ModelVote("gpt-4o", Direction.UP, 0.85, 67500, "bull"),
            ModelVote("gemini", Direction.UP, 0.8, 68500, "bull"),
        ]
        result = _compute_consensus(votes)
        assert result.direction == Direction.UP
        assert result.confidence == Confidence.HIGH
        assert result.rational_price is not None
        assert 67000 < result.rational_price < 69000

    def test_majority_up(self):
        votes = [
            ModelVote("claude", Direction.UP, 0.9, 68000, "bull"),
            ModelVote("gpt-4o", Direction.UP, 0.85, None, "bull"),
            ModelVote("gemini", Direction.DOWN, 0.6, 65000, "bear"),
        ]
        result = _compute_consensus(votes)
        assert result.direction == Direction.UP
        assert result.confidence == Confidence.MEDIUM

    def test_all_disagree(self):
        votes = [
            ModelVote("claude", Direction.UP, 0.9, 68000, "bull"),
            ModelVote("gpt-4o", Direction.DOWN, 0.85, 65000, "bear"),
            ModelVote("gemini", Direction.FLAT, 0.5, 67000, "flat"),
        ]
        result = _compute_consensus(votes)
        assert result.confidence == Confidence.LOW

    def test_empty_votes(self):
        result = _compute_consensus([])
        assert result.direction == Direction.FLAT
        assert result.confidence == Confidence.LOW
        assert result.confidence_score == 0.0

    def test_single_vote(self):
        votes = [ModelVote("claude", Direction.UP, 0.9, 68000, "bull")]
        result = _compute_consensus(votes)
        assert result.direction == Direction.UP
        assert result.confidence == Confidence.LOW  # Single vote = low confidence
        assert result.confidence_score == 0.45  # 0.9 * 0.5


class TestBuildPrompt:

    def test_prompt_contains_symbol(self):
        prompt = _build_prompt("BTC-USD", {"price": 67000, "change_pct": 2.5})
        assert "BTC-USD" in prompt
        assert "67000" in prompt

    def test_prompt_handles_missing_data(self):
        prompt = _build_prompt("TEST", {})
        assert "TEST" in prompt
        assert "N/A" in prompt


class TestAIConsensusPlugin:

    @pytest.mark.asyncio
    async def test_plugin_properties(self):
        plugin = AIConsensusPlugin()
        assert plugin.name == "ai-consensus"
        assert plugin.display_name == "AI Multi-Model Consensus"

    @pytest.mark.asyncio
    async def test_analyze_no_api_keys(self):
        """With no API keys set, all model calls fail gracefully -> flat/low."""
        plugin = AIConsensusPlugin()
        await plugin.initialize({})
        result = await plugin.analyze({
            "symbol": "BTC-USD",
            "market_data": {"price": 67000},
        })
        assert result["direction"] == "flat"
        assert result["confidence"] == "low"
