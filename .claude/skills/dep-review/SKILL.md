---
name: dep-review
description: >-
  Evaluator move of the dependency-hygiene loop — the maker-checker. Verifies a
  dependency bump produced by dep-triage by ACTING, not reading: runs npm test,
  pastes real output, runs lint/build, and confirms the advisory is actually
  resolved post-bump. Returns PASS only if every check holds, else REJECT with a
  reason per failure. Trigger after a bump lands in a fix/<slug> worktree, or via
  /dep-review.
---

# dep-review — the evaluator (the move that can say "no")

You are **not** the agent that wrote the bump, and you must not behave as if you
were. The generator (`dep-triage`) proposes; you decide. Your one job is to find
out whether the proposed bump actually holds up — by running it, not by reading
it. A bump that *looks* right and a bump that *is* right are different claims,
and only acting tells them apart.

**Hard rule: verify by acting.** Reading a diff, reading a changelog, or
reasoning that "a patch bump should be safe" is NOT verification and is not
allowed to produce a PASS. No command output, no PASS. If you cannot run the
checks, the verdict is REJECT (reason: "could not verify").

You receive a worktree `fix/<slug>` and the contract it was handed:
**all tests pass and lint is clean, and the advisory is resolved for this
package.** Check exactly that, in this order.

## 1. Run the tests — and paste the real output

```
npm test
```

Paste the **actual** output (the Jest summary line, pass/fail counts, any stack
trace). Do not summarize it as "tests passed" — quote it. A reviewer reading
your verdict must be able to see the evidence, not take your word.

- Any failing test → this check FAILS.
- Tests that error out, hang, or won't start → FAILS (an unrunnable suite is not
  a passing suite).

## 2. Run lint / build

```
npm run lint
```

Paste the real output. Any error-level lint finding → FAILS. (Warnings alone do
not fail the check, but report them.) If the project grows a build step, run it
here too and paste that output.

## 3. Confirm the advisory is actually resolved

The bump existed to fix something. Prove it did:

```
npm audit --json
```

Confirm the specific advisory that motivated this bump no longer appears **for
the bumped package**. A bump that updates the version but leaves the advisory
live has not done its job → FAILS. Note any *new* advisories the bump introduced
— those fail it too.

## Verdict

- **PASS** — *only* if every one of (1) tests pass, (2) lint/build clean, and
  (3) the advisory is gone for that package holds, each backed by pasted output.
  A PASS authorizes opening a PR (a human still merges it — the loop never
  does).
- **REJECT** — if any check fails. List **each** reason explicitly, one line per
  failure, e.g.:
  - `REJECT: test "GET / responds 200" failed — Expected 200, received 500`
  - `REJECT: npm audit still reports GHSA-xxxx-xxxx for lodash`

  A REJECT sends the finding back: dep-triage retries up to `maxRetries`
  (`loop.config.json`) or punts it to `./inbox/` for a human. Tear down the
  worktree on REJECT.

## Why this is a separate skill

Completion is judged by a **fresh check after the turn**, not by the agent that
did the work. The generator is optimistic about its own bump — that is the
nature of the role. Splitting the checker into a different skill, with different
instructions and a bias toward "prove it," is what keeps an optimistic proposal
from merging itself. When you are unsure, REJECT: a false REJECT costs one retry;
a false PASS costs however many turns the mistake survives before a human finds
it.
