---
name: release-ticket-title
description: Generate a terse release ticket title from pasted GitHub release notes / tags. Use when the user pastes a GitHub Releases page or version tags and wants a release ticket title, or says "release ticket title", "release title for these tags".
---

# Release Ticket Title

Turn pasted GitHub release notes / version tags into a terse release ticket title.

## Steps

1. Read the pasted release notes. Identify the version tags and the "What's Changed" PR line under each.
2. If the range is ambiguous (single latest vs. rollup of several versions), ask which scope. Skip if the paste clearly shows one version or the user already said.
3. Produce the title(s):

**Single version:**
`Release <vX.Y.Z> — <one terse phrase per notable change> (<TICKET-ID if in PR title>)`

**Rollup (multiple versions):**
`Release <vLOW→vHIGH> — <phrase>, <phrase>, ...`

## Rules

- Strip conventional-commit prefixes (`fix:`, `feat:`, `chore:`, `feat(ci):`).
- Drop `chore: bump version [skip ci]` entries — noise.
- Keep any `HOTFIX-####` / `TICKET-####` id — put it in parens after its phrase.
- One short phrase per change; imperative, no author names, no PR numbers, no URLs.
- Terse. The title is a line, not a changelog.

## Example

Input tags v211.32.10 → v211.33.1 with PRs for a modal hotfix, CI Slack alerts, a role restriction, and a rake task →

`Release v211.32.10→v211.33.1 — Attendance modal hotfix (HOTFIX-12275), CI Slack alerts, Termination Setup role restriction, contract end-date rake task`
