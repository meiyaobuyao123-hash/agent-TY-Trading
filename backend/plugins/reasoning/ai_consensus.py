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

你的分析必须做到:
1. 提及具体价格水平（支撑位/阻力位），用数字说话
2. 引用当前的量价关系来佐证判断
3. 基于市场类型给出针对性分析（而非泛泛而谈）
4. 给出明确的价格目标（rational_price必须填写具体数字）
5. 即使数据有限，也要基于已有价格和走势做出最佳判断，不要回避
6. 如果提供了技术指标(RSI/SMA/波动率)，必须在分析中引用它们

严禁:
- 说"数据不足无法判断" — 只要有价格就有趋势可分析
- 给出空泛的、适用于任何市场的通用分析

【关键校准规则 — 你的准确率取决于此】
1. 短期预测(4h)中，大多数资产的价格变化在噪声范围内。如果24h涨跌幅小于该市场类型的显著动量阈值，大概率应该预测"flat"。
2. 不要被"感觉"误导。仅因为近期跌了就预测继续跌、涨了就预测继续涨，是最常见的错误(趋势延续偏差)。
3. flat是一个合理的预测！在4小时窗口内，加密货币需要>1.5%的波动才算非flat，大多数时候市场是flat的。
4. 置信度校准：如果你不确定方向，给出flat并分配合理的概率分布(如up=0.35, down=0.30, flat=0.35)比强行选方向好得多。

动量判断基准(低于此阈值通常应选flat):
- 加密货币: 4h内变化>1.5%为显著动量(24h>3%)
- 股票/指数: 24h变化>0.8%为显著动量
- 外汇: 24h变化>0.3%为显著动量
- 大宗商品: 24h变化>1%为显著动量

置信度指南:
- 0.6-0.8: 强信号，明确的趋势+技术指标确认+量价配合
- 0.4-0.6: 中等信号，有一定依据但不完全确认
- 0.2-0.4: 弱信号，多空指标矛盾，倾向flat
- 注意: 不要给出>0.8的置信度，除非有极其明确的证据

请仅返回有效的JSON（不要markdown，不要代码围栏）:
{
  "direction": "up" | "down" | "flat",
  "up_probability": 0.0 to 1.0,
  "down_probability": 0.0 to 1.0,
  "flat_probability": 0.0 to 1.0,
  "confidence": 0.0 to 1.0,
  "rational_price": <必须填写具体数字，不能等于当前价格，至少偏移0.1%>,
  "reasoning": "<用简体中文写2-3句精炼分析，必须包含具体价格水平和技术指标>"
}

