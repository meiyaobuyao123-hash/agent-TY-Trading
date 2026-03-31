# Free Data Sources for Universal Trading Agent
## Deep Research Report - 2026-03-31

---

# 1. ON-CHAIN DATA (Blockchain Analytics)

## 1.1 DeFiLlama (BEST FREE - On-Chain DeFi Data)

| Attribute | Detail |
|---|---|
| **API Base URL** | `https://api.llama.fi` (free), `https://pro-api.llama.fi/{KEY}` (pro) |
| **Authentication** | None required for free endpoints |
| **Free Tier** | 31 free endpoints, no API key needed |
| **Rate Limits** | Not strictly documented for free; Pro = 1000 req/min |
| **Data Freshness** | TVL updates hourly; prices near real-time |
| **Data Range** | Full historical since protocol inception |

### Free Endpoints (Key Selection)

```
# TVL
GET /protocols                           # All protocols + current TVL
GET /protocol/{name}                     # Historical TVL per protocol
GET /tvl/{name}                          # Current TVL only
GET /v2/historicalChainTvl               # All chains historical
GET /v2/historicalChainTvl/{chain}       # Per-chain historical
GET /v2/chains                           # Current TVL all chains

# Prices (Token = "chain:address" format, e.g., "ethereum:0x...")
GET /prices/current/{coins}              # Current prices (batch)
GET /prices/historical/{timestamp}/{coins}  # Price at timestamp
GET /batchHistorical                     # Batch historical prices
GET /chart/{coins}                       # Price chart series
GET /percentage/{coins}                  # % change over periods
GET /prices/first/{coins}               # Earliest known price
GET /block/{chain}/{timestamp}           # Block at timestamp

# Stablecoins
GET /stablecoins                         # All stablecoins + mcap
GET /stablecoincharts/all                # Historical mcap combined
GET /stablecoincharts/{chain}            # Historical mcap per chain
GET /stablecoin/{id}                     # Single stablecoin detail
GET /stablecoinchains                    # Mcap per chain
GET /stablecoinprices                    # Historical stablecoin prices

# DEX Volume
GET /overview/dexs                       # All DEX volume
GET /overview/dexs/{chain}              # DEX volume per chain
GET /summary/dexs/{protocol}            # Single DEX detail

# Fees & Revenue
GET /overview/fees                       # All protocol fees
GET /overview/fees/{chain}              # Fees per chain
GET /summary/fees/{protocol}            # Single protocol fees

# Options & OI
GET /overview/options                    # Options overview
GET /overview/open-interest              # Open interest

# Yields
GET /pools                               # All yield pools + APY
GET /chart/{pool}                        # Historical yield data
```

### Pro-Only (Locked, $300/mo)
Token inflows/outflows, emissions schedules, bridges, ETF data, narratives, liquidity, equities, digital asset treasury.

### Best Use Case
TVL monitoring for protocol health, cross-chain flow detection, stablecoin supply shifts as risk indicator, DEX volume spikes, yield farming opportunities.

### Python Example
```python
import requests

# Get all protocol TVLs
protocols = requests.get("https://api.llama.fi/protocols").json()

# Get current token price
price = requests.get(
    "https://api.llama.fi/prices/current/ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7"
).json()  # USDT

# Get historical chain TVL
tvl = requests.get("https://api.llama.fi/v2/historicalChainTvl/Ethereum").json()
```

---

## 1.2 Dune Analytics

| Attribute | Detail |
|---|---|
| **API Base URL** | `https://api.dune.com/api/v1/` |
| **Authentication** | API key (header: `X-Dune-Api-Key`) |
| **Free Tier** | 2,500 credits/month, 40 req/min |
| **Rate Limits** | 40 requests/minute (free), 200/min (Plus) |
| **Data Freshness** | Depends on query; can be real-time with materialized views |
| **Pagination** | Free: must use SQL LIMIT/OFFSET (no API pagination) |

### Key Endpoints
```
POST /api/v1/query/{query_id}/execute     # Execute a saved query
GET  /api/v1/query/{query_id}/results     # Get latest results
GET  /api/v1/execution/{execution_id}/status   # Check status
GET  /api/v1/execution/{execution_id}/results  # Get results
```

### What You Can Query (SQL on Blockchain Data)
- Raw transactions, logs, traces for Ethereum, Polygon, Arbitrum, Optimism, Base, Solana, Bitcoin, etc.
- Decoded smart contract events and function calls
- DEX trades (Uniswap, Sushiswap, Curve, etc.)
- NFT transfers and sales
- Token transfers and balances
- Custom whale tracking queries

