---
name: daily-work-note
description: Create or update Sai'd's Obsidian daily work note in clean-hybrid format by gathering shipped/reviewed/meeting activity from Jira, GitHub, Bitbucket, Slack, and Confluence. Use when the user asks to "write/update my daily note", "log my work day", "daily standup note", "what did I do yesterday/today", or invokes /daily-work-note. Read-only everywhere except the vault's Daily/ folder.
---

# Daily Work Note

Build (or update) the user's Obsidian daily work note for a given day in **clean-hybrid format**, sourced only from real activity in Jira, GitHub, Bitbucket, Slack, and Confluence.

## STEP 0 — Decide the day (blocking gate)

- If the user named a date or said "today"/"yesterday", use that. "Yesterday" means the **last workday**: on a Sunday that is Thursday.
- If they did **NOT**, STOP and ask: **"today or yesterday?"** before doing anything else. Do not assume.
- **Headless/scheduled run** (no user to ask, prompt says `scheduled`): D = the last workday before today.
- Check the weekday with the shell, never from memory: `date -j -f %Y-%m-%d D +%a`.
- **Workweek is Sun–Thu; Fri and Sat are the weekend.** Write a Fri/Sat note only when there was real weekend work (a release, war room, incident or urgent bug) and say which in the Summary.

Resolve to:
- **D** = the target day, `YYYY-MM-DD`
- **D1** = D + 1 day
- TZ is **Asia/Amman** — interpret all date boundaries in that timezone.

## SAFETY (hard rules)

- **Read-only everywhere except the vault.** The only writes permitted are creating/editing markdown files under the vault's `Daily/` folder.
- Never comment, approve, merge, transition, push, or post in Jira / GitHub / Bitbucket / Slack.
- Never rename or delete existing vault files.
- **Integrity:** only state what's backed by a real Jira issue / PR / Slack message. Never fabricate. Never create a duplicate day.

## CONTEXT (don't rediscover)

- **Me:** Sai'd Al-Zain · saeed@zenhr.com · TZ Asia/Amman
- **Jira:** site `boundlesshr.atlassian.net` · cloudId `5aa9d8cb-1d53-438d-a617-1b6462e66491` · accountId `712020:6bb69e5f-91a1-4ad0-9298-2e111fc0f778` · projects `PLAT`, `DIM`
- **GitHub:** orgs `ZenHR` (`zenhr` aka el-ciclo, `osvdev`, `system_health`, `zen_ai_platform`) and `said-zenhr` (`zen_triage`, `pr-cycle-analyzer`, `vault`) · handle `said-zenhr` (use `gh` CLI)
- **Bitbucket:** workspace `boundlessdrop` · repos `mfe-monorepo`, `zds`, `zen_tms` · account_id `712020:6bb69e5f-91a1-4ad0-9298-2e111fc0f778` · use the logged-in `bkt` CLI (OAuth, refreshes itself). Never look for a keychain token.
- **Slack:** workspace `zenhr` · my user id `U093RUDJCLV`
- **Confluence:** same site/cloudId as Jira (`5aa9d8cb-1d53-438d-a617-1b6462e66491`) · my personal space key `~7120206bb69e5f91a14ad092982e111fc0f778`
- **Vault:** `~/Desktop/workspace/vault/` (daily notes in `Daily/`)

## STEP 1 — Gather for D (all read-only)

Run these in parallel where possible.

**Jira** (`searchJiraIssuesUsingJql` or equivalent):
- Shipped: `assignee=currentUser() AND resolutiondate>="D" AND resolutiondate<="D 23:59"`
- In-progress: `assignee=currentUser() AND updated>="D"`
- Capture: key + summary + status.

**GitHub** (`gh` CLI; confirm flags with `gh search prs --help` first; run for `--owner ZenHR` and `--owner said-zenhr`):
- `gh search prs --author=@me --merged=D` (shipped), `--created=D`, `--reviewed-by=@me --updated=D`, `--commenter=@me --updated=D`
- `updated:` only reflects the last update; for reviews, confirm the review/comment date is D via `gh api repos/<r>/pulls/<n>/reviews`.