注意: up_probability + down_probability + flat_probability 应该等于1.0。
confidence应等于direction对应方向的概率值。
例如direction为"up"时，confidence应等于up_probability。
rational_price必须反映你对合理估值的独立判断，不能简单复制当前价格。"""

# ── Market-type-specific prompt context ──────────────────────────
MARKET_TYPE_CONTEXT = {
    "crypto": (
        "这是加密货币市场，24/7全天候交易。"
        "\n\n"
        "【!!! 最高优先级 — 你必须先读完这段再作答 !!!】\n"
        "你的加密货币预测准确率只有15%。原因已确认：你几乎总是预测'down'，但实际价格在4小时内很少大跌。\n"
        "统计事实：加密货币4小时内70%的时间变化<1.5%，即结果为flat。\n\n"
        "===== 硬编码决策树(必须严格按此执行，不允许偏离) =====\n"
        "第1步：检查24h涨跌幅绝对值\n"
        "  - 如果|24h涨跌幅| <= 2%  =>  direction='flat'  (这是70%情况的正确答案)\n"
        "  - 如果|24h涨跌幅| 在 2%-5% => direction='flat'  (仍然倾向flat)\n"
        "  - 仅当|24h涨跌幅| > 5%    => 进入第2步\n\n"
        "第2步(仅|24h涨跌幅|>5%时)：\n"
        "  - 涨>5%: direction='up', confidence=0.5\n"
        "  - 跌>5%: direction='flat' (跌多了反弹概率高，不要追跌)\n\n"
        "第3步：RSI修正(仅当RSI数据可用时)\n"
        "  - RSI>70: direction='down', confidence=0.45\n"
        "  - RSI<30: direction='up', confidence=0.45\n\n"
        "===== 绝对禁止 =====\n"
        "- 禁止因为微跌(-3%到0%)就预测'down'\n"
        "- 禁止在|24h涨跌幅|<=2%时预测非flat方向\n"
        "- 当你预测flat时: confidence=0.45, up=0.28, down=0.27, flat=0.45\n"
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
    "etf": (
        "这是ETF基金，跟踪特定指数、行业或资产类别。"
        "分析时需关注其跟踪的底层资产走势、资金流入流出、折溢价率。"
        "SPY/QQQ跟踪美股大盘，GLD/SLV跟踪贵金属，TLT跟踪长期国债，EEM/VWO跟踪新兴市场。"
        "ETF的方向通常与其底层资产高度一致，关注宏观因素和板块轮动。"
    ),
    "jp-equities": (
        "这是日本股市，交易时间为东京时间9:00-15:00(中午休市11:30-12:30)。"
        "关注日银(BOJ)利率政策和日元汇率走势对出口型企业的影响。"
        "日经225指数是关键参考。日本企业注重公司治理改革(东证改革)，外资持续流入。"
        "丰田、索尼等出口龙头受日元贬值利好，Keyence等高端制造关注订单周期。"
    ),
    "eu-equities": (
        "这是欧洲股市，主要交易时间为欧洲中部时间9:00-17:30。"
        "关注欧央行(ECB)利率决策、欧元汇率、能源价格和地缘政治局势。"
        "SAP是欧洲最大科技股，ASML是全球光刻机垄断者，LVMH是奢侈品龙头。"
        "欧洲企业受能源成本和中国需求影响较大，注意欧美经济周期差异。"
    ),
    "kr-equities": (
        "这是韩国股市(KOSPI/KOSDAQ)，交易时间为韩国时间9:00-15:30。"
        "关注半导体周期(三星/SK海力士占全球DRAM/NAND主要份额)、韩元汇率和外资流向。"
        "韩国经济高度依赖出口，特别是半导体、汽车和电池产业。"
        "三星电子是全球最大存储芯片厂商，LG新能源是全球电动车电池龙头，现代汽车是韩国最大车企。"
        "关注中美科技博弈对韩国半导体出口的影响以及韩日经贸关系。"
    ),
    "in-equities": (
        "这是印度股市(NSE/BSE)，交易时间为印度时间9:15-15:30。"
        "印度是全球第五大经济体，GDP增速领先全球主要经济体。"
        "关注印度央行(RBI)利率政策、卢比汇率、外资流入(FPI)和国内消费趋势。"
        "Reliance是印度最大企业(涵盖能源、零售、电信)，TCS/Infosys是全球IT外包龙头。"
        "HDFC Bank是印度最大私营银行，Bharti Airtel是印度最大电信运营商。"
        "印度市场受益于人口红利和数字化转型，但需关注估值水平和地缘政治风险。"
    ),
    "latam-equities": (
        "这是拉丁美洲股票，多数在美国NYSE上市(ADR)。"
        "关注拉美各国通胀率、利率周期、汇率波动和大宗商品价格(巴西铁矿石/石油、阿根廷农产品)。"
        "MELI是拉美电商龙头(类似亚马逊)，NU是巴西最大数字银行。"
        "PBR(巴西石油)与油价高度联动，VALE(淡水河谷)是全球最大铁矿石生产商。"
        "ITUB/BBD是巴西最大银行，受巴西央行利率和汇率影响。"
        "拉美市场波动性较大，政治风险和货币贬值是主要风险因素。"
    ),
    "mena-equities": (
        "这是中东/非洲股票。"
        "2222.SR(沙特阿美)是全球最大石油公司，利润直接与油价挂钩。"
        "GFI(Gold Fields)是南非黄金矿业公司，股价与金价高度联动。"
        "关注OPEC+产量政策、地缘政治风险(中东局势)和全球能源转型趋势。"
        "新兴市场资金流向和美元强弱也会影响这些市场。"
    ),
    "sg-equities": (
        "这是新加坡股市(SGX)，交易时间为新加坡时间9:00-17:00。"
        "新加坡是亚洲金融中心，银行股(DBS/OCBC/UOB三大行)占据市场主导地位。"
        "关注新加坡金管局(MAS)货币政策、东南亚经济增长和全球贸易流向。"
        "DBS是东南亚最大银行，OCBC和UOB分列第二和第三。"
        "银行股受益于利率上升周期，但需关注资产质量和区域风险敞口。"
    ),
    "tw-equities": (
        "这是台湾股市(TWSE)，交易时间为台北时间9:00-13:30。"
        "台湾是全球半导体制造中心，台积电(2330)市值占台股约三成。"
        "关注全球半导体周期、AI芯片需求、地缘政治风险(台海局势)和外资动向。"
        "台积电是全球最大晶圆代工厂，鸿海(2317)是全球最大电子代工厂。"
        "联发科(2454)是全球主要手机芯片设计公司。台湾经济高度依赖科技出口。"
    ),
}


def _build_prompt(
    symbol: str,
    market_data: dict,
    horizon_hours: int = 4,
    history_text: str = "",
    last_judgment: dict | None = None,
    market_context: dict | None = None,
    fear_greed: dict | None = None,
    market_breadth: dict | None = None,
    genome_hint: str = "",
    tech_indicators_text: str = "",
    mcap_text: str = "",
    propagation_text: str = "",
    macro_text: str = "",
    regime_text: str = "",
    meta_insight_hint: str = "",
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
            if ctx_symbol.startswith("_") or not isinstance(ctx_data, dict):
                continue
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

    # Fear & Greed section (crypto only)
    fear_greed_section = ""
    if fear_greed:
        fng_value = fear_greed.get("value", 50)
        fng_label = fear_greed.get("label", "中性")
        fear_greed_section = f"\n加密市场恐慌贪婪指数: {fng_value} ({fng_label})"
        if fng_value <= 25:
            fear_greed_section += "\n注意: 极度恐慌通常是逆向买入机会，恐慌往往过度。"
        elif fng_value >= 75:
            fear_greed_section += "\n注意: 极度贪婪通常预示回调风险，贪婪往往过度。"

    # Market breadth section
    breadth_section = ""
    if market_breadth:
        mood = market_breadth.get("mood", "中性")
        up_pct = market_breadth.get("up_pct", 50)
        breadth_section = f"\n市场情绪广度: {up_pct:.0f}%市场上涨 — 情绪: {mood}"

    # Technical indicators section (R14)
    tech_section = f"\n{tech_indicators_text}" if tech_indicators_text else ""

    # Market cap section (R14 crypto)
    mcap_section = f"\n{mcap_text}" if mcap_text else ""

    # Signal propagation section (L2)
    propagation_section = f"\n\n【信号传导】{propagation_text}" if propagation_text else ""

    # Macro calendar section (L2)
    macro_section = f"\n\n【宏观日历】\n{macro_text}" if macro_text else ""

    # Market regime section (L2)
    regime_section = f"\n{regime_text}" if regime_text else ""

    # Strategy genome section (L4 self-evolution)
    genome_section = f"\n\n{genome_hint}" if genome_hint else ""

    # Meta-learning section (L4 self-awareness)
    meta_section_prompt = f"\n\n{meta_insight_hint}" if meta_insight_hint else ""

    return f"""分析以下市场并预测未来 {horizon_label} 的方向。