### Whale Tracking
Yes - write SQL to track specific wallet addresses, large transfers, smart money patterns.

### Limitations
- Credits consumed proportional to compute; complex queries cost more
- Credits do NOT roll over month-to-month
- Query timeout: 30 minutes
- Additional credits: $5 per 100

### Best Use Case
Custom on-chain analytics, whale wallet tracking via SQL, protocol-specific metrics, historical pattern analysis.

### Python Example
```python
import requests

API_KEY = "your_dune_api_key"
headers = {"X-Dune-Api-Key": API_KEY}

# Execute a query (e.g., top whale wallets)
r = requests.post(
    "https://api.dune.com/api/v1/query/1234567/execute",
    headers=headers
)
execution_id = r.json()["execution_id"]

# Get results
results = requests.get(
    f"https://api.dune.com/api/v1/execution/{execution_id}/results",
    headers=headers
).json()
```

---

## 1.3 Flipside Crypto

| Attribute | Detail |
|---|---|
| **API Base URL** | `https://flipsidecrypto.xyz/api` (via SDK) |
| **Authentication** | API key (free registration) |
| **Free Tier** | 500 query seconds/month, unlimited queries & dashboards |
| **Chains** | 20+ chains, 60+ 3rd-party APIs, 10 trillion+ rows |
| **Data Freshness** | Near real-time (minutes lag) |

### SDK Access (Python)
```python
from flipside import Flipside

flipside = Flipside("YOUR_API_KEY", "https://flipsidecrypto.xyz")

sql = """
SELECT date, sum(amount_usd) as volume
FROM ethereum.defi.ez_dex_swaps
WHERE block_timestamp > current_date - 7
GROUP BY 1 ORDER BY 1
"""

result = flipside.query(sql)
```

### Key Capabilities
- SQL queries across 20+ chains (Ethereum, Solana, Avalanche, Polygon, etc.)
- Standardized schemas with cross-chain tables
- Proprietary address labels (smart money identification)
- AI-powered query agent

### Best Use Case
Cross-chain analytics, address labeling for smart money tracking, DeFi protocol analysis.

---

## 1.4 Etherscan API

| Attribute | Detail |
|---|---|
| **API Base URL** | `https://api.etherscan.io/api` (also v2: `https://api.etherscan.io/v2/api`) |
| **Authentication** | API key (free registration) |
| **Free Tier** | 3 calls/sec, 100,000 calls/day |
| **Data Freshness** | Real-time (latest confirmed block) |
| **Chains (Free)** | Selected chains only (Ethereum mainnet + limited others) |

### Key Endpoints
```
# Account
?module=account&action=balance&address={addr}           # ETH balance
?module=account&action=txlist&address={addr}             # Transaction list
?module=account&action=tokentx&address={addr}            # ERC-20 transfers
?module=account&action=tokenbalance&address={addr}&contractaddress={token}

# Contract
?module=contract&action=getabi&address={addr}            # Contract ABI
?module=contract&action=getsourcecode&address={addr}     # Source code

# Transaction
?module=proxy&action=eth_getTransactionByHash&txhash={hash}

# Block
?module=proxy&action=eth_blockNumber                     # Latest block

# Gas
?module=gastracker&action=gasoracle                      # Gas prices
```

### 2025 Changes
- Etherscan scaled back free API: Avalanche, Base, BNB Chain, Optimism now require paid tier
- Contract verification endpoints remain free across all chains
- For multi-chain: consider Blockscout (open-source alternative)

### Whale Tracking
Yes - monitor specific addresses via `txlist`, `tokentx` endpoints. Set up polling at 3 req/sec.

### Best Use Case
Ethereum wallet monitoring, transaction verification, gas price tracking, contract interaction data.

---

## 1.5 Arkham Intelligence

| Attribute | Detail |
|---|---|
| **Platform** | `https://intel.arkm.com/` |
| **API** | `https://intel.arkm.com/api` |
| **Free Tier** | Basic wallet lookups and visualization; limited API |
| **Authentication** | Account registration required |
| **Data Freshness** | Real-time |

### Key Capabilities
- **Entity Identification**: Links blockchain addresses to real-world entities (exchanges, funds, individuals)
- **Multi-chain**: Cross-chain wallet tracking
- **Ultra Engine**: Proprietary address-matching AI
- **Alerts**: Telegram mini-app for automated notifications

### Whale Tracking
Best-in-class for entity attribution. Can identify wallets belonging to funds, exchanges, and known traders.

### Limitations
- Deep insights and Intel Exchange require ARKM token or paid subscription
- API access beyond basic lookups is premium

