---
name: describe-pr
description: >
  Produce a code-derived reading order and per-file mental model for reviewing a PR or diff,
  based on actual call graph (not file list order), with a short context paragraph and a
  one-line significance note per file. Use when the user asks "what order should I review this
  in", "how should I think about this PR/diff", "describe this PR", or wants a review plan
  broken into independent units with callers/callees, I/O, and why each file matters.
---

# Describe PR

Do not order files by diff listing, alphabetically, or by "impl then all specs." Derive the order from the real dependency graph of the changed code.

## Steps

1. **Get the changed file list** (impl files only — exclude specs/tests, they're read paired with their impl, not separately ordered).
   `gh pr view <n> --json files` or `git diff --name-only <base>...HEAD`.

2. **Find the real call graph among changed files.** For each changed file, grep the rest of the changed set (and the wider repo) for its class/module/method names to find who calls whom. Do not assume independence — check.
   `grep -rn "ClassName\." app --include="*.rb"`

3. **Classify each unit as one of:**
   - **Leaf** — calls nothing else in the changeset.
   - **Depends on leaf(s)** — calls one or more leaves.
   - **Value object / convention-linked** — consumes shapes/outputs of others by data contract, not by direct method call (e.g. a manifest struct built from other services' return values).
   - **Unwired / no production caller** — grep the whole app, not just the diff; note explicitly if nothing outside specs calls it yet.

4. **Order stepdown: entry point first, callees after** — start with the unit where the story starts (the root/entry point of the changeset), then its callees, ending with leaves. Caller above callee, like stepdown method order in a class. Still flag the leaf(s) that others depend on as high-priority — a bug there propagates. Within a tier, order by correctness risk / blast radius, not line count.

5. **Write one context paragraph, 1-3 sentences, prefixed and terse** — what the PR is and why it exists, nothing more. No feature-by-feature recap.

6. **Report per unit**, in this exact shape:

   ```
   **N. UnitName** — `path/to/impl.rb`
   *Why it matters: <one line — the significance, risk, or role of this file>*
   - Calls: <what it calls, or "none (leaf)">
   - Called by: <what calls it in the changeset, or "none yet" / "no production caller">
   - **In:** <method signatures / arg shapes accepted>
   - **Out:** <return shapes per public method>
   ```

   Then one line naming the paired spec file per unit (impl + spec together, not spec ordered separately).

7. **Close with the mental model**: state explicitly whether the changeset is a flat set of independent siblings, a tree/DAG (name the root/leaves), or something else — and name which single file is highest-leverage to get right first.

## Notes

- "Called by" must come from grep evidence, not inference from naming or PR description. If a class looks central but has zero real callers, say so — that's often the most important finding (unwired foundation code, dead code, or staged-for-later work).
- The "why it matters" line is judgment, not restatement of "Calls/Called by" — say what breaks, what's risky, or what's structurally central about this specific file.
- Keep everything terse: context paragraph capped at 3 sentences, per-unit blocks are signatures and one-liners, not prose paragraphs.

## Rules

- Avoid dense, too jargon-heavy, or too formal descriptions.
- Explain in a simple way, like you're explaining it to a smart friend over a beer.
- You must be terse, consice, straightforward and very clear with your answer.
- Be casual and direct ("basically...", "the point is...", "ok so..."). A touch of personality is welcome — don't turn it into a meme.