品种: {symbol}
市场类型: {market_type}
当前价格: {price}
24小时涨跌幅: {change}%
24小时成交量: {volume}
预测周期: {horizon_label}{type_section}{tech_section}{regime_section}{mcap_section}{history_section}{fear_greed_section}{breadth_section}{cross_market_section}{propagation_section}{macro_section}{evolution_section}{genome_section}{meta_section_prompt}

请给出方向判断(up/down/flat)、置信度(0-1)、合理价格目标，以及简体中文的精炼分析。
提醒: 如果技术指标未显示极端信号，且24h涨跌幅在噪声范围内，flat是合理选择。"""


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

    # Parse probabilities (R13 ensemble approach)
    up_prob = _safe_float(raw.get("up_probability"))
    down_prob = _safe_float(raw.get("down_probability"))
    flat_prob = _safe_float(raw.get("flat_probability"))

    # If probabilities are provided, normalize them to sum to 1.0
    if up_prob is not None and down_prob is not None and flat_prob is not None:
        total = up_prob + down_prob + flat_prob
        if total > 0:
            up_prob = up_prob / total
            down_prob = down_prob / total
            flat_prob = flat_prob / total
    elif up_prob is None and down_prob is None and flat_prob is None:
        # Derive from direction and confidence
        if direction == Direction.UP:
            up_prob = confidence
            remaining = 1.0 - confidence
            down_prob = remaining * 0.6
            flat_prob = remaining * 0.4
        elif direction == Direction.DOWN:
            down_prob = confidence
            remaining = 1.0 - confidence
            up_prob = remaining * 0.6
            flat_prob = remaining * 0.4
        else:
            flat_prob = confidence
            remaining = 1.0 - confidence
            up_prob = remaining * 0.5
            down_prob = remaining * 0.5

    rational_price = raw.get("rational_price")
    if rational_price is not None:
        try:
            rational_price = float(rational_price)
        except (TypeError, ValueError):
            rational_price = None

    reasoning = str(raw.get("reasoning", "No reasoning provided."))

    vote = ModelVote(
        model_name=raw.get("_model", model_name),
        direction=direction,
        confidence=confidence,
        rational_price=rational_price,
        reasoning=reasoning,
    )
    # Attach probabilities as extra attributes
    vote.up_probability = up_prob  # type: ignore[attr-defined]
    vote.down_probability = down_prob  # type: ignore[attr-defined]
    vote.flat_probability = flat_prob  # type: ignore[attr-defined]
    return vote


def _safe_float(val) -> float | None:
    """Safely convert a value to float, returning None on failure."""
    if val is None:
        return None
    try:
        return max(0.0, min(1.0, float(val)))
    except (TypeError, ValueError):
        return None


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

    # Aggregate probabilities across all votes (R13)
    n = len(votes)
    avg_up = sum(getattr(v, 'up_probability', 0.0) or 0.0 for v in votes) / n
    avg_down = sum(getattr(v, 'down_probability', 0.0) or 0.0 for v in votes) / n
    avg_flat = sum(getattr(v, 'flat_probability', 0.0) or 0.0 for v in votes) / n

    result = ConsensusResult(
        direction=majority_dir,
        confidence=conf,
        confidence_score=round(conf_score, 3),
        rational_price=round(avg_rational, 4) if avg_rational is not None else None,
        reasoning=combined_reasoning,
        model_votes=votes,
    )
    # Attach aggregate probabilities
    result.up_probability = round(avg_up, 3)  # type: ignore[attr-defined]
    result.down_probability = round(avg_down, 3)  # type: ignore[attr-defined]
    result.flat_probability = round(avg_flat, 3)  # type: ignore[attr-defined]
    return result


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
        fear_greed = context.get("fear_greed")
        market_breadth = context.get("market_breadth")

        genome_hint = context.get("genome_hint", "")
        tech_indicators_text = context.get("tech_indicators_text", "")
        mcap_text = context.get("mcap_text", "")
        propagation_text = context.get("propagation_text", "")
        macro_text = context.get("macro_text", "")
        regime_text = context.get("regime_text", "")
        meta_insight_hint = context.get("meta_insight_hint", "")

        prompt = _build_prompt(
            symbol, market_data, horizon_hours, history_text,
            last_judgment, market_context, fear_greed, market_breadth,
            genome_hint, tech_indicators_text, mcap_text,
            propagation_text, macro_text, regime_text,
            meta_insight_hint,
        )
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
            "up_probability": getattr(consensus, 'up_probability', None),
            "down_probability": getattr(consensus, 'down_probability', None),
            "flat_probability": getattr(consensus, 'flat_probability', None),
            "model_votes": [
                {
                    "model_name": v.model_name,
                    "direction": v.direction.value,
                    "confidence": v.confidence,
                    "rational_price": v.rational_price,
                    "reasoning": v.reasoning,
                    "up_probability": getattr(v, 'up_probability', None),
                    "down_probability": getattr(v, 'down_probability', None),
                    "flat_probability": getattr(v, 'flat_probability', None),
                }
                for v in consensus.model_votes
            ],
            "deviation_pct": consensus.deviation_pct,
        }