### Best Use Case
Smart money identification, whale wallet attribution, cross-chain entity tracking.

---

## 1.6 Chainlink Data Feeds

| Attribute | Detail |
|---|---|
| **Access Method** | On-chain smart contract reads (view functions) |
| **Authentication** | None (public on-chain data) |
| **Cost** | Free to READ (gas only if calling from smart contract; free via eth_call RPC) |
| **Data Freshness** | Real-time (updated by DON on deviation/heartbeat) |
| **Networks** | Ethereum, Polygon, Arbitrum, Optimism, Avalanche, BSC, etc. |

### How to Read Price Feeds (Free, Off-Chain)
```python
from web3 import Web3

# Use any free RPC (Infura free, Alchemy free, public RPCs)
w3 = Web3(Web3.HTTPProvider("https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"))

# AggregatorV3Interface ABI (latestRoundData)
abi = [{"inputs":[],"name":"latestRoundData","outputs":[
    {"name":"roundId","type":"uint80"},
    {"name":"answer","type":"int256"},
    {"name":"startedAt","type":"uint256"},
    {"name":"updatedAt","type":"uint256"},
    {"name":"answeredInRound","type":"uint80"}
],"stateMutability":"view","type":"function"},
{"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"stateMutability":"view","type":"function"}]

# ETH/USD Price Feed on Ethereum Mainnet
feed = w3.eth.contract(address="0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", abi=abi)
data = feed.functions.latestRoundData().call()
decimals = feed.functions.decimals().call()
price = data[1] / (10 ** decimals)
```

### Available Pairs
700+ price feeds across all supported networks (ETH/USD, BTC/USD, major DeFi tokens, forex pairs, commodities).

### Best Use Case
Reliable decentralized price data, arbitrage detection, price verification against CEX feeds.

---

## 1.7 Other On-Chain Sources

### Footprint Analytics
| Attribute | Detail |
|---|---|
| **URL** | `https://www.footprint.network/data-api` |
| **Free Tier** | Available (sign up free); exact limits undocumented |
| **Chains** | 24+ chains |
| **Features** | REST + SQL API, drag-and-drop dashboards, millisecond queries |
| **Best For** | GameFi, DeFi, NFT analytics with pre-built abstractions |

### L2Beat
| Attribute | Detail |
|---|---|
| **URL** | `https://l2beat.com/` |
| **API** | No documented public API; data accessible via open-source GitHub repo |
| **Data** | L2 TVS, risk scores, liveness metrics, security assessments |
| **Access** | Scrape from website or use GitHub data files (MIT license) |
| **Best For** | Layer 2 health monitoring, risk assessment |

### DeBank Cloud OpenAPI
| Attribute | Detail |
|---|---|
| **URL** | `https://docs.cloud.debank.com/en/readme/open-api` |
| **Free Tier** | Registration provides access key; some free units |
| **Rate Limit** | Pro: 100 req/sec |
| **Features** | User portfolio, token balances, DeFi positions, protocol data, chain data |
| **Best For** | Wallet portfolio tracking, DeFi position monitoring across chains |

---

# 2. SOCIAL SENTIMENT DATA

## 2.1 Alternative.me Fear & Greed Index (BEST FREE - Sentiment Indicator)

| Attribute | Detail |
|---|---|
| **API Endpoint** | `https://api.alternative.me/fng/` |
| **Authentication** | None required |
| **Rate Limits** | 60 req/min (enforced over 10-min window) |
| **Data Freshness** | Daily (updates once per day) |
| **Cost** | Completely free |
| **Format** | JSON (default) or CSV |

### Parameters
| Param | Type | Description | Default |
|---|---|---|---|
| `limit` | int | Number of results (0 = all history) | 1 |
| `format` | string | `json` or `csv` | json |
| `date_format` | string | `us`, `cn`, `kr`, `world` | unix timestamp |

### Response
```json
{
  "name": "Fear and Greed Index",
  "data": [
    {
      "value": "25",
      "value_classification": "Extreme Fear",
      "timestamp": "1711756800",
      "time_until_update": "43200"
    }
  ]
}
```

### Python Example
```python
import requests

# Current index
current = requests.get("https://api.alternative.me/fng/?limit=1").json()

# Full history
history = requests.get("https://api.alternative.me/fng/?limit=0&date_format=cn").json()
```

### Best Use Case
Contrarian indicator: Extreme Fear = potential buy, Extreme Greed = potential sell. Daily regime detection for position sizing.

---

## 2.2 Santiment (Free Tier - On-Chain + Social)

