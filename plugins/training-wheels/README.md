# Training Wheels Protocol — Claude Code plugin

AI guardrails Saeed (junior dev) built for himself so AI assists learning
instead of replacing it. Evidence basis: Anthropic RCT 2026 — code delegation
harms learning, conceptual inquiry doesn't. See MEMORY.md for history/decisions.

## Layout

- `scripts/tw.rb` — entire engine, Ruby 3.2 **stdlib only** (no gems, ever).
  Subcommands: `inject` (SessionStart), `scan` (UserPromptSubmit),
  `gate` (PreToolUse), `xp`, `gap`, `kata`, `level`, `stats`, `dash` (ANSI UI).
- `hooks/hooks.json` — wires the three hooks to tw.rb. All end `; exit 0`
  (a hook must never break a session).
- `skills/training-wheels/SKILL.md` — behavior rules per level + XP table.
- `commands/tw-{stats,gaps,level}.md` — slash commands.
- `.claude-plugin/plugin.json` + `marketplace.json` — local marketplace install.

## Runtime state (NOT in this repo)

`~/.claude/training-wheels/state.json` + `state.sig` (sha256, salt `tw-v1:`).
Hand-edits break the sig → logged as tamper, surfaced at next SessionStart.
Never regenerate the sig to hide a tamper.

## Key mechanics (don't break these)

- Levels: strict → normal (200 XP + 1 kata) → loose (500 XP + 3 katas).
  Both thresholds required — XP alone must never level up.
- Override is two-step: OVERRIDE_RE sets `pending_override`, CONFIRM_RE on the
  next prompt confirms (−15 XP, logged). Emergency regex bypasses free.
- Strict gate: denies Edit/Write to source files; allows scratchpad/tmp,
  docs/config extensions, tests, and 30 min after a confirmed override/emergency.
- `exit 0` always; JSON output shape of `gate` is the Claude Code
  PreToolUse `hookSpecificOutput.permissionDecision` contract.

## Dev loop

Test:    see MEMORY.md "manual test recipe"
Release: bump version in `.claude-plugin/plugin.json` (cache is version-pinned,
         no bump = stale install), then
         `claude plugin marketplace update training-wheels &&
          claude plugin update training-wheels@training-wheels`, restart session.
Wipe state for testing: `rm -rf ~/.claude/training-wheels`

Launcher: `~/Desktop/tw-protocol` + Desktop on PATH → `tw-protocol` opens dash.
