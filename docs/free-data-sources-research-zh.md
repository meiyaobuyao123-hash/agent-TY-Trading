# 通用交易Agent免费数据源研究
## 深度调研报告 - 2026-03-31

---

# 1. 链上数据 (Blockchain Analytics)

## 1.1 DeFiLlama (最佳免费 - 链上 DeFi 数据)

| 属性 | 详情 |
|---|---|
| **API Base URL** | `https://api.llama.fi` (免费), `https://pro-api.llama.fi/{KEY}` (专业版) |
| **认证** | 免费端点无需认证 |
| **免费层** | 31 个免费端点，无需 API key |
| **速率限制** | 免费版未严格文档化；专业版 = 1000 req/min |
| **数据时效** | TVL 每小时更新；价格近实时 |
| **数据范围** | 自协议创建以来的完整历史数据 |

### 免费端点 (重点选取)

```
# TVL（总锁仓量）
GET /protocols                           # 所有协议 + 当前 TVL
GET /protocol/{name}                     # 单协议历史 TVL
GET /tvl/{name}                          # 仅当前 TVL
GET /v2/historicalChainTvl               # 所有链历史 TVL
GET /v2/historicalChainTvl/{chain}       # 单链历史 TVL
GET /v2/chains                           # 所有链当前 TVL

# 价格 (Token = "chain:address" 格式, 如 "ethereum:0x...")
GET /prices/current/{coins}              # 当前价格（批量）
GET /prices/historical/{timestamp}/{coins}  # 指定时间戳价格
GET /batchHistorical                     # 批量历史价格
GET /chart/{coins}                       # 价格图表序列
GET /percentage/{coins}                  # 各周期百分比变化
GET /prices/first/{coins}               # 最早已知价格
GET /block/{chain}/{timestamp}           # 指定时间戳的区块

# 稳定币
GET /stablecoins                         # 所有稳定币 + 市值
GET /stablecoincharts/all                # 历史合并市值
GET /stablecoincharts/{chain}            # 单链历史市值
GET /stablecoin/{id}                     # 单个稳定币详情
GET /stablecoinchains                    # 各链市值
GET /stablecoinprices                    # 历史稳定币价格

# DEX 交易量
GET /overview/dexs                       # 所有 DEX 交易量
GET /overview/dexs/{chain}              # 单链 DEX 交易量
GET /summary/dexs/{protocol}            # 单个 DEX 详情

# 费用与收入
GET /overview/fees                       # 所有协议费用
GET /overview/fees/{chain}              # 单链费用
GET /summary/fees/{protocol}            # 单协议费用

# 期权与持仓量
GET /overview/options                    # 期权概览
GET /overview/open-interest              # 未平仓合约

# 收益率
GET /pools                               # 所有收益池 + APY
GET /chart/{pool}                        # 历史收益数据
```

### 专业版专属 (锁定, $300/月)
Token 流入/流出、释放计划、跨链桥、ETF 数据、叙事分析、流动性、权益、数字资产国库。

### 最佳使用场景
TVL 监控以评估协议健康度、跨链资金流向检测、稳定币供给变化作为风险指标、DEX 交易量激增、收益耕作机会。

### Python 示例
```python
import requests

# 获取所有协议 TVL
protocols = requests.get("https://api.llama.fi/protocols").json()

# 获取当前代币价格
price = requests.get(
    "https://api.llama.fi/prices/current/ethereum:0xdac17f958d2ee523a2206206994597c13d831ec7"
).json()  # USDT

# 获取历史链 TVL
tvl = requests.get("https://api.llama.fi/v2/historicalChainTvl/Ethereum").json()
```

---

## 1.2 Dune Analytics

| 属性 | 详情 |
|---|---|
| **API Base URL** | `https://api.dune.com/api/v1/` |
| **认证** | API key (请求头: `X-Dune-Api-Key`) |
| **免费层** | 每月 2,500 积分, 40 req/min |
| **速率限制** | 40 requests/minute (免费), 200/min (Plus) |
| **数据时效** | 取决于查询；物化视图可达实时 |
| **分页** | 免费版: 必须使用 SQL LIMIT/OFFSET (无 API 分页) |

