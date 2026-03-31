现在我已掌握全部背景。用户在金融软件开发方面有丰富的经验（Flutter 应用搭配 AI agent，基金/股票追踪，376 个测试全部通过）。这个新的 "agent TY Trading" 仓库是一个全新项目，目标远比之前宏大。让我来设计一份全面的架构方案。

---

# 世界模型金融智能系统 -- 架构蓝图

## 项目代号: TY (天演 -- Natural Evolution)

---

## 1. 哲学基础

### 1.1 统一原则：市场作为信息处理系统

所有金融市场——股票、加密货币、外汇、大宗商品、预测市场、债券——都是同一个抽象系统的实例：**不确定性下的分布式信念聚合**。市场价格不是关于世界的事实；它是数百万参与者在私有信息、认知局限和策略博弈激励下更新信念后的压缩输出。

三个数学框架统一了所有市场：

**Information Theory (Shannon, 1948)。** 市场价格编码了信息。其核心量是**信息量（surprisal）**：`I(event) = -log2(P(event))`。当新信息到达时，价格的变动幅度与其携带的信息量成正比。市场已经预期的事件（P 接近 1）对价格影响很小；真正出人意料的事件则会引发巨大波动。核心交易洞见：**利润来自于在市场之前正确估计信息量**。如果你知道市场对某一事件的隐含概率是错误的，你就有了优势。

形式化来看，市场对一项资产的定价可以被建模为市场对未来现金流的后验分布。你的优势就是你的后验分布与市场后验分布之间的 KL-divergence：`D_KL(P_you || P_market)`。当这个散度很大，且你更接近真相时，就存在可提取的利润。

**Game Theory (Nash/Harsanyi)。** 市场是不完全信息博弈。每个参与者都拥有私有信号并进行策略性行为。市场价格不一定是"正确的"价格——它是策略行为的 Nash 均衡。这意味着即使所有参与者都是理性的，价格也可能是错误的，因为均衡取决于每个参与者对其他人信念的信念（Keynes 的选美比赛）。系统必须对这种递归的信念结构进行建模。

**Bayesian Inference。** 给定证据后更新信念的正确方式。系统维护关于假设的显式概率分布，并使用 Bayes 规则进行更新：`P(H|E) = P(E|H) * P(H) / P(E)`。至关重要的是，这意味着需要维护先验（包括关于模型不确定性的先验），跟踪似然比，且永远不要折叠成点估计。

### 1.2 因果性 vs. 相关性

系统对以下两者做出严格区分：
- **相关性**：X 和 Y 在历史上协同变动。这并不能告诉你对 X 进行干预是否会影响 Y。
- **因果性**：改变 X *产生* Y 的变化，通过特定机制传导。

遵循 Judea Pearl 的层次体系：
1. **关联**（观察）：P(Y|X) -- 大多数 ML 模型止步于此
2. **干预**（行动）：P(Y|do(X)) -- 如果我们*强制*改变 X 会发生什么？
3. **反事实**（想象）：P(Y_x|X', Y') -- *本来会*发生什么？

仅基于相关性进行交易是脆弱的。当市场体制（regime）发生变化时，相关性会崩溃。基于因果机制进行交易是稳健的，因为你理解事物变动的*原因*。

示例：如果铜价上涨，这是否导致建筑股下跌（投入成本增加），还是两者都在对共同原因（经济扩张）做出响应？交易决策因因果结构不同而完全相反。

### 1.3 反身性 (Soros)

市场不是被动的测量设备。市场价格会*改变它们所测量的事物*。这就是 Soros 的反身性原理，形式化为：

```
x(t+1) = f(x(t), beliefs(t))
beliefs(t+1) = g(x(t+1), beliefs(t))
```

其中 `x` 是基本面价值，`beliefs` 是市场参与者的信念。这创造了一个反馈循环。关键推论：
- 泡沫和崩盘不是异常现象；它们是反身性系统的固有属性
- 系统不仅需要建模"正确的价格是什么"，还要建模"其他人相信什么，以及他们的信念将如何改变基本面"
- 最大的机会就在这里：当反身性反馈循环即将断裂时

### 1.4 认知偏差作为市场无效性

人类的认知偏差不是随机噪声——它们是系统性的、可预测的、持续存在的。它们创造了数学系统可以利用的定价错误：

| 偏差 | 市场表现 | 可利用的模式 |
|------|---------|-------------|
| **Anchoring（锚定效应）** | 尽管有新信息，价格仍停留在近期水平附近 | 对盈利修正的缓慢调整 |
| **Availability（可得性偏差）** | 过度加权近期/生动事件 | 崩盘后定价偏低，上涨后定价偏高 |
| **Herding（羊群效应）** | 拥挤交易，动量过冲 | 极端持仓后的均值回归 |
| **Loss aversion（损失厌恶）** | 处置效应（持有亏损、卖出盈利） | 税损卖出的季节性，对坏消息的延迟反应 |
| **Narrative fallacy（叙事谬误）** | "故事股"定价过高 | 基本面价值 vs. 叙事溢价的背离 |
| **Recency bias（近因偏差）** | 外推近期趋势 | 对短期数据的过度反应 |
| **Time preference（时间偏好）** | 对未来事件的双曲折现 | 长期期权定价偏低 |
| **Dunning-Kruger（达克效应）** | 散户对 meme 股的过度自信 | 做衰极端散户情绪 |

---

## 2. 系统架构（4 层）

### 架构概览

```
                          +-----------------------+
                          |   Self-Evolver (L4)   |
                          | Strategy Genome Pool  |
                          | Natural Selection     |
                          | Meta-Cognition        |
                          +----------+------------+
                                     |
                          +----------v------------+
                          | Cognitive Bias Hunter  |
                          |       (L3)            |
                          | Rational Price Calc   |
                          | Edge Detection        |
                          | Position Sizing       |
                          +----------+------------+
                                     |
                          +----------v------------+
                          | Causal Reasoning      |
                          |    Engine (L2)        |
                          | SCM / DAGs            |
                          | Bayesian Networks     |
                          | Counterfactuals       |
                          +----------+------------+
                                     |
                          +----------v------------+
                          | World Perceiver (L1)  |
                          | Data Ingestion        |
                          | Curiosity Search      |
                          | Novelty Scoring       |
                          +-----------------------+
                                     |
                    [Markets / News / Data / World]
```

### 第一层：World Perceiver（世界感知器）

**目标**：自主发现、采集和评分来自所有市场和数据源的信息。

**核心原则**：好奇心驱动的搜索。系统不是被动地消费固定的数据流。它根据预期最高信息价值来主动决定关注什么。

#### 1.1 数据源分类

