---
name: engineer-agent-builder
description: Build a distinct AI agent modeled on a specific engineer's real work history and skills. Use this whenever the user wants to "make an agent for" a named engineer/colleague, build a per-teammate AI persona, or create a roster/team of engineer-agents from commit history, Slack, Confluence, and Jira data. Always trigger this for requests like "make an X agent", "build agents for each engineer", or "create a persona agent based on [name]'s work" — runs a strict 4-phase interview → data-gather → analysis → confirmation workflow and enforces that no two agents in the roster share the same specialization.
---

# Engineer Agent Builder

Turns a real engineer's work footprint (commits, Slack, Confluence, Jira) into a
standalone AI agent persona file. Runs as a strict 4-phase conversation. Do not
skip phases or collapse them to save time — each phase ends with an explicit
user confirmation before moving on.

**Executor stance**: gather and present facts and options; do not invent an
engineer's personality traits or skill ratings the data doesn't support. Where
data is thin, say so and ask rather than guessing.

## Roster registry (read this first, every time)

Before Phase 1, check for an existing registry at
`/mnt/user-data/outputs/engineer-agents/registry.md` (create the folder if
missing — see `assets/registry-template.md`). This file tracks every agent
already built: engineer name, one-line specialization, and top 3 strengths.
Read it so Phase 3 can guarantee the new agent doesn't duplicate an existing
one's specialization. If two engineers' data genuinely produces overlapping
strengths, differentiate on the sharper, more specific trait (e.g. not
"backend engineer" twice — one is "permission hot-path perf", the other is
"Rails modularization/Packwerk").

## Phase 1 — Identify the engineer

Ask (use `ask_user_input_v0` where the options are enumerable, plain question otherwise):
- Name of the engineer (and their Slack/Jira/git handle if different from display name)
- Which repos/orgs to pull commit history from (default: same org as prior work — confirm, don't assume)
- Time window (e.g. last 6 months, since joining, all time)
- Anything the user already knows and wants folded in (e.g. "he's our Rails perf guy")

Ask follow-ups if the handle across systems isn't obvious (git author email vs
Slack display name vs Jira account ID often differ — resolve this before
Phase 2 or the data pull will silently miss things).

Do not proceed to Phase 2 until the user confirms scope.

## Phase 2 — Gather data

Pull, in this order, checking off each source. See `references/data-sources.md`
for exact tool calls per source (git log across repos, Slack search via MCP,
Confluence via Atlassian Rovo, Jira via Atlassian Rovo).

1. **Commit history** — across every repo in scope, filtered to the engineer's author identity. Capture: commit count, size/frequency pattern, which parts of the codebase they touch most, notable PRs.
2. **Slack messages** — search public + private channels for their messages. Capture: what channels they're active in, what kind of help they give (debugging, reviews, mentoring), tone.
3. **Confluence docs authored** — RFCs, ADRs, runbooks, onboarding docs.
4. **Jira tickets created/resolved** — ticket types, project areas, resolution patterns.
5. **Brainstorm with the user** — before closing this phase, explicitly ask what else might matter that isn't captured above. Prompt with concrete candidates rather than an open-ended "anything else": PR review comments/style, 1:1 or perf-review notes if the user has them, who they mentor vs. who mentors them, incident/postmortem involvement, on-call history. Let the user pick which of these are worth pulling.

**Phase 2 checkpoint (mandatory)**: after pulling what's available, report back
what was found per source and explicitly flag any source that came back thin
or empty (e.g. "only 4 Slack messages found — check the handle mapping").
Ask the user to confirm the data is sufficient, or to point at more sources,
before moving to Phase 3. Do not silently proceed on gappy data.

## Phase 3 — Analyze and propose the persona

Write findings to a markdown file (`{name}-analysis.md` in
`/mnt/user-data/outputs/engineer-agents/{name}/`) covering:

- **Footprint summary**: repos/areas touched, commit patterns, Slack/Confluence/Jira activity levels
- **Demonstrated strengths**: only claims the data actually supports, each with a concrete example (a PR, a doc, a thread) — no generic praise
- **Demonstrated weaknesses / gaps**: areas they don't touch, patterns suggesting struggle (long review cycles, repeated similar bugs, etc.) — stated factually, not judgmentally
- **Unique trait**: the one thing that differentiates this engineer from the others already in the registry — this becomes the agent's specialization
- **Proposed agent persona**: name, one-line specialization, tone/voice inferred from their actual Slack/PR-comment style, and what kinds of questions this agent should be best at answering

Cross-check the proposed specialization against the registry. If it overlaps
with an existing agent, sharpen it or flag the conflict to the user directly.

**Phase 3 checkpoint (mandatory)**: present the analysis and proposed persona
summary to the user (not just "file written" — surface the actual proposed
specialization and strengths inline in chat) and get explicit confirmation or
revisions before building the agent. Do not generate the agent file yet.

## Phase 4 — Final confirmation and build

Restate, in 3-5 bullets, exactly what will be built: agent name, specialization,
persona traits, and what makes it distinct from every other agent in the
registry. Get an explicit go-ahead.

Then:
1. Generate `{name}-agent.md` (use `assets/agent-template.md`) — a system-prompt-style
   persona file the user can drop into Claude Code, a project, or wherever they
   run these agents.
2. Append the new agent's name + specialization + top 3 strengths to the
   registry file.
3. Present both files to the user via `present_files`.

## Constraints throughout

- Never fabricate a strength, weakness, or quote not traceable to a pulled data point.
- Never let two agents converge on the same specialization — check the registry every time, not just at the end.
- Keep Phase 2/3 checkpoints real gates, not rhetorical — wait for the user's actual confirmation message before proceeding.
