---
name: hyperliquid-data
description: Query Hyperscope's curated Hyperliquid Data API for traders, markets, aggregates, and history. Use this for analytics-flavored queries (joins, derived metrics, time-series with defaults). For raw Hyperliquid info reads, use the hyperliquid-info skill.
---

## Setup
1. Get the API key (try in this order, **optional**):
   - Environment variable `$HYPERSCOPE_API_KEY` if set in the shell.
   - File `~/.hyperscope/.env`, line `HYPERSCOPE_API_KEY=...` (persistent default for both marketplace and curl installs).
   - File `.env` next to this `SKILL.md` (per-project override, written by the curl installer).
   - If none exist, **proceed without a key** — the API is open to anonymous use on a free tier (1000 requests/day). Mention to the user that they can get a free key at https://hyperscope.sh for higher limits.
2. Fetch the OpenAPI schema once at session start: https://hyperscope.sh/arx-data.json. Parse it to discover every operation, parameter, and response shape.
3. Base URL for all requests: https://data.hyperscope.sh
4. Auth: if a key is available, send it as `X-API-Key: <key>` on every request. Without a key, omit the header.

## Rate limit handling (free tier)
Free-tier responses include:
- `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset` (Unix seconds at next UTC midnight).

Behavior:
- If `X-RateLimit-Remaining` drops below ~50, surface a brief note to the user that quota is running out and suggest getting a free key.
- On `429`, the daily quota is spent. Read `Retry-After` (seconds) from the response and tell the user when the quota resets, plus the upgrade hint. Don't auto-retry.

## Usage loop
- Pick the operation from the schema that answers the user's question.
- Build the URL as BASE_URL + path, substituting path parameters.
- Attach required query parameters per the schema.
- Issue the request with the auth header.

## Conventions
- **Addresses**: lowercase every `0x...` address before sending. Mixed-case or checksummed inputs can return 404.
- **Default time windows**: when the user asks for "history" without dates, try the endpoint's default first.
- **Nullable numerics**: money fields (`net_pnl`, `account_value`, `total_notional`, ...) are stringified decimals and may be `null`. Coerce with 0 or filter before aggregating; parse late to preserve precision. Units follow the schema's field descriptions (Hyperliquid perps values are USD-denominated).

## Example: trader PnL history
```bash
curl -s -H "X-API-Key: $HYPERSCOPE_API_KEY" \
  "https://data.hyperscope.sh/v1/traders/0xabc.../daily?start_date=2025-01-01&end_date=2026-04-24&limit=1000" \
  | jq '[.data[] | {date: .trade_date, net_pnl: (.net_pnl // "0" | tonumber)}] | sort_by(.date)'
```