```
Tier 1（实时，结构化）：
  - 市场数据源：价格、成交量、订单簿深度
  - 经济数据发布：CPI、GDP、就业、PMI
  - 央行通讯：利率决议、会议纪要、演讲
  - 公司文件：财报、10-K/Q、内部人交易

Tier 2（准实时，半结构化）：
  - 新闻通讯社：Reuters、Bloomberg、新华社、TASS
  - 社交媒体：Twitter/X 金融账户、Reddit（WSB、加密货币板块）
  - 预测市场：Polymarket、Metaculus、PredictIt
  - 政府政策文件：Federal Register、欧盟法规

Tier 3（延迟，非结构化）：
  - 学术论文：arXiv（quant-fin、econ）、SSRN、NBER
  - 供应链数据：航运舱单、港口拥堵
  - 卫星/另类数据：停车场车辆计数、石油库存
  - 专利申请、招聘信息（领先指标）
```

#### 1.2 注意力机制（关注什么）

系统使用**期望信息增益**公式来决定如何分配注意力：

```
attention_score(source) = E[KL(posterior || prior)] * relevance(source, active_hypotheses) * (1 / cost(source))
```

其中：
- `E[KL(posterior || prior)]` = 查询该数据源的期望信息增益
- `relevance` = 该数据源影响当前活跃假设的可能性
- `cost` = 访问该数据源的计算/资金成本

这被实现为一个优先级队列。历史上提供了高信息增益数据的来源会被优先排序。系统从未检查过的来源会获得一个探索奖励（Upper Confidence Bound 风格）。

#### 1.3 新颖性评分（"市场已经消化了这个信息吗？"）

每条信息都会获得一个新颖性评分：

```python
def novelty_score(info, market_state):
    # 1. 这条信息是否已经公开可用？
    public_duration = time_since_first_public(info)

    # 2. 发布以来市场变动了多少？
    market_reaction = price_change_since(info.publication_time)

    # 3. 相对于共识，内容有多出人意料？
    content_surprisal = -log2(P(info.content | consensus))

    # 4. 新颖性随时间和市场反应呈指数衰减
    novelty = content_surprisal * exp(-decay_rate * public_duration) * (1 - abs(market_reaction) / expected_reaction)

    return novelty
```

关键洞见：既出人意料*又*尚未被市场反应的信息是最有价值的。

#### 1.4 实现组件

```
world_perceiver/
  connectors/
    market_data/        # WebSocket 数据源：Binance、IBKR、polygon.io
    news/               # RSS、API、网页抓取管道
    social/             # Twitter API、Reddit API、情绪提取
    alternative/        # 卫星、航运、网络流量
    prediction_markets/ # Polymarket、Metaculus API
  attention/
    priority_queue.py   # 期望信息增益排序
    exploration.py      # UCB 探索奖励，用于未知来源
    budget_manager.py   # API 成本跟踪和分配
  processing/
    deduplication.py    # 跨来源语义去重
    entity_linking.py   # 将提及映射到规范实体
    novelty_scorer.py   # 信息新颖性评分
    embedding_store.py  # 语义搜索的向量存储
  output/
    information_stream.py  # 经评分的信息项统一流
```

### 第二层：Causal Reasoning Engine（因果推理引擎）

**目标**：构建和维护关于世界运作方式的因果模型。利用它们进行预测、干预分析和反事实推理。

#### 2.1 Structural Causal Models (SCMs)

系统维护一个因果 DAG（Directed Acyclic Graphs，有向无环图）库，用于表示已知的因果机制。这些图不是纯粹从数据中学习的（数据只能发现相关性），而是从领域知识中构建，再通过数据进行精炼。

系统应建模的因果链示例：

```
因果链 1：地缘政治 → 能源 → 一切
  地缘政治紧张 → 石油供应中断 → 能源价格飙升
    → 运输成本 → 消费者价格 → 央行应对
    → 利率 → 资产价格（股票、债券、房地产）

因果链 2：气候 → 农业 → 通胀
  El Nino/La Nina → 作物产量 → 食品大宗商品价格
    → CPI 食品分项 → 总体通胀 → 政策应对

因果链 3：科技 → 劳动力 → 消费
  AI 能力 → 工作自动化 → 就业变化
    → 消费者支出 → 企业收入 → 股票价格

因果链 4：中国房地产 → 全球大宗商品
  中国房地产新开工 → 钢铁/铜/水泥需求
    → 大宗商品价格 → 新兴市场货币
    → 全球风险偏好
```

#### 2.2 Pearl's do-calculus 实现

```python
class CausalModel:
    def __init__(self, dag: nx.DiGraph, structural_equations: Dict):
        self.dag = dag
        self.equations = structural_equations

    def observe(self, variable, value):
        """P(Y | X=x) -- 基于观察的条件化"""
        # 标准 Bayesian 条件化
        return self.posterior(variable, value)

    def intervene(self, variable, value):
        """P(Y | do(X=x)) -- 干预（切断入边）"""
        # 移除干预变量的所有入边
        mutilated_dag = self.dag.copy()
        mutilated_dag.remove_edges_from(
            [(parent, variable) for parent in self.dag.predecessors(variable)]
        )
        # 将变量设为固定值
        return self.evaluate(mutilated_dag, {variable: value})

    def counterfactual(self, evidence, intervention, query):
        """P(Y_x | X'=x', Y'=y') -- 本来会发生什么？"""
        # 步骤 1：溯因 - 从证据推断外生变量
        exogenous = self.abduct(evidence)
        # 步骤 2：干预 - 在模型中进行干预
        modified = self.intervene_model(intervention)
        # 步骤 3：预测 - 通过修改后的模型传播
        return modified.predict(query, exogenous)
```

#### 2.3 Bayesian Belief Networks

系统维护一个关于市场相关假设的 Bayesian 网络：

```python
class BeliefNetwork:
    def __init__(self):
        self.hypotheses = {}  # {name: prior_probability}
        self.evidence_log = []

    def add_hypothesis(self, name: str, prior: float, causal_links: List):
        """注册一个假设及其先验和因果连接"""
        self.hypotheses[name] = {
            'prior': prior,
            'posterior': prior,
            'evidence_history': [],
            'causal_links': causal_links
        }

    def update(self, evidence: Evidence):
        """对所有受影响的假设进行 Bayesian 更新"""
        for h_name, h in self.hypotheses.items():
            likelihood_ratio = self.compute_likelihood_ratio(evidence, h_name)
            # Bayes 更新：后验几率 = 先验几率 * 似然比
            prior_odds = h['posterior'] / (1 - h['posterior'])
            posterior_odds = prior_odds * likelihood_ratio
            h['posterior'] = posterior_odds / (1 + posterior_odds)
            h['evidence_history'].append((evidence, likelihood_ratio))

    def get_confidence(self, hypothesis: str) -> Tuple[float, float]:
        """返回 (概率, 校准不确定性)"""
        h = self.hypotheses[hypothesis]
        # 跟踪校准：过去的概率预测实际结果的准确度如何？
        calibration = self.calibration_score(h['evidence_history'])
        return h['posterior'], calibration
```

#### 2.4 跨市场因果图

最强大的能力：检测跨越市场边界的因果链。

