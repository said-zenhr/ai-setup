---
description: Show knowledge-gap study list and suggest a kata
---

Run `ruby ${CLAUDE_PLUGIN_ROOT}/scripts/tw.rb stats`, extract the gaps
section, and propose ONE no-AI kata (20–40 min) targeting the top gap.
If the user accepts and completes it, review their code and record the result
with `ruby ${CLAUDE_PLUGIN_ROOT}/scripts/tw.rb kata pass|fail "<desc>"`.
