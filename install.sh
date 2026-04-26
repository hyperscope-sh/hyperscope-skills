#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: install.sh <plugin> [api-key] [--global|--local]

Installs a Hyperscope plugin into a Claude Code skills directory.

Arguments:
  plugin       Plugin name. Available: hyperliquid
  api-key      (Optional) API key. If provided, written to .env (chmod 600).
               Without a key the skill works on the free tier.

Flags:
  --local      Install to ./.claude/skills/  (default if inside a git repo)
  --global     Install to ~/.claude/skills/  (default otherwise)

Get an API key at https://hyperscope.sh
EOF
}

PLUGIN=""
KEY=""
SCOPE=""

for arg in "$@"; do
  case "$arg" in
    --global) SCOPE="global" ;;
    --local)  SCOPE="local" ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [ -z "$PLUGIN" ]; then PLUGIN="$arg"
      elif [ -z "$KEY" ];    then KEY="$arg"
      else echo "Unexpected argument: $arg" >&2; usage; exit 1
      fi
      ;;
  esac
done

if [ -z "$PLUGIN" ]; then
  usage; exit 1
fi

case "$PLUGIN" in
  hyperliquid)
    SKILL="hyperliquid"
    ENV_KEY="HYPERSCOPE_API_KEY"
    ;;
  *) echo "Unknown plugin: $PLUGIN" >&2; echo "Available: hyperliquid" >&2; exit 1 ;;
esac

# Pick install root
if [ -z "$SCOPE" ]; then
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    SCOPE="local"
  else
    SCOPE="global"
  fi
fi

if [ "$SCOPE" = "local" ]; then
  ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  SKILLS_DIR="${ROOT}/.claude/skills"
else
  SKILLS_DIR="${HOME}/.claude/skills"
fi

REPO_RAW="https://raw.githubusercontent.com/hyperscope-sh/hyperscope-skills/main/plugins/${PLUGIN}/skills/${SKILL}"
DEST="${SKILLS_DIR}/${SKILL}"

mkdir -p "$DEST"
echo "Installing ${PLUGIN} (${SCOPE}) → ${DEST}"

curl -fsSL "${REPO_RAW}/SKILL.md"     -o "${DEST}/SKILL.md"
curl -fsSL "${REPO_RAW}/.env.example" -o "${DEST}/.env.example"

if [ -n "$KEY" ]; then
  printf '%s=%s\n' "$ENV_KEY" "$KEY" > "${DEST}/.env"
  chmod 600 "${DEST}/.env"
  # Also persist to ~/.hyperscope/.env (single source of truth shared with marketplace installs).
  mkdir -p "${HOME}/.hyperscope"
  printf '%s=%s\n' "$ENV_KEY" "$KEY" > "${HOME}/.hyperscope/.env"
  chmod 600 "${HOME}/.hyperscope/.env"
  echo "✓ Installed. Key written to ~/.hyperscope/.env and ${DEST}/.env"
elif [ ! -f "${DEST}/.env" ]; then
  cp "${DEST}/.env.example" "${DEST}/.env"
  echo "✓ Installed (free tier). To raise limits, set the key at ~/.hyperscope/.env (var: ${ENV_KEY})"
else
  echo "✓ Installed. Existing .env preserved."
fi