```
示例：巴拿马运河干旱 (2023-24)
  降雨量低 → 运河水位下降
    → 通行限制 → 航运延误
      → LNG 送达亚洲延迟 → 亚洲天然气价格上涨
      → 集装箱航运改道绕行非洲 → 航程延长
        → 航运费率上涨 → ZIM、Maersk 股票价格
        → 商品进口成本增加 → 零售利润率压缩

系统应检测到：
  1. 天气数据（卫星） → 运河通行数据（另类数据）
  2. 运河通行 → 航运费率（大宗商品）
  3. 航运费率 → 个别股票、通胀预期
  4. 时序：天气信号在市场影响之前数周到达
```

#### 2.5 反身性建模

```python
class ReflexivityDetector:
    """检测和建模自我强化的反馈循环"""

    def detect_feedback_loop(self, asset, timeframe):
        """
        寻找：价格变动 → 信念变化 → 基本面变化 → 价格变动
        """
        # 测量以下两者的相关性：
        # 1. 价格变化和情绪变化（信念 → 价格）
        # 2. 价格变化和基本面变化（价格 → 现实）

        price_to_sentiment = self.granger_causality(
            asset.price_returns, asset.sentiment_changes, max_lag=5
        )
        price_to_fundamentals = self.granger_causality(
            asset.price_returns, asset.fundamental_changes, max_lag=20
        )

        if price_to_sentiment.is_significant and price_to_fundamentals.is_significant:
            return ReflexiveLoop(
                asset=asset,
                direction='positive' if price_to_fundamentals.coefficient > 0 else 'negative',
                strength=min(price_to_sentiment.strength, price_to_fundamentals.strength),
                estimated_duration=self.estimate_loop_duration(asset, timeframe)
            )
```

#### 2.6 实现组件

```
causal_engine/
  models/
    structural_causal_model.py  # Pearl's SCM 实现
    bayesian_network.py         # 带 Bayes 更新的信念网络
    causal_graph_library.py     # 预构建的领域因果图
  inference/
    do_calculus.py              # 干预查询
    counterfactual.py           # 反事实推理
    granger_causality.py        # 时间序列因果发现
    transfer_entropy.py         # 信息论因果性
  discovery/
    pc_algorithm.py             # 基于约束的因果发现
    causal_forest.py            # 异质性处理效应
    cross_market_linker.py      # 发现跨市场的因果链
  reflexivity/
    feedback_detector.py        # 检测反身性循环
    loop_modeler.py             # 循环动态建模
    break_predictor.py          # 预测循环何时断裂
```

### 第三层：Cognitive Bias Hunter（认知偏差猎手）

**目标**：系统性地检测市场定价中的人类认知偏差，并计算"理性价格"与实际价格的偏差。

#### 3.1 偏差检测框架

```python
class BiasHunter:
    def __init__(self, causal_engine: CausalEngine, perceiver: WorldPerceiver):
        self.causal_engine = causal_engine
        self.perceiver = perceiver
        self.bias_detectors = [
            AnchoringDetector(),
            HerdingDetector(),
            AvailabilityBiasDetector(),
            LossAversionDetector(),
            NarrativeFallacyDetector(),
            RecencyBiasDetector(),
            OverconfidenceDetector(),
        ]

    def scan_asset(self, asset) -> List[BiasSignal]:
        """对一个资产运行所有偏差检测器"""
        signals = []
        for detector in self.bias_detectors:
            signal = detector.detect(asset, self.causal_engine, self.perceiver)
            if signal.strength > signal.threshold:
                signals.append(signal)
        return signals
```

#### 3.2 具体偏差检测器

**Anchoring Detector（锚定效应检测器）**：
```python
class AnchoringDetector:
    def detect(self, asset, causal_engine, perceiver):
        # 比较价格变动与基本面信息变化
        info_change = causal_engine.fundamental_surprise(asset, lookback='30d')
        price_change = asset.return_over('30d')

        # 如果信息发生了重大变化但价格几乎没动，
        # 市场可能锚定在旧价格上
        adjustment_ratio = abs(price_change) / abs(info_change) if info_change != 0 else 1.0

        if adjustment_ratio < 0.3:  # 价格变动不到信息隐含变动的 30%
            return BiasSignal(
                bias='anchoring',
                asset=asset,
                strength=1 - adjustment_ratio,
                direction='same_as_information_direction',
                evidence=f"Info implies {info_change:.1%} move, actual {price_change:.1%}"
            )
```

**Herding Detector（羊群效应检测器）**：
```python
class HerdingDetector:
    def detect(self, asset, causal_engine, perceiver):
        # 测量持仓极端值
        positioning = asset.get_positioning_data()  # COT、13F、交易所资金流
        sentiment = perceiver.get_sentiment(asset)

        # 持仓相对于历史的 Z-score
        positioning_z = (positioning.current - positioning.mean_2y) / positioning.std_2y

        if abs(positioning_z) > 2.0:
            # 极端持仓 = 很可能是羊群效应
            return BiasSignal(
                bias='herding',
                asset=asset,
                strength=min(abs(positioning_z) / 3.0, 1.0),
                direction='contrarian',  # 做反向交易
                evidence=f"Positioning z-score: {positioning_z:.1f}"
            )
```

#### 3.3 理性价格计算器

```python
class RationalPriceCalculator:
    """
    利用 Bayesian 推断（无认知偏差），
    计算基于所有可用信息的合理价格。
    """

    def calculate(self, asset, causal_engine, perceiver):
        # 1. 收集所有相关信息
        info = perceiver.get_all_relevant_info(asset)

        # 2. 构建未来现金流的概率分布
        scenarios = causal_engine.generate_scenarios(asset, info)

        # 3. 按后验概率加权情景
        expected_value = sum(
            scenario.probability * scenario.discounted_cash_flows
            for scenario in scenarios
        )

        # 4. 计算不确定性
        variance = sum(
            scenario.probability * (scenario.dcf - expected_value)**2
            for scenario in scenarios
        )

        return RationalPrice(
            point_estimate=expected_value,
            confidence_interval=(
                expected_value - 2 * variance**0.5,
                expected_value + 2 * variance**0.5
            ),
            market_price=asset.current_price,
            mispricing=expected_value - asset.current_price,
            mispricing_pct=(expected_value - asset.current_price) / asset.current_price,
            bias_attribution=self.attribute_mispricing_to_biases(asset)
        )
```

#### 3.4 仓位管理：广义 Kelly Criterion

