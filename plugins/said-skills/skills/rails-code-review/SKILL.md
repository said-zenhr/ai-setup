---
name: rails-code-review
description: >
  Senior Rails code review for ZenHR (el-ciclo): PRs, branch diffs, pasted code,
  migrations, services, models, controllers, and architecture plans. Use when the
  user asks to review, check, approve, sanity-check, or evaluate Rails changes —
  including "review since main/master", "is this the right approach", or PR feedback.
---

# Rails Code Review

Always follow this skill for Rails review requests; do not improvise a different review format from memory.

**Philosophy:** Ship blockers first, constitution second, requirements third — one verdict, no theater.

Three lenses (one agent, sequential passes — do not merge findings mentally until output):
- **Ship** — will this break, slow, or compromise production?
- **Standards** — does it violate documented ZenHR rules?
- **Requirements** — does it match the ticket/PRD/issue? (only when a requirements source exists)

---

## Setup

### Scope

- **Pasted code or diff** → proceed.
- **Vague** ("review my changes", "check this service") → ask once:

  > What's the scope? (paste code, name the file/service, Packwerk package, or git base branch e.g. `main`)

  Then wait.

### Git (branch / PR / "since X")

When the review is scoped to git changes, pin a fixed point (`main`, `master`, branch, tag, SHA, `HEAD~5`, etc.). If unspecified, ask once: "Review against what — `main`, a branch, or a commit?"

Use git (and shell) freely to build an accurate picture — not limited to a fixed command list. Typical moves: three-dot diff vs merge-base, commit log, file list, blame, or reading specific paths when the diff is huge. Prefer what answers "what changed?" and "why?" for this review.

For very large changes, split reading across parallel explore sub-agents or narrow to touched packages — use judgement.

### Requirements source (optional — Lens 3)

Find the originating ticket or PRD, in order:

1. Issue keys in commit messages (`ZNR-123`, `#123`, `Closes …`) — fetch via Atlassian MCP if available.
2. Path the user provided.
3. PRD under `docs/` or root, or a doc matching the branch name.

If nothing is found, skip Lens 3 entirely. No requirements doc is not a failed review.

### Standards prep (Lens 2)

Read `.agents/constitution/index.md`. For Lens 2, open **only** the files that match areas touched in the change (see table below). Cite `constitution/<file>.md` + the rule when flagging. Skip what CI/linters already enforce (RuboCop, Packwerk check in CI, etc.).

| If the change touches… | Read |
|------------------------|------|
| Always (any review) | `core_principles.md`, `packwerk_transition_rules.md` |
| API endpoints or contracts | `api_contract_rules.md` |
| Auth, permissions, PII, secrets, input handling | `security_constraints.md` |
| Tests added/changed or missing coverage | `testing_requirements.md` |
| Naming, formatting, Ruby/Rails style | `code_style_conventions.md` |
| Services, layers, packages, structural design | `architectural_patterns.md` |
| `db/migrate`, schema, data backfills | `migration_constraints.md` |

---

## Choose mode

| Input | Mode |
|-------|------|
| Code, diff, or "is this OK?" on a file | **A** — three lenses, verdict output below |
| Architecture plan, design doc, "how should I structure this?" (no diff yet) | **B** — architecture review |
| Design doc **and** diff/PR together | **A** — diff is source of truth; use `### Architectural pushback` if plan ≠ code |

`### Architectural pushback` in Mode A is overflow for design decisions in the diff — not a required section.

---

## Mode A — PR / code review

Run three lenses in order. **Ship** findings that block merge go in critical bullets. **Standards** hard violations (security, Packwerk layers, migration policy) → critical bullets; judgement calls → minors only. **Requirements** gaps that mean wrong/missing feature → critical; partial/nice-to-have → `### Requirements gaps` or minors.

### Lens 1 — Ship

Think like a senior Rails engineer who's seen production incidents. Flag only what matters before merge:

- Bugs or incorrect behavior
- Data integrity — missing transactions, partial multi-step writes
- Performance — N+1, unnecessary loads, memory issues
- Security — authorization, strong params, injection, data exposure
- Concurrency / race conditions
- Database — missing indexes on queried columns, unsafe migrations (locks, non-concurrent indexes)
- Rails misuse with real consequences — not style preferences

Rails-specific:
- Business logic hidden in callbacks callers can't see
- Jobs passing AR objects instead of IDs, non-idempotent retries
- Fat controllers vs model/service boundaries
- Multi-tenant leakage
- Packwerk boundary violations when packages are touched (only newly introduced violations)

### Lens 2 — Standards

Does the diff violate a **documented** project rule from the constitution files loaded per the table above? Distinguish hard violations from judgement calls. Do not re-litigate Ship issues as "standards."

### Lens 3 — Requirements

Only if a ticket/PRD was found. For each finding, quote the requirement line. Report: (a) missing or partial requirements, (b) scope creep not in the ticket, (c) implemented but likely wrong vs stated intent.

