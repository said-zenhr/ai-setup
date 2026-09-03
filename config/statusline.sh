#!/usr/bin/env bash
# Reads Claude Code statusline JSON on stdin.
input=$(cat)
dir=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")

# git branch + dirty flag (not reliably in the JSON)
branch=""
if [ -n "$dir" ] && git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  git -C "$dir" diff --quiet 2>/dev/null && git -C "$dir" diff --cached --quiet 2>/dev/null || branch="${branch}*"
fi

jq -rj --arg branch "$branch" '
  def clr(x): "[" + x + "m";
  def dim: clr("2"); def rst: clr("0");
  def g: clr("32"); def y: clr("33"); def r: clr("31"); def c: clr("36"); def m: clr("35");

  ( .workspace.current_dir // .cwd // "" | split("/") | last ) as $dir
  | ( .model.display_name // .model.id // "?" ) as $model
  | ( if .fast_mode == true then "⚡" else "" end ) as $fast
  | ( .effort.level // "" ) as $effort
  | ( .context_window.remaining_percentage // null ) as $ctx
  | ( .cost.total_cost_usd // 0 ) as $cost
  | ( .rate_limits.five_hour.used_percentage // null ) as $rl
  | ( .rate_limits.five_hour.resets_at // null ) as $reset

  | ( c + "📁 " + $dir + rst ) as $s_dir
  | ( if $branch != "" then g + "🌿 " + $branch + rst else "" end ) as $s_branch
  | ( m + "🤖 " + $model + $fast + rst ) as $s_model
  | ( if $effort != "" then "⚙️ " + $effort else "" end ) as $s_effort
  | ( if $ctx != null then
        ( if $ctx < 15 then r elif $ctx < 30 then y else g end )
        + "🧠 " + ($ctx | floor | tostring) + "%" + rst
      else "" end ) as $s_ctx
  | ( dim + "💵 $" + ($cost | . * 100 | round / 100 | tostring) + rst ) as $s_cost
  | ( if $reset != null then
        ( ($reset - now) / 60 | floor ) as $mins
        | if $mins > 0 then " (" + ($mins/60|floor|tostring) + "h" + ($mins%60|tostring) + "m)" else "" end
      else "" end ) as $left
  | ( if $rl != null then
        ( if $rl > 85 then r elif $rl > 60 then y else dim end )
        + "5h " + ($rl | floor | tostring) + "%" + $left + rst
      else "" end ) as $s_rl

  | [ $s_dir, $s_branch, $s_model, $s_effort, $s_ctx, $s_cost, $s_rl ]
  | map(select(. != "")) | join(dim + " · " + rst)
' <<<"$input"
