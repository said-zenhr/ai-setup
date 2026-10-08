---
name: weekly-summary
description: Build Sai'd's weekly work summary for the team meeting, grouped by project, from the vault's daily and session notes plus GitHub, Jira, Confluence, Slack and Bitbucket, and save it to the vault's Weekly/ folder. Use when the user asks for a "weekly summary", "what did I do this week", "team meeting update", "weekly rollup", or /weekly-summary.
---

# Weekly Summary

One terse, project-grouped summary of a work week, saved to the vault and printed for the team meeting.

## STEP 0 — Decide the week

- Workweek is **Sun–Thu**. Fri/Sat count only when a note shows real weekend work (release, war room, incident).
- No week named → the current week if today is Thu or later, else the previous one. Say which range you chose.
- Check every date's weekday with the shell: `date -j -f %Y-%m-%d <date> +%a`.

## STEP 1 — Gather (read-only)

Run in parallel, one agent per source when available:
- **Vault** (`~/Desktop/workspace/vault`): `Daily/` notes in range (their `project:` frontmatter groups the work), `Sessions/` notes in range, and each touched project note's `## Anchor` (State, Decisions, Open questions).
- **GitHub** (`gh`, owners `ZenHR` and `said-zenhr`): PRs I merged, opened, reviewed or commented on in range.
- **Bitbucket** (`bkt api`, workspace `boundlessdrop`, repos `mfe-monorepo`, `zds`, `zen_tms`): PRs I authored or reviewed in range.
- **Jira** (cloudId `5aa9d8cb-1d53-438d-a617-1b6462e66491`): my issues resolved or updated in range.
- **Confluence**: pages I created or edited in range.
- **Slack** (`from:<@U093RUDJCLV>`): meetings, decisions, incidents in range.

Vault notes are the base; the live sources fill gaps the dailies missed. Never rely on the vault alone.

**Coverage gate**: list each source as `OK n` / `empty` / `FAILED: reason` before writing. Put any FAILED source at the top of the note as `> ⚠️ Missing: …`.

## STEP 2 — Write `Weekly/YYYY-Www.md`

```markdown
---
type: weekly
description: "<one-line summary of the week>"
project:
  - "[[<each project touched>]]"
created: <week start>
---
# Week of <Sun date> – <Thu date>

## [[Project name]]
- shipped / progressed / decided — one line each, every ticket and PR linked

## Reviews
- [[Person]] — what, verdict · [#N](url)

## Next week
- open items carried over, from anchors' Open questions

> Summary: one line.
```

Rules:
- Group by project using the vault's project note names (`type: project`); people by their vault note names. Use names the team recognizes, not internal shorthand.
- Every ticket, PR and Confluence page is a markdown link; the scribe hook rejects bare refs.
- ≤ 400 words. One line per item, outcome first.
- Update an existing week's note in place; never duplicate.

## STEP 3 — Finish

Print a team-meeting version in chat: 3–6 bullets, one per project, no links. End with the coverage line.
