---
name: scribe-backfill
description: Reconstruct a gap in the vault (days/weeks unrecorded) by sweeping Jira, Confluence, Bitbucket, GitHub, Slack, Google Calendar, Gmail and any other connected MCP source, then writing the missing notes scribe-style. Use when the user says "fill the gaps", "backfill", "I haven't recorded in a while", or /scribe-backfill.
---

# Scribe backfill

Vault: `~/Desktop/workspace/vault`. All scribe rules apply — budgets, ≥2
wikilinks, search-before-create, templates. The gate hook enforces them on
every backfilled note too.

Every ticket, PR and Confluence page mentioned is a markdown link to its URL (scribe
skill step 4); every note sets `type`, `description` and `project:`, and touched
projects get their `## Anchor` updated.

Entity rule applies: any person/project linked >2× gets a note from its
template in `References/` (embeds `Backlinks.base`) — see scribe skill
"Entities & mentions".

## 1. Resolve the scope

Parse what the user actually meant; two scope kinds, combinable:

**Time scope** — "since July 15", "last month", "past two weeks", or nothing.
Interpret relative phrases against today's date. If no time given at all,
auto-detect: day after the newest of `Sessions/log.md` entry, newest `Daily/`
note, newest meeting note.

**Entity scope** — "fill gaps in <project/person/topic>", e.g. zen_triage:
1. Find the vault's knowledge of it: Grep the vault for `[[zen_triage]]` /
   name variants; note the newest mention date and what the notes claim
   (status, decisions, open questions).
2. Find reality: locate the project itself (repo on Desktop, Jira project,
   Confluence space, Slack channel — whatever matches the name) and pull
   activity SINCE the vault's newest mention.
3. The gap = the staleness delta between what the vault says and what
   actually happened. Sweep only sources relevant to that entity.
4. Update in place where a note already exists (append/correct, keep it
   under budget by pruning superseded lines) — new notes only for genuinely
   new events.

Entity scope without time scope means "vault-knowledge date → today".
State the resolved scope in one line ("zen_triage, vault stale since Jul 20,
sweeping repo+Jira+Slack to today") and confirm before sweeping.

## 2. Sweep (multi-modal, parallel)

Fan out one background agent per source — each blind to the others
(ToolSearch loads MCP tools inside agents):

- **Jira** (Atlassian MCP): issues Saeed created/was assigned/transitioned/
  commented in range.
- **Confluence** (Atlassian MCP): pages he created/edited.
- **Bitbucket + GitHub**: `git log --author` in local repos on Desktop;
  `gh search prs --author` / Bitbucket via Slack mentions if no direct access.
- **Slack**: threads he posted in, decisions in channels (search_public_and_private).
- **Google Calendar**: meetings attended (title, attendees, date).
- **Gmail**: sent mail with decisions/commitments.

Each agent returns raw dated events, no prose.

## 3. Distill and write

Merge, dedupe (a PR + its Jira ticket + its Slack thread = ONE event), then:

- Meetings → `Notes/YYYY-MM-DD Meeting with X.md` (Meeting Template),
  attendees linked.
- Shipped work → one session-style note per work item or per dense day:
  `Sessions/YYYY-MM-DD <topic>.md`. Batch quiet days: a single
  `Sessions/YYYY-MM-DD..DD summary.md` beats ten thin notes.
- Open action items discovered → `scribe.rb todo add`.
- Real insights → offer evergreen notes, don't auto-create.

Frontmatter marks provenance honestly — every backfilled note gets:

```yaml
generated: { by: claude-fable-5, at: <iso> }
verified: false
sources:
  - resource: <jira/slack/pr url>
tags: [backfilled]
```

Update `Sessions/index.md`; one line in `Sessions/log.md`:
"backfilled YYYY-MM-DD..YYYY-MM-DD (N notes)".

## 4. Report

End with: range covered, notes created (linked list), todos added, anything
ambiguous left OUT (never guess a decision — if a Slack thread is unclear,
list it for the user instead of fabricating a note).
