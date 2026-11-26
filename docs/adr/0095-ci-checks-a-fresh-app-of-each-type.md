# ADR-0095: The kit's CI checks a fresh app of each app type it can build on Linux

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The kit's output is an app repo: the files `tools/Export-KitApp.ps1` writes (ADR-0032), which `New-KitApp` commits and pushes (ADR-0033). Until now only the kit's sample app was built and checked, and it's built inside the kit, with the kit's own root files. Nothing checked an app as an app gets it: its own `Directory.Packages.props` without the kit's sample and tool packages, its `tests/Directory.Build.props`, its `.kit/` copies, its generated rule files, its own git history. So a kit change that would give every new app a failing gate could merge green (scorecard GAP-049). PR 116's "Not verified" is one case: an app gets `docs/standards/security.md` without the kit's `.gitleaksignore`, whose fingerprints name kit commits, so only the line's inline `gitleaks:allow` marker keeps the app's own secret scan green, and no run showed it does.

Three things shape the job:

- **Apps start empty** (ADR-0032): an exported app's solution has no projects, so its .NET gates skip their .NET steps. A check needs a project of each app type in it.
- **The app's checks are the kit's shared workflows** (`dotnet-ci.reusable.yml`, `app-checks.reusable.yml`), which check out the calling repo. In the kit's CI the calling repo is the kit, not the exported app.
- **App types** (`docs/standards/app-types.yml`, ADR-0084): web-api, blazor and maui. A MAUI app builds only on Windows and macOS (ADR-0059), and those jobs aren't proven yet (GAP-028); the owner put MAUI after the practice run.

The owner chose on 2026-11-25 to build this before v0.1.0, as an exception to the coming freeze on new checks.

## Options

### Option 1: export an app, add the kit's reference app of its type, and run the shared workflows on it (recommended)

`tools/New-FreshApp.ps1 -Type <type>` exports the app with `Export-KitApp.ps1` and an app profile for that type, makes New-KitApp's first commit (one shared function, `New-KitAppFirstCommit`), and copies in the probe: the kit's own reference app of the type, from the same commit. For web-api that's the sample (`sample/src` and `sample/tests`), whose packages it adds back from the kit's "Sample app" group; for blazor it's the web UI fixture (`fixtures/WebUi`), whose packages are all in groups an app keeps. The workflow restores (writing the app's own lock files), commits the probe as an app's first task would, and uploads a git bundle. Then it calls the two shared workflows with a new input, `app-bundle`, which makes each of their jobs check the bundle's clone instead of the kit's checkout.

- **Trade-offs:** the app's gates run through the very workflow files apps call, so nothing is copied and nothing drifts (CRF-003). The probes are code the kit already keeps green, so the job adds no project to maintain. The shared workflows gain an input and two steps per job, skipped unless the input is set; every app run downloads one more action at job setup, a few seconds.
- **Reversibility:** easy: remove the three jobs from `ci.yml`, the input and its steps from the two shared workflows, and the script.
- **Risk:** the probes are the kit's reference apps, not a fresh agent's first project, so they show what the kit's files do to an app that follows the kit's rules, not what a new app's first task might write. A probe change in the kit (GAP-025 moving the sample to SQL Server, say) reaches the job at once, which is the point.

### Option 2: new minimal probe projects, kept only for this job

- **Trade-offs:** smaller apps and faster runs. But a project that passes the kit's analyzers and the shared host checks (`tools/AppTests/Functional`) needs most of what the sample already has: health endpoints, ProblemDetails, security headers, the host part. A second copy of that knowledge drifts from the sample (CRF-003).
- **Reversibility:** easy.
- **Risk:** the copy goes stale and keeps passing while the sample moves on.

### Option 3: `dotnet new` the projects at CI time

- **Trade-offs:** no committed probe. But the templates don't meet the kit's rules (no health checks, no shared host checks, warnings the kit treats as errors), so the job would test the templates, and their output changes with each SDK.
- **Reversibility:** easy.
- **Risk:** red from day one for reasons unrelated to the kit's output.

Ways to run the app's checks, considered with option 1:

- **A script that mirrors the workflows' steps:** a second copy of every gate, which drifts from the one apps run. Rejected (CRF-003).
- **`act` (runs workflows locally in containers):** a new tool, large runner images, and it doesn't resolve the kit's `$/` action references. Rejected.
- **Pushing the app to a ref in the kit and calling the workflows there:** writes to GitHub on every run, and the shared workflows would still check out the kit. Rejected.

## Recommendation

Option 1: it checks an exported app through the same workflow files every app runs, with probes the kit already keeps green, so a kit change that breaks an app's gates fails the kit's own CI first.

## Decision

Accepted as recommended, in auto mode (the owner asked for the job on 2026-11-25). It covers web-api and blazor. The MAUI leg waits for GAP-028 and for MAUI's turn after the practice run, so GAP-049 stays open for it, and `New-FreshApp.ps1` refuses maui with that reason.

**Not required.** Adding a required check changes the kit's "main protection" ruleset, which is the owner's call (SEC-003), so the fresh-app jobs aren't in it. An agent still treats a red fresh-app job like a red required check: it doesn't merge, and it fixes the kit (or the probe) first, as AGENTS.md's CI paragraph says. Whether to make them required is a question for the owner.