### 关键端点
```
POST /api/v1/query/{query_id}/execute     # 执行已保存的查询
GET  /api/v1/query/{query_id}/results     # 获取最新结果
GET  /api/v1/execution/{execution_id}/status   # 检查执行状态
GET  /api/v1/execution/{execution_id}/results  # 获取执行结果
```

### 可查询内容 (基于区块链数据的 SQL)
- Ethereum、Polygon、Arbitrum、Optimism、Base、Solana、Bitcoin 等链的原始交易、日志、Traces
- 解码后的智能合约事件和函数调用
- DEX 交易 (Uniswap, Sushiswap, Curve 等)
- NFT 转账和销售
- 代币转账和余额
- 自定义鲸鱼追踪查询

### 鲸鱼追踪
支持 - 编写 SQL 追踪特定钱包地址、大额转账、聪明钱模式。

### 限制
- 积分消耗与计算量成正比；复杂查询消耗更多
- 积分不可跨月累积
- 查询超时：30 分钟
- 额外积分：每 100 积分 $5

### 最佳使用场景
自定义链上分析、基于 SQL 的鲸鱼钱包追踪、特定协议指标、历史模式分析。

### Python 示例
```python
import requests

API_KEY = "your_dune_api_key"
headers = {"X-Dune-Api-Key": API_KEY}

# 执行查询 (例: 顶级鲸鱼钱包)
r = requests.post(
    "https://api.dune.com/api/v1/query/1234567/execute",
    headers=headers
)
execution_id = r.json()["execution_id"]

# 获取结果
results = requests.get(
    f"https://api.dune.com/api/v1/execution/{execution_id}/results",
    headers=headers
).json()
```

---

## 1.3 Flipside Crypto

| 属性 | 详情 |
|---|---|
| **API Base URL** | `https://flipsidecrypto.xyz/api` (通过 SDK) |
| **认证** | API key (免费注册) |
| **免费层** | 每月 500 查询秒数，无限查询和仪表板 |
| **链** | 20+ 条链, 60+ 第三方 API, 10 万亿+ 行数据 |
| **数据时效** | 近实时（分钟级延迟） |

### SDK 访问 (Python)
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

### 核心能力
- 跨 20+ 条链的 SQL 查询 (Ethereum, Solana, Avalanche, Polygon 等)
- 标准化的跨链表结构
- 专有地址标签（聪明钱识别）
- AI 驱动的查询助手

### 最佳使用场景
跨链分析、聪明钱追踪的地址标签、DeFi 协议分析。

---

## 1.4 Etherscan API

| 属性 | 详情 |
|---|---|
| **API Base URL** | `https://api.etherscan.io/api` (另有 v2: `https://api.etherscan.io/v2/api`) |
| **认证** | API key (免费注册) |
| **免费层** | 3 次调用/秒, 100,000 次调用/天 |
| **数据时效** | 实时（最新确认区块） |
| **链 (免费)** | 仅限部分链（Ethereum 主网 + 有限其他链） |

### 关键端点
```
# 账户
?module=account&action=balance&address={addr}           # ETH 余额
?module=account&action=txlist&address={addr}             # 交易列表
?module=account&action=tokentx&address={addr}            # ERC-20 转账
?module=account&action=tokenbalance&address={addr}&contractaddress={token}

# 合约
?module=contract&action=getabi&address={addr}            # 合约 ABI
?module=contract&action=getsourcecode&address={addr}     # 源代码

# 交易
?module=proxy&action=eth_getTransactionByHash&txhash={hash}

# 区块
?module=proxy&action=eth_blockNumber                     # 最新区块

# Gas
?module=gastracker&action=gasoracle                      # Gas 价格
```

### 2025 年变更
- Etherscan 缩减了免费 API：Avalanche、Base、BNB Chain、Optimism 现需付费层
- 合约验证端点在所有链上仍然免费
- 多链需求：可考虑 Blockscout（开源替代方案）

### 鲸鱼追踪
支持 - 通过 `txlist`、`tokentx` 端点监控特定地址。以 3 req/sec 频率设置轮询。

### 最佳使用场景
Ethereum 钱包监控、交易验证、Gas 价格追踪、合约交互数据。

---

## 1.5 Arkham Intelligence