| Attribute | Detail |
|---|---|
| **API Type** | GraphQL |
| **Endpoint** | `https://api.santiment.net/graphql` |
| **Authentication** | API key (free registration) |
| **Free Tier Limits** | 1,000 calls/month, 500/hour, 100/minute |
| **Historical Data** | 1 year (restricted metrics have 30-day lag) |
| **Assets** | 3,000+ crypto assets |

### Free Metrics (Selection)
- Price, volume, market cap
- Daily active addresses
- Transaction volume
- Social volume, social dominance
- Development activity (GitHub commits)
- Exchange inflow/outflow
- MVRV ratio (Market Value to Realized Value)
- NVT ratio (Network Value to Transactions)

### GraphQL Query Example
```python
import requests

API_KEY = "your_santiment_key"
headers = {"Authorization": f"Apikey {API_KEY}"}

query = """
{
  getMetric(metric: "social_volume_total") {
    timeseriesData(
      slug: "bitcoin"
      from: "2025-01-01T00:00:00Z"
      to: "2025-03-31T00:00:00Z"
      interval: "1d"
    ) {
      datetime
      value
    }
  }
}
"""

r = requests.post(
    "https://api.santiment.net/graphql",
    json={"query": query},
    headers=headers
)
```

### Best Use Case
Social volume spikes as leading indicator, development activity for fundamentals, exchange flow for whale detection. The 30-day lag on restricted metrics limits real-time use on free tier.

---

## 2.3 LunarCrush

| Attribute | Detail |
|---|---|
| **API v2** | No API key required (deprecated but functional) |
| **API v3+** | Requires paid subscription (from $1/day) |
| **Key Metrics** | Galaxy Score, AltRank, social volume, sentiment |
| **Data Freshness** | Real-time (paid); delayed (free) |

### Galaxy Score Components
1. Price Score (MACD-based)
2. Social Impact Score (engagement across platforms)
3. Average Sentiment (ML-classified)
4. Correlation Rank (social vs price correlation)

### MCP Server
LunarCrush offers an MCP server for AI agent integration (paid subscriptions only).

### Best Use Case
Crypto-specific social sentiment; Galaxy Score as composite indicator. Limited free access makes it better as a paid supplement.

---

## 2.4 Reddit API

| Attribute | Detail |
|---|---|
| **API Base** | `https://oauth.reddit.com/` |
| **Authentication** | OAuth2 (free app registration) |
| **Free Rate Limit** | 100 req/min (OAuth), 10 req/min (unauthenticated) |
| **Data Freshness** | Real-time |

### Key Subreddits for Trading Sentiment
- r/wallstreetbets, r/stocks, r/investing (equities)
- r/cryptocurrency, r/bitcoin, r/ethereum (crypto)
- r/options, r/thetagang (options)

### Endpoints
```
GET /r/{subreddit}/hot          # Hot posts
GET /r/{subreddit}/new          # New posts
GET /r/{subreddit}/comments     # Comments
GET /search?q={query}           # Search posts
```

### Pushshift Status
Pushshift historical archives still exist but real-time ingestion stopped in 2023. For historical data, use PullPush archives.

### Best Use Case
Retail sentiment gauge, meme stock detection, narrative tracking. Combine with NLP for sentiment scoring.

---

## 2.5 Twitter/X Scraping

| Attribute | Detail |
|---|---|
| **Tool** | snscrape (Python, open-source) |
| **Authentication** | None (scrapes public web) |
| **Cost** | Free |
| **Stability** | Breaks every 2-4 weeks as X changes defenses |
| **Rate** | Variable; slower than API |

### Alternative Approaches
| Method | Cost | Stability | Speed |
|---|---|---|---|
| snscrape | Free | Low (breaks often) | Medium |
| X API Free | Free | High | 10 req/min, very limited |
| X API Basic | $100/mo | High | 10K tweets/mo |
| Apify actors | Free trial | Medium | Fast |
| Nitter instances | Free | Low (shutting down) | Medium |

### Best Use Case
Supplement only. Use snscrape for batch historical analysis; build resilient fallback logic since it breaks frequently.

---

## 2.6 StockTwits

| Attribute | Detail |
|---|---|
| **API** | Available via RapidAPI |
| **Users** | 10M+ |
| **Data** | Bullish/bearish labels, message volume, trending tickers |
| **Free Tier** | Limited (via RapidAPI free tier) |
| **Data Freshness** | Real-time |

### Best Use Case
Pre-labeled sentiment (users self-tag bullish/bearish), trending stock detection, retail sentiment pulse.

---

## 2.7 Chinese Market Sentiment

