---
name: plan-checklist
description: Check a plan against the five Azure Well-Architected pillars plus accessibility, data and docs before showing it to the owner. Use while writing any plan for a non-trivial change.
---

# Plan checklist

Answer each heading in the plan. Where a heading doesn't apply, write "n/a" with a reason; never leave it blank. This checklist exists because two plans were rejected for missing health checks and telemetry (ADR-0016).

## Reliability
- What fails, and how does the change behave when it does (timeouts, retries, partial failure)?
- Is every new behavior on the test list, with the right kind of test (see `docs/standards/testing.md`)?

## Security
- Does it touch data, sign-in, secrets or a trust boundary? If so, write a short threat model: what could an attacker do, and what stops them?
- Are inputs validated? Do any secrets stay out of the repo and the logs?

## Cost optimization
- Does it add a paid service, a dependency or cloud resources? Each needs the owner's OK.

## Operational excellence
- **Observability:** are health checks, logs, metrics and traces covered for new behavior?
- Are CI, scripts and docs updated so the next person can run it?

## Performance efficiency
- Are there hot paths, large data sets or new network calls? Is a benchmark or budget needed?

## Accessibility
- For UI: does it meet WCAG 2.2 (keyboard, contrast, labels)? Is there an axe check in the UI tests?

## Data
- Schema changes, migrations, retention, personal data?

## Docs and decisions
- Which docs change in the same PR? Which choices need an ADR (`write-adr`)? Which dependencies need approval?
