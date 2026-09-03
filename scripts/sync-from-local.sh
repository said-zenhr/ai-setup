#!/usr/bin/env bash
# Pull the live ~/.claude state back into this repo so the repo stays the source of truth.
# Copies: own (non-symlink) skills, output styles, statusline, sanitized settings, third-party skill list.
set -euo pipefail
cd "$(dirname "$0")/.."
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "▸ own skills"
for d in "$CLAUDE_DIR"/skills/*/; do
  [ -L "${d%/}" ] && continue            # symlinks = third-party (npx skills); tracked in third-party/skills.txt
  name="$(basename "$d")"
  rm -rf "plugins/said-skills/skills/$name"
  cp -R "$d" "plugins/said-skills/skills/$name"
  echo "  $name"
done
find plugins -name .DS_Store -delete

echo "▸ output styles + statusline"
cp "$CLAUDE_DIR"/output-styles/*.md plugins/said-skills/output-styles/ 2>/dev/null || true
cp "$CLAUDE_DIR/statusline.sh" config/statusline.sh

echo "▸ settings (sanitized: hooks, autoMode, machine paths dropped)"
jq 'del(.hooks, .autoMode, .skipDangerousModePermissionPrompt)
    | .statusLine = {type:"command", command:"bash \"$HOME/.claude/statusline.sh\""}' \
    "$CLAUDE_DIR/settings.json" > config/settings.json

echo "▸ third-party skills list"
if [ -f "$HOME/.agents/.skill-lock.json" ]; then
  {
    echo "# Third-party skills installed with \`npx skills add <repo> --skill <names> -g -y\`."
    echo "# One line per source repo: <owner/repo> <comma-separated skill names>"
    echo "# Not vendored here on purpose: they update from upstream via \`npx skills update -g\`."
    echo
    jq -r '.skills | to_entries | group_by(.value.source)[] | "\(.[0].value.source) \([.[].key] | sort | join(","))"' "$HOME/.agents/.skill-lock.json" | sort
  } > third-party/skills.txt
fi

echo "▸ plugins"
{
  echo "# Third-party plugins: <plugin>@<marketplace>  <enabled|disabled>"
  echo "# Marketplaces are declared in config/settings.json (extraKnownMarketplaces); install.sh adds them."
  jq -r '.enabledPlugins | to_entries[] | select(.key | endswith("@said") | not) | "\(.key) \(if .value then "enabled" else "disabled" end)"' "$CLAUDE_DIR/settings.json"
} > third-party/plugins.txt

git status --short