### AKShare (BEST FREE - Chinese Market Data)
| Attribute | Detail |
|---|---|
| **Install** | `pip install akshare` |
| **Cost** | Completely free, open-source |
| **Sources** | Eastmoney, Sina Finance, Xueqiu, Tencent |
| **Data** | A-shares, HK stocks, US stocks, futures, options, forex, bonds, funds |
| **Freshness** | Real-time quotes available |

```python
import akshare as ak

# Real-time A-share quotes (all stocks)
df = ak.stock_zh_a_spot_em()

# Historical K-line
df = ak.stock_zh_a_hist(symbol="000001", period="daily", adjust="qfq")

# Eastmoney Guba sentiment (stock discussion forum)
# Use custom scraper for guba.eastmoney.com
```

### Xueqiu (Snowball Finance)
| Attribute | Detail |
|---|---|
| **MCP Server** | Available (liqiongyu/xueqiu_mcp) |
| **API** | Unofficial; accessible via AKShare or direct scraping |
| **Users** | 57M+ Chinese investors |
| **Data** | Stock discussions, sentiment, portfolio holdings |
| **Best For** | Chinese retail investor sentiment analysis |

### Eastmoney Guba (Stock Forum)
| Attribute | Detail |
|---|---|
| **URL** | `https://guba.eastmoney.com/` |
| **Access** | Web scraping (BeautifulSoup/Selenium) |
| **Data** | Post titles, view counts, reply counts, timestamps |
| **NLP** | Use ERNIE 3.0 or similar for Chinese sentiment classification |
| **Academic Use** | Proven correlation with stock price jumps/crashes |

---

## 2.8 Telegram Channel Monitoring

| Attribute | Detail |
|---|---|
| **API** | Telegram Bot API (free) |
| **Method** | Create bot, add to channels, receive messages via webhook/polling |
| **Cost** | Free |
| **Data** | Message text, timestamps, media, reactions |

### Implementation
```python
from telegram import Bot

bot = Bot(token="YOUR_BOT_TOKEN")
# Add bot to crypto signal channels
# Process messages via getUpdates() or webhook
# Run NLP sentiment analysis on message content
```

### Key Crypto Channels to Monitor
- Whale Alert channels
- Trading signal groups
- Project announcement channels

### Best Use Case
Real-time alpha from crypto signal channels, whale alert monitoring, project news flow.

---

# 3. ECONOMIC CALENDAR & EVENTS

## 3.1 FRED API (BEST FREE - Economic Data)

| Attribute | Detail |
|---|---|
| **API Base URL** | `https://api.stlouisfed.org/fred/` |
| **Authentication** | API key (free registration at fred.stlouisfed.org) |
| **Cost** | Completely free |
| **Data** | 800,000+ economic time series |
| **Format** | JSON or XML |
| **Data Freshness** | Updated as released (real-time for new releases) |

### Key Endpoints
```
GET /fred/series/observations?series_id={id}   # Get data values
GET /fred/series/search?search_text={text}     # Search series
GET /fred/series?series_id={id}                # Series metadata
GET /fred/releases                              # All data releases
GET /fred/releases/dates                        # Release schedule
GET /fred/series/updates                        # Recently updated series
GET /fred/category/series?category_id={id}     # Series by category
```

### Key Series IDs for Trading
| Series ID | Description | Frequency |
|---|---|---|
| `DFF` | Federal Funds Rate | Daily |
| `DGS10` | 10-Year Treasury Yield | Daily |
| `DGS2` | 2-Year Treasury Yield | Daily |
| `CPIAUCSL` | CPI (Inflation) | Monthly |
| `UNRATE` | Unemployment Rate | Monthly |
| `GDP` | GDP | Quarterly |
| `M2SL` | M2 Money Supply | Monthly |
| `VIXCLS` | VIX (CBOE Volatility Index) | Daily |
| `DEXUSEU` | USD/EUR Exchange Rate | Daily |
| `DEXCHUS` | USD/CNY Exchange Rate | Daily |
| `BAMLH0A0HYM2` | High Yield Spread | Daily |

### Python Example
```python
import requests

API_KEY = "your_fred_api_key"
params = {
    "series_id": "DGS10",
    "api_key": API_KEY,
    "file_type": "json",
    "sort_order": "desc",
    "limit": 30
}
r = requests.get("https://api.stlouisfed.org/fred/series/observations", params=params)
data = r.json()["observations"]
```

### Best Use Case
Macro regime detection, yield curve monitoring, inflation tracking, money supply analysis, cross-market correlation.

---

## 3.2 Investing.com Economic Calendar