| 属性 | 详情 |
|---|---|
| **平台** | `https://intel.arkm.com/` |
| **API** | `https://intel.arkm.com/api` |
| **免费层** | 基础钱包查询和可视化；API 有限 |
| **认证** | 需要注册账户 |
| **数据时效** | 实时 |

### 核心能力
- **实体识别**：将区块链地址关联到现实世界实体（交易所、基金、个人）
- **多链**：跨链钱包追踪
- **Ultra Engine**：专有地址匹配 AI
- **提醒**：Telegram 小程序自动通知

### 鲸鱼追踪
实体归属领域的最佳选择。能够识别属于基金、交易所和知名交易者的钱包。

### 限制
- 深度分析和 Intel Exchange 需要 ARKM 代币或付费订阅
- 超出基础查询的 API 访问为付费功能

### 最佳使用场景
聪明钱识别、鲸鱼钱包归属、跨链实体追踪。

---

## 1.6 Chainlink Data Feeds

| 属性 | 详情 |
|---|---|
| **访问方式** | 链上智能合约读取（view 函数） |
| **认证** | 无需认证（公开链上数据） |
| **成本** | 读取免费（仅从智能合约调用时需 Gas；通过 eth_call RPC 免费） |
| **数据时效** | 实时（由 DON 在偏差/心跳时更新） |
| **网络** | Ethereum, Polygon, Arbitrum, Optimism, Avalanche, BSC 等 |

### 如何读取价格源 (免费, 链下)
```python
from web3 import Web3

# 使用任何免费 RPC (Infura 免费, Alchemy 免费, 公共 RPC)
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

# Ethereum 主网 ETH/USD 价格源
feed = w3.eth.contract(address="0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419", abi=abi)
data = feed.functions.latestRoundData().call()
decimals = feed.functions.decimals().call()
price = data[1] / (10 ** decimals)
```

### 可用交易对
700+ 价格源覆盖所有支持的网络（ETH/USD、BTC/USD、主流 DeFi 代币、外汇交易对、大宗商品）。

### 最佳使用场景
可靠的去中心化价格数据、套利检测、与 CEX 价格源的交叉验证。

---

## 1.7 其他链上数据源

### Footprint Analytics
| 属性 | 详情 |
|---|---|
| **URL** | `https://www.footprint.network/data-api` |
| **免费层** | 可用（免费注册）；具体限制未文档化 |
| **链** | 24+ 条链 |
| **功能** | REST + SQL API、拖拽式仪表板、毫秒级查询 |
| **最适合** | 预构建抽象层的 GameFi、DeFi、NFT 分析 |

### L2Beat
| 属性 | 详情 |
|---|---|
| **URL** | `https://l2beat.com/` |
| **API** | 无文档化公开 API；可通过开源 GitHub 仓库访问数据 |
| **数据** | L2 TVS、风险评分、活跃度指标、安全评估 |
| **访问** | 从网站抓取或使用 GitHub 数据文件（MIT 许可证） |
| **最适合** | Layer 2 健康度监控、风险评估 |

### DeBank Cloud OpenAPI
| 属性 | 详情 |
|---|---|
| **URL** | `https://docs.cloud.debank.com/en/readme/open-api` |
| **免费层** | 注册提供 access key；部分免费额度 |
| **速率限制** | Pro: 100 req/sec |
| **功能** | 用户投资组合、代币余额、DeFi 持仓、协议数据、链数据 |
| **最适合** | 跨链钱包投资组合追踪、DeFi 持仓监控 |

---

# 2. 社交情绪数据

## 2.1 Alternative.me 恐惧与贪婪指数 (最佳免费 - 情绪指标)

| 属性 | 详情 |
|---|---|
| **API 端点** | `https://api.alternative.me/fng/` |
| **认证** | 无需认证 |
| **速率限制** | 60 req/min (10 分钟窗口内执行) |
| **数据时效** | 每日（每天更新一次） |
| **成本** | 完全免费 |
| **格式** | JSON (默认) 或 CSV |

### 参数
| 参数 | 类型 | 说明 | 默认值 |
|---|---|---|---|
| `limit` | int | 结果数量 (0 = 全部历史) | 1 |
| `format` | string | `json` 或 `csv` | json |
| `date_format` | string | `us`, `cn`, `kr`, `world` | unix 时间戳 |

