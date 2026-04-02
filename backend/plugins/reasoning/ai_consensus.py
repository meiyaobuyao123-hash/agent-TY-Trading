"""AI Consensus Reasoning — multi-model judgment with graceful degradation.

Calls DeepSeek + GPT-4o + Gemini in parallel, parses direction/confidence/reasoning
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

SYSTEM_PROMPT = """你是一位资深金融分析AI，精通加密货币、股票、外汇、大宗商品和宏观经济。你分析市场数据并给出方向性判断。

你的分析应考虑:
- 价格动量和趋势方向（结合近7日走势）
- 成交量模式（高成交量确认趋势，低成交量暗示弱势）
- 市场类型特征（加密货币24/7高波动，外汇跟随宏观周期，股票跟随财报/情绪）
- 基于价格水平的关键支撑/阻力位
- 市场状态（趋势 vs 震荡）

要果断。除非你确实看不到方向偏差，否则避免默认给出"flat"。24小时内2%+的变化是显著动量。

置信度指南:
- 0.7-1.0: 强信号，有明确的动量/催化剂
- 0.4-0.7: 中等信号，有些不确定性
- 0.1-0.4: 弱信号，指标矛盾

请仅返回有效的JSON（不要markdown，不要代码围栏）:
{
  "direction": "up" | "down" | "flat",
  "confidence": 0.0 to 1.0,
  "rational_price": <number or null>,
  "reasoning": "<用简体中文写2-3句精炼分析>"
}"""

# ── Market-type-specific prompt context ──────────────────────────
MARKET_TYPE_CONTEXT = {
    "crypto": (
        "这是加密货币市场，24/7全天候交易，波动性极高。"
        "注意BTC的联动效应——如果不是BTC本身，需要考虑BTC走势对该币的影响。"
        "关注链上数据趋势、市场情绪(恐慌/贪婪)和流动性变化。"
    ),
    "us-equities": (
        "这是美股市场，交易时间为美东时间9:30-16:00。"
        "关注财报季节因素、板块轮动、美联储政策预期和VIX恐慌指数。"
        "注意盘前盘后的价格发现信号。"
    ),
    "hk-equities": (
        "这是港股市场，交易时间为港时9:30-16:00。"
        "关注南向资金流向、中国政策面影响以及与A股的联动。"
        "注意汇率(USD/HKD)和中美关系对港股的影响。"
    ),
    "cn-equities": (
        "这是A股市场，交易时间为北京时间9:30-15:00，有涨跌停板限制(±10%/±20%)。"
        "关注政策面消息、北向资金流向、板块轮动和融资融券数据。"
        "注意大盘指数走势对个股的带动效应。"
    ),
    "forex": (
        "这是外汇市场，24小时交易(周末休市)。"
        "关注利率差异、央行政策方向(加息/降息预期)、地缘政治事件和贸易数据。"
        "注意技术面的关键心理价位和趋势通道。"
    ),
    "commodities": (
        "这是大宗商品市场。关注供需基本面动态: "
        "库存数据、产能变化、地缘政治风险、季节性因素和美元强弱。"
        "黄金还需关注避险需求和实际利率，原油关注OPEC+决议和全球经济前景。"
    ),
    "macro": (
        "这是宏观经济指标，不是可交易资产。分析指标值的趋势方向: "
        "指标是在上升还是下降？速度如何？与市场预期相比如何？"
        "关注指标对货币政策和资产价格的传导效应。"
    ),
    "global-indices": (
        "这是全球主要股指。关注宏观经济数据、央行政策、地缘政治局势。"
        "注意全球资金流向和跨市场联动(如美股对亚洲市场的影响)。"
        "指数走势反映整体市场情绪和经济预期。"
    ),
    "prediction-markets": (
        "这是预测市场，价格代表事件发生的概率(0-1)。"
        "分析时需考虑事件的最新进展、民调数据和市场流动性。"
    ),
}


def _build_prompt(
    symbol: str,
    market_data: dict,
    horizon_hours: int = 4,
    history_text: str = "",
    last_judgment: dict | None = None,
    market_context: dict | None = None,
) -> str:
    """Build the prompt for AI models given market data."""
    price = market_data.get("price", "N/A")
    change = market_data.get("change_pct", "N/A")
    volume = market_data.get("volume", "N/A")
    market_type = market_data.get("market_type", "unknown")

    horizon_label = f"{horizon_hours}h" if horizon_hours < 24 else f"{horizon_hours // 24}d"

    # Market-type-specific context
    type_context = MARKET_TYPE_CONTEXT.get(market_type, "")
    type_section = f"\n市场特征: {type_context}" if type_context else ""

    # Historical price section
    history_section = f"\n7日价格走势: {history_text}" if history_text else ""

    # Cross-market context section (L2 causal reasoning)
    cross_market_section = ""
    if market_context:
        lines = []
        for ctx_symbol, ctx_data in market_context.items():
            ctx_price = ctx_data.get("price", "N/A")
            ctx_change = ctx_data.get("change_pct", "N/A")
            lines.append(f"  {ctx_symbol}: 价格 {ctx_price}, 24h变化 {ctx_change}%")
        sentiment = market_context.get("_sentiment", "")
        if lines:
            cross_market_section = "\n\n【跨市场背景】请结合以下相关市场的走势进行因果推理:"
            cross_market_section += "\n" + "\n".join(lines)
            if sentiment:
                cross_market_section += f"\n  市场情绪概览: {sentiment}"

    # Self-evolution: feedback from last judgment
    evolution_section = ""
    if last_judgment:
        direction_cn = {"up": "看涨", "down": "看跌", "flat": "观望"}.get(
            last_judgment.get("direction", ""), last_judgment.get("direction", "")
        )
        result_cn = "正确" if last_judgment.get("is_correct") else "错误"
        conf = last_judgment.get("confidence_score", 0)
        reasoning_summary = (last_judgment.get("reasoning") or "")[:120]
        evolution_section = (
            f"\n\n【自我进化反馈】上次判断: {direction_cn} (置信度{conf:.0%}) — 结果: {result_cn}"
            f"\n上次分析: {reasoning_summary}"
            f"\n请反思上次判断{'的成功经验' if last_judgment.get('is_correct') else '的失误原因'}，并据此改进本次分析。"
        )

    return f"""分析以下市场并预测未来 {horizon_label} 的方向。

品种: {symbol}
市场类型: {market_type}
当前价格: {price}
24小时涨跌幅: {change}%
24小时成交量: {volume}
预测周期: {horizon_label}{type_section}{history_section}{cross_market_section}{evolution_section}

请给出方向判断(up/down/flat)、置信度(0-1)、合理价格目标，以及简体中文的精炼分析。"""


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

    3+/N agree = high confidence
    2/N agree = medium confidence
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
    if majority_count >= 3:
        conf = Confidence.HIGH
        conf_score = sum(v.confidence for v in votes if v.direction == majority_dir) / majority_count
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
        horizon_hours = context.get("horizon_hours", 4)
        history_text = context.get("history_text", "")
        last_judgment = context.get("last_judgment")
        market_context = context.get("market_context")

        prompt = _build_prompt(symbol, market_data, horizon_hours, history_text, last_judgment, market_context)
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
