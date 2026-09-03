# Project memory — training-wheels

## History

- 2026-08-16: designed from research (Anthropic skill-formation RCT, METR
  perception gap, HN/Osmani practitioner consensus) + Stark's Training Wheels
  Protocol gap analysis. Built in Python, same day ported to Ruby (ZenHR is
  Rails; Saeed wants to read/hack his own suit). v1.1.0 installed, user scope.

## Decisions (don't relitigate)

- **Ruby, stdlib only.** No gems — macOS ruby has no curses gem, so dash uses
  raw ANSI + `io/console`. Node was runner-up (plugin-ecosystem standard);
  revisit only if publishing publicly or Windows support needed.
- **Plugin with hooks, not plain skill** — enforcement must survive my drift;
  same mechanism as caveman/ponytail.
- **Two-step override** (Saeed's explicit ask): push back once + one hint,
  second ask complies. Never comply on first "just do it".
- **Kata gates on level-up** — the "nothing without the suit" exam. XP grinding
  must never unlock alone.
- **Tampering detectable, not preventable** — owner can always hack own suit
  (Ned problem); we log loudly instead of fighting it.
- **Boilerplate/concepts exempt** — friction only on code delegation, the one
  pattern the RCT showed harms learning.

## Manual test recipe

```sh
cd ~/Desktop/training-wheels
rm -rf ~/.claude/training-wheels
ruby scripts/tw.rb inject                                        # fresh strict
echo '{"prompt":"just do it for me"}' | ruby scripts/tw.rb scan  # pushback msg
echo '{"prompt":"im sure do it"}'     | ruby scripts/tw.rb scan  # confirmed −15
echo '{"tool_input":{"file_path":"/x/src/app.ts"}}' | ruby scripts/tw.rb gate
# ^ NOTE: prints nothing here because a confirmed override <30min unlocks the
#   gate. For a deny, wipe state first, then run gate alone.
ruby scripts/tw.rb xp 10 test && ruby scripts/tw.rb kata pass demo
ruby scripts/tw.rb stats
rm -rf ~/.claude/training-wheels                                 # clean up
```

## Ideas parked (not committed)

- `/tw-stats --share` mentor view (Stark-monitoring; off by default)
- weekly auto-nag at 3+ overrides (skill mentions it; no cron yet)
- Windows support (needs node port)

## Gotchas

- `hooks/hooks.json` is auto-loaded by convention — do NOT also set
  `"hooks"` in plugin.json (duplicate-hooks load error, plugin gets orphaned).
- Plugin cache is version-pinned: editing files without bumping
  `plugin.json` version = update is a no-op, stale code keeps running.
- `Date`/regex in scan: OVERRIDE_RE is intentionally narrow; widen carefully —
  false positives make me refuse normal requests.
- Hooks print to stdout as injected context; noisy output pollutes every turn.
