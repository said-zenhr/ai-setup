---
description: Record this session (or dictated content) into the vault now
argument-hint: "[optional: what to record]"
---

Follow the scribe skill: write the session note (or parse `$ARGUMENTS` as a
dictation — meeting/decision/todos), then run
`ruby ${CLAUDE_PLUGIN_ROOT}/scripts/scribe.rb mark <session_id>`.