### 响应
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

### Python 示例
```python
import requests

# 当前指数
current = requests.get("https://api.alternative.me/fng/?limit=1").json()

# 完整历史
history = requests.get("https://api.alternative.me/fng/?limit=0&date_format=cn").json()
```

### 最佳使用场景
逆向指标：极度恐惧 = 潜在买入，极度贪婪 = 潜在卖出。每日市场机制检测用于仓位管理。

---

## 2.2 Santiment (免费层 - 链上 + 社交)

| 属性 | 详情 |
|---|---|
| **API 类型** | GraphQL |
| **端点** | `https://api.santiment.net/graphql` |
| **认证** | API key (免费注册) |
| **免费层限制** | 每月 1,000 次调用, 每小时 500 次, 每分钟 100 次 |
| **历史数据** | 1 年（受限指标有 30 天延迟） |
| **资产** | 3,000+ 加密资产 |

### 免费指标 (精选)
- 价格、交易量、市值
- 每日活跃地址
- 交易量
- 社交量、社交主导度
- 开发活动 (GitHub commits)
- 交易所流入/流出
- MVRV 比率（市场价值与实现价值之比）
- NVT 比率（网络价值与交易之比）

### GraphQL 查询示例
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

### 最佳使用场景
社交量飙升作为先行指标、开发活动作为基本面、交易所资金流向用于鲸鱼检测。免费层受限指标的 30 天延迟限制了实时使用。

---

## 2.3 LunarCrush

| 属性 | 详情 |
|---|---|
| **API v2** | 无需 API key（已弃用但仍可用） |
| **API v3+** | 需付费订阅（起步 $1/天） |
| **关键指标** | Galaxy Score、AltRank、社交量、情绪 |
| **数据时效** | 实时（付费）；延迟（免费） |

### Galaxy Score 组成
1. 价格评分 (基于 MACD)
2. 社交影响评分 (跨平台参与度)
3. 平均情绪 (ML 分类)
4. 相关性排名 (社交与价格的相关性)

### MCP Server
LunarCrush 提供用于 AI Agent 集成的 MCP server（仅限付费订阅）。

### 最佳使用场景
加密货币专用社交情绪；Galaxy Score 作为复合指标。有限的免费访问使其更适合作为付费补充。

---

## 2.4 Reddit API

| 属性 | 详情 |
|---|---|
| **API Base** | `https://oauth.reddit.com/` |
| **认证** | OAuth2 (免费应用注册) |
| **免费速率限制** | 100 req/min (OAuth), 10 req/min (未认证) |
| **数据时效** | 实时 |

### 交易情绪相关的关键 Subreddit
- r/wallstreetbets, r/stocks, r/investing (股票)
- r/cryptocurrency, r/bitcoin, r/ethereum (加密货币)
- r/options, r/thetagang (期权)

### 端点
```
GET /r/{subreddit}/hot          # 热门帖子
GET /r/{subreddit}/new          # 最新帖子
GET /r/{subreddit}/comments     # 评论
GET /search?q={query}           # 搜索帖子
```

### Pushshift 状态
Pushshift 历史存档仍然存在，但实时采集于 2023 年停止。历史数据请使用 PullPush 存档。

### 最佳使用场景
散户情绪风向标、Meme 股检测、叙事追踪。结合 NLP 进行情绪评分。

---

## 2.5 Twitter/X 抓取

| 属性 | 详情 |
|---|---|
| **工具** | snscrape (Python, 开源) |
| **认证** | 无需（抓取公开网页） |
| **成本** | 免费 |
| **稳定性** | 每 2-4 周因 X 更改防护措施而失效 |
| **速率** | 不固定；比 API 慢 |

### 替代方案
| 方式 | 成本 | 稳定性 | 速度 |
|---|---|---|---|
| snscrape | 免费 | 低（经常失效） | 中 |
| X API Free | 免费 | 高 | 10 req/min, 非常有限 |
| X API Basic | $100/月 | 高 | 10K tweets/月 |
| Apify actors | 免费试用 | 中 | 快 |
| Nitter instances | 免费 | 低（关停中） | 中 |

### 最佳使用场景
仅作补充。使用 snscrape 进行批量历史分析；需构建弹性降级逻辑，因其频繁失效。

