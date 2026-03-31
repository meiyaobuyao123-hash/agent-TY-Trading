Now I have full context. The user has deep experience building financial software (Flutter app with AI agent, fund/stock tracking, 376 tests passing). This new "agent TY Trading" repo is a greenfield project for something far more ambitious. Let me design the comprehensive architecture.

---

# World Model Financial Intelligence System -- Architecture Blueprint

## Project Codename: TY (天演 -- Natural Evolution)

---

## 1. Philosophical Foundation

### 1.1 The Unifying Principle: Markets as Information Processing Systems

All financial markets -- equities, crypto, forex, commodities, prediction markets, bonds -- are instances of the same abstract system: **distributed belief aggregation under uncertainty**. A market price is not a fact about the world; it is the compressed output of millions of agents updating their beliefs given private information, cognitive limitations, and strategic incentives.

Three mathematical frameworks unify all markets:

**Information Theory (Shannon, 1948).** A market price encodes information. The key quantity is **surprisal**: `I(event) = -log2(P(event))`. When new information arrives, the price moves in proportion to the surprisal it carries. An event the market already expects (P close to 1) moves the price little; a genuinely surprising event moves it enormously. The core trading insight: **profit comes from correctly estimating surprisal before the market does**. If you know that the market's implied probability for an event is wrong, you have edge.

Formally, the market's pricing of an asset can be modeled as the market's posterior distribution over future cash flows. Your edge is the KL-divergence between your posterior and the market's posterior: `D_KL(P_you || P_market)`. When this divergence is large and you are closer to truth, there is profit to be extracted.

