# ADR-0047: Every app keeps a runbook, from a template, checked in CI

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

Nothing in the kit said how to operate an app once it's deployed: how to deploy and roll back a release, check its health, read its telemetry, restore its data, or handle an incident (scorecard GAP-017). The kit's apps already expose `/health` and `/alive` (OPS-002) and send telemetry over OTLP (OPS-001), but nothing told the person on call how to use them.

The Azure Well-Architected Framework asks for runbooks that are stored in version control, made from templates, and carry review dates (OE:02). It also asks for a documented incident process with defined roles and a postmortem (OE:08), and for a rollback to the last known good release (OE:11). Diátaxis calls this kind of page a how-to guide: steps toward one goal for someone who already knows the system, with no teaching or background.

No app is deployed yet: the production workflow is GAP-015. No kit release has been published, but two test apps exist (`kit-app-test` and `kit-app-test-public`), pinned to earlier kit commits and without a runbook. They also predate the sync job (ADR-0044, ADR-0045): no `kit-sync.yml`, no Dependabot `github-actions` entry, and no `appName` in their manifests. So a runbook must exist before it can be complete, nothing can yet tell CI whether an app has been deployed, and the kit sync, which until now never touched an app-owned file, wouldn't give a runbook to an app made after the sync job but before this change.

## Options

### Option 1: A required `docs/runbook.md` from a template, with a Draft or In use status, checked in CI

Every new app gets `docs/runbook.md` from `templates/app/`, which the app owns. It has a status line, a review date, a "Where it runs" reference section, and one required "## How to ..." section per task. App-specific steps are `[fill in: ...]` placeholders. `Test-Runbook.ps1` runs in the shared app checks. It always checks the shape. Once the status is In use, it also fails on any placeholder left.

- **Trade-offs:** A new app passes CI on day one, and a deployed app can't keep a half-written runbook. Cheap: one script and one template, no package. The agent has to remember to switch the status to In use at the first deployment, until GAP-015's production workflow can refuse a Draft.
- **Reversibility:** Easy. Drop the step and the script; apps keep their runbooks as plain docs.
- **Risk:** Low. A runbook can pass the check and still be wrong; the reviewer and a practised restore cover that.

### Option 2: A runbook template only, with no check

Ship the template and a rule, and leave the rest to the reviewer.

- **Trade-offs:** Least work, but nothing stops an app from deleting a section, or from deploying with every placeholder still in it. The rule would be advisory.
- **Reversibility:** Easy.
- **Risk:** Medium: runbooks rot without anyone noticing, and are found wanting during an incident.

### Option 3: Create the runbook only at the first deployment

New apps get no runbook. The agent preparing the first deployment copies the template in, and CI checks it only if it exists.

- **Trade-offs:** No placeholders in the repo before they're needed. But the check is skipped whenever the file is missing, so deleting it switches the check off, and nothing reminds anyone to write it.
- **Reversibility:** Easy.
- **Risk:** Medium: the step most likely to be forgotten is the one the check depends on.

### Option 4: One file per task under `docs/runbooks/`

- **Trade-offs:** Smaller files, but more to check and link. A small app's runbook is one page, which is quicker to find and follow during an incident.
- **Reversibility:** Moderate; links and the check change.
- **Risk:** Low, but it adds structure that today's apps don't need (CRF-004).

## Recommendation

Option 1: it's the only option where a missing or unfinished runbook fails CI, and it costs nothing.

## Decision

Proposed (auto mode, ADR-0035), with OPS-004; the owner accepts or changes it.

## Consequences

- New rule OPS-004 (proposed) in `docs/standards/operations.md`, in the scorecard's "Docs and decisions" area. GAP-017 is closed.
- `tools/Test-Runbook.ps1`, with Pester tests. The required sections are listed once, in the script; the template is tested against it.
- `templates/app/docs/runbook.md` is the template. Export-KitApp lists it as app-owned, so the sync job never overwrites an app's runbook, and it copies `Test-Runbook.ps1` to `.kit/tools/`.
- `app-checks.reusable.yml` runs the check on every pull request and push. A missing runbook fails.
- The kit sync (ADR-0044) now adds a file a release is the first to start every app with, for the app to own, when the app's kit version didn't have it and the app lacks it; the PR lists it under "Needs a look". It never changes one the app has. So an app that has the sync job gets a Draft runbook in the same kit-pin PR that brings in the check, and that PR passes.
- The two test apps predate the sync job, so moving their kit pin by hand past this change fails their App checks until each gets `docs/runbook.md` from the template (and, for the sync, the setup ADR-0044 and ADR-0045 describe).
- **Follow-up:** the production workflow (GAP-015) should run `Test-Runbook.ps1` and refuse to deploy while the status is Draft. Until then, the switch to In use at the first deployment is advisory.
- A later kit change to the template doesn't reach existing apps, because they own their copies. A new required section would fail every existing app's kit-pin PR until the app adds it, so it needs a release note that says so, or a change to the sync.

## Pillars affected

- **Operational Excellence:** written, versioned steps for deployment, rollback and incidents (OE:02, OE:08, OE:11).
- **Reliability:** a rehearsed rollback and restore shorten recovery.
- **Security:** a leaked secret is rotated first, and the runbook names where secrets are kept, never their values.

## Sources

- https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/formalize-operations-tasks, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/incident-response, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/manage/ready-cloud-operations, retrieved 2026-11-11
- https://diataxis.fr/how-to-guides/, retrieved 2026-11-11
