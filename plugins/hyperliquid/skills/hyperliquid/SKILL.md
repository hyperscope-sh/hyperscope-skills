---
name: hyperliquid
description: Query and analyze Hyperliquid trader and market data via the Hyperscope APIs. Covers live state (orderbook, mids, account positions, candles, fills, funding) and historical analytics (PnL history, leaderboards, smart-money rankings, win rates, time-series).
---

## Setup
1. Get the API key (try in this order, **optional**):
   - Environment variable `$HYPERSCOPE_API_KEY` if set in the shell.
   - File `~/.hyperscope/.env`, line `HYPERSCOPE_API_KEY=...` (persistent default for both marketplace and curl installs).
   - File `.env` next to this `SKILL.md` (per-project override, written by the curl installer).
   - If none exist, **proceed without a key** — both APIs are open on a free tier (1000 requests/day). Mention to the user that they can get a free key at https://hyperscope.sh for higher limits.
2. Auth: if a key is available, send it as `X-API-Key: <key>` on every request. Without a key, omit the header.

## Routing: which API to hit

Two upstream APIs share one key. Pick per question:

### Use the **info** API (POST `/info` on `https://api.hyperscope.sh`) when:
- The question maps cleanly to a single Hyperliquid `/info` request type.
- Live market state: orderbook, mid prices, candles, meta tables.
- Single-account snapshot: balances, positions, open orders, recent fills, funding payments, ledger updates.
- Cost (authenticated): 1 credit/call.

### Use the **data** API (GET `/v1/*` on `https://data.hyperscope.sh`) when:
- Answer needs aggregation, ranking, or time-series with sensible defaults.
- Cross-trader queries: top by PnL, smart-money rankings, leaderboards.
- Pre-joined analytics that aren't a single `/info` call: cumulative PnL, ROI, win-rate, daily/weekly series.
- Cost (authenticated): 2 credits/call.

### When in doubt
Try **info** first — it's cheaper and closer to raw HL. Only fall back to **data** if info doesn't expose the right shape.

---

## Info API

Base URL: `https://api.hyperscope.sh`
All public reads: POST `/info` with JSON body `{ "type": "...", ...params }` — the request format mirrors Hyperliquid's native `/info` RPC.

### Discovering request types
Hyperliquid's `/info` is RPC-style with ~30 request types. The TypeScript interfaces in [nktkas/hyperliquid](https://github.com/nktkas/hyperliquid) are the source of truth. **Don't fetch them eagerly** — only when a request type isn't on the cheat sheet below:

```
https://raw.githubusercontent.com/nktkas/hyperliquid/main/src/types/info/requests.d.ts
https://raw.githubusercontent.com/nktkas/hyperliquid/main/src/types/info/responses.d.ts
```
Cache for the session.

### Common requests (cheat sheet)

| Type | Body | Returns |
|------|------|---------|
| `meta` | `{"type":"meta"}` | universe (all perp coins) + margin tables |
| `spotMeta` | `{"type":"spotMeta"}` | spot universe + token metadata |
| `allMids` | `{"type":"allMids"}` | mid prices for every coin |
| `l2Book` | `{"type":"l2Book","coin":"BTC"}` | level-2 orderbook (top N levels per side) |
| `candleSnapshot` | `{"type":"candleSnapshot","req":{"coin":"BTC","interval":"1m","startTime":<ms>,"endTime":<ms>}}` | OHLCV candles |
| `clearinghouseState` | `{"type":"clearinghouseState","user":"0x..."}` | perps account state (positions, margin, value) |
| `spotClearinghouseState` | `{"type":"spotClearinghouseState","user":"0x..."}` | spot account balances |
| `openOrders` | `{"type":"openOrders","user":"0x..."}` | user's resting orders |
| `userFills` | `{"type":"userFills","user":"0x...","aggregateByTime":true}` | recent fills (capped, paginated by time) |
| `userFunding` | `{"type":"userFunding","user":"0x...","startTime":<ms>,"endTime":<ms>}` | funding payments in window |
| `userNonFundingLedgerUpdates` | `{"type":"userNonFundingLedgerUpdates","user":"0x...","startTime":<ms>}` | deposits, withdrawals, transfers |
| `portfolio` | `{"type":"portfolio","user":"0x..."}` | aggregated PnL/exposure snapshot |
| `historicalOrders` | `{"type":"historicalOrders","user":"0x..."}` | order history |