### Output (strict — do not invent sections)

1. Verdict on its own line: `✅ Approved` or `⚠️ Issues found`. No prefix, no trailing prose.
2. Critical bullets — one line each, `file:line` (or method), concrete failure mode today. Ship + hard Standards + blocking requirements gaps live here.
3. Optional `Minor suggestions (optional)` — max 3 short bullets.
4. Optional `### Requirements gaps` — only when a ticket/PRD existed and gaps are non-blocking. Quote the requirement; one line per gap.
5. Optional `### Architectural pushback` — only when the diff has a design decision worth challenging (Mode B shape: wrong → why → alternative → concrete change; cite `file:line`).

No "Should fix in this PR", "Verification gap", "Follow-ups", or offers to commit/push.

**Example — approved:**
```
✅ Approved
```

**Example — approved with minors:**
```
✅ Approved

Minor suggestions (optional)

- `app/models/company_role.rb:34` — `dependent: :destroy` on join may surprise if roles are shared; confirm product intent
- Consider `algorithm: :concurrently` on the follow-up index migration if table is large in prod
```

**Example — ship issues only:**
```
⚠️ Issues found

- `app/controllers/users_controller.rb:12` — N+1: `User.all` then `.company` in view; add `.includes(:company)`
- `app/services/order_service.rb:88` — no transaction around charge + status update; partial failure desyncs payment and order
```

**Example — with requirements and pushback:**
```
⚠️ Issues found

- ZNR-123: "Role permissions are company-scoped" — `CompanyRole` query in `index` has no `company_id` filter; cross-tenant role list
- `db/migrate/…_add_index.rb:4` — index without `algorithm: :concurrently`; locks table in production

### Requirements gaps

- ZNR-123: "Export includes inactive roles" — CSV path only exports `active` scope

### Architectural pushback

- `app/services/billing/pipeline.rb` — four service objects chained with no shared invariant; move steps to `Invoice` methods called from controller
```

### Anti-patterns

- **Hypotheticals are not issues.** Failure must run on a path in the diff today.
- **Defensive-coding suggestions** — would you add this guard unprompted? If no, drop.
- **Proportionality.** Output shorter than the diff unless the diff is trivial.
- **Don't manufacture architectural pushback** — but push back firmly when the diff warrants it.
- **Don't repackage other reviewers' comments** as your findings.
- **Axes stay separate mentally** — perfect Rails style that ships the wrong feature is a Requirements fail, not "Approved."

### Self-check (every critical bullet)

1. `file:line` or method from the diff.
2. Failure path in one sentence.
3. Would merge without this let corruption, slowness, security holes, or production breakage through? If no → minor, Requirements gaps, or drop.

Zero critical bullets after self-check → `✅ Approved`.

---

## Mode B — architecture review

Design before build — no diff required. Use constitution files from the Standards table when the plan touches those areas (especially `architectural_patterns.md`, `packwerk_transition_rules.md`, `security_constraints.md` for auth design).

For each issue worth raising: what's wrong → why (maintenance, perf, correctness, testability) → idiomatic Rails alternative → concrete change (file, class, method).

Watch for: fat controllers/models, unnecessary service objects, callback-hidden logic, missing DB constraints/indexes, unsafe migrations, N+1 traps, broad rescues, bad transaction boundaries, weak authorization design, missing edge-case tests, overengineered abstractions.

**Principle:** boring, idiomatic Rails unless complexity earns its keep.

### Output (strict — do not invent sections)

1. Verdict on its own line: `✅ Sound` or `⚠️ Rethink before building`. No prefix, no trailing prose.
2. **Issues** — one line per bullet when present; cite layer or component (e.g. `CompanyRole service`, `packs/billing`). Each bullet: problem → why it hurts → fix in one line.
3. Optional `### Open questions` — max 3 bullets; decisions the plan leaves ambiguous that block implementation.
4. Close with one line: **Highest risk:** … and **Tackle first:** …

No offers to implement, commit, or "run Mode A when you have a PR."

**Example — sound:**
```
✅ Sound

Highest risk: none blocking — Tackle first: nail company scoping in the role model before adding UI
```

**Example — rethink:**
```
⚠️ Rethink before building

- `BillingPipeline` (proposed) — four service objects with no shared invariant; chains calls only, hides control flow, hard to test steps. Use `Invoice` methods per step called from controller instead.
- Auth on role APIs — plan says "admin can edit"; no company boundary in diagram; cross-tenant risk. Scope every mutation to `current_company` in controller + policy.

### Open questions

- Are inactive roles in scope for v1 or a follow-up?

Highest risk: missing company scope on role mutations — Tackle first: model + policy design before controllers
```

### Anti-patterns (Mode B)

- **Rubber-stamping** — "looks good" without challenging unnecessary layers.
- **Implementation detail without design flaw** — naming nits belong in Mode A later, not here.
- **Hypothetical scale** — "might need Kafka someday" unless the plan already commits to that complexity.
