---
name: morning-brief
description: >
  Generate today's Morning Brief — gather what happened while the user was
  away and what needs them today from their connected sources (Slack, Jira,
  GitHub, Google Calendar, or whatever is available), triage it, write
  data.json, and render brief.html. Use when the user says "morning brief",
  "brief me", "what needs me today", or on a schedule.
---

# Morning Brief

Produce one page that answers three questions in under two minutes of reading:
what happened since the user logged off, what needs them today, and what's on
the schedule. Output is `data.json` (this directory's schema) rendered to
`brief.html` by `generate.mjs`.

## Step 1 — Gather (parallel)

Query every source the user has connected. Typical set, adapt to what exists:

- **Calendar** (MCP): today's events, with start times and RSVP status.
- **Slack** (MCP): mentions of the user and DMs since the last brief
  (default: last 16 hours; after a weekend, since Friday evening).
- **Issue tracker** (Jira MCP / GitHub Issues / Linear): issues assigned to
  the user updated recently; issues that moved status.
- **Pull requests** (`gh` CLI or Bitbucket API): PRs where the user's review
  is requested, and the user's own open PRs with new activity.

Run independent fetches in a single parallel batch. If a source is not
connected, skip it silently — never block the brief on one missing source.

## Step 2 — Triage

The rules that matter (each earned by a real failure):

1. **A mention is a lead, not a fact.** A Slack "can you review this?" enters
   "Needs you" only if the PR is *confirmed still open* (`gh pr view` or the
   tracker API) and a ticket ask only if the ticket isn't Done. Resolved asks
   go to `moved` with a "resolved without you — no action" note, or are dropped.
2. **"Needs you" is confirmed-actionable only.** Anything you cannot verify
   (no API access to that source) demotes to `fyi` with a "couldn't verify"
   note — never up.
3. **Never truncate "Needs you".** If it's actionable, it's listed,
   oldest-unanswered first. Cap `fyi` at 5.
4. **Slack links use the `slack://` protocol** so they open the desktop app:
   `slack://channel?team=<TEAM_ID>&id=<CHANNEL_OR_DM_ID>`. Get channel/DM IDs
   from Slack search result permalinks. The team ID is in the Slack desktop
   app's local storage (`~/Library/Application Support/Slack/storage/root-state.json`
   on macOS) or the workspace admin URL. Web sources keep `https://`.
5. **Skip noise.** Social banter, bot notifications, and lunch-order threads
   don't make the brief. When in doubt, `fyi` — not `needsYou`.
6. **Quiet day is a valid brief.** Empty sections are omitted by the
   renderer; don't pad.

## Step 3 — Write `data.json`

Schema (see `data.example.json` for a filled example):

```jsonc
{
  "masthead": "Your Team · The Daily",   // optional nameplate kicker
  "date": "Monday, July 6",              // human date, no year needed
  "greetingName": "Alex",                // optional
  "needsYou": [{ "text", "meta"?, "url"?, "actions"?: [{ "label", "url" }] }],
  "today":    [{ "time", "text", "meta"? }],          // sorted by time
  "moved":    [{ "text", "meta"?, "url"?, "panel"?, "done"? }],
  "fyi":      [{ "text", "meta"?, "url"?, "panel"? }] // renderer caps at 5
}
```

`text` is the serif headline; `meta` the one-line context under it; `panel`
is extra detail revealed on click; `actions` render as link chips (first chip
is highlighted); `done: true` renders a green "Done" tag instead of a link.

## Step 4 — Render and open

```bash
node generate.mjs && open brief.html   # xdg-open on Linux
```

`generate.mjs` self-checks (uncapped needs, escaping, single inline script)
and overwrites `brief.html` in place, so the user's `file://` bookmark keeps
working.

## Notes

- `data.json` and `brief.html` contain personal work data — they are
  gitignored and must stay out of commits.
- Counts in the header row are derived from the data at render time; never
  hand-edit `brief.html`.
