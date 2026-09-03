---
description: Show or manually force training-wheels level (forced changes are logged)
argument-hint: "[strict|normal|loose|auto]"
---

Run `ruby ${CLAUDE_PLUGIN_ROOT}/scripts/tw.rb level $ARGUMENTS` and show the
result. If the user forced a level ABOVE their earned level, note once that
it's logged in history — no lecture beyond that. `auto` returns to earned level.
