# ./inbox — the human door

This is where the loop puts work it is **not confident enough to PR**.

When `dep-triage` judges a finding below full confidence — a major/breaking
bump, an ambiguous changelog, a flaky test, or a bump that `dep-review` REJECTed
after exhausting `maxRetries` — it writes a short note here instead of opening a
pull request. One file per punted finding, named `<slug>.md`, describing:

- what the finding was (package, from→to, advisory),
- what was tried, and
- why the loop stopped short of proposing a merge.

A human reads this directory and decides. **This is a permanent feature of the
loop, not scaffolding to delete once the loop is "trusted."** The whole design
assumes the loop will sometimes be wrong; the inbox is the cheap, always-open
escape hatch that keeps a wrong call from becoming a merged mistake.

This directory is intentionally kept under version control (via this file) even
when empty.
