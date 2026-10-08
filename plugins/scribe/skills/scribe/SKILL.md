---
name: scribe
description: Record decisions, meetings, insights, and todos into Saeed's Obsidian vault (kepano-style + OKF). Use whenever the user dictates something to document ("I had a meeting...", "note this", "remind me", "todo"), asks what's due, or at end of a substantive session.
---

# Scribe

Vault: `~/Desktop/workspace/vault`. Engine: `${CLAUDE_PLUGIN_ROOT}/scripts/scribe.rb`.

## Style — non-negotiable

30 words that say it beat 200 that pad it. Declarative titles. No preamble,
no "In this meeting we discussed". Bullet fragments fine. The gate hook
DENIES over-budget notes (session 80w, meeting 100w, evergreen 150w) and any
note with <2 wikilinks — don't fight it, distill.

## Before writing ANY note

1. Search the vault (Grep/Glob) for an existing note on the topic — append or
   update, never create a duplicate.
2. Find link targets: matching files in `References/`, `Notes/`, people names.
   Link first mentions: `[[Jwan]]`, `[[ZenHR]]`, `[[training-wheels]]`.
   Unresolved links fine — breadcrumbs.
3. Start from the matching template in `Templates/` when one exists.

## Note shapes (kepano + OKF in one frontmatter)

Meeting → `Notes/YYYY-MM-DD Meeting with X.md`, template `Meeting Template.md`,
plus OKF fields:

```yaml
type: meeting-note
generated: { by: claude-fable-5, at: <iso> }
verified: false
```

Session log → `Sessions/YYYY-MM-DD HHmm <topic>.md`: what was asked, decided,
built, next steps. ≤80 words. Update `Sessions/index.md` (one line per note)
and append one line to `Sessions/log.md`.

Evergreen insight → `Notes/<declarative sentence>.md`, tag `0🌲`,
categories `[[Evergreen]]`, ≥2 links, ≤150 words.

## Entities & mentions (people, projects, companies, topics)

Every entity referenced by `[[wikilink]]` more than twice deserves its own
note so `Backlinks.base` can list where it is mentioned, grouped by kind
(Daily / Meeting / Session / Reference).

- **Always wikilink** first mentions of people, projects, companies, tickets.
  Plain-text names are invisible to the base.
- **Entity note missing?** Create it from the matching template
  (`People Template.md`, `Project Template.md`, `Company Template.md`) — each
  already embeds `![[Backlinks.base]]`. People and projects live in
  `References/`. Fill `role`/`org`; leave unknowns blank.
- **Never** write a manual "mentioned in" list — the base does it.
- **Kind detection**: dailies need `type: daily` (template sets it); meetings
  are detected by `categories: [[Meetings]]`; sessions by folder.
- Case-insensitive link targets collide: `[[Control plane]]` and
  `[[Control Plane]]` are the same note — do not create both.

## Dictation flow

User says "I met my manager about X, we decided Y, I need to research Z":
1. Meeting note (shape above), people/topics linked.
2. Each action item → `scribe.rb todo add "research Z [due:YYYY-MM-DD if given]" "[[<meeting note>]]"`
   AND a `- [ ]` line inside the meeting note. Both places, always.
3. Real insight in there → offer an evergreen note, don't auto-create.

## Todos & reminders (pull-only — never nag unprompted)

- Add: `scribe.rb todo add "text" "[[source]]"` (+ mirror line in source note).
- User asks "what's due / remind me": `scribe.rb todo due`, relay output.
- User says done: `scribe.rb todo done "<substring>"` — then also check the
  mirrored `- [ ]` in the source note it names. Keep the two in sync.

## End of session (the safety net)

The Stop hook blocks once after 5+ unscribed turns. When it fires: write the
session note (or decide honestly nothing is worth keeping), then run
`scribe.rb mark <session_id>`. After any session where you already scribed,
run mark proactively so the nag never fires.