```python
class PositionSizer:
    """
    带估计不确定性的广义 Kelly Criterion，
    用于连续分布。
    """

    def calculate_kelly(self, edge: float, odds: float, uncertainty: float) -> float:
        """
        根据估计不确定性调整的 Kelly 比例。

        标准 Kelly：f* = (p*b - q) / b  其中 p=胜率, b=赔率, q=1-p

        考虑不确定性时，我们使用分数 Kelly：
        f_actual = f_kelly * confidence_factor

        其中 confidence_factor 对以下因素进行惩罚：
        1. 样本量小
        2. 模型不确定性
        3. 参数估计误差
        """
        if edge <= 0:
            return 0.0

        kelly_fraction = edge / odds

        # 按置信度缩减 Kelly
        # 永远不超过半 Kelly（业界公认的最佳实践）
        confidence_factor = min(0.5, 1.0 / (1.0 + uncertainty))

        return kelly_fraction * confidence_factor

    def portfolio_kelly(self, opportunities: List[Opportunity]) -> Dict[str, float]:
        """
        使用协方差矩阵的多资产 Kelly。
        求解：f* = Sigma^{-1} * mu（均值-方差最优）
        以 Kelly 解释并进行分数缩放。
        """
        mu = np.array([o.expected_return for o in opportunities])
        Sigma = self.estimate_covariance(opportunities)

        # 最优比例（无约束）
        f_star = np.linalg.solve(Sigma, mu)

        # 应用约束：单个持仓最大 20%，总计最大 100%
        f_constrained = self.apply_constraints(f_star, max_single=0.20, max_total=1.0)

        return {o.name: f for o, f in zip(opportunities, f_constrained)}
```

#### 3.5 实现组件

```
bias_hunter/
  detectors/
    anchoring.py
    herding.py
    availability.py
    loss_aversion.py
    narrative_fallacy.py
    recency.py
    overconfidence.py
    time_preference.py
  pricing/
    rational_price.py        # Bayesian 公允价值计算器
    scenario_generator.py    # Monte Carlo 情景生成
    mispricing_scorer.py     # 量化与理性价格的偏差
  sizing/
    kelly_criterion.py       # 带不确定性的广义 Kelly
    portfolio_optimizer.py   # 多资产 Kelly 优化
    risk_budget.py           # 跨策略风险分配
  confidence/
    calibration_tracker.py   # 跟踪预测准确度随时间的变化
    brier_score.py           # 概率预测评分
    metacognition.py         # "我对自己的优势判断可能错多少？"
```

### 第四层：Self-Evolver（自我进化器）

**目标**：通过自然选择进化策略。检测并修复自身错误。处理未知的未知。

#### 4.1 策略基因组

系统中每个策略都被编码为一个"基因组"——一种可以变异、交叉和选择的结构化表示：

```python
@dataclass
class StrategyGenome:
    """编码为可组合、可进化的基因组的策略"""

    # 身份标识
    id: str
    name: str
    generation: int
    parent_ids: List[str]

    # 感知基因：关注什么信息
    data_sources: List[DataSourceConfig]
    attention_weights: Dict[str, float]
    timeframe: Timeframe

    # 推理基因：如何处理信息
    causal_model_id: str
    hypothesis_template: str
    update_rules: List[UpdateRule]

    # 决策基因：何时以及如何交易
    entry_conditions: List[Condition]
    exit_conditions: List[Condition]
    position_sizing: SizingConfig
    max_drawdown_tolerance: float

    # 元基因：自我调节
    confidence_threshold: float
    max_correlation_with_other_strategies: float
    regime_detection: RegimeConfig

    def mutate(self, mutation_rate: float = 0.1) -> 'StrategyGenome':
        """创建此基因组的变异副本"""
        child = deepcopy(self)
        child.id = generate_id()
        child.generation = self.generation + 1
        child.parent_ids = [self.id]

        for field in fields(child):
            if random() < mutation_rate:
                child = self._mutate_field(child, field)

        return child

    @staticmethod
    def crossover(parent_a: 'StrategyGenome', parent_b: 'StrategyGenome') -> 'StrategyGenome':
        """有性繁殖：组合两个父代的基因"""
        child = StrategyGenome(
            id=generate_id(),
            generation=max(parent_a.generation, parent_b.generation) + 1,
            parent_ids=[parent_a.id, parent_b.id],
            # 从某一个父代随机选择每个基因
            data_sources=choice([parent_a.data_sources, parent_b.data_sources]),
            causal_model_id=choice([parent_a.causal_model_id, parent_b.causal_model_id]),
            entry_conditions=choice([parent_a.entry_conditions, parent_b.entry_conditions]),
            exit_conditions=choice([parent_a.exit_conditions, parent_b.exit_conditions]),
            position_sizing=choice([parent_a.position_sizing, parent_b.position_sizing]),
            # ... 等等
        )
        return child
```

#### 4.2 自然选择引擎

```python
class NaturalSelection:
    """
    同时运行 100+ 个策略变体。
    选择标准：风险调整后收益、稳健性、去相关性。
    """

    def __init__(self, population_size: int = 100):
        self.population: List[StrategyGenome] = []
        self.population_size = population_size
        self.fitness_history: Dict[str, List[float]] = {}

    def fitness(self, genome: StrategyGenome, results: BacktestResults) -> float:
        """
        多目标适应度函数。
        不仅仅是收益——我们选择稳健的、不相关的策略。
        """
        sharpe = results.sharpe_ratio
        sortino = results.sortino_ratio
        max_dd = results.max_drawdown
        robustness = results.out_of_sample_sharpe / max(results.in_sample_sharpe, 0.01)

        # 惩罚与现有优胜者相关的策略
        decorrelation_bonus = self.decorrelation_score(genome, results)

        # 惩罚过拟合：样本外与样本内表现的比率
        overfit_penalty = max(0, 1 - robustness) * 2

        fitness = (
            0.3 * sharpe
            + 0.2 * sortino
            - 0.2 * abs(max_dd)
            + 0.2 * decorrelation_bonus
            - 0.1 * overfit_penalty
        )

        return fitness

    def evolve_generation(self):
        """一代进化"""
        # 1. 评估适应度
        fitnesses = {g.id: self.fitness(g, self.evaluate(g)) for g in self.population}

        # 2. 选择（锦标赛选择，保留前 20%）
        sorted_pop = sorted(self.population, key=lambda g: fitnesses[g.id], reverse=True)
        survivors = sorted_pop[:int(self.population_size * 0.2)]

        # 3. 繁殖
        new_pop = list(survivors)  # 精英主义：前 20% 原样存活

        while len(new_pop) < self.population_size:
            if random() < 0.7:
                # 交叉：组合两个成功父代
                parent_a, parent_b = sample(survivors, 2)
                child = StrategyGenome.crossover(parent_a, parent_b)
            else:
                # 变异：修改一个成功策略
                parent = choice(survivors)
                child = parent.mutate(mutation_rate=0.15)

            new_pop.append(child)

        self.population = new_pop
```

#### 4.3 Meta-Cognition（元认知——分析自身错误）

