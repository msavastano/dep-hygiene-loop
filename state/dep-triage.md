<!--
  CROSS-ROUND MEMORY for the dependency-hygiene loop.

  The agent forgets. The repo does not. This file is committed back after every
  triage run, so the next run — even with a freshly flushed context window —
  can read what already happened and avoid re-doing or undoing it.

  dep-triage APPENDS one row per finding (see .claude/skills/dep-triage/SKILL.md,
  "Write"). Never rewrite history here; only add rows. status ∈
  taken | flagged | skipped | punted.
-->

# Dependency triage log

| package | from→to | advisory | priority | status |
| ------- | ------- | -------- | -------- | ------ |
| _(seed)_ | _–_ | _none yet_ | _–_ | _initialized_ |