### Example: BTC orderbook + 1-minute candles for the last hour
```bash
KEY="$HYPERSCOPE_API_KEY"
URL="https://api.hyperscope.sh/info"

# Top of book
curl -s -X POST "$URL" \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"type":"l2Book","coin":"BTC"}' \
  | jq '{best_bid: .levels[0][0].px, best_ask: .levels[1][0].px}'

# Last hour of 1-minute candles
NOW=$(($(date +%s) * 1000))
HOUR_AGO=$((NOW - 3600000))
curl -s -X POST "$URL" \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d "{\"type\":\"candleSnapshot\",\"req\":{\"coin\":\"BTC\",\"interval\":\"1m\",\"startTime\":$HOUR_AGO,\"endTime\":$NOW}}" \
  | jq '[.[] | {t, o, h, l, c, v}]'
```

---

## Data API

Base URL: `https://data.hyperscope.sh`

### Discovering endpoints
The Data API is REST with an OpenAPI schema. **Don't fetch it eagerly** — fetch the first time you decide a query needs this API:

```
https://hyperscope.sh/arx-data.json
```

Cache the parsed schema for the rest of the session. Pick the operation that answers the question, build the URL as `BASE_URL + path`, attach required query params, send with `X-API-Key` if you have a key.

### Example: trader 30-day PnL history
```bash
curl -s -H "X-API-Key: $HYPERSCOPE_API_KEY" \
  "https://data.hyperscope.sh/v1/traders/0xabc.../daily?start_date=2025-01-01&end_date=2026-04-24&limit=1000" \
  | jq '[.data[] | {date: .trade_date, net_pnl: (.net_pnl // "0" | tonumber)}] | sort_by(.date)'
```

---

## Conventions (apply to both APIs)

- **Addresses**: lowercase every `0x...` address before sending. Mixed-case may 404 or return empty.
- **Time**:
  - Info API: Hyperliquid uses Unix **milliseconds** (not seconds). On macOS: `$(($(date +%s) * 1000))` or `gdate +%s%3N`.
  - Data API: ISO date strings (`YYYY-MM-DD`) for `start_date`/`end_date`; defaults are usually fine.
- **Numbers**: prices, sizes, money fields are stringified decimals; parse late to preserve precision. Money fields (`net_pnl`, `account_value`, `total_notional`, ...) can be `null` — coerce with 0 before aggregating. Hyperliquid perps values are USD-denominated.
- **Coin names**: perps use bare ticker (`BTC`, `ETH`); spot pairs use `@<index>` notation (look up via `spotMeta`).
- **Pagination** (info user-history requests): accept `startTime`/`endTime` (ms). Single calls cap at 500–2000 results — chunk windows for longer ranges.

## Rate limit handling (free tier)

Free-tier responses include:
- `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (Unix seconds at next UTC midnight).

Behavior:
- If `X-RateLimit-Remaining` drops below ~50, surface a brief note to the user that quota is running out and suggest getting a free key.
- On `429`, the daily quota is spent. Read `Retry-After` (seconds) from the response and tell the user when the quota resets, plus the upgrade hint. Don't auto-retry.

## Notes

- This skill is **read-only**. For order placement / signing, use Hyperliquid's official trading SDKs directly with your wallet — Hyperscope does not custody or sign.
- WebSocket streaming (`api.hyperscope.sh/ws`) exists but is out of scope for this skill; use the official `nktkas/hyperliquid` client if you need subscriptions.
