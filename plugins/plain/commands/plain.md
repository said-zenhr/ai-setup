---
description: Set the STE100 reply word cap (1-7, a level name, a word count 30-900, or off)
argument-hint: "[1-7 | whisper|terse|brief|normal|detailed|thorough|essay | 30-900 | off]"
allowed-tools: Bash(ruby:*)
---

!`ruby "${CLAUDE_PLUGIN_ROOT}/scripts/plain.rb" set $ARGUMENTS`

Relay the line above to the user in one sentence. From the next reply on, obey that cap and the STE100 rules.