**What runs.** In `ci.yml`: `fresh-app` (a matrix of web-api and blazor) exports the app; then `fresh-dotnet` calls `dotnet-ci.reusable.yml` and `fresh-app-checks` calls `app-checks.reusable.yml`, each with `app-bundle: fresh-app-<type>`. They cover the three checks an app's ruleset requires (`templates/github/main-protection.json`): "Build, test and package checks", "Secret scan (gitleaks)" and "App checks", reported under the caller jobs' names, as `Fresh <type> app (.NET) / Build, test and package checks`, `Fresh <type> app (.NET) / Secret scan (gitleaks)` and `Fresh <type> app (app checks) / App checks`. CodeQL, mutation, performance, Scorecard and the kit sync aren't required in an app (ADR-0036, ADR-0039, ADR-0062, ADR-0044), so they're left out.

**How `app-bundle` works.** Each job of the two shared workflows keeps its checkout; when the input is set, it then downloads the artifact to `RUNNER_TEMP` and runs the `$/.github/actions/exported-app` action, which empties the workspace and clones the bundle's `main` into it, with its whole history. So MinVer, the shallow-history check and gitleaks see an app's own history: New-KitApp's first commit and the probe's. The action fails when the bundle is missing or has no `main`; it never falls back to the kit's checkout. With the input set, app-checks' pull request steps run too, on that history: the commit checks read `HEAD` (every commit of the app), and the title check reads HEAD's subject. The SBOM artifact is named `sbom-<bundle>` instead of `sbom`, since an artifact name must be unique within a run. The action is bash and git only, so it would run on the Windows and macOS legs too; for these probes, which have no UI project, those legs don't run.

**What it proves, and what not.** It proves the app's own `Directory.Packages.props` resolves the probe's packages (with NuGet's audit), and that the build, format, tests, coverage gate, deprecated packages, empty projects, code shape, package licenses, duplicate code, SBOM, secret scan, ADR sections, architecture diagram, runbook, safe migrations and commit checks all pass in an app. The locked restore reads lock files written moments before, so it proves they resolve, not that they equal the kit's. Each probe has to clear the coverage gate on its own: in the kit's run, the sample's assemblies and Kit.WebUi are at 100% of lines, so they should; a probe change that drops one below the gate would fail here though the kit's merged total stays green.

**Cost and time.** The kit is public, so its standard GitHub-hosted runners are free: $0. Estimated from the kit's own jobs (the .NET job takes about three minutes, the kit checks about eight): an export of a minute or two, then a .NET job of about three, per type, in parallel with the kit checks, so a PR's wall time barely moves.

**Threat model.** The bundle comes from this run's own `fresh-app` job (download-artifact reads only the current run's artifacts without a token); the shared workflows keep `contents: read` and `persist-credentials: false`. The input lets a caller point its required checks at other content: an app that edits its own `ci.yml` could do that, but it could already change what that file runs, so the input adds nothing an app couldn't do. No app data or sign-in is touched, so no ASVS chapter applies.

## Consequences

- `tools/New-FreshApp.ps1` (kit only) and its tests; `.github/actions/exported-app`; `app-bundle` on `dotnet-ci.reusable.yml` and `app-checks.reusable.yml`; three jobs in `ci.yml`.
- New-KitApp's first commit is one function, `New-KitAppFirstCommit`, which New-FreshApp calls too; Export-KitApp's pattern for a labelled package group is one function, `Get-KitPackageGroupPattern`.
- The first runs caught two things, both fixed in this PR: the export job needs `powershell-yaml` for the app's own `Build-AgentRules.ps1`, and the probes' test hosts named the kit's folders (`sample/src`, `fixtures/WebUi/src`) for their content root, so every hosted test failed in an app. They now use `tools/AppTests/Hosting`'s `ProjectFolder` (ADR-0081's update of 2026-11-25), which apps get too.
- GAP-049 narrows to the MAUI leg.
- A kit change that breaks an app's required checks for web-api or blazor fails the kit's PR.

## Pillars affected

- **Reliability:** a kit release can't give new apps a red required check for web-api or blazor without the kit's CI showing it first.
- **Security:** the app's own secret scan runs on the files apps get, so a quote the kit skips only by fingerprint shows up.
- **Operational Excellence:** a failure names the type in the check's name; the job's steps are the app's own, so a failure reads as it would in the app.
- **Performance Efficiency:** an estimated five minutes per type, in parallel.
- **Cost Optimization:** $0 on the kit's public repo.

## Sources

- owner, 2026-11-25 (build GAP-049 before v0.1.0; MAUI after the practice run)
- ADR-0024, ADR-0032, ADR-0033, ADR-0059, ADR-0084, GAP-028, GAP-049
- https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows, retrieved 2026-11-25 ("Jobs using the matrix strategy can call a reusable workflow.")
- https://github.com/actions/upload-artifact, retrieved 2026-11-25 ("Artifact names must be unique since each created artifact is idempotent so multiple jobs cannot modify the same artifact."; hidden files are ignored by default)
- https://github.com/actions/download-artifact, retrieved 2026-11-25 ("By default, the permissions are scoped so they can only download Artifacts within the current workflow run.")
- https://git-scm.com/docs/git-bundle, retrieved 2026-11-25 ("It is possible git-clone a new repository from a bundle")