```python
class MetaCognition:
    """
    监视系统的系统。
    系统性地分析错误以改善未来表现。
    """

    def analyze_prediction_error(self, prediction, actual_outcome):
        """分类预测为什么是错误的"""
        error_categories = {
            'model_error': self.was_causal_model_wrong(prediction, actual_outcome),
            'data_error': self.was_data_missing_or_wrong(prediction),
            'timing_error': self.was_direction_right_timing_wrong(prediction, actual_outcome),
            'sizing_error': self.was_position_sized_wrong(prediction),
            'unknown_unknown': self.was_cause_outside_model(prediction, actual_outcome),
            'execution_error': self.was_execution_suboptimal(prediction),
        }

        # 更新错误分布
        dominant_error = max(error_categories, key=error_categories.get)
        self.error_distribution[dominant_error] += 1

        # 触发纠正措施
        if dominant_error == 'model_error':
            self.flag_for_causal_model_review(prediction)
        elif dominant_error == 'unknown_unknown':
            self.expand_data_sources(actual_outcome)
            self.create_new_hypothesis_template(actual_outcome)

        return ErrorAnalysis(categories=error_categories, dominant=dominant_error)

    def detect_unknown_unknowns(self):
        """
        在残差中寻找暗示缺失变量的模式。
        如果预测误差与我们未跟踪的某个变量相关，
        那个变量就是一个未知的未知。
        """
        residuals = self.get_recent_prediction_residuals()

        # 测试残差与我们当前未使用的
        # 每个可用数据序列的相关性
        unused_data = self.perceiver.get_unused_data_series()

        for series in unused_data:
            corr = pearsonr(residuals, series.values)
            if abs(corr.statistic) > 0.3 and corr.pvalue < 0.05:
                self.alert(
                    f"Unknown unknown detected: {series.name} correlates with "
                    f"prediction errors (r={corr.statistic:.2f}, p={corr.pvalue:.4f}). "
                    f"Consider adding to causal model."
                )
```

#### 4.4 实现组件

```
self_evolver/
  genome/
    strategy_genome.py       # 基因组数据结构
    mutation.py              # 变异算子
    crossover.py             # 交叉算子
    gene_library.py          # 预构建的基因组件
  selection/
    natural_selection.py     # 锦标赛选择、精英主义
    fitness_function.py      # 多目标适应度
    population_manager.py    # 跟踪世代、谱系
  meta/
    error_analyzer.py        # 预测错误分类
    calibration_auditor.py   # 跟踪预测校准随时间的变化
    unknown_unknown.py       # 检测缺失变量
    regime_detector.py       # 检测市场体制变化
  external/
    plugin_interface.py      # 外部策略贡献者接口
    gene_marketplace.py      # 提交、审核、合并外部基因
    contribution_scorer.py   # 外部贡献排名
```

---

## 3. 市场抽象层

### 3.1 统一市场接口

所有市场，尽管表面上各不相同，却共享相同的抽象操作。系统定义了一个通用接口：

```python
class UnifiedMarket(ABC):
    """所有市场都实现的抽象接口"""

    @abstractmethod
    def get_price(self, instrument: Instrument) -> Price:
        """当前中间价"""

    @abstractmethod
    def get_orderbook(self, instrument: Instrument, depth: int) -> OrderBook:
        """订单簿（或等效的流动性指标）"""

    @abstractmethod
    def get_historical(self, instrument: Instrument, start: datetime, end: datetime,
                       interval: str) -> pd.DataFrame:
        """OHLCV 数据"""

    @abstractmethod
    def place_order(self, order: Order) -> OrderResult:
        """提交订单"""

    @abstractmethod
    def get_positions(self) -> List[Position]:
        """当前持仓"""

    @abstractmethod
    def get_funding_rate(self, instrument: Instrument) -> Optional[float]:
        """资金费率（加密永续合约）或持有成本（外汇、期货）"""

# 实现
class CryptoMarket(UnifiedMarket):    # Binance、Coinbase 等
class StockMarket(UnifiedMarket):     # IBKR、Alpaca
class ForexMarket(UnifiedMarket):     # OANDA、IBKR
class CommodityMarket(UnifiedMarket): # 通过 IBKR 的期货
class PredictionMarket(UnifiedMarket):# Polymarket、Metaculus
class BondMarket(UnifiedMarket):      # Treasury Direct、IBKR
```

### 3.2 通用数据模型

```python
@dataclass
class Instrument:
    """通用金融工具表示"""
    symbol: str              # "BTC-USD"、"AAPL"、"EUR/USD"、"GC=F"
    market_type: MarketType  # CRYPTO、EQUITY、FOREX、COMMODITY、PREDICTION、BOND
    exchange: str            # "binance"、"nasdaq"、"polymarket"
    base_currency: str
    quote_currency: str
    contract_size: float     # 现货为 1，期货各不相同
    tick_size: float
    min_order_size: float
    trading_hours: TradingHours  # 加密货币 24/7，股票交易时段

    # 统一风险参数
    typical_spread_bps: float
    typical_daily_vol: float
    max_leverage: float
    settlement: str          # "T+0"、"T+1"、"T+2"

@dataclass
class Position:
    """通用持仓表示"""
    instrument: Instrument
    side: Side               # LONG 或 SHORT
    size: float              # 以基础货币单位计
    entry_price: float
    current_price: float
    unrealized_pnl: float
    margin_used: float
    strategy_id: str         # 哪个策略基因组拥有该持仓

    @property
    def notional_value(self) -> float:
        return abs(self.size) * self.current_price * self.instrument.contract_size
```

### 3.3 统一风险管理

```python
class UnifiedRiskManager:
    """
    跨市场风险管理。
    核心洞见：风险在所有市场中以相同的单位衡量。
    """

    def __init__(self, max_total_risk: float = 0.02):
        # 任何时刻最多 2% 的组合处于风险中
        self.max_total_risk = max_total_risk

    def calculate_portfolio_var(self, positions: List[Position],
                                 confidence: float = 0.99) -> float:
        """
        同时跨所有市场计算 Value at Risk。
        考虑跨市场相关性。
        """
        returns = self.get_correlated_returns(positions)
        # 使用历史模拟或 Monte Carlo
        portfolio_return_distribution = self.simulate_portfolio(returns, n=10000)
        var = np.percentile(portfolio_return_distribution, (1 - confidence) * 100)
        return var

    def can_take_position(self, new_position: Position,
                          existing_positions: List[Position]) -> RiskCheck:
        """检查新增该持仓是否违反任何风险限制"""
        checks = {
            'single_position_limit': new_position.notional_value / self.portfolio_value < 0.20,
            'market_concentration': self.market_concentration_ok(new_position, existing_positions),
            'correlation_limit': self.correlation_acceptable(new_position, existing_positions),
            'var_limit': self.portfolio_var_acceptable(new_position, existing_positions),
            'drawdown_limit': self.current_drawdown < self.max_drawdown * 0.8,
        }
        return RiskCheck(passed=all(checks.values()), details=checks)

    def market_attention_allocator(self, opportunities: List[Opportunity]) -> Dict[MarketType, float]:
        """
        决定在每个市场分配多少资金/注意力。
        基于：当前机会集、流动性和分散化。
        """
        scores = {}
        for opp in opportunities:
            market = opp.instrument.market_type
            score = opp.expected_edge * opp.confidence * opp.liquidity_score
            scores[market] = scores.get(market, 0) + score

        # 归一化为分配比例
        total = sum(scores.values())
        return {market: score / total for market, score in scores.items()}
```

---

## 4. 信息架构

### 4.1 数据源清单