**Bitbucket** (`bkt api "/repositories/boundlessdrop/<repo>/pullrequests?q=updated_on>=D AND updated_on<D1"`):
- For each repo (`mfe-monorepo`, `zds`, `zen_tms`), list PRs with `updated_on` in `[D, D1)`.
- Mine = `author.account_id` matches mine. Reviewed = I'm a `REVIEWER` participant.
- If field names are unclear, inspect one PR's JSON first.

**Slack** (`slack_search_*`):
- Search `from:<@U093RUDJCLV>` on D for meetings / UATs / decisions / blockers. Ignore chatter.

**Confluence** (`searchConfluenceUsingCql`, same cloudId as Jira):
- Pages created/edited: `contributor = currentUser() AND lastmodified >= "D 00:00" AND lastmodified <= "D 23:59" AND type in (page, blogpost)`.
- Capture: title + webUrl. These are docs/write-ups → put under a **Docs** section.

**Vault** (side work the other sources miss):
- `Sessions/D *.md` and any note with `created: D` — Claude sessions, side projects, war rooms.

**Coverage gate** — before writing, list each source as `OK n items` / `empty` / `FAILED: reason`. If any source FAILED, say so at the top of your reply and in the note (`> ⚠️ Missing: Bitbucket (auth)`), never silently skip it.

## STEP 2 — Write the note

**Location:** `Daily/` folder.
- If a file whose name **starts with `D`** already exists → **UPDATE it** (e.g. `2026-06-21 1934.md`).
- Else → create **`D 0500.md`** (e.g. `2026-06-30 0500.md`).
- Never rename/delete existing files.

**Format** (omit any empty section):

```markdown
---
type: daily
description: "<the Summary line>"
project:
  - "[[<project note from the vault's project list>]]"
created: D
tags:
  - note
  - journal
  - daily
---
## What I did — D (Ddd)

**Shipped**
- [TICKET](https://boundlesshr.atlassian.net/browse/TICKET) — what changed and why it matters · [zenhr#N](url) / [mfe!N](url)

**In progress**
- [TICKET](url) — where it stands, what is next · [#N](url)

**Reviewed**
- [[Person]] — what the PR does, what I flagged (approved / changes requested) · [#N](url)

**Docs**
- [Page title](confluence url) — what it covers

**Meetings**
- [[Person]] / name — decision or outcome in one line

**Incidents & support**
- what broke, who asked, how it was resolved · [HOTFIX-N](url)

**Side work**
- [[Project]] — Claude sessions and side projects from the vault: [[Session note]]

> Summary: one line.
```

**Conventions:**
- `Ddd` = three-letter weekday (Sun, Mon, …).
- People as `[[wikilinks]]` using the **existing vault spellings** (check other `Daily/` notes — e.g. `[[Ali Obeidat]]`, `[[Diya' Almahameed]]`, `[[Abdullah Al-araj]]`).
- Tickets link to `https://boundlesshr.atlassian.net/browse/KEY`.
- PR link labels: GitHub `[zenhr#N]` / `[osvdev#N]`; Bitbucket `[mfe!N]` / `[zds!N]` / `[zen_tms!N]`.
- Confluence: link the page by its title, `[Page title](webUrl)`.
- Every ticket, PR and page mention is a link, including repeats and the Summary line; never a bare `PLAT-1`, `#12` or `PR 12`. The vault's scribe hook rejects bare refs.
- `project:` lists each project note (`type: project` in the vault) the day touched; wikilink a project's first mention in the body too.
- One line per item with the outcome, not just the title: what changed, what was decided, what is next. Factual, no filler.
- Length: up to ~300 words of body; the scribe hook caps daily notes at 350.

## STEP 3 — Edge cases & finish

- If **D is a workday (Sun–Thu)** and nothing is found → write the note with body `No tracked activity logged.`
- If **D is Fri/Sat** and nothing is found → do nothing (no file). With weekend work, write it and name the reason (release / war room / incident).
- **End by printing one line:** which date you wrote and what you found.