---

## 2.6 StockTwits

| 属性 | 详情 |
|---|---|
| **API** | 通过 RapidAPI 提供 |
| **用户** | 1000 万+ |
| **数据** | 看涨/看跌标签、消息量、热门标的 |
| **免费层** | 有限（通过 RapidAPI 免费层） |
| **数据时效** | 实时 |

### 最佳使用场景
预标注情绪（用户自行标记看涨/看跌）、热门股检测、散户情绪脉搏。

---

## 2.7 中国市场情绪

### AKShare (最佳免费 - 中国市场数据)
| 属性 | 详情 |
|---|---|
| **安装** | `pip install akshare` |
| **成本** | 完全免费，开源 |
| **数据来源** | 东方财富、新浪财经、雪球、腾讯 |
| **数据** | A 股、港股、美股、期货、期权、外汇、债券、基金 |
| **时效** | 可获取实时行情 |

```python
import akshare as ak

# 实时 A 股行情（全部股票）
df = ak.stock_zh_a_spot_em()

# 历史 K 线
df = ak.stock_zh_a_hist(symbol="000001", period="daily", adjust="qfq")

# 东方财富股吧情绪（股票讨论论坛）
# 使用自定义爬虫抓取 guba.eastmoney.com
```

### 雪球 (Snowball Finance)
| 属性 | 详情 |
|---|---|
| **MCP Server** | 可用 (liqiongyu/xueqiu_mcp) |
| **API** | 非官方；可通过 AKShare 或直接抓取访问 |
| **用户** | 5700 万+ 中国投资者 |
| **数据** | 股票讨论、情绪、持仓组合 |
| **最适合** | 中国散户投资者情绪分析 |

### 东方财富股吧 (股票论坛)
| 属性 | 详情 |
|---|---|
| **URL** | `https://guba.eastmoney.com/` |
| **访问** | 网页抓取 (BeautifulSoup/Selenium) |
| **数据** | 帖子标题、浏览量、回复数、时间戳 |
| **NLP** | 使用 ERNIE 3.0 或类似模型进行中文情感分类 |
| **学术应用** | 已证实与股价跳涨/暴跌存在相关性 |

---

## 2.8 Telegram 频道监控

| 属性 | 详情 |
|---|---|
| **API** | Telegram Bot API (免费) |
| **方式** | 创建 Bot，加入频道，通过 Webhook/轮询接收消息 |
| **成本** | 免费 |
| **数据** | 消息文本、时间戳、媒体、反应 |

### 实现方式
```python
from telegram import Bot

bot = Bot(token="YOUR_BOT_TOKEN")
# 将 Bot 添加到加密信号频道
# 通过 getUpdates() 或 webhook 处理消息
# 对消息内容运行 NLP 情绪分析
```

### 需要监控的关键加密频道
- 鲸鱼预警频道
- 交易信号群组
- 项目公告频道

### 最佳使用场景
来自加密信号频道的实时 Alpha、鲸鱼预警监控、项目新闻流。

---

# 3. 经济日历与事件

## 3.1 FRED API (最佳免费 - 经济数据)

| 属性 | 详情 |
|---|---|
| **API Base URL** | `https://api.stlouisfed.org/fred/` |
| **认证** | API key (在 fred.stlouisfed.org 免费注册) |
| **成本** | 完全免费 |
| **数据** | 800,000+ 经济时间序列 |
| **格式** | JSON 或 XML |
| **数据时效** | 随发布更新（新发布数据实时更新） |

### 关键端点
```
GET /fred/series/observations?series_id={id}   # 获取数据值
GET /fred/series/search?search_text={text}     # 搜索序列
GET /fred/series?series_id={id}                # 序列元数据
GET /fred/releases                              # 所有数据发布
GET /fred/releases/dates                        # 发布时间表
GET /fred/series/updates                        # 最近更新的序列
GET /fred/category/series?category_id={id}     # 按类别查看序列
```

