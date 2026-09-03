# Data source pull patterns

## Commit history (git)
If repos are local/cloneable, use `bash_tool`:
```
git log --author="<name or email>" --since="<date>" --pretty=format:'%h|%ad|%s' --date=short -- .
```
Run per repo, per remote/org. For Bitbucket repos (e.g. `boundlessdrop/mfe-monorepo`)
clone shallow if not already present. If GitHub, `api.github.com` is allowed —
use the commits API filtered by `author`.

Capture per repo: total commits in window, top-touched directories
(`git log --author=... --name-only | sort | uniq -c | sort -rn | head -20`),
and a handful of representative commit messages for flavor/tone.

## Slack (via Slack MCP — load with tool_search first)
- `slack_search_users` to resolve display name → user ID if handle is ambiguous.
- `slack_search_public_and_private` with the person's name/handle as author filter to find their messages across channels (needs private channel search if the user has access).
- `slack_read_thread` on notable hits to get full context, not just the matched message.
- `slack_read_user_profile` for role/title/status text — cheap extra signal.

## Confluence (via Atlassian Rovo — load with tool_search first)
- `search` (Rovo Search) scoped to Confluence, query by author name, or
- `searchConfluenceUsingCql` with `creator = "<accountId>"` if you have their Jira/Atlassian account ID (get it via `lookupJiraAccountId` or `atlassianUserInfo`).
- For each hit, `getConfluencePage` to pull body content for the analysis (don't rely on search snippets alone for doc-authorship quality assessment).

## Jira (via Atlassian Rovo)
- `searchJiraIssuesUsingJql` with JQL like `creator = "<accountId>" ORDER BY created DESC` (and a separate pass for `assignee = "<accountId>"` and `reporter = "<accountId>"` — these can diverge).
- Note project areas (`project in (...)`), issue types, and resolution time patterns.
- `getJiraIssue` on a sample of tickets for detail if aggregate JQL isn't enough.

## Handle resolution gotchas
- Git author email often differs from Slack email or Jira account email — resolve this explicitly in Phase 1, don't assume they match.
- Confluence/Jira share the same Atlassian accountId — resolve once via `atlassianUserInfo` or `lookupJiraAccountId`, reuse for both.
- If a source's search comes back near-empty, don't conclude "they don't use this tool" without checking the handle mapping first.
