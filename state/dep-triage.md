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
| express | 4.17.1→4.22.2 | GHSA-qwcr-r2fm-qrc7 + express cluster (qs/cookie/send/serve-static/path-to-regexp) | high | taken |
| lodash | 4.17.15→4.18.1 | none | chore | skipped |
| eslint | 8.57.1→10.5.0 | none (major) | chore | flagged |
| jest | 29.7.0→30.4.2 | none (major) | chore | flagged |
| supertest | 6.3.4→7.2.2 | none (major) | chore | flagged |
| js-yaml | transitive ≤4.1.1 | GHSA-h67p-54hq-rp68 | moderate | flagged |
| lodash | 4.17.15→4.18.1 | GHSA-35jh-r3h4-6jhm (CORRECTS prior "skipped/none" row — first audit head truncated this high) | high | taken |