### 交易用关键序列 ID
| 序列 ID | 说明 | 频率 |
|---|---|---|
| `DFF` | 联邦基金利率 | 每日 |
| `DGS10` | 10 年期国债收益率 | 每日 |
| `DGS2` | 2 年期国债收益率 | 每日 |
| `CPIAUCSL` | CPI（通货膨胀） | 每月 |
| `UNRATE` | 失业率 | 每月 |
| `GDP` | GDP | 每季 |
| `M2SL` | M2 货币供给量 | 每月 |
| `VIXCLS` | VIX (CBOE 波动率指数) | 每日 |
| `DEXUSEU` | USD/EUR 汇率 | 每日 |
| `DEXCHUS` | USD/CNY 汇率 | 每日 |
| `BAMLH0A0HYM2` | 高收益利差 | 每日 |

### Python 示例
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

### 最佳使用场景
宏观市场机制检测、收益率曲线监控、通胀追踪、货币供给分析、跨市场相关性。

---

## 3.2 Investing.com 经济日历

| 属性 | 详情 |
|---|---|
| **官方 API** | 无（合同限制） |
| **访问** | 网页抓取或 Apify actors |
| **数据** | 全球经济事件、预测、实际值、影响级别 |
| **时效** | 网站上实时 |

### 抓取库
- `investpy` (Python) - 可能存在兼容性问题
- BeautifulSoup 自定义爬虫
- Apify: `pintostudio/economic-calendar-data-investing-com`

### 最佳使用场景
高影响事件检测（非农就业、CPI、利率决议）、事件驱动型交易触发器。

---

## 3.3 ForexFactory 日历

| 属性 | 详情 |
|---|---|
| **官方 API** | 无 |
| **访问** | 网页抓取 (Python/Node.js) |
| **GitHub 工具** | `maurodelazeri/forexcalendar` (Node.js), `fizahkhalid/forex_factory_calendar_news_scraper` (Python+Selenium) |
| **数据** | 事件名称、货币、影响级别、预测值、实际值、前值 |

### 基于 Flask 的 API 封装
```
# AtaCanYmc/ForexFactoryScrapper - 自托管 API
# 监听 0.0.0.0:5000
GET /calendar?date=2026-03-31
```

### 最佳使用场景
外汇和宏观事件日历、影响级别筛选用于交易风险管理。

---

## 3.4 TradingEconomics

| 属性 | 详情 |
|---|---|
| **API Base** | `https://api.tradingeconomics.com/` |
| **免费层** | 非常有限；主要通过 Excel/Python 包配合分析订阅使用 |
| **付费** | 基于功能/用量的定制定价 |
| **数据** | 300,000 个指标, 196 个国家, 实时日历 |

### 最佳使用场景
如预算允许，最全面的经济日历。免费方案建议使用 FRED + ForexFactory 抓取替代。

---

## 3.5 央行日程

| 央行 | 日程来源 | 格式 |
|---|---|---|
| **美联储 (FOMC)** | `https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm` | HTML (抓取) |
| **欧央行 (ECB)** | `https://www.ecb.europa.eu/press/govcdec/mopo/html/index.en.html` | HTML |
| **中国人民银行 (PBOC)** | `http://www.pbc.gov.cn/` | HTML (中文) |
| **日本央行 (BOJ)** | `https://www.boj.or.jp/en/mopo/mpmdeci/` | HTML |
| **英国央行 (BOE)** | `https://www.bankofengland.co.uk/monetary-policy-summary-and-minutes` | HTML |

所有均需抓取；无免费 API。FRED 发布日期 (`/fred/releases/dates`) 部分覆盖美联储数据发布。

---

# 4. 订单流与市场微结构

## 4.1 Binance WebSocket (最佳免费 - 加密货币订单流)

| 属性 | 详情 |
|---|---|
| **WebSocket URL** | `wss://stream.binance.com:9443` 或 `wss://stream.binance.com:443` |
| **仅市场数据** | `wss://data-stream.binance.vision` |
| **认证** | 公开流无需认证 |
| **成本** | 完全免费 |
| **数据时效** | 实时（亚秒级） |

### 连接限制
| 限制 | 值 |
|---|---|
| 每连接最大流数 | 1,024 |
| 每 5 分钟每 IP 最大连接数 | 300 |
| 每秒入站消息数 | 5 |
| 连接生命周期 | 24 小时 |

### 可用流 (全部免费, 实时)

