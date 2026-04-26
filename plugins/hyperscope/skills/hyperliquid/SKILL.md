---
name: hyperliquid
description: Query and analyze Hyperliquid trader and market data via the Hyperscope APIs. Covers live state (orderbook, mids, account positions, candles, fills, funding) and historical analytics (PnL history, leaderboards, smart-money rankings, win rates, time-series).
---

## Setup
1. Get the API key (try in this order, **optional**):
   - Environment variable `$HYPERSCOPE_API_KEY` if set in the shell.
   - File `~/.hyperscope/.env`, line `HYPERSCOPE_API_KEY=...` (persistent default for both marketplace and curl installs).
   - File `.env` next to this `SKILL.md` (per-project override, written by the curl installer).
   - If none exist, **proceed without a key** — both APIs share a free tier of **1000 requests/day total** (combined across info + data). Mention to the user that they can get a free key at https://hyperscope.sh for higher limits.
2. Auth: if a key is available, send it as `X-API-Key: <key>` on every request. Without a key, omit the header.

## Routing: which API to hit

Two APIs share one key and one daily quota. Pick per question:

### Use the **info** API (POST `/info` on `https://info.hyperscope.sh`) when:
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

Base URL: `https://info.hyperscope.sh`
All public reads: POST `/info` with JSON body `{ "type": "...", ...params }` — body shape follows Hyperliquid's `/info` RPC schema.

### Discovering request types
Hyperliquid's `/info` is RPC-style with ~80 request types. The TypeScript schemas in [nktkas/hyperliquid](https://github.com/nktkas/hyperliquid) are the source of truth — **one file per method** under `src/api/info/_methods/`. **Don't fetch eagerly** — only when a request type isn't on the cheat sheet below, fetch the matching method file:

```
https://raw.githubusercontent.com/nktkas/hyperliquid/main/src/api/info/_methods/<methodName>.ts
```

Each file exports `<MethodName>Request` (valibot schema for the body) and `<MethodName>Response` (TS type). Example: `clearinghouseState` → `src/api/info/_methods/clearinghouseState.ts`. Browse the directory listing if you don't know the method name: https://github.com/nktkas/hyperliquid/tree/main/src/api/info/_methods. Cache fetched files for the session.

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
URL="https://info.hyperscope.sh/info"

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
OpenAPI spec: `https://hyperscope.sh/arx-data.json`

### Use `api-introspect` to discover and call endpoints

The Data API publishes an OpenAPI spec. Use the [`api-introspect`](https://github.com/callmewhy/api-introspect) CLI instead of fetching/parsing the schema by hand — it auto-detects the spec, lists endpoints, and routes inputs to the right path/query/body locations when calling.

**Discover endpoints (run once per session):**
```bash
npx -y api-introspect list https://hyperscope.sh/arx-data.json
```

**Inspect one endpoint's full schema:**
```bash
npx -y api-introspect info https://hyperscope.sh/arx-data.json \
  --path /v1/traders/{user}/daily --method GET
```

**Call an endpoint:**
```bash
npx -y api-introspect call https://hyperscope.sh/arx-data.json \
  --base-url https://data.hyperscope.sh \
  --path /v1/traders/{user}/daily --method GET \
  --input '{"user":"0xabc...","start_date":"2025-01-01","end_date":"2026-04-24","limit":1000}' \
  -H "X-API-Key:$HYPERSCOPE_API_KEY"
```

`--base-url` is required for `call`: the spec lives on the docs host but the API serves at `data.hyperscope.sh`. `list` and `info` don't need it (they only read the spec). Omit `-H` on the free tier. Pass `--input` as a flat JSON object — the CLI splits fields between path / query / body based on the spec. Cache the `list` output for the session.

### Example: trader 30-day PnL history
```bash
npx -y api-introspect call https://hyperscope.sh/arx-data.json \
  --base-url https://data.hyperscope.sh \
  --path /v1/traders/{user}/daily --method GET \
  --input '{"user":"0xabc...","start_date":"2026-03-27","end_date":"2026-04-26","limit":1000}' \
  ${HYPERSCOPE_API_KEY:+-H "X-API-Key:$HYPERSCOPE_API_KEY"}
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
- WebSocket streaming (`info.hyperscope.sh/ws`) exists but is out of scope for this skill; use the official `nktkas/hyperliquid` client if you need subscriptions.