| Attribute | Detail |
|---|---|
| **Official API** | None (contractual restrictions) |
| **Access** | Web scraping or Apify actors |
| **Data** | Global economic events, forecasts, actual values, impact level |
| **Freshness** | Real-time on website |

### Scraping Libraries
- `investpy` (Python) - may have breaking changes
- BeautifulSoup custom scrapers
- Apify: `pintostudio/economic-calendar-data-investing-com`

### Best Use Case
High-impact event detection (NFP, CPI, rate decisions), event-driven trading triggers.

---

## 3.3 ForexFactory Calendar

| Attribute | Detail |
|---|---|
| **Official API** | None |
| **Access** | Web scraping (Python/Node.js) |
| **GitHub Tools** | `maurodelazeri/forexcalendar` (Node.js), `fizahkhalid/forex_factory_calendar_news_scraper` (Python+Selenium) |
| **Data** | Event name, currency, impact level, forecast, actual, previous |

### Flask-Based API Wrapper
```
# AtaCanYmc/ForexFactoryScrapper - self-hosted API
# Listens on 0.0.0.0:5000
GET /calendar?date=2026-03-31
```

### Best Use Case
Forex and macro event calendar, impact-level filtering for trade risk management.

---

## 3.4 TradingEconomics

| Attribute | Detail |
|---|---|
| **API Base** | `https://api.tradingeconomics.com/` |
| **Free Tier** | Very limited; mainly Excel/Python package with analytical subscription |
| **Paid** | Custom pricing based on features/volume |
| **Data** | 300,000 indicators, 196 countries, real-time calendar |

### Best Use Case
If budget allows, most comprehensive economic calendar. For free, use FRED + ForexFactory scraping instead.

---

## 3.5 Central Bank Schedules

| Bank | Schedule Source | Format |
|---|---|---|
| **Fed (FOMC)** | `https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm` | HTML (scrape) |
| **ECB** | `https://www.ecb.europa.eu/press/govcdec/mopo/html/index.en.html` | HTML |
| **PBOC** | `http://www.pbc.gov.cn/` | HTML (Chinese) |
| **BOJ** | `https://www.boj.or.jp/en/mopo/mpmdeci/` | HTML |
| **BOE** | `https://www.bankofengland.co.uk/monetary-policy-summary-and-minutes` | HTML |

All require scraping; no free APIs. FRED release dates (`/fred/releases/dates`) partially covers Fed data releases.

---

# 4. ORDER FLOW & MARKET MICROSTRUCTURE

## 4.1 Binance WebSocket (BEST FREE - Crypto Order Flow)

| Attribute | Detail |
|---|---|
| **WebSocket URL** | `wss://stream.binance.com:9443` or `wss://stream.binance.com:443` |
| **Market Data Only** | `wss://data-stream.binance.vision` |
| **Authentication** | None for public streams |
| **Cost** | Completely free |
| **Data Freshness** | Real-time (sub-second) |

### Connection Limits
| Limit | Value |
|---|---|
| Max streams per connection | 1,024 |
| Max connections per 5 min per IP | 300 |
| Incoming messages per second | 5 |
| Connection lifetime | 24 hours |

### Available Streams (All Free, Real-Time)

| Stream | Format | Update Speed |
|---|---|---|
| Aggregate Trades | `{symbol}@aggTrade` | Real-time |
| Raw Trades | `{symbol}@trade` | Real-time |
| Klines | `{symbol}@kline_{interval}` | 1-2s |
| Mini Ticker | `{symbol}@miniTicker` | 1s |
| Full Ticker | `{symbol}@ticker` | 1s |
| Book Ticker (BBO) | `{symbol}@bookTicker` | Real-time |
| Partial Depth (5/10/20) | `{symbol}@depth{levels}` | 100ms or 1s |
| Diff Depth | `{symbol}@depth` | 100ms or 1s |
| Average Price | `{symbol}@avgPrice` | 1s |

### REST Endpoint for Snapshot
```
GET https://api.binance.com/api/v3/depth?symbol=BTCUSDT&limit=5000
```

### Python Example (Order Book)
```python
import websocket
import json

def on_message(ws, message):
    data = json.loads(message)
    # Process order book updates
    bids = data.get("b", [])  # [[price, qty], ...]
    asks = data.get("a", [])

ws = websocket.WebSocketApp(
    "wss://stream.binance.com:9443/ws/btcusdt@depth@100ms",
    on_message=on_message
)
ws.run_forever()
```

### Futures Order Book (Also Free)
```
wss://fstream.binance.com/ws/btcusdt@depth@100ms    # USDT-M Futures
wss://dstream.binance.com/ws/btcusd_perp@depth@100ms # COIN-M Futures
```