| 来源 | 类型 | 延迟 | 成本 | API |
|------|------|------|------|-----|
| Polygon.io | 美股逐笔数据 | 实时 | $200/月 | REST + WebSocket |
| Binance | 加密货币市场数据 | 实时 | 免费 | WebSocket |
| OANDA | 外汇汇率 | 实时 | 免费（模拟账户） | REST + Streaming |
| FRED | 美国经济数据 | 每日 | 免费 | REST |
| Quandl/Nasdaq Data Link | 另类数据 | 每日 | 价格不等 | REST |
| Twitter/X API | 社交情绪 | 准实时 | $100/月 | Streaming |
| Reddit API | 散户情绪 | 准实时 | 免费 | REST |
| Polymarket | 预测市场赔率 | 实时 | 免费 | REST + WebSocket |
| NewsAPI / GDELT | 新闻 | 准实时 | 免费档 | REST |
| SEC EDGAR | 公司文件 | 每日 | 免费 | REST |
| arXiv API | 学术论文 | 每日 | 免费 | REST |
| OpenWeatherMap | 天气（商品影响） | 每小时 | 免费档 | REST |
| MarineTraffic / AIS | 航运数据 | 准实时 | $500/月 | REST |

### 4.2 信息流管道

```
原始数据 → 标准化 → 去重 → 实体链接 → 新颖性评分 → 路由

评分管道：
  1. 将原始数据解析为结构化 InformationItem
  2. 实体链接：映射到规范的金融工具/实体
  3. 语义去重（embedding 余弦相似度 > 0.92 = 重复）
  4. 新颖性评分（第 2.1.3 节）
  5. 相对于活跃假设进行相关性评分
  6. 路由到适当的因果模型进行信念更新
```

### 4.3 因果图构建

```python
class CausalGraphBuilder:
    """从信息中构建因果图"""

    def build_from_domain_knowledge(self) -> CausalGraph:
        """从已知的因果关系开始"""
        g = CausalGraph()

        # 宏观关系
        g.add_edge("fed_funds_rate", "usd_strength", mechanism="interest_rate_differential")
        g.add_edge("usd_strength", "em_currencies", mechanism="inverse", lag="0-2d")
        g.add_edge("usd_strength", "gold_price", mechanism="inverse", lag="0-1d")
        g.add_edge("usd_strength", "commodity_prices", mechanism="inverse", lag="0-3d")
        g.add_edge("oil_price", "inflation_expectations", mechanism="input_cost", lag="1-3mo")
        g.add_edge("inflation_expectations", "fed_funds_rate", mechanism="policy_response", lag="1-6mo")

        # ... 更多数百条关系
        return g

    def refine_with_data(self, graph: CausalGraph, data: pd.DataFrame) -> CausalGraph:
        """使用统计检验来验证/精炼因果边"""
        for edge in graph.edges:
            # 使用 Granger causality 检验
            granger = granger_causality_test(
                data[edge.cause], data[edge.effect], max_lag=edge.max_lag
            )
            # 使用 transfer entropy 检验
            te = transfer_entropy(data[edge.cause], data[edge.effect])

            # 更新边的置信度
            edge.confidence = (granger.confidence + te.confidence) / 2

            if edge.confidence < 0.1:
                graph.flag_for_review(edge)

        return graph
```

### 4.4 存储架构

```
PostgreSQL（TimescaleDB 扩展）：
  - 市场数据（OHLCV、订单簿快照）
  - 交易历史、持仓、盈亏
  - 策略表现指标
  - 预测日志（用于校准跟踪）

Redis：
  - 实时价格缓存
  - 活跃假设及其后验概率
  - 策略信号队列
  - 速率限制计数器

Vector Database（Qdrant 或 pgvector）：
  - 新闻/信息 embedding 用于语义搜索
  - 去重索引
  - 相似事件检索（"上次 X 发生时情况如何？"）

Object Storage（兼容 S3）：
  - 原始数据归档
  - 模型检查点
  - 回测结果
  - 因果图快照
```

---

## 5. 验证和证明体系

### 5.1 渐进式验证框架

系统在触及真实资金之前必须证明自己。四个阶段：

```
阶段 0：回测（历史数据）
  持续时间：不限
  目标：开发和优化策略
  指标：扣除交易成本后样本外数据 Sharpe > 1.5

阶段 1：模拟交易（实时数据，模拟执行）
  持续时间：最少 3 个月
  目标：验证实时数据处理和信号生成
  指标：模拟 Sharpe > 1.0，最大回撤 < 15%

阶段 2：小额实盘（$1,000 - $10,000）
  持续时间：最少 6 个月
  目标：验证执行、滑点和真实世界的优势
  指标：实盘 Sharpe > 0.8，滑点在模拟估计的 2 倍以内

阶段 3：扩大实盘
  持续时间：持续进行
  目标：生产交易
  指标：持续监控，自动降风险
  扩容规则：如指标保持，每 3 个月翻倍分配
```

### 5.2 预测日志和校准

```python
class PredictionLog:
    """
    系统做出的每个预测都被记录和评分。
    这是系统质量的基本真相（GROUND TRUTH）。
    """

    def log_prediction(self, prediction: Prediction):
        """记录预测，包含时间戳、置信度和推理过程"""
        self.db.insert({
            'timestamp': now(),
            'asset': prediction.asset,
            'prediction_type': prediction.type,  # 方向、幅度、时机
            'predicted_value': prediction.value,
            'confidence': prediction.confidence,
            'reasoning': prediction.reasoning_chain,
            'causal_model_used': prediction.causal_model_id,
            'information_used': prediction.information_ids,
            'strategy_genome_id': prediction.genome_id,
            'resolved': False,
        })

    def calibration_report(self, lookback_days: int = 90) -> CalibrationReport:
        """
        我们的校准是否良好？
        我们说有 70% 可能性的事情，是否真的有 70% 发生了？
        """
        predictions = self.db.query(resolved=True, days=lookback_days)

        # 按声明的置信度分箱
        bins = np.arange(0, 1.1, 0.1)
        calibration = {}

        for i in range(len(bins) - 1):
            low, high = bins[i], bins[i+1]
            in_bin = [p for p in predictions if low <= p.confidence < high]
            if in_bin:
                actual_hit_rate = sum(1 for p in in_bin if p.was_correct) / len(in_bin)
                stated_confidence = np.mean([p.confidence for p in in_bin])
                calibration[f"{low:.0%}-{high:.0%}"] = {
                    'stated': stated_confidence,
                    'actual': actual_hit_rate,
                    'count': len(in_bin),
                    'gap': actual_hit_rate - stated_confidence,
                }

        brier_score = np.mean([(p.confidence - p.was_correct)**2 for p in predictions])

        return CalibrationReport(calibration=calibration, brier_score=brier_score)
```

### 5.3 公开仪表板

```
仪表板组件：
  1. 实时预测准确率（滚动 30/90/365 天）
  2. 校准曲线（声明置信度 vs 实际命中率）
  3. 策略基因组排行榜（各世代最佳表现者）
  4. 因果图可视化（交互式，展示活跃因果链）
  5. 偏差检测日志（最近发现的定价错误）
  6. 模拟交易盈亏曲线（实时）
  7. 风险指标（VaR、回撤、相关性矩阵）
  8. 元认知日志（错误分析、检测到的未知的未知）

技术栈：Streamlit（MVP阶段）、Grafana（生产监控）
数据：PostgreSQL → 实时 WebSocket 推送到仪表板
```

