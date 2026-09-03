---
name: daily-work-note
description: Create or update Sai'd's Obsidian daily work note in clean-hybrid format by gathering shipped/reviewed/meeting activity from Jira, GitHub, Bitbucket, Slack, and Confluence. Use when the user asks to "write/update my daily note", "log my work day", "daily standup note", "what did I do yesterday/today", or invokes /daily-work-note. Read-only everywhere except the vault's Daily/ folder.
---

# Daily Work Note

Build (or update) the user's Obsidian daily work note for a given day in **clean-hybrid format**, sourced only from real activity in Jira, GitHub, Bitbucket, Slack, and Confluence.

## STEP 0 — Decide the day (blocking gate)

- If the user named a date or said "today"/"yesterday", use that.
- If they did **NOT**, STOP and ask: **"today or yesterday?"** before doing anything else. Do not assume.
- Default to suggest = **yesterday** (notes document a finished day).

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
- **GitHub:** org `ZenHR` · repos `ZenHR/zenhr`, `ZenHR/osvdev` · handle `said-zenhr` (use `gh` CLI)
- **Bitbucket:** workspace `boundlessdrop` · repos `mfe-monorepo`, `zds`, `zen_tms` · account_id `712020:6bb69e5f-91a1-4ad0-9298-2e111fc0f778` · token from keychain: `security find-generic-password -s "<SERVICE>" -a "<ACCOUNT>" -w`
- **Slack:** workspace `zenhr` · my user id `U093RUDJCLV`
- **Confluence:** same site/cloudId as Jira (`5aa9d8cb-1d53-438d-a617-1b6462e66491`) · my personal space key `~7120206bb69e5f91a14ad092982e111fc0f778`
- **Vault:** `/Users/saeedalzean/Desktop/Obsidian - Main/` (daily notes in `Daily/`)

## STEP 1 — Gather for D (all read-only)

Run these in parallel where possible.

**Jira** (`searchJiraIssuesUsingJql` or equivalent):
- Shipped: `assignee=currentUser() AND resolutiondate>="D" AND resolutiondate<="D 23:59"`
- In-progress: `assignee=currentUser() AND updated>="D"`
- Capture: key + summary + status.

**GitHub** (`gh` CLI; confirm flags with `gh search prs --help` first):
- `gh search prs --owner ZenHR --author=@me merged:D` (shipped)
- `gh search prs --owner ZenHR --author=@me created:D`
- `gh search prs --owner ZenHR --reviewed-by=@me updated:D` (reviewed)

**Bitbucket** (REST API with the keychain token):
- For each repo (`mfe-monorepo`, `zds`, `zen_tms`), list PRs with `updated_on` in `[D, D1)`.
- Mine = `author.account_id` matches mine. Reviewed = I'm a `REVIEWER` participant.
- If field names are unclear, inspect one PR's JSON first.

**Slack** (`slack_search_*`):
- Search `from:<@U093RUDJCLV>` on D for meetings / UATs / decisions / blockers. Ignore chatter.

**Confluence** (`searchConfluenceUsingCql`, same cloudId as Jira):
- Pages created/edited: `contributor = currentUser() AND lastmodified >= "D 00:00" AND lastmodified <= "D 23:59" AND type in (page, blogpost)`.
- Capture: title + webUrl. These are docs/write-ups → put under a **Docs** section.

## STEP 2 — Write the note

**Location:** `Daily/` folder.
- If a file whose name **starts with `D`** already exists → **UPDATE it** (e.g. `2026-06-21 1934.md`).
- Else → create **`D 0500.md`** (e.g. `2026-06-30 0500.md`).
- Never rename/delete existing files.

**Format** (omit any empty section):

```markdown
---
type: daily
created: D
tags:
  - note
  - journal
  - daily
---
## What I did — D (Ddd)

**Shipped**
- [TICKET](https://boundlesshr.atlassian.net/browse/TICKET) — short desc · [zenhr#N](url) / [mfe!N](url)

**Reviewed**
- [[Person]] — what · [PR](url)

**Docs**
- [Page title](confluence url) — what it covers

**Meetings**
- name

> Summary: one line.
```

**Conventions:**
- `Ddd` = three-letter weekday (Sun, Mon, …).
- People as `[[wikilinks]]` using the **existing vault spellings** (check other `Daily/` notes — e.g. `[[Ali Obeidat]]`, `[[Diya' Almahameed]]`, `[[Abdullah Al-araj]]`).
- Tickets link to `https://boundlesshr.atlassian.net/browse/KEY`.
- PR link labels: GitHub `[zenhr#N]` / `[osvdev#N]`; Bitbucket `[mfe!N]` / `[zds!N]` / `[zen_tms!N]`.
- Confluence: link the page by its title, `[Page title](webUrl)`.
- Concise, factual. No filler.

## STEP 3 — Edge cases & finish

- If **D is a workday (Sun–Thu)** and nothing is found → write the note with body `No tracked activity logged.`
- If **D is Fri/Sat** and nothing is found → do nothing (no file).
- **End by printing one line:** which date you wrote and what you found.