**Game Theory (Nash/Harsanyi).** Markets are games of incomplete information. Each participant has private signals and acts strategically. The market price is not necessarily the "correct" price -- it is a Nash equilibrium of strategic behavior. This means the price can be wrong even when all participants are individually rational, because the equilibrium depends on what each player believes about what others believe (Keynes' beauty contest). The system must model this recursive belief structure.

**Bayesian Inference.** The correct way to update beliefs given evidence. The system maintains explicit probability distributions over hypotheses and updates them using Bayes' rule: `P(H|E) = P(E|H) * P(H) / P(E)`. Crucially, this means maintaining priors (including priors about model uncertainty), tracking likelihood ratios, and never collapsing to point estimates.

### 1.2 Causality vs. Correlation

The system draws a hard distinction between:
- **Correlation**: X and Y move together historically. This tells you nothing about whether intervening on X will affect Y.
- **Causation**: Changing X *produces* a change in Y, mediated by a specific mechanism.

Following Judea Pearl's hierarchy:
1. **Association** (seeing): P(Y|X) -- most ML models stop here
2. **Intervention** (doing): P(Y|do(X)) -- what happens if we *force* X to change?
3. **Counterfactual** (imagining): P(Y_x|X', Y') -- what *would have* happened?

Trading on correlation alone is fragile. When the regime changes, correlations break. Trading on causal mechanisms is robust because you understand *why* things move.

Example: If copper prices rise, does that cause construction stocks to fall (input cost increase) or is it because both are responding to a common cause (economic expansion)? The trading decision is opposite depending on the causal structure.

### 1.3 Reflexivity (Soros)

Markets are not passive measurement devices. Market prices *change the thing they measure*. This is Soros's reflexivity principle, formalized as:

```
x(t+1) = f(x(t), beliefs(t))
beliefs(t+1) = g(x(t+1), beliefs(t))
```

Where `x` is the fundamental value and `beliefs` are market participants' beliefs. This creates a feedback loop. Key consequences:
- Bubbles and crashes are not anomalies; they are inherent in reflexive systems
- The system must model not just "what is the correct price" but "what do others believe, and how will their beliefs change the fundamentals"
- This is where the biggest opportunities lie: when reflexive feedback loops are about to break

### 1.4 Cognitive Biases as Market Inefficiencies

Human cognitive biases are not random noise -- they are systematic, predictable, and persistent. They create mispricings that a mathematical system can exploit:

| Bias | Market Manifestation | Exploitable Pattern |
|------|---------------------|-------------------|
| **Anchoring** | Price stuck near recent levels despite new information | Slow adjustment to earnings revisions |
| **Availability** | Overweighting recent/vivid events | Post-crash underpricing, post-rally overpricing |
| **Herding** | Crowded trades, momentum overshoot | Mean reversion after extreme positioning |
| **Loss aversion** | Disposition effect (hold losers, sell winners) | Tax-loss selling seasonality, delayed reaction to bad news |
| **Narrative fallacy** | Overpricing "story stocks" | Fundamental value vs. narrative premium divergence |
| **Recency bias** | Extrapolating recent trends | Overreaction to short-term data |
| **Time preference** | Hyperbolic discounting of future events | Long-dated options underpriced |
| **Dunning-Kruger** | Retail overconfidence in meme stocks | Fading extreme retail sentiment |

---

## 2. System Architecture (4 Layers)

### Architecture Overview

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

### Layer 1: World Perceiver (世界感知器)

**Purpose**: Autonomously discover, ingest, and score information across all markets and data sources.

**Core Principle**: Curiosity-driven search. The system does not passively consume a fixed data feed. It actively decides what to look at based on what it expects will have the highest information value.

#### 1.1 Data Source Categories

```
Tier 1 (Real-time, structured):
  - Market data feeds: price, volume, order book depth
  - Economic data releases: CPI, GDP, employment, PMI
  - Central bank communications: rate decisions, minutes, speeches
  - Corporate filings: earnings, 10-K/Q, insider transactions

Tier 2 (Near real-time, semi-structured):
  - News wires: Reuters, Bloomberg, Xinhua, TASS
  - Social media: Twitter/X financial accounts, Reddit (WSB, crypto subs)
  - Prediction markets: Polymarket, Metaculus, PredictIt
  - Government policy documents: Federal Register, EU regulations

Tier 3 (Delayed, unstructured):
  - Academic papers: arXiv (quant-fin, econ), SSRN, NBER
  - Supply chain data: shipping manifests, port congestion
  - Satellite/alternative data: parking lot counts, oil storage
  - Patent filings, job postings (leading indicators)
```

#### 1.2 Attention Mechanism (What to Look At)

The system uses an **expected information gain** formula to decide where to allocate attention:

```
attention_score(source) = E[KL(posterior || prior)] * relevance(source, active_hypotheses) * (1 / cost(source))
```

Where:
- `E[KL(posterior || prior)]` = expected information gain from querying this source
- `relevance` = how likely this source is to affect currently active hypotheses
- `cost` = computational/financial cost of accessing this source

This is implemented as a priority queue. Sources that have historically provided high-information-gain data are prioritized. Sources that the system has never checked are given an exploration bonus (Upper Confidence Bound style).

#### 1.3 Novelty Scoring ("Has the market priced this in?")

Every piece of information gets a novelty score:

```python
def novelty_score(info, market_state):
    # 1. Has this specific information been publicly available?
    public_duration = time_since_first_public(info)
    
    # 2. How much has the market moved since publication?
    market_reaction = price_change_since(info.publication_time)
    
    # 3. How surprising is the content relative to consensus?
    content_surprisal = -log2(P(info.content | consensus))
    
    # 4. Novelty decays exponentially with time and market reaction
    novelty = content_surprisal * exp(-decay_rate * public_duration) * (1 - abs(market_reaction) / expected_reaction)
    
    return novelty
```

Key insight: information that is surprising *and* that the market has not yet reacted to is the most valuable.

#### 1.4 Implementation Components

```
world_perceiver/
  connectors/
    market_data/        # WebSocket feeds: Binance, IBKR, polygon.io
    news/               # RSS, API, web scraping pipelines
    social/             # Twitter API, Reddit API, sentiment extraction
    alternative/        # Satellite, shipping, web traffic
    prediction_markets/ # Polymarket, Metaculus API
  attention/
    priority_queue.py   # Expected information gain ranking
    exploration.py      # UCB exploration bonus for unknown sources
    budget_manager.py   # API cost tracking and allocation
  processing/
    deduplication.py    # Semantic dedup across sources
    entity_linking.py   # Map mentions to canonical entities
    novelty_scorer.py   # Score information novelty
    embedding_store.py  # Vector store for semantic search
  output/
    information_stream.py  # Unified stream of scored information items
```

### Layer 2: Causal Reasoning Engine (因果推理引擎)

**Purpose**: Build and maintain causal models of how the world works. Use them for prediction, intervention analysis, and counterfactual reasoning.

#### 2.1 Structural Causal Models (SCMs)

The system maintains a library of causal DAGs (Directed Acyclic Graphs) representing known causal mechanisms. These are not learned purely from data (which can only find correlations) but are constructed from domain knowledge and refined by data.

Example causal chains the system should model:

```
Chain 1: Geopolitical → Energy → Everything
  Geopolitical tension → Oil supply disruption → Energy price spike
    → Transportation costs → Consumer prices → Central bank response
    → Interest rates → Asset prices (stocks, bonds, real estate)

Chain 2: Climate → Agriculture → Inflation
  El Nino/La Nina → Crop yields → Food commodity prices
    → CPI food component → Headline inflation → Policy response

Chain 3: Tech → Labor → Consumption
  AI capability → Automation of jobs → Employment changes
    → Consumer spending → Corporate revenue → Stock prices

Chain 4: China Property → Global Commodities
  China property starts → Steel/copper/cement demand
    → Commodity prices → Emerging market currencies
    → Global risk appetite
```

#### 2.2 Pearl's do-calculus Implementation

```python
class CausalModel:
    def __init__(self, dag: nx.DiGraph, structural_equations: Dict):
        self.dag = dag
        self.equations = structural_equations
    
    def observe(self, variable, value):
        """P(Y | X=x) -- condition on observation"""
        # Standard Bayesian conditioning
        return self.posterior(variable, value)
    
    def intervene(self, variable, value):
        """P(Y | do(X=x)) -- intervention (cut incoming edges)"""
        # Remove all edges INTO the intervened variable
        mutilated_dag = self.dag.copy()
        mutilated_dag.remove_edges_from(
            [(parent, variable) for parent in self.dag.predecessors(variable)]
        )
        # Set variable to fixed value
        return self.evaluate(mutilated_dag, {variable: value})
    
    def counterfactual(self, evidence, intervention, query):
        """P(Y_x | X'=x', Y'=y') -- what would have happened?"""
        # Step 1: Abduction - infer exogenous variables from evidence
        exogenous = self.abduct(evidence)
        # Step 2: Action - intervene in the model
        modified = self.intervene_model(intervention)
        # Step 3: Prediction - propagate through modified model
        return modified.predict(query, exogenous)
```

#### 2.3 Bayesian Belief Networks

The system maintains a Bayesian network over market-relevant hypotheses:

```python
class BeliefNetwork:
    def __init__(self):
        self.hypotheses = {}  # {name: prior_probability}
        self.evidence_log = []
        
    def add_hypothesis(self, name: str, prior: float, causal_links: List):
        """Register a hypothesis with its prior and causal connections"""
        self.hypotheses[name] = {
            'prior': prior,
            'posterior': prior,
            'evidence_history': [],
            'causal_links': causal_links
        }
    
    def update(self, evidence: Evidence):
        """Bayesian update all affected hypotheses"""
        for h_name, h in self.hypotheses.items():
            likelihood_ratio = self.compute_likelihood_ratio(evidence, h_name)
            # Bayes update: posterior odds = prior odds * likelihood ratio
            prior_odds = h['posterior'] / (1 - h['posterior'])
            posterior_odds = prior_odds * likelihood_ratio
            h['posterior'] = posterior_odds / (1 + posterior_odds)
            h['evidence_history'].append((evidence, likelihood_ratio))
    
    def get_confidence(self, hypothesis: str) -> Tuple[float, float]:
        """Return (probability, calibration_uncertainty)"""
        h = self.hypotheses[hypothesis]
        # Track calibration: how well did past probabilities predict outcomes?
        calibration = self.calibration_score(h['evidence_history'])
        return h['posterior'], calibration
```

#### 2.4 Cross-Market Causal Graph

The most powerful capability: detecting causal chains that cross market boundaries.

```
Example: Panama Canal drought (2023-24)
  Low rainfall → Canal water levels drop
    → Transit restrictions → Shipping delays
      → LNG delivery delays to Asia → Asian nat gas prices rise
      → Container shipping reroutes around Africa → Longer voyages
        → Shipping rates rise → ZIM, Maersk stock prices
        → Higher import costs for goods → Retail margin compression
  
System should detect:
  1. Weather data (satellite) → Canal transit data (alternative data)
  2. Canal transit → Shipping rates (commodities)
  3. Shipping rates → Individual stocks, inflation expectations
  4. Timing: weather signal arrives WEEKS before market impact
```

#### 2.5 Reflexivity Modeling

```python
class ReflexivityDetector:
    """Detect and model self-reinforcing feedback loops"""
    
    def detect_feedback_loop(self, asset, timeframe):
        """
        Look for: price movement → belief change → fundamental change → price movement
        """
        # Measure correlation between:
        # 1. Price changes and sentiment changes (belief → price)
        # 2. Price changes and fundamental changes (price → reality)
        
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

#### 2.6 Implementation Components

```
causal_engine/
  models/
    structural_causal_model.py  # Pearl's SCM implementation
    bayesian_network.py         # Belief network with Bayes updates
    causal_graph_library.py     # Pre-built domain causal graphs
  inference/
    do_calculus.py              # Intervention queries
    counterfactual.py           # Counterfactual reasoning
    granger_causality.py        # Time-series causal discovery
    transfer_entropy.py         # Information-theoretic causality
  discovery/
    pc_algorithm.py             # Constraint-based causal discovery
    causal_forest.py            # Heterogeneous treatment effects
    cross_market_linker.py      # Find causal chains across markets
  reflexivity/
    feedback_detector.py        # Detect reflexive loops
    loop_modeler.py             # Model loop dynamics
    break_predictor.py          # Predict when loops will break
```

### Layer 3: Cognitive Bias Hunter (认知偏差猎手)

**Purpose**: Systematically detect human cognitive biases in market pricing and calculate the "rational price" vs. actual price.

#### 3.1 Bias Detection Framework

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
        """Run all bias detectors on an asset"""
        signals = []
        for detector in self.bias_detectors:
            signal = detector.detect(asset, self.causal_engine, self.perceiver)
            if signal.strength > signal.threshold:
                signals.append(signal)
        return signals
```

#### 3.2 Specific Bias Detectors

**Anchoring Detector**:
```python
class AnchoringDetector:
    def detect(self, asset, causal_engine, perceiver):
        # Compare price movement to fundamental information change
        info_change = causal_engine.fundamental_surprise(asset, lookback='30d')
        price_change = asset.return_over('30d')
        
        # If information changed dramatically but price barely moved,
        # market may be anchored to old price
        adjustment_ratio = abs(price_change) / abs(info_change) if info_change != 0 else 1.0
        
        if adjustment_ratio < 0.3:  # Price moved less than 30% of what info implies
            return BiasSignal(
                bias='anchoring',
                asset=asset,
                strength=1 - adjustment_ratio,
                direction='same_as_information_direction',
                evidence=f"Info implies {info_change:.1%} move, actual {price_change:.1%}"
            )
```

**Herding Detector**:
```python
class HerdingDetector:
    def detect(self, asset, causal_engine, perceiver):
        # Measure positioning extremes
        positioning = asset.get_positioning_data()  # COT, 13F, exchange flows
        sentiment = perceiver.get_sentiment(asset)
        
        # Z-score of positioning relative to history
        positioning_z = (positioning.current - positioning.mean_2y) / positioning.std_2y
        
        if abs(positioning_z) > 2.0:
            # Extreme positioning = likely herding
            return BiasSignal(
                bias='herding',
                asset=asset,
                strength=min(abs(positioning_z) / 3.0, 1.0),
                direction='contrarian',  # Fade the herd
                evidence=f"Positioning z-score: {positioning_z:.1f}"
            )
```

#### 3.3 Rational Price Calculator

```python
class RationalPriceCalculator:
    """
    Calculate what the price SHOULD be given all available information,
    using Bayesian inference with no cognitive biases.
    """
    
    def calculate(self, asset, causal_engine, perceiver):
        # 1. Gather all relevant information
        info = perceiver.get_all_relevant_info(asset)
        
        # 2. Build probability distribution over future cash flows
        scenarios = causal_engine.generate_scenarios(asset, info)
        
        # 3. Weight scenarios by posterior probability
        expected_value = sum(
            scenario.probability * scenario.discounted_cash_flows
            for scenario in scenarios
        )
        
        # 4. Calculate uncertainty
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

#### 3.4 Position Sizing: Generalized Kelly Criterion

```python
class PositionSizer:
    """
    Generalized Kelly Criterion for continuous distributions
    with estimation uncertainty.
    """
    
    def calculate_kelly(self, edge: float, odds: float, uncertainty: float) -> float:
        """
        Kelly fraction adjusted for estimation uncertainty.
        
        Standard Kelly: f* = (p*b - q) / b  where p=win_prob, b=odds, q=1-p
        
        With uncertainty, we use fractional Kelly:
        f_actual = f_kelly * confidence_factor
        
        Where confidence_factor penalizes for:
        1. Small sample size
        2. Model uncertainty
        3. Parameter estimation error
        """
        if edge <= 0:
            return 0.0
        
        kelly_fraction = edge / odds
        
        # Shrink Kelly by confidence
        # Never bet more than half-Kelly (widely accepted best practice)
        confidence_factor = min(0.5, 1.0 / (1.0 + uncertainty))
        
        return kelly_fraction * confidence_factor
    
    def portfolio_kelly(self, opportunities: List[Opportunity]) -> Dict[str, float]:
        """
        Multi-asset Kelly using covariance matrix.
        Solves: f* = Sigma^{-1} * mu  (mean-variance optimal)
        with Kelly interpretation and fractional scaling.
        """
        mu = np.array([o.expected_return for o in opportunities])
        Sigma = self.estimate_covariance(opportunities)
        
        # Optimal fractions (unconstrained)
        f_star = np.linalg.solve(Sigma, mu)
        
        # Apply constraints: max 20% per position, max 100% total
        f_constrained = self.apply_constraints(f_star, max_single=0.20, max_total=1.0)
        
        return {o.name: f for o, f in zip(opportunities, f_constrained)}
```

#### 3.5 Implementation Components

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
    rational_price.py        # Bayesian fair value calculator
    scenario_generator.py    # Monte Carlo scenario generation
    mispricing_scorer.py     # Quantify deviation from rational price
  sizing/
    kelly_criterion.py       # Generalized Kelly with uncertainty
    portfolio_optimizer.py   # Multi-asset Kelly optimization
    risk_budget.py           # Risk allocation across strategies
  confidence/
    calibration_tracker.py   # Track prediction accuracy over time
    brier_score.py           # Probabilistic forecast scoring
    metacognition.py         # "How wrong might I be about my edge?"
```

### Layer 4: Self-Evolver (自我进化器)

**Purpose**: Evolve strategies through natural selection. Detect and fix its own errors. Handle unknown unknowns.

#### 4.1 Strategy Genome

Every strategy in the system is encoded as a "genome" -- a structured representation that can be mutated, crossed over, and selected:

```python
@dataclass
class StrategyGenome:
    """A strategy encoded as a composable, evolvable genome"""
    
    # Identity
    id: str
    name: str
    generation: int
    parent_ids: List[str]
    
    # Perception genes: what information to look at
    data_sources: List[DataSourceConfig]
    attention_weights: Dict[str, float]
    timeframe: Timeframe
    
    # Reasoning genes: how to process information
    causal_model_id: str
    hypothesis_template: str
    update_rules: List[UpdateRule]
    
    # Decision genes: when and how to trade
    entry_conditions: List[Condition]
    exit_conditions: List[Condition]
    position_sizing: SizingConfig
    max_drawdown_tolerance: float
    
    # Meta genes: self-regulation
    confidence_threshold: float
    max_correlation_with_other_strategies: float
    regime_detection: RegimeConfig
    
    def mutate(self, mutation_rate: float = 0.1) -> 'StrategyGenome':
        """Create a mutated copy of this genome"""
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
        """Sexual reproduction: combine genes from two parents"""
        child = StrategyGenome(
            id=generate_id(),
            generation=max(parent_a.generation, parent_b.generation) + 1,
            parent_ids=[parent_a.id, parent_b.id],
            # Randomly select each gene from one parent
            data_sources=choice([parent_a.data_sources, parent_b.data_sources]),
            causal_model_id=choice([parent_a.causal_model_id, parent_b.causal_model_id]),
            entry_conditions=choice([parent_a.entry_conditions, parent_b.entry_conditions]),
            exit_conditions=choice([parent_a.exit_conditions, parent_b.exit_conditions]),
            position_sizing=choice([parent_a.position_sizing, parent_b.position_sizing]),
            # ... etc
        )
        return child
```

#### 4.2 Natural Selection Engine

```python
class NaturalSelection:
    """
    Run 100+ strategy variants simultaneously.
    Select for: risk-adjusted return, robustness, decorrelation.
    """
    
    def __init__(self, population_size: int = 100):
        self.population: List[StrategyGenome] = []
        self.population_size = population_size
        self.fitness_history: Dict[str, List[float]] = {}
    
    def fitness(self, genome: StrategyGenome, results: BacktestResults) -> float:
        """
        Multi-objective fitness function.
        Not just returns -- we select for ROBUST, UNCORRELATED strategies.
        """
        sharpe = results.sharpe_ratio
        sortino = results.sortino_ratio
        max_dd = results.max_drawdown
        robustness = results.out_of_sample_sharpe / max(results.in_sample_sharpe, 0.01)
        
        # Penalize strategies correlated with existing winners
        decorrelation_bonus = self.decorrelation_score(genome, results)
        
        # Penalize overfitting: ratio of out-of-sample to in-sample performance
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
        """One generation of evolution"""
        # 1. Evaluate fitness
        fitnesses = {g.id: self.fitness(g, self.evaluate(g)) for g in self.population}
        
        # 2. Selection (tournament selection, keep top 20%)
        sorted_pop = sorted(self.population, key=lambda g: fitnesses[g.id], reverse=True)
        survivors = sorted_pop[:int(self.population_size * 0.2)]
        
        # 3. Reproduction
        new_pop = list(survivors)  # Elitism: top 20% survive unchanged
        
        while len(new_pop) < self.population_size:
            if random() < 0.7:
                # Crossover: combine two successful parents
                parent_a, parent_b = sample(survivors, 2)
                child = StrategyGenome.crossover(parent_a, parent_b)
            else:
                # Mutation: modify a successful strategy
                parent = choice(survivors)
                child = parent.mutate(mutation_rate=0.15)
            
            new_pop.append(child)
        
        self.population = new_pop
```

#### 4.3 Meta-Cognition (Analyzing Own Errors)

```python
class MetaCognition:
    """
    The system that watches the system.
    Systematically analyzes errors to improve future performance.
    """
    
    def analyze_prediction_error(self, prediction, actual_outcome):
        """Classify WHY a prediction was wrong"""
        error_categories = {
            'model_error': self.was_causal_model_wrong(prediction, actual_outcome),
            'data_error': self.was_data_missing_or_wrong(prediction),
            'timing_error': self.was_direction_right_timing_wrong(prediction, actual_outcome),
            'sizing_error': self.was_position_sized_wrong(prediction),
            'unknown_unknown': self.was_cause_outside_model(prediction, actual_outcome),
            'execution_error': self.was_execution_suboptimal(prediction),
        }
        
        # Update error distribution
        dominant_error = max(error_categories, key=error_categories.get)
        self.error_distribution[dominant_error] += 1
        
        # Trigger corrective action
        if dominant_error == 'model_error':
            self.flag_for_causal_model_review(prediction)
        elif dominant_error == 'unknown_unknown':
            self.expand_data_sources(actual_outcome)
            self.create_new_hypothesis_template(actual_outcome)
        
        return ErrorAnalysis(categories=error_categories, dominant=dominant_error)
    
    def detect_unknown_unknowns(self):
        """
        Look for patterns in residuals that suggest missing variables.
        If prediction errors are correlated with something we're not tracking,
        that something is an unknown unknown.
        """
        residuals = self.get_recent_prediction_residuals()
        
        # Test correlation of residuals with every available data series
        # we're NOT currently using
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

#### 4.4 Implementation Components

```
self_evolver/
  genome/
    strategy_genome.py       # Genome data structure
    mutation.py              # Mutation operators
    crossover.py             # Crossover operators
    gene_library.py          # Pre-built gene components
  selection/
    natural_selection.py     # Tournament selection, elitism
    fitness_function.py      # Multi-objective fitness
    population_manager.py    # Track generations, lineage
  meta/
    error_analyzer.py        # Classify prediction errors
    calibration_auditor.py   # Track prediction calibration over time
    unknown_unknown.py       # Detect missing variables
    regime_detector.py       # Detect market regime changes
  external/
    plugin_interface.py      # Interface for external strategy contributors
    gene_marketplace.py      # Submit, review, merge external genes
    contribution_scorer.py   # Rank external contributions
```

---

## 3. Market Abstraction Layer

### 3.1 Unified Market Interface

All markets, despite their surface differences, share the same abstract operations. The system defines a universal interface:

```python
class UnifiedMarket(ABC):
    """Abstract interface that ALL markets implement"""
    
    @abstractmethod
    def get_price(self, instrument: Instrument) -> Price:
        """Current mid price"""
    
    @abstractmethod
    def get_orderbook(self, instrument: Instrument, depth: int) -> OrderBook:
        """Order book (or equivalent liquidity measure)"""
    
    @abstractmethod
    def get_historical(self, instrument: Instrument, start: datetime, end: datetime, 
                       interval: str) -> pd.DataFrame:
        """OHLCV data"""
    
    @abstractmethod
    def place_order(self, order: Order) -> OrderResult:
        """Submit an order"""
    
    @abstractmethod
    def get_positions(self) -> List[Position]:
        """Current open positions"""
    
    @abstractmethod
    def get_funding_rate(self, instrument: Instrument) -> Optional[float]:
        """Funding rate (crypto perps) or carry cost (forex, futures)"""

# Implementations
class CryptoMarket(UnifiedMarket):    # Binance, Coinbase, etc.
class StockMarket(UnifiedMarket):     # IBKR, Alpaca
class ForexMarket(UnifiedMarket):     # OANDA, IBKR
class CommodityMarket(UnifiedMarket): # Futures via IBKR
class PredictionMarket(UnifiedMarket):# Polymarket, Metaculus
class BondMarket(UnifiedMarket):      # Treasury Direct, IBKR
```

### 3.2 Common Data Model

```python
@dataclass
class Instrument:
    """Universal instrument representation"""
    symbol: str              # "BTC-USD", "AAPL", "EUR/USD", "GC=F"
    market_type: MarketType  # CRYPTO, EQUITY, FOREX, COMMODITY, PREDICTION, BOND
    exchange: str            # "binance", "nasdaq", "polymarket"
    base_currency: str
    quote_currency: str
    contract_size: float     # 1 for spot, varies for futures
    tick_size: float
    min_order_size: float
    trading_hours: TradingHours  # 24/7 for crypto, market hours for stocks
    
    # Unified risk parameters
    typical_spread_bps: float
    typical_daily_vol: float
    max_leverage: float
    settlement: str          # "T+0", "T+1", "T+2"

@dataclass
class Position:
    """Universal position representation"""
    instrument: Instrument
    side: Side               # LONG or SHORT
    size: float              # In base currency units
    entry_price: float
    current_price: float
    unrealized_pnl: float
    margin_used: float
    strategy_id: str         # Which strategy genome owns this
    
    @property
    def notional_value(self) -> float:
        return abs(self.size) * self.current_price * self.instrument.contract_size
```

### 3.3 Unified Risk Management

```python
class UnifiedRiskManager:
    """
    Cross-market risk management.
    Key insight: risk is measured in the SAME units across all markets.
    """
    
    def __init__(self, max_total_risk: float = 0.02):
        # Maximum 2% of portfolio at risk at any time
        self.max_total_risk = max_total_risk
    
    def calculate_portfolio_var(self, positions: List[Position], 
                                 confidence: float = 0.99) -> float:
        """
        Value at Risk across ALL markets simultaneously.
        Accounts for cross-market correlations.
        """
        returns = self.get_correlated_returns(positions)
        # Use historical simulation or Monte Carlo
        portfolio_return_distribution = self.simulate_portfolio(returns, n=10000)
        var = np.percentile(portfolio_return_distribution, (1 - confidence) * 100)
        return var
    
    def can_take_position(self, new_position: Position, 
                          existing_positions: List[Position]) -> RiskCheck:
        """Check if adding this position violates any risk limits"""
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
        Decide how much capital/attention to allocate to each market.
        Based on: current opportunity set, liquidity, and diversification.
        """
        scores = {}
        for opp in opportunities:
            market = opp.instrument.market_type
            score = opp.expected_edge * opp.confidence * opp.liquidity_score
            scores[market] = scores.get(market, 0) + score
        
        # Normalize to allocation percentages
        total = sum(scores.values())
        return {market: score / total for market, score in scores.items()}
```

---

## 4. Information Architecture

### 4.1 Data Source Inventory

| Source | Type | Latency | Cost | API |
|--------|------|---------|------|-----|
| Polygon.io | US equities tick data | Real-time | $200/mo | REST + WebSocket |
| Binance | Crypto market data | Real-time | Free | WebSocket |
| OANDA | Forex rates | Real-time | Free (demo) | REST + Streaming |
| FRED | US economic data | Daily | Free | REST |
| Quandl/Nasdaq Data Link | Alternative data | Daily | Varies | REST |
| Twitter/X API | Social sentiment | Near real-time | $100/mo | Streaming |
| Reddit API | Retail sentiment | Near real-time | Free | REST |
| Polymarket | Prediction market odds | Real-time | Free | REST + WebSocket |
| NewsAPI / GDELT | News | Near real-time | Free tier | REST |
| SEC EDGAR | Corporate filings | Daily | Free | REST |
| arXiv API | Academic papers | Daily | Free | REST |
| OpenWeatherMap | Weather (commodity impact) | Hourly | Free tier | REST |
| MarineTraffic / AIS | Shipping data | Near real-time | $500/mo | REST |

### 4.2 Information Flow Pipeline

```
Raw Data → Normalize → Deduplicate → Entity Link → Score Novelty → Route

Scoring Pipeline:
  1. Parse raw data into structured InformationItem
  2. Entity linking: map to canonical instruments/entities
  3. Semantic deduplication (embedding cosine similarity > 0.92 = duplicate)
  4. Novelty scoring (Section 2.1.3)
  5. Relevance scoring against active hypotheses
  6. Route to appropriate causal model(s) for belief updates
```

### 4.3 Causal Graph Construction

```python
class CausalGraphBuilder:
    """Build causal graphs from information"""
    
    def build_from_domain_knowledge(self) -> CausalGraph:
        """Start with known causal relationships"""
        g = CausalGraph()
        
        # Macro relationships
        g.add_edge("fed_funds_rate", "usd_strength", mechanism="interest_rate_differential")
        g.add_edge("usd_strength", "em_currencies", mechanism="inverse", lag="0-2d")
        g.add_edge("usd_strength", "gold_price", mechanism="inverse", lag="0-1d")
        g.add_edge("usd_strength", "commodity_prices", mechanism="inverse", lag="0-3d")
        g.add_edge("oil_price", "inflation_expectations", mechanism="input_cost", lag="1-3mo")
        g.add_edge("inflation_expectations", "fed_funds_rate", mechanism="policy_response", lag="1-6mo")
        
        # ... hundreds more relationships
        return g
    
    def refine_with_data(self, graph: CausalGraph, data: pd.DataFrame) -> CausalGraph:
        """Use statistical tests to validate/refine causal edges"""
        for edge in graph.edges:
            # Test with Granger causality
            granger = granger_causality_test(
                data[edge.cause], data[edge.effect], max_lag=edge.max_lag
            )
            # Test with transfer entropy
            te = transfer_entropy(data[edge.cause], data[edge.effect])
            
            # Update edge confidence
            edge.confidence = (granger.confidence + te.confidence) / 2
            
            if edge.confidence < 0.1:
                graph.flag_for_review(edge)
        
        return graph
```

### 4.4 Storage Architecture

```
PostgreSQL (Timescale extension):
  - Market data (OHLCV, order book snapshots)
  - Trade history, positions, PnL
  - Strategy performance metrics
  - Prediction log (for calibration tracking)

Redis:
  - Real-time price cache
  - Active hypotheses and their posteriors
  - Strategy signals queue
  - Rate limiting counters

Vector Database (Qdrant or pgvector):
  - News/information embeddings for semantic search
  - Deduplication index
  - Similar-event retrieval ("what happened last time X occurred?")

Object Storage (S3-compatible):
  - Raw data archives
  - Model checkpoints
  - Backtest results
  - Causal graph snapshots
```

---

## 5. Verification and Proof System

### 5.1 Progressive Validation Framework

The system MUST prove itself before touching real capital. Four stages:

```
Stage 0: Backtest (historical data)
  Duration: Unlimited
  Purpose: Develop and refine strategies
  Metric: Sharpe > 1.5 after transaction costs on out-of-sample data
  
Stage 1: Paper Trading (live data, simulated execution)
  Duration: Minimum 3 months
  Purpose: Verify real-time data processing and signal generation
  Metric: Paper Sharpe > 1.0, max drawdown < 15%
  
Stage 2: Small Real ($1,000 - $10,000)
  Duration: Minimum 6 months
  Purpose: Verify execution, slippage, and real-world edge
  Metric: Real Sharpe > 0.8, slippage within 2x of paper estimate
  
Stage 3: Scaled Real
  Duration: Ongoing
  Purpose: Production trading
  Metric: Continuous monitoring with automatic de-risking
  Scale-up rule: double allocation every 3 months if metrics hold
```

### 5.2 Prediction Log and Calibration

```python
class PredictionLog:
    """
    Every prediction the system makes is logged and scored.
    This is the GROUND TRUTH for system quality.
    """
    
    def log_prediction(self, prediction: Prediction):
        """Log a prediction with timestamp, confidence, and reasoning"""
        self.db.insert({
            'timestamp': now(),
            'asset': prediction.asset,
            'prediction_type': prediction.type,  # direction, magnitude, timing
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
        Are we well-calibrated?
        Of things we said were 70% likely, did 70% actually happen?
        """
        predictions = self.db.query(resolved=True, days=lookback_days)
        
        # Bin predictions by stated confidence
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

### 5.3 Public Dashboard

```
Dashboard Components:
  1. Live prediction accuracy (rolling 30/90/365 day)
  2. Calibration curve (stated confidence vs actual hit rate)
  3. Strategy genome leaderboard (top performers across generations)
  4. Causal graph visualization (interactive, showing active causal chains)
  5. Bias detection log (recent mispricings found)
  6. Paper trading PnL curve (real-time)
  7. Risk metrics (VaR, drawdown, correlation matrix)
  8. Meta-cognition log (error analysis, unknown unknowns detected)

Tech: Streamlit or Grafana + custom React components
Data: PostgreSQL → real-time WebSocket to dashboard
```

---

## 6. Collective Building (群体共建)

### 6.1 Strategy Plugin Interface

```python
class StrategyPlugin(ABC):
    """
    Interface for external contributors to submit strategy genes.
    A plugin provides ONE atomic capability (a gene, not a full strategy).
    """
    
    @property
    @abstractmethod
    def gene_type(self) -> GeneType:
        """What kind of gene is this? PERCEPTION, REASONING, DECISION, META"""
    
    @property
    @abstractmethod
    def metadata(self) -> PluginMetadata:
        """Author, description, version, dependencies"""
    
    @abstractmethod
    def configure(self, config: Dict) -> None:
        """Setup with configuration parameters"""
    
    @abstractmethod
    def process(self, context: StrategyContext) -> GeneOutput:
        """Execute this gene's logic given current context"""
    
    @abstractmethod
    def backtest_validate(self, historical_data: pd.DataFrame) -> ValidationResult:
        """Self-validation on historical data"""

# Example: someone contributes a new bias detector
class OptionsSkewBiasDetector(StrategyPlugin):
    """Detect when options skew implies market fear exceeds rational level"""
    
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

### 6.2 Contribution Workflow

```
1. Contributor forks the repo
2. Implements StrategyPlugin interface
3. Includes backtest results and unit tests
4. Submits PR
5. Automated validation pipeline:
   a. Unit tests pass
   b. Backtest on holdout data
   c. No data leakage detection
   d. Correlation check with existing genes
   e. Security review (no network calls, no file system access)
6. If validation passes → merged into gene pool
7. Gene competes in natural selection
8. If gene improves population fitness → contributor credited
```

### 6.3 Reward Mechanism

```python
class ContributionScorer:
    """Track and reward contributions based on actual performance"""
    
    def score_contribution(self, gene_id: str, period: str = '90d') -> ContributionScore:
        # How much did strategies containing this gene outperform?
        strategies_with = self.get_strategies_containing(gene_id)
        strategies_without = self.get_strategies_not_containing(gene_id)
        
        marginal_sharpe = (
            np.mean([s.sharpe for s in strategies_with]) - 
            np.mean([s.sharpe for s in strategies_without])
        )
        
        # Gene is valuable if it ADDS to population, not just performs alone
        return ContributionScore(
            gene_id=gene_id,
            marginal_sharpe=marginal_sharpe,
            strategies_using=len(strategies_with),
            survival_generations=self.get_survival_count(gene_id),
        )
```

---

## 7. Technical Implementation

### 7.1 Recommended Tech Stack

```
Language:        Python 3.12+ (primary), Rust (performance-critical paths)
Framework:       asyncio for concurrency, no heavyweight web framework needed
Data Pipeline:   Apache Kafka or Redis Streams for event streaming
Database:        PostgreSQL 16 + TimescaleDB (time-series), Redis (cache)
Vector Store:    pgvector (keep it simple, one fewer service)
ML Framework:    PyTorch (if needed for learned components), scikit-learn
Causal Inference: DoWhy + EconML (Microsoft's causal ML libraries)
Bayesian:        PyMC or NumPyro (probabilistic programming)
Backtesting:     Custom (existing frameworks too rigid for this architecture)
Visualization:   Streamlit (MVP), Grafana (production monitoring)
Deployment:      Docker Compose (dev), Kubernetes (production)
CI/CD:           GitHub Actions
Testing:         pytest with property-based testing (Hypothesis library)
```

### 7.2 Directory Structure

```
ty_trading/
  core/
    types.py                    # Universal data types (Instrument, Position, etc.)
    config.py                   # Configuration management
    event_bus.py                # Internal event system
  
  layer1_perceiver/
    connectors/                 # Market-specific data connectors
    attention/                  # Curiosity-driven information search
    processing/                 # NLP, entity linking, dedup
    novelty/                    # Novelty scoring
  
  layer2_causal/
    models/                     # SCM, Bayesian networks
    inference/                  # do-calculus, counterfactuals
    discovery/                  # Causal structure learning
    graphs/                     # Pre-built causal graph library
  
  layer3_bias/
    detectors/                  # Individual bias detectors
    pricing/                    # Rational price calculator
    sizing/                     # Kelly criterion, portfolio optimization
    calibration/                # Prediction tracking
  
  layer4_evolver/
    genome/                     # Strategy genome, mutation, crossover
    selection/                  # Natural selection engine
    meta/                       # Error analysis, unknown unknowns
    plugins/                    # External contribution interface
  
  markets/
    abstract.py                 # UnifiedMarket interface
    crypto.py                   # Binance, etc.
    equity.py                   # IBKR, Alpaca
    forex.py                    # OANDA
    prediction.py               # Polymarket
    risk_manager.py             # Cross-market risk
  
  infrastructure/
    database.py                 # PostgreSQL + TimescaleDB
    cache.py                    # Redis
    vector_store.py             # pgvector
    event_stream.py             # Kafka/Redis Streams
  
  dashboard/
    app.py                      # Streamlit dashboard
    components/                 # Dashboard components
  
  tests/
    unit/
    integration/
    backtest/
    property_based/
  
  docs/
    architecture.md
    causal_graphs/              # Documentation of causal models
    strategy_genes/             # Gene documentation
```

### 7.3 Phased Development Roadmap

**Phase 0: Foundation (Weeks 1-4)**
- Set up repository, CI/CD, testing infrastructure
- Implement core types (`Instrument`, `Position`, `Order`, `Price`)
- Implement ONE market connector (Binance -- 24/7, free API, simplest)
- Implement basic data pipeline: ingest -> store -> query
- Basic backtesting framework
- **Deliverable**: Can fetch live crypto data and run a simple backtest

**Phase 1: First Brain (Weeks 5-10)**
- Implement Bayesian belief network (Layer 2 core)
- Implement ONE causal model (e.g., BTC-ETH-altcoin contagion)
- Implement ONE bias detector (herding via exchange flow data)
- Implement Kelly position sizing
- Paper trading for crypto only
- **Deliverable**: System makes paper trades on crypto with logged reasoning

**Phase 2: Multi-Market (Weeks 11-18)**
- Add equity connector (Alpaca -- free API, US stocks)
- Add forex connector (OANDA demo)
- Implement cross-market causal chains
- Implement World Perceiver attention mechanism
- Implement novelty scoring
- Add news ingestion (NewsAPI)
- **Deliverable**: System tracks opportunities across 3 markets, makes paper trades

**Phase 3: Evolution (Weeks 19-26)**
- Implement strategy genome encoding
- Implement natural selection (start with 20 genome variants)
- Implement meta-cognition (error analysis)
- Implement calibration tracking and public dashboard
- **Deliverable**: Self-evolving system with calibration tracking

**Phase 4: Collective (Weeks 27-34)**
- Plugin interface for external contributors
- Scale to 100+ strategy genomes
- Add prediction markets (Polymarket)
- Add alternative data sources
- Prepare for Stage 2 (small real money)
- **Deliverable**: Open for contributions, paper trading validated

**Phase 5: Production (Weeks 35+)**
- Stage 2 validation (small real money, minimum 6 months)
- Performance optimization (Rust for hot paths)
- Kubernetes deployment
- Full public dashboard
- Scale-up based on validated performance

### 7.4 MVP Definition (Minimum to Prove the Concept)

The MVP must prove ONE thing: **the system can find a mispricing that a human would miss, by combining information across markets with causal reasoning**.

MVP scope:
1. **One market**: Crypto (BTC, ETH, top 20 altcoins)
2. **One data source beyond price**: Social sentiment (Twitter/Reddit) OR on-chain data
3. **One causal model**: How sentiment/on-chain signals cause price movements
4. **One bias detector**: Herding (extreme exchange inflows/outflows)
5. **Paper trading** with full prediction logging
6. **Calibration dashboard**: Are our stated probabilities accurate?

MVP success criteria:
- Paper Sharpe ratio > 1.0 over 60 days
- Calibration: predictions are within 10% of actual hit rates
- At least 3 documented cases where the system identified a mispricing before the market corrected

### 7.5 Infrastructure Requirements

```
Development (single machine):
  - 32GB RAM, 8-core CPU
  - 500GB SSD (historical data)
  - PostgreSQL + Redis locally
  - Cost: ~$0 (existing machine + free API tiers)

Paper Trading (VPS):
  - 4 vCPU, 16GB RAM VPS ($50-100/month)
  - Managed PostgreSQL ($15/month)
  - Redis ($10/month)
  - API costs: ~$200/month (Polygon, Twitter)
  - Total: ~$300/month

Production:
  - Kubernetes cluster (3 nodes, 8 vCPU / 32GB each)
  - Managed PostgreSQL with TimescaleDB
  - Redis cluster
  - Kafka cluster
  - Total: ~$1,500-3,000/month
  - Scales with AUM
```

---

## 8. Key Design Decisions and Trade-offs

### 8.1 Why Python over C++/Rust for Core

Python is the right choice for initial development because:
- The bottleneck is *thinking speed*, not *execution speed*. This is not an HFT system. It operates on minutes-to-days timeframes.
- The Python ecosystem for causal inference (DoWhy), Bayesian inference (PyMC), and data science (pandas, numpy) is unmatched.
- Rapid iteration matters more than microsecond latency at this stage.
- Rust can be introduced later for hot paths (data ingestion, signal computation) via PyO3 bindings.

### 8.2 Why Not Use an LLM as the Core Reasoning Engine

LLMs (GPT-4, Claude) are useful for:
- Parsing unstructured text (news, filings)
- Generating natural language reasoning explanations
- Helping build causal models from domain knowledge

LLMs should NOT be the core reasoning engine because:
- They cannot do precise probabilistic inference (Bayes updates)
- They hallucinate and are not calibrated
- They cannot maintain persistent, evolving belief states
- Their reasoning is not auditable in the mathematical sense
- Token costs would be prohibitive at the scale needed

The system uses LLMs as a *perception tool* (Layer 1) but does its core reasoning with explicit mathematical models (Layers 2-4).

### 8.3 Why Evolutionary (Not Gradient-Based) Strategy Optimization

Gradient-based optimization (neural networks, reinforcement learning) has problems for trading:
- Overfits to historical data
- Not interpretable (black box)
- Catastrophic forgetting when regime changes
- Requires continuous retraining

Evolutionary optimization is better because:
- Strategies are interpretable (you can read the genome)
- Natural selection is robust to regime changes (diverse population)
- No gradient -- works for non-differentiable objectives
- Crossover can combine insights from different domains
- New genes from external contributors integrate naturally

---

## 9. Risk Controls (Non-Negotiable)

```python
class HardLimits:
    """These limits CANNOT be overridden by any strategy or evolution"""
    
    MAX_DRAWDOWN_HALT = 0.15          # 15% drawdown → all trading stops
    MAX_SINGLE_POSITION = 0.20        # 20% of portfolio max per position
    MAX_DAILY_LOSS = 0.05             # 5% daily loss → halt for 24h
    MAX_LEVERAGE = 3.0                # 3x max across all markets
    MIN_LIQUIDITY_RATIO = 0.01        # Position < 1% of daily volume
    PAPER_TRADING_MINIMUM_DAYS = 90   # 90 days paper before real money
    SMALL_REAL_MINIMUM_DAYS = 180     # 180 days small real before scaling
    MAX_CORRELATION_BETWEEN_POSITIONS = 0.7  # Diversification requirement
```

These limits are enforced at the infrastructure level, not the strategy level. No amount of evolution can override them.

---

### Critical Files for Implementation

Since this is a greenfield repository, the critical files are the ones that must be created first:

- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/core/types.py` - Universal data types (Instrument, Position, Order, Price) that every other module depends on. Must be designed first and designed right.
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/markets/abstract.py` - The UnifiedMarket abstract interface. Every market connector implements this. Getting this interface wrong means rewriting all connectors.
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/layer2_causal/models/bayesian_network.py` - The Bayesian belief network is the intellectual core of the system. This is where "philosophical monster" lives. It must support proper Bayes updates, calibration tracking, and hypothesis management.
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/layer4_evolver/genome/strategy_genome.py` - The strategy genome data structure determines how strategies can be represented, mutated, and combined. This is the DNA of the entire evolutionary system.
- `/Users/wenruiwei/Desktop/agent TY Trading/ty_trading/markets/crypto.py` - The first concrete market implementation (Binance). This is the MVP entry point: if this works end-to-end with paper trading, the concept is proven.

---

### Related Documentation

For details on the **plugin system implementation** -- including plugin interfaces for all four layers, the plugin manifest schema, SDK usage (Python & TypeScript), and the contribution workflow for plugins -- see [Open Plugin Architecture](open-architecture.md).