| 流 | 格式 | 更新速度 |
|---|---|---|
| 聚合交易 | `{symbol}@aggTrade` | 实时 |
| 原始交易 | `{symbol}@trade` | 实时 |
| K 线 | `{symbol}@kline_{interval}` | 1-2 秒 |
| 迷你行情 | `{symbol}@miniTicker` | 1 秒 |
| 完整行情 | `{symbol}@ticker` | 1 秒 |
| 最优挂单 (BBO) | `{symbol}@bookTicker` | 实时 |
| 部分深度 (5/10/20) | `{symbol}@depth{levels}` | 100ms 或 1 秒 |
| 增量深度 | `{symbol}@depth` | 100ms 或 1 秒 |
| 平均价格 | `{symbol}@avgPrice` | 1 秒 |

### REST 端点获取快照
```
GET https://api.binance.com/api/v3/depth?symbol=BTCUSDT&limit=5000
```

### Python 示例 (订单簿)
```python
import websocket
import json

def on_message(ws, message):
    data = json.loads(message)
    # 处理订单簿更新
    bids = data.get("b", [])  # [[price, qty], ...]
    asks = data.get("a", [])

ws = websocket.WebSocketApp(
    "wss://stream.binance.com:9443/ws/btcusdt@depth@100ms",
    on_message=on_message
)
ws.run_forever()
```

### 期货订单簿 (同样免费)
```
wss://fstream.binance.com/ws/btcusdt@depth@100ms    # USDT 本位合约
wss://dstream.binance.com/ws/btcusd_perp@depth@100ms # 币本位合约
```

### 最佳使用场景
实时订单簿失衡检测、大单资金流分析、清算级联监控（期货）、价差分析。

---

## 4.2 Polymarket CLOB (最佳免费 - 预测市场)

| 属性 | 详情 |
|---|---|
| **Gamma API (市场数据)** | `https://gamma-api.polymarket.com` |
| **CLOB API (交易)** | `https://clob.polymarket.com` |
| **Data API** | `https://data-api.polymarket.com` |
| **WebSocket** | `wss://ws-subscriptions-clob.polymarket.com/ws/market` |
| **认证** | Gamma API: 无需。CLOB/交易: EIP-712 钱包签名 |
| **成本** | 市场数据免费 |

### 速率限制
| 端点 | 突发量 (每 10 秒) |
|---|---|
| Gamma /events | 500 |
| Gamma /markets | 300 |
| Gamma search | 350 |
| CLOB general | 9,000 |
| CLOB /book, /price | 1,500 |
| Data API general | 1,000 |

### 关键端点 (免费, 无需认证)
```
GET https://gamma-api.polymarket.com/events         # 所有预测市场
GET https://gamma-api.polymarket.com/markets         # 单个市场合约
GET https://gamma-api.polymarket.com/markets?slug={slug}  # 特定市场

# CLOB (只读, 无需认证)
GET https://clob.polymarket.com/book?token_id={id}  # 订单簿
GET https://clob.polymarket.com/price?token_id={id} # 当前价格
GET https://clob.polymarket.com/midpoint?token_id={id} # 中间价
```

### SDK
- Python: `pip install polymarket-apis`
- TypeScript: `@polymarket/clob-client`
- Rust: `rs-clob-client`

### 最佳使用场景
事件概率追踪（选举、美联储决议、地缘政治事件）、通过预测市场价格作为情绪代理、宏观交易的独特 Alpha 来源。

---

## 4.3 期权资金流 (免费来源)

| 来源 | 访问 | 成本 | 数据 |
|---|---|---|---|
| **Unusual Whales API** | REST + WebSocket + Kafka | 有免费层；完整版: $250/月 | 期权资金流、暗池、100+ 端点 |
| **Barchart (via Apify)** | Apify 爬虫 | 免费试用 | 异常期权活动 |
| **InsiderFinance** | 网页平台 | 免费层 | 异常期权活动检测 |
| **CBOE** | 网站延迟数据 | 免费 | 看跌/看涨比率、VIX 期限结构 |

### Unusual Whales API
```
Base: https://api.unusualwhales.com
Auth: Bearer {API_KEY}

GET /api/stock/{ticker}/options-flow     # 按标的查看期权资金流
GET /api/darkpool/{ticker}               # 暗池成交
GET /api/market/overview                 # 全市场概览
```

