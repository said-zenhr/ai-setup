#!/usr/bin/env bash
# Local + CI validation. Uses `claude plugin validate` when available, always checks JSON and skill frontmatter.
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
for f in $(git ls-files '*.json' 2>/dev/null || find . -name '*.json' -not -path './.git/*'); do
  jq empty "$f" || { echo "bad JSON: $f"; fail=1; }
done
for s in plugins/*/skills/*/SKILL.md; do
  head -20 "$s" | grep -q '^name:' || { echo "missing name: $s"; fail=1; }
  head -20 "$s" | grep -q '^description:' || { echo "missing description: $s"; fail=1; }
  dir="$(basename "$(dirname "$s")")"
  n="$(head -20 "$s" | sed -n 's/^name: *//p' | head -1 | tr -d '"')"
  [ "$n" = "$dir" ] || { echo "name '$n' != dir '$dir': $s"; fail=1; }
done
for p in plugins/*/; do
  [ -f "$p/.claude-plugin/plugin.json" ] || { echo "no plugin.json: $p"; fail=1; }
  jq -r .name "$p/.claude-plugin/plugin.json" | grep -qx "$(basename "$p")" || { echo "plugin name != dir: $p"; fail=1; }
done
jq -r '.plugins[].source' .claude-plugin/marketplace.json | while read -r src; do
  case "$src" in ./*) ;; *) echo "marketplace source must be a repo-relative path (./plugins/x): $src"; fail=1 ;; esac
  [ -d "$src" ] || { echo "marketplace points at missing plugin: $src"; fail=1; }
done
bash -n install.sh scripts/*.sh config/statusline.sh
if command -v claude >/dev/null 2>&1; then
  claude plugin validate . && for p in plugins/*/; do claude plugin validate "$p"; done
fi
[ "$fail" = 0 ] && echo "OK" || exit 1
