# ADR-0056: Run OpenSSF Scorecard through a shared workflow

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

The quality scorecard's GAP-014 is "OpenSSF Scorecard ... isn't run; it would check this area from outside." OpenSSF Scorecard scores a repo's supply-chain practices from 0 to 10, in checks such as Pinned-Dependencies, Token-Permissions, Branch-Protection, Dangerous-Workflow, Code-Review and SAST. The OpenSSF's `scorecard-action` runs it in GitHub Actions. It can publish the score to the OpenSSF API, which powers the public badge and score page, and its findings can go to the repo's code scanning as SARIF.

Publishing only works from a workflow that keeps the action's documented restrictions:
- no top-level `env` or `defaults`, and no write permission at workflow level;
- `id-token: write` only in the Scorecard job;
- that job has no `env`, `defaults`, container or services, and runs on GitHub's Ubuntu runners;
- its steps are only actions from an allowed list (checkout, upload-artifact, CodeQL's upload-sarif, scorecard-action, harden-runner).

The OpenSSF's example workflow (`scorecard-analysis.yml`) gives its job only `security-events: write` (the SARIF upload) and `id-token: write` (to sign the published results). It names `push` and `schedule` on the default branch as the supported triggers.

The kit and new apps are public (ADR-0031, ADR-0033). The action and code scanning are free there. On a private repo the action never publishes, and the code scanning upload needs GitHub Code Security, a paid licence, as for CodeQL (ADR-0036). A scheduled run's event carries no repository, so `github.event.repository.private` can't tell a private repo there. The "code scanning" ruleset (`templates/github/code-scanning.json`) only gates on CodeQL's results, so Scorecard's SARIF doesn't block a merge.

This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: A shared workflow, `scorecard.reusable.yml`, called by the kit and by each app

The shared workflow's Scorecard job keeps the restrictions above, with every action pinned by SHA. A first job asks the API for the repo's visibility, and the Scorecard job is skipped on a private repo, on every trigger. The kit's `scorecard.yml` and the app template's call it on every push to `main` and weekly.

- **Trade-offs:** Versioned and tested with the kit, like the CodeQL workflow. An app picks up a new action version with its next kit pin. It's a new workflow file, so existing apps add the template's `scorecard.yml` by hand ("WorkflowByHand", ADR-0044); new apps get it from `New-KitApp`. The OIDC certificate names the shared workflow that ran, and the OpenSSF's publish check reads that file, in the kit, at the pinned commit (`api/app/server/post_results.go` in `ossf/scorecard-infra`).
- **Reversibility:** Easy. Delete the three files.
- **Risk:** Low to medium. It can't run before merge, because publishing only works on the default branch, so the first run on `main` is the proof.

### Option 2: A full copy of the action's example workflow in the kit and in the app template

- **Trade-offs:** The publish check reads the calling repo's own file, the setup the action documents. But the same job lives in two places, and each app's copy drifts from the kit's as Dependabot moves its pins separately (CRF-003).
- **Reversibility:** Easy.
- **Risk:** Low.

### Option 3: Run Scorecard without publishing

Upload SARIF only, with `publish_results: false`.

- **Trade-offs:** None of the restrictions apply. But there's no public score or badge, which is what checks "from outside".
- **Reversibility:** Easy.
- **Risk:** Low.

## Recommendation

Option 1: one tested copy that every app pins, like the kit's other shared workflows. If the first run on `main` shows the publish check refusing a shared workflow, Option 2 is the fallback, under a new ADR.

## Decision

Proposed (auto mode, ADR-0035), with SUP-010; the owner accepts or changes it.

## Consequences

- New rule SUP-010 (proposed) in `docs/standards/supply-chain.md`. GAP-014 is closed.
- `.github/workflows/scorecard.reusable.yml`, called by `.github/workflows/scorecard.yml` and `templates/app/.github/workflows/scorecard.yml`. `tools/tests/SharedCi.Tests.ps1` checks each restriction, the permissions and the pins.
- It isn't a required check: it doesn't run on pull requests, and the ruleset requires only checks from workflows that do (`New-KitApp.Tests.ps1` checks the list).
- On a private repo only the visibility job runs, a few seconds of a Linux runner per push to `main` and per week, which count against the owner's included Actions minutes.
- GitHub turns off a public repo's scheduled workflows after 60 days with no activity, so a quiet app's weekly run stops until something is pushed.
- Scorecard's findings appear in each repo's Security tab beside CodeQL's. A low check score is a finding to triage, not a failed build.

## Pillars affected

- **Security:** an outside, repeatable score of the kit's and each app's supply-chain practices, with findings in code scanning.
- **Operational Excellence:** one shared, versioned workflow; a public score shows drift without anyone looking.
- **Cost Optimization:** free on public repos, and skipped on private ones.
- **Reliability and Performance Efficiency:** not affected; it runs weekly and on pushes to `main`, not on pull requests.

## Sources

- https://github.com/ossf/scorecard-action (README, "Workflow Restrictions"), retrieved 2026-11-11
- https://github.com/ossf/scorecard/blob/main/.github/workflows/scorecard-analysis.yml (the example workflow and its job permissions), retrieved 2026-11-11
- https://github.com/ossf/scorecard-action/blob/fa7117db83c52d787ae5a89f350999701505d78e/options/options.go (no publishing from a private repo), retrieved 2026-11-11
- https://github.com/ossf/scorecard-infra/blob/main/api/app/server/post_results.go (the publish check reads the workflow the certificate names), retrieved 2026-11-11
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule (no webhook payload), retrieved 2026-11-11
- https://github.com/ossf/scorecard-action/releases/tag/v2.5.0 (commit fa7117db83c52d787ae5a89f350999701505d78e), retrieved 2026-11-11
- https://github.com/ossf/scorecard/blob/main/docs/checks.md, retrieved 2026-11-11
- https://openssf.org/, retrieved 2026-11-11
