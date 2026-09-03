# Setup inventory (snapshot 2026-09-03)

Reference dump of the full Claude Code setup this repo packages. Regenerate the live version any time with the prompt "list my claude setup, everything".

## Core config

| Item | Value |
|---|---|
| Claude Code | 2.1.259 |
| Model | Fable 5.1, effort medium (Fable 5: medium, Opus 5: medium, Sonnet 5: low) |
| Output style | Terse (`plugins/said-skills/output-styles/terse.md`) |
| Theme / verbose | dark / off |
| Voice | enabled, hold mode |
| Notifications | input-needed and agent push on |
| Auto-updates | off |
| Status line | `config/statusline.sh` |
| Auto mode | on, ZenHR environment profile (not in repo) |
| Hooks | One Orca dispatcher shim registered on 12 events (not in repo — see below) |

## Hooks — deliberately not vendored

The 12 hook entries in `settings.json` are not 12 hooks. They are the **same
generated command** (md5 `32ce876f`) registered on SessionStart, UserPromptSubmit,
Stop, StopFailure, SubagentStart, SubagentStop, TeammateIdle, PreToolUse,
PostToolUse, PostToolUseFailure, PermissionRequest, and PostCompact. It is a
cross-platform shim that dispatches to `$HOME/.orca/agent-hooks/claude-hook.sh`;
most of its ~27KB is Windows/PowerShell branching.

**Orca owns this.** It rewrites the block on install and upgrade, so a vendored
copy would rot. To restore hooks on a new machine, install Orca — not this repo.
`install.sh` warns if `~/.orca/agent-hooks/` is missing.

`autoMode` (`soft_deny` + the ZenHR environment profile) is hand-written and
*should* be vendored; it is not yet. See the repo TODO.

## Own skills (`plugins/said-skills/skills`)

bro, code-mentor, concise-output, daily-work-note, describe-pr, engineer-agent-builder, morning-brief, rails-code-review, release-ticket-title, terse-executor.

## Own plugins

- scribe 1.2.2 — hooks: PreToolUse (Edit|Write) gate, Stop safety net. Skills: scribe, scribe-backfill. Commands: scribe, scribe-backfill, scribe-due.
- training-wheels 1.1.1 — hooks: SessionStart inject, UserPromptSubmit scan, PreToolUse gate. Skill: training-wheels. Commands: tw-gaps, tw-level, tw-stats.

## Third-party

See `third-party/skills.txt` and `third-party/plugins.txt`.

## MCP servers

- User: excalidraw (HTTP).
- Project el-ciclo: tableplus (stdio). Project zen_triage: zen-triage (HTTP, ngrok, bearer token; never commit).
- Plugin: chrome-devtools (npx chrome-devtools-mcp).
- claude.ai connectors: Figma, Atlassian Rovo, Gmail, Google Calendar, Slack, ZenHR, plus unauthenticated stubs for AirOps, Airtable, Apollo.io, Canva, Clay, Gamma, Google Drive, HubSpot, Mixpanel, Postman, Semrush, Stytch, Webflow, Zoom.

## Project-scope extras (el-ciclo, not in repo)

Skills: add-ai-agent, add-left-menu-item, documentation-writer, rails-code-review, react-code-review. Agent: package-documenter.

## Built-in skills available

design, dataviz, artifact-design, artifact-diagramming, artifact-capabilities, update-config, keybindings-help, simplify, fewer-permission-prompts, loop, schedule, claude-api, workflow-authoring, run, init, security-review.

## Agent types

claude, claude-code-guide, Explore, general-purpose, Plan, statusline-setup (+ cavecrew-* when caveman is enabled).
