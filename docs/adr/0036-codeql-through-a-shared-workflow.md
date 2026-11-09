# ADR-0036: Run CodeQL code scanning through a shared workflow

- **Status:** Accepted
- **Date:** 2026-11-07

## Context

The quality scorecard's GAP-005 is "No code scanning: CodeQL is free on public repos but isn't set up" (ADR-0034). The kit is public (ADR-0031), and new apps are public by default (ADR-0033).

GitHub's CodeQL can scan C# up to 14 and GitHub Actions workflows; it can't scan PowerShell (CodeQL docs, "Supported languages and frameworks"). On a private repo, code scanning needs a GitHub Code Security licence, which costs money. For C#, CodeQL can analyze without a build (`build-mode: none`).

GitHub's own setting, "default setup", picks the languages it finds, and GitHub's docs say it adds a language that appears later. But it found only `actions` in the kit: GitHub counts the sample app under `sample/` as documentation, so it ignores the kit's C#. And it can't be tested or versioned with the kit.

This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: A shared workflow, `codeql.reusable.yml`, called by the kit's and each app's CI

A first job finds the languages: `actions` always, and `csharp` once the repo has a `.cs` file, because CodeQL fails on a language with no source. A matrix then runs CodeQL's `init` and `analyze` per language, pinned by SHA. The upload needs `security-events: write` on that job only. Apps skip the job on private repos.

- **Trade-offs:** It's versioned and tested with the kit, like the other shared workflows. It scans the kit's sample C#, and an app's C# as soon as it exists. The sync job moves it with each kit release. Dependabot updates the action pin in the kit. It costs about two Linux jobs per PR, which are free on public repos. Its check names depend on the languages, so it can't simply be a required check.
- **Reversibility:** Easy. Removing the jobs and the file undoes it.
- **Risk:** Low. It reads code and uploads results; it changes nothing in the repo.

### Option 2: GitHub's default setup, turned on per repo

- **Trade-offs:** No workflow to maintain. But it's a repo setting rather than code: it can't be tested, and new apps would need `New-KitApp` to apply it. It skips the kit's C#. It does pick up a language added later (GitHub's docs, "Code scanning setup types").
- **Reversibility:** Easy.
- **Risk:** Medium: in the kit, the scan quietly covers less than intended.

### Option 3: A third-party scanner, such as Semgrep or SonarCloud

- **Trade-offs:** These cover more languages, PowerShell among some of them. But they're another service and another account, and some are paid. CodeQL is GitHub's own and free here.
- **Reversibility:** Medium.
- **Risk:** Medium: a new dependency and possible cost.

## Recommendation

Option 1: it's tested and versioned like the rest of the kit's CI, and it covers C# that default setup misses.

## Decision

Accepted (auto mode, ADR-0035: the action is the one GAP-005 and GitHub's code scanning docs name). The owner can reverse it, as with any merged change.

## Consequences

- `.github/workflows/codeql.reusable.yml` is new. The kit's `ci.yml` calls it, and so does every app's `ci.yml`, with `if: ${{ !github.event.repository.private }}`. Results appear under each repo's Security tab and as checks on PRs.
- **SEC-006 is proposed:** every public repo runs CodeQL on its PRs and on `main`. The owner ratifies it.
- **GAP-005 is closed** in the scorecard.
- **Not a required check yet.** The checks are `codeql / CodeQL languages`, `codeql / CodeQL (actions)`, `codeql / CodeQL (csharp)` and a `CodeQL` results check from GitHub; an app with no C# has no `csharp` one. Requiring them would change the ruleset, which is the owner's call. So would a "require code scanning results" rule, which blocks a merge on alerts. `tools/tests/New-KitApp.Tests.ps1` leaves CodeQL out of the required checks it derives.
- **Update (2026-11-09):** the owner accepted SEC-006, and the kit's "main protection" ruleset gained a "require code scanning results" rule: CodeQL, blocking on an alert of severity error or a security alert high or higher on lines the pull request changes, or while CodeQL's analysis is in progress or missing. The CodeQL jobs still aren't required status checks, and apps' rulesets don't have the rule yet.
- **PowerShell, most of the kit, isn't scanned.** CodeQL doesn't support it, and PSScriptAnalyzer would be its own gap.
- **Finding the languages:** the step reads `git ls-files` in full rather than piping it into `grep -q`. Under GitHub's `bash -e -o pipefail`, that pipe can end git with SIGPIPE on a large repo, and C# would drop out silently (review 1 of PR 20). A test runs the step as CI does.
- **Known limits, left for later:**
  - The kit's deliberately flawed test fixtures (`tools/tests/fixtures`) are scanned too. There are no alerts today; a `paths-ignore` config could leave them out if they cause noise.
  - There's no weekly scan of a quiet `main`.
  - A new app's first push to `main` happens while it's still private, so its first `main` analysis comes with its second push.
- **Fork PRs:** GitHub's docs say code scanning always accepts an upload from a `pull_request` run, so a fork's read-only token is enough. Not tried yet.

## Pillars affected

- **Security:** every public repo is scanned for code-level flaws on each PR.
- **Cost Optimization:** free on public repos, and skipped on private ones, where it would need a paid licence.
- **Operational Excellence:** one shared, versioned workflow.
- **Reliability and Performance Efficiency:** not affected; the scan adds a few minutes of CI per PR.

## Sources

- https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/, retrieved 2026-11-07
- https://docs.github.com/en/code-security/concepts/code-scanning/codeql/codeql-code-scanning, retrieved 2026-11-07
- https://docs.github.com/en/code-security/code-scanning/enabling-code-scanning/configuring-default-setup-for-code-scanning, retrieved 2026-11-07
- https://docs.github.com/en/code-security/concepts/code-scanning/setup-types, retrieved 2026-11-07
- https://docs.github.com/en/code-security/reference/code-scanning/troubleshoot-analysis-errors/resource-not-accessible, retrieved 2026-11-07
