---
name: hyperliquid-info
description: Explore Hyperliquid's public API (the /info RPC endpoint) via Hyperscope's authenticated proxy. Use for orderbook, account state, fills, candles, funding, mids, and other on-chain reads. For analytics-flavored queries, prefer the hyperliquid-data skill.
---

## Setup
1. Get the API key (try in this order, **optional**):
   - Environment variable `$HYPERSCOPE_API_KEY` if set in the shell.
   - File `~/.hyperscope/.env`, line `HYPERSCOPE_API_KEY=...` (persistent default for both marketplace and curl installs).
   - File `.env` next to this `SKILL.md` (per-project override, written by the curl installer).
   - If none exist, **proceed without a key** — the API is open to anonymous use on a free tier (1000 requests/day). Mention to the user that they can get a free key at https://hyperscope.sh for higher limits.
2. Base URL: `https://api.hyperscope.sh` (Hyperscope's proxy of `api.hyperliquid.xyz`).
3. All public reads are POST to `/info` with JSON body `{ "type": "...", ...params }`.
4. Auth: if a key is available, send it as `X-API-Key: <key>` on every request. Without a key, omit the header.

## Rate limit handling (free tier)
Free-tier responses include:
- `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (Unix seconds at next UTC midnight).

Behavior:
- If `X-RateLimit-Remaining` drops below ~50, surface a brief note to the user that quota is running out and suggest getting a free key.
- On `429`, the daily quota is spent. Read `Retry-After` (seconds) from the response and tell the user when the quota resets, plus the upgrade hint. Don't auto-retry.

## Discovering request types
Hyperliquid's public API is RPC-style with ~30 request types under a single `/info` endpoint. Treat the TypeScript interfaces in [nktkas/hyperliquid](https://github.com/nktkas/hyperliquid) as the source of truth for shapes:

- Request bodies: `src/types/info/requests.d.ts`
- Response shapes: `src/types/info/responses.d.ts`

For an unfamiliar type, fetch the relevant `.d.ts` once via:
```
https://raw.githubusercontent.com/nktkas/hyperliquid/main/src/types/info/requests.d.ts
https://raw.githubusercontent.com/nktkas/hyperliquid/main/src/types/info/responses.d.ts
```
and read the interface. Cache for the session.

## Common requests (cheat sheet)

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

For anything not on this table, check the nktkas type files.

## Conventions
- **Addresses**: lowercase every `0x...` address before sending. Mixed-case may 404 or return empty.
- **Time**: Hyperliquid uses Unix **milliseconds** (not seconds). On macOS use `$(($(date +%s) * 1000))` or `gdate +%s%3N`.
- **Numbers**: prices and sizes are stringified decimals; parse late to preserve precision. Money-like fields can be `null` — coerce with 0 before aggregating.
- **Coin names**: perps use the bare ticker (`BTC`, `ETH`); spot pairs use `@<index>` notation (look up via `spotMeta`).
- **Pagination**: most user-history requests accept `startTime` / `endTime` (ms). Single calls cap at 500-2000 results — chunk windows for longer ranges.
- **Credit cost**: 1 credit per `/info` call **when authenticated**. Free-tier calls don't consume credits but count toward the daily quota. The curated Data API costs 2 credits/call when authenticated. Use this skill for cheap raw reads, the data skill for joined analytics.

## Example: BTC orderbook + 1-minute candles for the last hour

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

## Notes
- This skill only proxies HL's **public read** endpoints. For order placement/signing, use Hyperliquid's official trading SDKs directly with your wallet — Hyperscope does not custody or sign.
- WebSocket streaming (`api.hyperscope.sh/ws`) exists but is out of scope for this skill; use the official `nktkas/hyperliquid` client if you need subscriptions.
