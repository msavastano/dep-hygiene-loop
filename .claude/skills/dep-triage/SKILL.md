---
name: dep-triage
description: >-
  Discovery + generator move of the dependency-hygiene loop. Reads npm audit /
  outdated and prior state, judges what is safe to bump today, writes its
  decisions to disk, and hands each kept finding off to an isolated worktree.
  It proposes bumps; it does NOT decide they are correct — that is dep-review's
  job. Trigger when running a dependency-triage pass (cron, /dep-triage, or
  manual).
---

# dep-triage — the generator

You are the **generator** in a generator/evaluator split. Your output is a
*proposal*, never a verdict. A separate skill — `dep-review` — verifies your
work by acting, and it is allowed to say no. Write for that reader: leave a
trail it can check, and never claim a bump is "done."

You forget when the context window flushes. **The repo does not.** Everything
that must survive your own amnesia goes in `./state/dep-triage.md` (kept work)
or `./inbox/` (punted work) — see **Write** and **Stop**.

The six sections below are the whole job: five moves and one boundary. Do them
in order.

## Read  — discovery inputs

Gather, before judging anything:

- `npm audit --json` — current advisories with severities and fix availability.
- `npm outdated --json` — installed vs wanted vs latest for every dependency.
- Advisories that touch **DIRECT** dependencies (those in `package.json`).
  Transitive-only advisories that have no direct-dep fix are noise this pass —
  note them, don't act.
- The previous `./state/dep-triage.md` — what earlier runs already took,
  flagged, PR'd, or punted. This is your memory of yesterday.

Read all of it before deciding. Do not bump anything during Read.

## Judge  — sets the ceiling

This is where you decide how far the loop is allowed to reach today. Judge each
candidate and assign exactly one disposition:

- **Take it** — patch or minor bump that is *likely safe* (no breaking-change
  notes, semver-minor or below, advisory has a fix in range). These earn a
  worktree.
- **Flag only** — major version jump, or any bump whose changelog signals
  breaking changes. Record it; **do not attempt it** unattended.
- **Skip** — already tracked in `./state/dep-triage.md`, already has an open PR,
  or already resolved. No new work.

Keep only what is worth a worktree *today*. A short, high-confidence list beats
a long, hopeful one — every kept finding costs a verification pass downstream.

## Write  — persistence output

For every finding you Read (not just the ones you take), append one row to
`./state/dep-triage.md`:

```
| package | from→to | advisory | priority | status |
```

- `status` is one of `taken` (worktree created), `flagged` (major/breaking,
  needs a human), `skipped` (already handled), or `punted` (sent to `./inbox/`).
- `priority` follows advisory severity (critical/high/moderate/low) or `chore`
  for a plain freshness bump with no advisory.

Then **commit** the updated state file (`git add state/dep-triage.md && git
commit`). The commit is the point: it is how the next run — possibly with a
blank context window — knows what this run did.

## Hand off  — isolation per finding

For each finding judged **Take it**, emit a handoff line:

```
worktree=fix/<slug> goal=<stop-condition>
```

- `<slug>` is `<package>-<from>-to-<to>`, e.g. `lodash-4.17.15-to-4.17.21`.
- `<stop-condition>` is always the same contract: **all tests pass and lint is
  clean, and the advisory is resolved for this package**.

Then create the isolated worktree so parallel bump attempts never collide on
`package.json` / `package-lock.json`:

```
scripts/handoff.ps1 -Slug <slug> -Action create     # Windows
scripts/handoff.sh   create <slug>                   # bash
```

Apply the bump **inside that worktree only**, then hand the slug to the
`dep-review` evaluator. Do not verify your own work here.

## Verify  — hand to the evaluator (do not self-grade)

Completion is judged by a **fresh** check after your turn — maker-checker — not
by you, the agent that wrote the bump. For each worktree, invoke the
`dep-review` skill (`.claude/skills/dep-review/SKILL.md`) against that worktree.
It will run `npm test`, the build/lint, and re-check `npm audit`, and return
PASS or REJECT.

- **PASS** → the worktree may be opened as a PR (a human merges it; the loop
  never does). Update the row's `status`.
- **REJECT** → do not open a PR. Either retry up to `maxRetries`
  (`loop.config.json`) or punt the finding to `./inbox/` (see **Stop**). Tear
  the worktree down: `scripts/handoff.* teardown <slug>`.

If you ever feel the urge to mark something done without dep-review having
acted, that is the urge this section exists to stop.

## Stop  — the boundary the loop cannot infer

Load-bearing. Not boilerplate. These are the limits the loop has no way to
derive on its own, so they are stated here once and enforced everywhere:

- **Never auto-merge.** You open PRs. Humans merge them. There is no path in
  this loop that merges its own work.
- **Never bump a major version unattended.** Major / breaking changes are
  *flagged only* (status `flagged`) and left for a human. No exceptions on a
  cron run.
- **Anything below full confidence goes to `./inbox/`, not a PR.** If a bump is
  ambiguous, a changelog is unclear, a test is flaky, or dep-review REJECTs and
  retries are exhausted — write a short note to `./inbox/<slug>.md` describing
  what you saw and why you stopped. The inbox is the open door for a human; the
  PR queue is only for work that fully passed a fresh check.

When in doubt, do less and write it down. A finding parked in `./inbox/` costs
nothing. A wrong bump merged unattended costs as much as the number of turns it
survives before someone notices (see MISTAKE-RADIUS in the README).