---

## 6. 群体共建

### 6.1 策略插件接口

```python
class StrategyPlugin(ABC):
    """
    外部贡献者提交策略基因的接口。
    一个插件提供一个原子能力（一个基因，而非完整策略）。
    """

    @property
    @abstractmethod
    def gene_type(self) -> GeneType:
        """这是什么类型的基因？PERCEPTION（感知）、REASONING（推理）、DECISION（决策）、META（元）"""

    @property
    @abstractmethod
    def metadata(self) -> PluginMetadata:
        """作者、描述、版本、依赖项"""

    @abstractmethod
    def configure(self, config: Dict) -> None:
        """使用配置参数进行设置"""

    @abstractmethod
    def process(self, context: StrategyContext) -> GeneOutput:
        """在给定当前上下文的情况下执行该基因的逻辑"""

    @abstractmethod
    def backtest_validate(self, historical_data: pd.DataFrame) -> ValidationResult:
        """在历史数据上进行自我验证"""

# 示例：有人贡献了一个新的偏差检测器
class OptionsSkewBiasDetector(StrategyPlugin):
    """检测期权偏度暗示的市场恐慌是否超出理性水平"""

    gene_type = GeneType.REASONING

    def process(self, context):
        skew = context.get_options_skew(context.asset)
        historical_skew = context.get_historical_skew(context.asset, lookback=252)
        z_score = (skew - historical_skew.mean()) / historical_skew.std()

        if z_score > 2.0:
            return GeneOutput(
                signal='fear_excessive',
                strength=min(z_score / 3.0, 1.0),
                confidence=0.6,
                reasoning=f"Options skew z-score {z_score:.1f} suggests excessive fear"
            )
```

### 6.2 贡献工作流

```
1. 贡献者 fork 仓库
2. 实现 StrategyPlugin 接口
3. 包含回测结果和单元测试
4. 提交 PR
5. 自动化验证管道：
   a. 单元测试通过
   b. 在保留数据集上回测
   c. 无数据泄漏检测
   d. 与现有基因的相关性检查
   e. 安全审查（无网络调用、无文件系统访问）
6. 如验证通过 → 合并到基因池
7. 基因在自然选择中竞争
8. 如果基因提升了种群适应度 → 贡献者获得署名
```

### 6.3 奖励机制

```python
class ContributionScorer:
    """基于实际表现跟踪和奖励贡献"""

    def score_contribution(self, gene_id: str, period: str = '90d') -> ContributionScore:
        # 包含该基因的策略相比不包含的策略表现提升了多少？
        strategies_with = self.get_strategies_containing(gene_id)
        strategies_without = self.get_strategies_not_containing(gene_id)

        marginal_sharpe = (
            np.mean([s.sharpe for s in strategies_with]) -
            np.mean([s.sharpe for s in strategies_without])
        )

        # 基因的价值在于它是否为种群增值，而不仅仅是单独表现
        return ContributionScore(
            gene_id=gene_id,
            marginal_sharpe=marginal_sharpe,
            strategies_using=len(strategies_with),
            survival_generations=self.get_survival_count(gene_id),
        )
```

---

## 7. 技术实现

### 7.1 推荐技术栈

```
语言：          Python 3.12+（主要语言），Rust（性能关键路径）
框架：          asyncio 用于并发，无需重量级 Web 框架
数据管道：      Apache Kafka 或 Redis Streams 用于事件流
数据库：        PostgreSQL 16 + TimescaleDB（时序数据），Redis（缓存）
向量存储：      pgvector（保持简单，少一个服务）
ML 框架：       PyTorch（如果需要学习组件），scikit-learn
因果推断：      DoWhy + EconML（Microsoft 的因果 ML 库）
Bayesian：      PyMC 或 NumPyro（概率编程）
回测：          自定义（现有框架对该架构来说过于僵化）
可视化：        Streamlit（MVP）、Grafana（生产监控）
部署：          Docker Compose（开发），Kubernetes（生产）
CI/CD：         GitHub Actions
测试：          pytest + 基于属性的测试（Hypothesis 库）
```

### 7.2 目录结构

```
ty_trading/
  core/
    types.py                    # 通用数据类型（Instrument、Position 等）
    config.py                   # 配置管理
    event_bus.py                # 内部事件系统

  layer1_perceiver/
    connectors/                 # 特定市场的数据连接器
    attention/                  # 好奇心驱动的信息搜索
    processing/                 # NLP、实体链接、去重
    novelty/                    # 新颖性评分

  layer2_causal/
    models/                     # SCM、Bayesian 网络
    inference/                  # do-calculus、反事实
    discovery/                  # 因果结构学习
    graphs/                     # 预构建的因果图库

  layer3_bias/
    detectors/                  # 个别偏差检测器
    pricing/                    # 理性价格计算器
    sizing/                     # Kelly criterion、组合优化
    calibration/                # 预测跟踪

  layer4_evolver/
    genome/                     # 策略基因组、变异、交叉
    selection/                  # 自然选择引擎
    meta/                       # 错误分析、未知的未知
    plugins/                    # 外部贡献接口

  markets/
    abstract.py                 # UnifiedMarket 接口
    crypto.py                   # Binance 等
    equity.py                   # IBKR、Alpaca
    forex.py                    # OANDA
    prediction.py               # Polymarket
    risk_manager.py             # 跨市场风险

  infrastructure/
    database.py                 # PostgreSQL + TimescaleDB
    cache.py                    # Redis
    vector_store.py             # pgvector
    event_stream.py             # Kafka/Redis Streams

  dashboard/
    app.py                      # Streamlit 仪表板
    components/                 # 仪表板组件

  tests/
    unit/
    integration/
    backtest/
    property_based/

  docs/
    architecture.md
    causal_graphs/              # 因果模型文档
    strategy_genes/             # 基因文档
```

### 7.3 分阶段开发路线图

**第 0 阶段：基础建设（第 1-4 周）**
- 搭建仓库、CI/CD、测试基础设施
- 实现核心类型（`Instrument`、`Position`、`Order`、`Price`）
- 实现一个市场连接器（Binance——24/7 可用、免费 API、最简单）
- 实现基本数据管道：采集 -> 存储 -> 查询
- 基本回测框架
- **交付物**：能够获取实时加密货币数据并运行简单回测

**第 1 阶段：第一个大脑（第 5-10 周）**
- 实现 Bayesian belief network（第 2 层核心）
- 实现一个因果模型（例如，BTC-ETH-山寨币传染）
- 实现一个偏差检测器（通过交易所资金流数据检测羊群效应）
- 实现 Kelly 仓位管理
- 仅加密货币的模拟交易
- **交付物**：系统在加密货币上进行模拟交易并记录推理过程

