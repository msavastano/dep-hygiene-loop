# dep-hygiene-loop

A trivial Node app wrapped in a **complete dependency-hygiene loop**. The app is
beside the point — it exists only to produce real `npm audit` / `npm outdated`
findings. The point is the *loop engineering* around it: the machinery that lets
an agent safely keep dependencies fresh, unattended, on a schedule, without ever
merging its own mistakes.

## The four layers (and where this repo sits)

Reliable agentic work stacks in four layers: the **prompt** is the single
instruction you give a model; **context** is everything you put in front of it
for one turn (files, tool output, prior state); the **harness** is the loop body
that runs one turn — call the model, run its tools, feed results back; and the
**loop** is the outer machine that turns the harness into a durable, scheduled,
self-checking system — discovery, isolation, a separate verifier, state on disk,
a trigger, and a human door. **This repo lives at the loop layer.** The prompt
(`/dep-triage`), the context (audit/outdated output + `./state/`), and the
harness (Claude Code running a turn) are all assumed; what is built here is the
loop wrapped around them.

## The five moves — and where each lives

| Move | What it does | Where it lives |
| --- | --- | --- |
| **Discovery** | Read audit/outdated + prior state, judge what's safe today, write decisions | [`.claude/skills/dep-triage/SKILL.md`](.claude/skills/dep-triage/SKILL.md) |
| **Handoff** | One git worktree per finding so parallel bumps never collide | [`scripts/handoff.ps1`](scripts/handoff.ps1) · [`scripts/handoff.sh`](scripts/handoff.sh) |
| **Verification** | A *separate* evaluator that verifies by acting and can say "no" | [`.claude/skills/dep-review/SKILL.md`](.claude/skills/dep-review/SKILL.md) |
| **Persistence** | Cross-round memory on disk that survives a flushed context window | [`state/dep-triage.md`](state/dep-triage.md) · [`inbox/`](inbox/) |
| **Scheduling** | A real trigger that turns one run into a loop | [`.github/workflows/dep-triage.yml`](.github/workflows/dep-triage.yml) · [`scripts/register-task.ps1`](scripts/register-task.ps1) |

The generator/evaluator split is the load-bearing idea: `dep-triage` *proposes*
bumps, `dep-review` *verifies by running them* — different skills, different
instructions, maker-checker. Completion is judged by a fresh check after the
turn, never by the agent that wrote the bump.

## Quick start

```bash
npm install
npm test        # the loop's stop condition, half of it
npm run lint    # the other half
npm start       # GET http://localhost:3000/  ->  {"status":"ok",...}
```

`npm install && npm test` passes on a fresh clone. Those two commands —
`npm test` and `npm run lint` — *are* the loop's stop condition: a bump is only
allowed through when **all tests pass and lint is clean** (and the advisory it
targeted is actually gone).

The runtime deps are pinned stale on purpose (`express@4.17.1`,
`lodash@4.17.15`) so `npm audit` and `npm outdated` produce genuine findings to
act on. That is a feature of this demo, not an oversight.

## Human review is permanent, not scaffolding

PRs are **opened, never auto-merged.** Uncertain findings go to
[`inbox/`](inbox/), not the PR queue. This is a **permanent feature of the
loop** — not training wheels to remove once the loop has "earned trust." The
design assumes the loop will sometimes be wrong; the human door is the
always-open escape hatch that keeps a wrong call from becoming a merged mistake.
There is deliberately no configuration that turns auto-merge on.

## MISTAKE-RADIUS

**The cost of a mistake scales with how many turns it survives before someone
notices.** A bad bump caught by `dep-review` in the same turn costs one retry. A
bad bump that merges unattended, ships, and is discovered three weeks later
costs a debugging session, a rollback, and everything built on top of it
meanwhile. Three pieces of this repo exist specifically to *shorten the distance
between a mistake and its discovery*:

- the **state file** (`state/dep-triage.md`) — so a mistake is visible to the
  next run instead of silently repeated;
- the **evaluator** (`dep-review`) — a fresh, acting check that catches the
  break in the same turn it was made;
- the **human door** (`inbox/` + PR-only, never auto-merge) — so anything below
  full confidence stops at a human instead of compounding.

Everything else is plumbing. These three are the brakes.

## Guardrails (token caps)

[`loop.config.json`](loop.config.json) sets a **per-run** budget, a **daily**
budget, and a **max-retry** count, commented as *set assuming something spins
idle overnight* — an unattended cron with no ceiling is how one bad turn burns a
month of tokens. The GitHub workflow lifts these values into the job env and
passes the per-run cap to the skill as a hard ceiling.

## Windows gotcha (MCP connectors)

Any npx-based MCP server (e.g. the GitHub server the loop uses to open PRs)
**must be wrapped in `cmd /c` on Windows**, or it fails *silently* — the tools
just never appear. See [`.mcp.json`](.mcp.json): the correct form is

```json
{ "command": "cmd", "args": ["/c", "npx", "-y", "@modelcontextprotocol/server-github"] }
```

not a bare `npx`.

## Growing it safely

Add capability in this order, and **add parallelism LAST**:

1. Run the loop **serially** — one finding at a time — until you have watched it
   work on real bumps.
2. **Prove the evaluator catches a real break before you trust it to run
   unwatched.** Do a deliberate test: hand the loop a bump you *know* breaks the
   suite — for example, bump a dependency to a major version with an incompatible
   API, or edit a test to expect the wrong status code alongside the bump — and
   confirm `dep-review` returns **REJECT** with the failing `npm test` output
   pasted, and that the finding lands in `inbox/` rather than a PR. If the
   evaluator ever PASSes a known break, stop and fix the evaluator. An evaluator
   you haven't seen reject is not yet a verifier.
3. **Only then** add parallelism — multiple worktrees bumping at once. The
   worktree isolation in `scripts/handoff.*` exists precisely so parallel bumps
   don't collide on `package.json` / `package-lock.json`, but parallelism also
   multiplies the blast radius of a weak evaluator. Earn it.

## Layout

```
dep-hygiene-loop/
├─ src/index.js                      # trivial express app (one JSON route)
├─ test/server.test.js              # asserts the server responds (stop condition)
├─ .eslintrc.json                   # lint config (the other half of the stop condition)
├─ loop.config.json                # token caps + policy guardrails
├─ .mcp.json                       # GitHub MCP connector (cmd /c npx — Windows)
├─ state/dep-triage.md             # cross-round memory (committed each run)
├─ inbox/                          # the human door — uncertain findings land here
├─ scripts/
│  ├─ handoff.ps1 / handoff.sh     # worktree per finding (isolation)
│  └─ register-task.ps1            # Windows local-fallback scheduler
├─ .github/workflows/dep-triage.yml # cloud cron (turns even when your machine is off)
└─ .claude/skills/
   ├─ dep-triage/SKILL.md          # generator: discovery + handoff
   └─ dep-review/SKILL.md          # evaluator: verify by acting, can say no
```
