#!/usr/bin/env bash
# One-shot install of Sai'd's Claude Code setup on a fresh machine. Idempotent; safe to re-run.
#   curl -fsSL https://raw.githubusercontent.com/said-zenhr/ai-setup/main/install.sh | bash
# or, from a clone:  ./install.sh
set -euo pipefail

REPO="said-zenhr/ai-setup"
MARKETPLACE="said"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
SKIP_THIRD_PARTY="${SKIP_THIRD_PARTY:-0}"

log()  { printf '\033[1;32m▸\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 ($2)"; exit 1; }; }

need claude "install Claude Code first: https://code.claude.com/docs/en/setup"
need jq     "brew install jq"
need git    "install git"

# Running from a clone? Use it as the marketplace source so local edits are what gets installed.
if [ -n "$HERE" ] && [ -f "$HERE/.claude-plugin/marketplace.json" ]; then
  SOURCE="$HERE"
else
  SOURCE="$REPO"
fi

log "Adding marketplaces"
add_mp() { claude plugin marketplace add "$1" >/dev/null 2>&1 && log "  added $1" || log "  already have $1"; }
add_mp "$SOURCE"
add_mp warpdotdev/claude-code-warp
add_mp DietrichGebert/ponytail
add_mp JuliusBrussee/caveman

log "Installing plugins"
inst() { # <plugin@marketplace> <enabled|disabled>
  claude plugin install "$1" --scope user >/dev/null 2>&1 && log "  installed $1" || log "  already have $1"
  if [ "$2" = "disabled" ]; then claude plugin disable "$1" --scope user >/dev/null 2>&1 || true; fi
}
inst "said-skills@$MARKETPLACE" enabled
inst "scribe@$MARKETPLACE" enabled
inst "training-wheels@$MARKETPLACE" disabled
PLUGINS_TXT="${HERE:+$HERE/third-party/plugins.txt}"
if [ -n "$PLUGINS_TXT" ] && [ -f "$PLUGINS_TXT" ]; then
  grep -v '^\s*#' "$PLUGINS_TXT" | grep -v '^\s*$' | while read -r p state; do inst "$p" "$state"; done
else
  inst ruby-lsp@claude-plugins-official enabled
  inst chrome-devtools-mcp@claude-plugins-official enabled
  inst warp@claude-code-warp enabled
  inst ponytail@ponytail disabled
  inst caveman@caveman disabled
fi

log "Status line"
mkdir -p "$CLAUDE_DIR"
if [ -n "$HERE" ] && [ -f "$HERE/config/statusline.sh" ]; then
  cp "$HERE/config/statusline.sh" "$CLAUDE_DIR/statusline.sh"
else
  curl -fsSL "https://raw.githubusercontent.com/$REPO/main/config/statusline.sh" -o "$CLAUDE_DIR/statusline.sh"
fi
chmod +x "$CLAUDE_DIR/statusline.sh"

log "Settings"
if [ -n "$HERE" ] && [ -f "$HERE/config/settings.json" ]; then
  TEMPLATE="$HERE/config/settings.json"
else
  TEMPLATE="$(mktemp)"; curl -fsSL "https://raw.githubusercontent.com/$REPO/main/config/settings.json" -o "$TEMPLATE"
fi
TARGET="$CLAUDE_DIR/settings.json"
if [ ! -f "$TARGET" ]; then
  cp "$TEMPLATE" "$TARGET"; log "  wrote $TARGET"
else
  # Merge: template keys fill in only where the existing file has no value. Existing wins on conflict.
  cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d%H%M%S)"
  jq -s '.[0] * .[1]' "$TEMPLATE" "$TARGET" > "$TARGET.tmp" && mv "$TARGET.tmp" "$TARGET"
  log "  merged into existing $TARGET (backup kept; your values win)"
fi

if [ "$SKIP_THIRD_PARTY" != "1" ]; then
  log "Third-party skills (via npx skills)"
  if command -v npx >/dev/null 2>&1; then
    LIST="${HERE:+$HERE/third-party/skills.txt}"
    [ -n "$LIST" ] && [ -f "$LIST" ] || { LIST="$(mktemp)"; curl -fsSL "https://raw.githubusercontent.com/$REPO/main/third-party/skills.txt" -o "$LIST"; }
    grep -v '^\s*#' "$LIST" | grep -v '^\s*$' | while read -r repo skills; do
      log "  $repo → $skills"
      npx -y skills@latest add "$repo" --skill "${skills//,/ }" -g -y -a claude-code >/dev/null 2>&1 || warn "  failed: $repo (re-run: npx skills add $repo -g)"
    done
  else
    warn "npx not found; skipping third-party skills. Install Node 22.20+ and re-run, or SKIP_THIRD_PARTY=1."
  fi
fi

log "Done. Start a new Claude Code session, then run /plugin to confirm, and /output-style Terse."
