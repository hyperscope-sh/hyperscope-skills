# Hyperscope Skills

Agent skills for the [Hyperscope](https://hyperscope.sh) APIs. Distributed as a Claude Code plugin marketplace, with a curl-based installer for any agent that reads `SKILL.md`.

## Available plugins

| Plugin | Skill | Description |
|--------|-------|-------------|
| [`hyperscope`](./plugins/hyperscope) | `hyperliquid` | Query Hyperliquid blockchain data. Auto-routes between raw `/info` RPC (`info.hyperscope.sh`, 1 credit/call) and curated Data API analytics (`data.hyperscope.sh`, 2 credits/call). One key, two backends. |

## API key (optional)

The Hyperscope APIs have a free tier of **1000 requests/day** that works without any key (applies to both `data.hyperscope.sh` and `info.hyperscope.sh`). For higher limits, create a project at [hyperscope.sh](https://hyperscope.sh) → Dashboard → your project → **Agent** tab.

The skill works either way — without a key it uses the free tier, with a key it switches to authenticated (credit-metered) mode.

## Install (Claude Code plugin)

In Claude Code, run these **as two separate commands** (Claude Code only parses one slash command per prompt — pasting both at once will fail):

```
/plugin marketplace add hyperscope-sh/hyperscope-skills
```

```
/plugin install hyperscope@hyperscope-skills
```

That's it — the skill is usable immediately on the free tier. To raise your limit, save a key to the location the skill checks:

```bash
mkdir -p ~/.hyperscope && echo 'HYPERSCOPE_API_KEY=hs_...' > ~/.hyperscope/.env && chmod 600 ~/.hyperscope/.env
```

The skill checks `$HYPERSCOPE_API_KEY` first, then `~/.hyperscope/.env`. If you prefer a shell env var, append `export HYPERSCOPE_API_KEY=hs_...` to `~/.zshrc` or `~/.bashrc` instead.

## Install (curl, any agent)

For agents other than Claude Code, or for project-scoped install:

```bash
# With a key (writes it to .env automatically)
curl -fsSL https://raw.githubusercontent.com/hyperscope-sh/hyperscope-skills/main/install.sh \
  | bash -s -- hyperscope <YOUR_API_KEY>

# Without a key (free tier, 1000/day)
curl -fsSL https://raw.githubusercontent.com/hyperscope-sh/hyperscope-skills/main/install.sh \
  | bash -s -- hyperscope
```

The skill installs into:
- `<current-git-repo>/.claude/skills/hyperliquid/` (project-scoped, default in a git repo)
- or `~/.claude/skills/hyperliquid/` (default outside a git repo)

Force one or the other with `--local` / `--global`:

```bash
curl -fsSL .../install.sh | bash -s -- hyperscope <KEY> --global
```

When provided, the key is written to the skill's local `.env` **and** to `~/.hyperscope/.env` (both chmod 600), so the skill works the same regardless of how you installed it. Nothing leaves your machine. Rerun anytime to upgrade or rotate.

## Source

This repo is auto-synced from the [hyperscope monorepo](https://github.com/hyperscope-sh/hyperscope) on every change. Open issues or PRs there.

## Repo layout

```
.
├── .claude-plugin/
│   └── marketplace.json              # marketplace manifest
├── plugins/
│   └── hyperscope/
│       ├── .claude-plugin/
│       │   └── plugin.json           # plugin manifest
│       └── skills/
│           └── hyperliquid/
│               ├── SKILL.md
│               └── .env.example
├── install.sh                        # curl installer (non-Claude-Code path)
└── README.md
```