**第 2 阶段：多市场（第 11-18 周）**
- 添加股票连接器（Alpaca——免费 API，美股）
- 添加外汇连接器（OANDA 模拟账户）
- 实现跨市场因果链
- 实现 World Perceiver 注意力机制
- 实现新颖性评分
- 添加新闻采集（NewsAPI）
- **交付物**：系统跨 3 个市场追踪机会，进行模拟交易

**第 3 阶段：进化（第 19-26 周）**
- 实现策略基因组编码
- 实现自然选择（从 20 个基因组变体开始）
- 实现元认知（错误分析）
- 实现校准跟踪和公开仪表板
- **交付物**：具有校准跟踪的自进化系统

**第 4 阶段：群体共建（第 27-34 周）**
- 外部贡献者的插件接口
- 扩展到 100+ 个策略基因组
- 添加预测市场（Polymarket）
- 添加另类数据源
- 为第 2 阶段（小额实盘）做准备
- **交付物**：开放贡献，模拟交易已验证

**第 5 阶段：生产（第 35 周以后）**
- 第 2 阶段验证（小额实盘，最少 6 个月）
- 性能优化（Rust 处理热路径）
- Kubernetes 部署
- 完整的公开仪表板
- 基于已验证的表现进行扩容

### 7.4 MVP 定义（证明概念的最小可行产品）

MVP 必须证明一件事：**系统能够通过跨市场的因果推理，发现人类会遗漏的定价错误**。

MVP 范围：
1. **一个市场**：加密货币（BTC、ETH、前 20 名山寨币）
2. **价格之外的一个数据源**：社交情绪（Twitter/Reddit）或链上数据
3. **一个因果模型**：情绪/链上信号如何引发价格变动
4. **一个偏差检测器**：羊群效应（极端的交易所资金流入/流出）
5. **模拟交易**，完整的预测日志记录
6. **校准仪表板**：我们声明的概率准确吗？

MVP 成功标准：
- 60 天内模拟交易 Sharpe ratio > 1.0
- 校准：预测与实际命中率的偏差在 10% 以内
- 至少 3 个有文档记录的案例，系统在市场修正之前识别出了定价错误

### 7.5 基础设施需求

```
开发环境（单机）：
  - 32GB RAM，8 核 CPU
  - 500GB SSD（历史数据）
  - 本地 PostgreSQL + Redis
  - 成本：约 $0（现有机器 + 免费 API 档次）

模拟交易（VPS）：
  - 4 vCPU，16GB RAM VPS（$50-100/月）
  - 托管 PostgreSQL（$15/月）
  - Redis（$10/月）
  - API 成本：约 $200/月（Polygon、Twitter）
  - 合计：约 $300/月

生产环境：
  - Kubernetes 集群（3 节点，每节点 8 vCPU / 32GB）
  - 托管 PostgreSQL + TimescaleDB
  - Redis 集群
  - Kafka 集群
  - 合计：约 $1,500-3,000/月
  - 随 AUM 扩展
```

---

## 8. 关键设计决策和权衡

### 8.1 为什么核心用 Python 而非 C++/Rust

Python 是初期开发的正确选择，原因如下：
- 瓶颈在于*思考速度*，而非*执行速度*。这不是高频交易系统。它在分钟到天的时间框架上运行。
- Python 在因果推断（DoWhy）、Bayesian 推断（PyMC）和数据科学（pandas、numpy）方面的生态系统无可匹敌。
- 在当前阶段，快速迭代比微秒级延迟更重要。
- Rust 可以后续通过 PyO3 绑定引入到热路径（数据采集、信号计算）。

### 8.2 为什么不用 LLM 作为核心推理引擎

LLM（GPT-4、Claude）适合用于：
- 解析非结构化文本（新闻、文件）
- 生成自然语言推理解释
- 帮助从领域知识构建因果模型

LLM 不应作为核心推理引擎，因为：
- 它们无法进行精确的概率推断（Bayes 更新）
- 它们会产生幻觉且校准不佳
- 它们无法维护持久的、不断演化的信念状态
- 它们的推理在数学意义上不可审计
- 在所需规模下，token 成本将令人望而却步

系统使用 LLM 作为*感知工具*（第 1 层），但核心推理使用显式的数学模型（第 2-4 层）。

### 8.3 为什么用进化（而非基于梯度的）策略优化

基于梯度的优化（神经网络、强化学习）在交易中存在问题：
- 容易过拟合历史数据
- 不可解释（黑箱）
- 体制变化时的灾难性遗忘
- 需要持续重新训练

进化优化更好，因为：
- 策略是可解释的（你可以读懂基因组）
- 自然选择对体制变化具有鲁棒性（种群多样性）
- 无需梯度——适用于不可微分的目标函数
- 交叉可以结合不同领域的洞见
- 外部贡献者的新基因可以自然地整合

---

## 9. 风险控制（不可逾越）

```python
class HardLimits:
    """这些限制不能被任何策略或进化过程覆盖"""

    MAX_DRAWDOWN_HALT = 0.15          # 15% 回撤 → 所有交易停止
    MAX_SINGLE_POSITION = 0.20        # 单个持仓最大占组合 20%
    MAX_DAILY_LOSS = 0.05             # 5% 日亏损 → 暂停 24 小时
    MAX_LEVERAGE = 3.0                # 所有市场最大 3 倍杠杆
    MIN_LIQUIDITY_RATIO = 0.01        # 持仓 < 日成交量的 1%
    PAPER_TRADING_MINIMUM_DAYS = 90   # 实盘前最少 90 天模拟交易
    SMALL_REAL_MINIMUM_DAYS = 180     # 扩容前最少 180 天小额实盘
    MAX_CORRELATION_BETWEEN_POSITIONS = 0.7  # 分散化要求
```

这些限制在基础设施层面执行，而非策略层面。任何进化都无法覆盖它们。

---

### 实现的关键文件

由于这是一个全新仓库，关键文件是必须首先创建的文件：

- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/core/types.py` - 通用数据类型（Instrument、Position、Order、Price），每个其他模块都依赖于此。必须首先设计，且必须设计正确。
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/markets/abstract.py` - UnifiedMarket 抽象接口。每个市场连接器都实现此接口。如果这个接口设计错误，意味着所有连接器都要重写。
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/layer2_causal/models/bayesian_network.py` - Bayesian belief network 是系统的智识核心。"哲学怪物"的灵魂就在这里。它必须支持正确的 Bayes 更新、校准跟踪和假设管理。
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/layer4_evolver/genome/strategy_genome.py` - 策略基因组数据结构决定了策略如何被表示、变异和组合。这是整个进化系统的 DNA。
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/markets/crypto.py` - 第一个具体的市场实现（Binance）。这是 MVP 的入口点：如果这个端到端的模拟交易能正常运作，概念就得到了验证。

---

### 相关文档

关于**插件系统实现**的详细信息——包括四个层级的插件接口、插件清单 schema、SDK 使用方式（Python 和 TypeScript）以及插件贡献工作流——请参阅 [开放插件架构](open-architecture.md)。