### Best Use Case
Real-time order book imbalance detection, large order flow analysis, liquidation cascade monitoring (futures), spread analysis.

---

## 4.2 Polymarket CLOB (BEST FREE - Prediction Markets)

| Attribute | Detail |
|---|---|
| **Gamma API (Market Data)** | `https://gamma-api.polymarket.com` |
| **CLOB API (Trading)** | `https://clob.polymarket.com` |
| **Data API** | `https://data-api.polymarket.com` |
| **WebSocket** | `wss://ws-subscriptions-clob.polymarket.com/ws/market` |
| **Authentication** | Gamma API: None. CLOB/Trading: EIP-712 wallet signature |
| **Cost** | Free for market data |

### Rate Limits
| Endpoint | Burst (per 10s) |
|---|---|
| Gamma /events | 500 |
| Gamma /markets | 300 |
| Gamma search | 350 |
| CLOB general | 9,000 |
| CLOB /book, /price | 1,500 |
| Data API general | 1,000 |

### Key Endpoints (Free, No Auth)
```
GET https://gamma-api.polymarket.com/events         # All prediction markets
GET https://gamma-api.polymarket.com/markets         # Individual market contracts
GET https://gamma-api.polymarket.com/markets?slug={slug}  # Specific market

# CLOB (read-only, no auth needed)
GET https://clob.polymarket.com/book?token_id={id}  # Order book
GET https://clob.polymarket.com/price?token_id={id} # Current price
GET https://clob.polymarket.com/midpoint?token_id={id} # Midpoint
```

### SDKs
- Python: `pip install polymarket-apis`
- TypeScript: `@polymarket/clob-client`
- Rust: `rs-clob-client`

### Best Use Case
Event probability tracking (elections, Fed decisions, geopolitical events), sentiment proxy via prediction market prices, unique alpha source for macro trading.

---

## 4.3 Options Flow (Free Sources)

| Source | Access | Cost | Data |
|---|---|---|---|
| **Unusual Whales API** | REST + WebSocket + Kafka | Free tier available; full: $250/mo | Options flow, dark pool, 100+ endpoints |
| **Barchart (via Apify)** | Apify scraper | Free trial | Unusual options activity |
| **InsiderFinance** | Web platform | Free tier | Unusual options activity detection |
| **CBOE** | Delayed data on website | Free | Put/call ratio, VIX term structure |

### Unusual Whales API
```
Base: https://api.unusualwhales.com
Auth: Bearer {API_KEY}

GET /api/stock/{ticker}/options-flow     # Options flow by ticker
GET /api/darkpool/{ticker}               # Dark pool prints
GET /api/market/overview                 # Market-wide overview
```

### Best Use Case
Detect institutional positioning via unusual options volume, dark pool accumulation signals, put/call ratio for sentiment.

---

## 4.4 Other Free Level 2 / Order Book Sources

| Source | Markets | Free Tier | Notes |
|---|---|---|---|
| **Alpaca Crypto** | 20+ coins | Free | L2 streaming via API |
| **Finnhub** | Stocks + Crypto | Free (60 calls/min) | Real-time quotes, some L2 |
| **Alpha Vantage** | Stocks, Forex, Crypto | Free (25 req/day) | Very limited |
| **Twelve Data** | Stocks, Forex, Crypto | Free (800 req/day) | Good for prototyping |
| **Tardis.dev** | Crypto (historical) | Free trial | Tick-level historical order book |

---

# 5. RECOMMENDED STACK FOR TRADING AGENT

## Tier 1: Core Free Sources (Must-Have)

| Category | Source | Why |
|---|---|---|
| **DeFi/TVL/Prices** | DeFiLlama | 31 free endpoints, no auth, comprehensive |
| **On-Chain SQL** | Dune Analytics | 2,500 credits/mo, custom whale queries |
| **Crypto Order Flow** | Binance WebSocket | Real-time, free, sub-second depth |
| **Macro/Economic** | FRED API | 800K+ series, completely free |
| **Sentiment Index** | Alternative.me FGI | Free, no auth, daily signal |
| **Chinese Markets** | AKShare | Free, real-time A-shares, comprehensive |
| **Blockchain Explorer** | Etherscan | Free, 100K calls/day |
| **Prediction Markets** | Polymarket Gamma API | Free, no auth, event probabilities |

## Tier 2: Valuable Supplements

