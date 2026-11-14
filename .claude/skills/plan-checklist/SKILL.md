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
- Are inputs validated and bounded (SEC-010)? Do any secrets stay out of the repo and the logs?
- Does a new endpoint need a signed-in user (the fallback policy, SEC-007), and does it reach only the caller's own data (SEC-009)? If it must be public, say why.

## Cost optimization
- Does it pick a tool, service or tier? Start on the industry-standard option while it's free; within the app's budget (`docs/app-profile.md`, $0 unless the owner set one), pick the option that fits best, and list any paid one with its estimated price, source and date (ARC-012).
- Does it add a paid service or cloud resources? Each needs the owner's OK, in both modes. A new dependency needs it in review mode; in auto mode, name the source that recommends it (`AGENTS.md`, "Working modes").

## Operational excellence
- **Observability:** are health checks, logs, metrics and traces covered for new behavior?
- Are CI, scripts and docs updated so the next person can run it?

## Performance efficiency
- Are there hot paths, large data sets or new network calls? Is a benchmark or budget needed?

## Accessibility
- For UI: does it meet WCAG 2.2 level AA, and which of UI-001's checks does it touch (`docs/standards/ui.md`)? Name how each is tested: an axe check in the browser tests, where the app has them, or a manual keyboard and screen-reader pass.

## Data
- Does the app store data for the first time? Pick the database with `docs/database-guide.md` (where the data lives, its shape, then any preference), and name it, its label (Free, Free tier or Paid), its price and why (DAT-001). For a cloud database, name the guard that keeps it free (DAT-006).
- Does the schema change? Is each migration safe for the version still running, with any drop or rename left to a later release (expand, migrate, contract: DAT-003, `docs/standards/data.md`)? Do the tests run on the real engine (DAT-005)?
- Retention, personal data?

## API style
- Does it add or change an API? Name its style (an HTTP API with Minimal APIs, gRPC or SignalR) and why; controllers or GraphQL need an ADR (API-001, `docs/standards/api-design.md`).

## Craft
- Does the change fix the root cause? Name any safety net that stays, and why (CRF-001); name any better design that has to wait, and where it's planned (CRF-002).
- Is it the simplest design that's fully correct for today's requirements (CRF-004)? Does it state any fact that already lives somewhere else (CRF-003)?
- Does it use every library, tool and service as its documentation describes for the version in use (CRF-010)? Cite the page.

## Proportion
- How many modules, and which distinct business area needs each (ARC-009, `docs/standards/architecture.md`)? One, unless a second has its own language, data and rules.
- Which projects does it add, and what's the first real type in each? A project starts with its first type, never empty, and so does each of a module's five.
- Which patterns does it add (aggregates, value objects, domain events, CQRS, a mediator, a generic repository, an interface that inverts no dependency)? Name the requirement that needs each.

## Docs and decisions
- Which docs change in the same PR? Which choices need an ADR (`write-adr`)? Which dependencies does it add, and, in review mode, which need approval?
