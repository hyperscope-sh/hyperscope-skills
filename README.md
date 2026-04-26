# Hyperscope Skills

Agent skills for the [Hyperscope](https://hyperscope.sh) APIs. Distributed as a Claude Code plugin marketplace, with a curl-based installer for any agent that reads `SKILL.md`.

## Available plugins

| Plugin | Skills | Description |
|--------|--------|-------------|
| [`hyperliquid`](./plugins/hyperliquid) | `data`, `info` | Curated Hyperscope Data API + raw Hyperliquid public API, both via Hyperscope's authenticated proxy |

The `hyperliquid` plugin ships two skills that share one API key:
- **`data`** (`data.hyperscope.sh`) — analytics-flavored queries: joins, derived metrics, time-series with sane defaults. 2 credits/call.
- **`info`** (`api.hyperscope.sh`) — raw Hyperliquid `/info` RPC: orderbook, account state, fills, candles, funding. 1 credit/call.

## API key (optional)

The Hyperscope APIs have a free tier of **1000 requests/day** that works without any key (applies to both `data.hyperscope.sh` and `api.hyperscope.sh`). For higher limits, create a project at [hyperscope.sh](https://hyperscope.sh) → Dashboard → your project → **Agent** tab.

The skills work either way — without a key they use the free tier, with a key they switch to authenticated (credit-metered) mode.

## Install (Claude Code plugin)

In Claude Code:

```
/plugin marketplace add hyperscope-sh/hyperscope-skills
/plugin install hyperliquid@hyperscope-skills
```

That's it — the skills are usable immediately in anonymous mode. To raise your limit, save a key to the location the skills check:

```bash
mkdir -p ~/.hyperscope && echo 'HYPERSCOPE_API_KEY=hs_...' > ~/.hyperscope/.env && chmod 600 ~/.hyperscope/.env
```

The skills check `$HYPERSCOPE_API_KEY` first, then `~/.hyperscope/.env`. If you prefer a shell env var, append `export HYPERSCOPE_API_KEY=hs_...` to `~/.zshrc` or `~/.bashrc` instead.

## Install (curl, any agent)

For agents other than Claude Code, or for project-scoped install:

```bash
# With a key (writes it to .env automatically)
curl -fsSL https://raw.githubusercontent.com/hyperscope-sh/hyperscope-skills/main/install.sh \
  | bash -s -- hyperliquid <YOUR_API_KEY>

# Without a key (free tier, 1000/day)
curl -fsSL https://raw.githubusercontent.com/hyperscope-sh/hyperscope-skills/main/install.sh \
  | bash -s -- hyperliquid
```

This installs **both** skills (data + info) into:
- `<current-git-repo>/.claude/skills/hyperliquid-data/` and `.../hyperliquid-info/` (project-scoped, default in a git repo)
- or `~/.claude/skills/hyperliquid-{data,info}/` (default outside a git repo)

Force one or the other with `--local` / `--global`:

```bash
curl -fsSL .../install.sh | bash -s -- hyperliquid <KEY> --global
```

When provided, the key is written to each skill's local `.env` **and** to `~/.hyperscope/.env` (both chmod 600), so the skills work the same regardless of how you installed them. Nothing leaves your machine. Rerun anytime to upgrade or rotate.

## Source

This repo is auto-synced from the [hyperscope monorepo](https://github.com/hyperscope-sh/hyperscope) on every change. Open issues or PRs there.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json              # marketplace manifest
├── plugins/
│   └── hyperliquid/
│       ├── .claude-plugin/
│       │   └── plugin.json           # plugin manifest
│       └── skills/
│           ├── data/
│           │   ├── SKILL.md
│           │   └── .env.example
│           └── info/
│               ├── SKILL.md
│               └── .env.example
├── install.sh                        # curl installer (non-Claude-Code path)
└── README.md
```