| Category | Source | Why |
|---|---|---|
| **Social + On-Chain** | Santiment Free | 1K calls/mo, social volume + on-chain metrics |
| **Cross-Chain SQL** | Flipside Crypto | 500 query-sec/mo, 20+ chains, address labels |
| **Smart Money** | Arkham Intelligence | Best entity attribution (limited free) |
| **Reddit Sentiment** | Reddit API | 100 req/min, r/wallstreetbets signals |
| **Price Oracles** | Chainlink Feeds | Decentralized, tamper-proof price data |
| **Economic Calendar** | ForexFactory Scraping | Impact-level event data |
| **Options Flow** | Unusual Whales Free | Institutional positioning signals |

## Tier 3: Supplementary / Paid When Ready

| Category | Source | Why |
|---|---|---|
| **Crypto Sentiment** | LunarCrush | Galaxy Score (from $1/day) |
| **Chinese Sentiment** | Xueqiu / Guba Scraping | 57M+ user sentiment |
| **X/Twitter** | snscrape / X API | Breaks often; unreliable for production |
| **Wallet Tracking** | DeBank OpenAPI | DeFi position monitoring |
| **L2 Analytics** | L2Beat (scrape) | Layer 2 health monitoring |
| **Economic Calendar** | TradingEconomics | Comprehensive but paid |

---

# 6. AGGREGATE FREE CAPACITY SUMMARY

| Source | Daily Free Calls | Real-Time? | Auth Required? |
|---|---|---|---|
| DeFiLlama | Unlimited (soft) | Hourly TVL | No |
| Dune Analytics | ~83/day (2500/mo) | Query-dependent | Yes (API key) |
| Flipside | ~17/day (500 sec/mo) | Minutes lag | Yes (API key) |
| Etherscan | 100,000 | Yes | Yes (API key) |
| Alternative.me FGI | 86,400 (60/min) | Daily | No |
| Santiment | ~33/day (1000/mo) | 30-day lag | Yes (API key) |
| FRED | Unlimited (soft) | On release | Yes (API key) |
| Reddit | 144,000 (100/min) | Yes | Yes (OAuth) |
| Binance WS | Unlimited | Yes (sub-sec) | No |
| Polymarket | ~430K/day (500/10s) | Yes | No |
| Chainlink | Unlimited (RPC limit) | Yes | No (RPC key) |

---

## Sources

- [DeFiLlama API Docs](https://api-docs.defillama.com/)
- [DeFiLlama SDK (GitHub)](https://github.com/DefiLlama/api-sdk)
- [Dune Analytics Pricing](https://dune.com/pricing)
- [Dune API FAQ](https://docs.dune.com/api-reference/overview/faq)
- [Flipside Crypto SDK](https://github.com/FlipsideCrypto/sdk)
- [Flipside Pricing](https://flipsidecrypto.xyz/pricing)
- [Etherscan Rate Limits](https://docs.etherscan.io/resources/rate-limits)
- [Etherscan API](https://etherscan.io/apis)
- [Arkham Intelligence API](https://intel.arkm.com/api)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [Alternative.me Fear & Greed API](https://alternative.me/crypto/fear-and-greed-index/#api)
- [Santiment API Plans](https://academy.santiment.net/products-and-plans/sanapi-plans/)
- [Santiment Rate Limits](https://academy.santiment.net/sanapi/rate-limits/)
- [LunarCrush API](https://lunarcrush.com/about/api)
- [Reddit API](https://www.reddit.com/dev/api/)
- [snscrape (GitHub)](https://github.com/JustAnotherArchivist/snscrape)
- [AKShare (GitHub)](https://github.com/akfamily/akshare)
- [Xueqiu MCP Server](https://www.pulsemcp.com/servers/liqiongyu-xueqiu)
- [FRED API](https://fred.stlouisfed.org/docs/api/fred/)
- [Binance WebSocket Streams](https://developers.binance.com/docs/binance-spot-api-docs/web-socket-streams)
- [Polymarket API Docs](https://docs.polymarket.com/)
- [Polymarket Rate Limits](https://docs.polymarket.com/api-reference/rate-limits)
- [Unusual Whales API](https://api.unusualwhales.com/docs)
- [Footprint Analytics](https://www.footprint.network/data-api)
- [L2Beat (GitHub)](https://github.com/l2beat/l2beat)
- [DeBank Cloud OpenAPI](https://docs.cloud.debank.com/en/readme/open-api)
- [ForexFactory Scraper (GitHub)](https://github.com/maurodelazeri/forexcalendar)
- [TradingEconomics API](https://tradingeconomics.com/api/)
- [Finnhub](https://finnhub.io/)
- [Twelve Data](https://twelvedata.com/)
- [Alpha Vantage](https://www.alphavantage.co/)