### 最佳使用场景
通过异常期权交易量检测机构仓位、暗池吸筹信号、看跌/看涨比率用于情绪判断。

---

## 4.4 其他免费 Level 2 / 订单簿来源

| 来源 | 市场 | 免费层 | 备注 |
|---|---|---|---|
| **Alpaca Crypto** | 20+ 币种 | 免费 | 通过 API 的 L2 流数据 |
| **Finnhub** | 股票 + 加密货币 | 免费 (60 calls/min) | 实时报价，部分 L2 |
| **Alpha Vantage** | 股票, 外汇, 加密货币 | 免费 (25 req/天) | 非常有限 |
| **Twelve Data** | 股票, 外汇, 加密货币 | 免费 (800 req/天) | 适合原型开发 |
| **Tardis.dev** | 加密货币 (历史) | 免费试用 | Tick 级别历史订单簿 |

---

# 5. 交易 Agent 推荐技术栈

## 第一梯队: 核心免费来源 (必备)

| 类别 | 来源 | 原因 |
|---|---|---|
| **DeFi/TVL/价格** | DeFiLlama | 31 个免费端点，无需认证，全面 |
| **链上 SQL** | Dune Analytics | 每月 2,500 积分，自定义鲸鱼查询 |
| **加密货币订单流** | Binance WebSocket | 实时，免费，亚秒级深度 |
| **宏观/经济** | FRED API | 800K+ 序列，完全免费 |
| **情绪指数** | Alternative.me FGI | 免费，无需认证，每日信号 |
| **中国市场** | AKShare | 免费，实时 A 股，全面 |
| **区块链浏览器** | Etherscan | 免费，每天 100K 次调用 |
| **预测市场** | Polymarket Gamma API | 免费，无需认证，事件概率 |

## 第二梯队: 有价值的补充

| 类别 | 来源 | 原因 |
|---|---|---|
| **社交 + 链上** | Santiment Free | 每月 1K 次调用，社交量 + 链上指标 |
| **跨链 SQL** | Flipside Crypto | 每月 500 查询秒数，20+ 条链，地址标签 |
| **聪明钱** | Arkham Intelligence | 最佳实体归属（有限免费） |
| **Reddit 情绪** | Reddit API | 100 req/min, r/wallstreetbets 信号 |
| **价格预言机** | Chainlink Feeds | 去中心化、防篡改价格数据 |
| **经济日历** | ForexFactory 抓取 | 影响级别事件数据 |
| **期权资金流** | Unusual Whales Free | 机构仓位信号 |

## 第三梯队: 补充 / 有预算时付费

| 类别 | 来源 | 原因 |
|---|---|---|
| **加密情绪** | LunarCrush | Galaxy Score (起步 $1/天) |
| **中国情绪** | 雪球 / 股吧抓取 | 5700 万+ 用户情绪 |
| **X/Twitter** | snscrape / X API | 经常失效；不适合生产环境 |
| **钱包追踪** | DeBank OpenAPI | DeFi 持仓监控 |
| **L2 分析** | L2Beat (抓取) | Layer 2 健康度监控 |
| **经济日历** | TradingEconomics | 全面但付费 |

---

# 6. 免费容量汇总

| 来源 | 每日免费调用次数 | 实时? | 需要认证? |
|---|---|---|---|
| DeFiLlama | 无限（软限制） | 每小时 TVL | 否 |
| Dune Analytics | ~83/天 (2500/月) | 取决于查询 | 是 (API key) |
| Flipside | ~17/天 (500 秒/月) | 分钟级延迟 | 是 (API key) |
| Etherscan | 100,000 | 是 | 是 (API key) |
| Alternative.me FGI | 86,400 (60/min) | 每日 | 否 |
| Santiment | ~33/天 (1000/月) | 30 天延迟 | 是 (API key) |
| FRED | 无限（软限制） | 随发布 | 是 (API key) |
| Reddit | 144,000 (100/min) | 是 | 是 (OAuth) |
| Binance WS | 无限 | 是 (亚秒级) | 否 |
| Polymarket | ~430K/天 (500/10s) | 是 | 否 |
| Chainlink | 无限 (受 RPC 限制) | 是 | 否 (需 RPC key) |

---

## 参考资料

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
