# Agent instructions: {{Name}}

This repo is **{{Name}}**.

<!-- kit:begin. Managed by dotnet-agent-kit: the sync job replaces everything from here to kit:end. Put this app's own notes under "This app", below kit:end. -->

This repo follows dotnet-agent-kit {{KitVersion}} (commit `{{KitCommit}}`): the kit's rules, checks and agent instructions apply here.

{{KitSections}}

## Commands

| What | Command |
|---|---|
| Check this machine's toolchain | `./.kit/tools/Initialize-DevMachine.ps1 -RepoRoot .` |
| Show the working mode; switch it (the owner's call) | `./.kit/tools/Set-AgentMode.ps1 -RepoRoot .`, with `-Mode Review` or `-Mode Auto` |
| Build | `dotnet build {{Name}}.slnx` |
| .NET tests with coverage, then the coverage gate (TST-004) | Delete `TestResults` first (the gate merges every report it finds), then `dotnet test --solution {{Name}}.slnx --coverage --coverage-output-format cobertura --results-directory TestResults` and `./.kit/tools/Test-CoverageGate.ps1 -Path TestResults -Solution {{Name}}.slnx`. On Windows, run it from a clone in a short folder, such as `C:\src\<repo>`: from a deep one, the coverage collector can drop the browser tests' project and the gate fails the web project (docs/standards/testing.md, "Browser and accessibility tests") |
| If this app has an `E2E.Tests` project: its browser and accessibility tests (Playwright, axe) need the Chromium build the Microsoft.Playwright version pins. Installing it is the owner's step ("Always ask"); CI installs it itself (kit ADR-0061) | After a Debug build: `pwsh tests/{{Name}}.E2E.Tests/bin/Debug/<target framework>/playwright.ps1 install chromium` |
| List the solution's MAUI and desktop (UI) projects, which CI builds on Windows and macOS and the coverage gate exempts (ARC-010) | `./.kit/tools/Get-UiProject.ps1 -Solution {{Name}}.slnx` |
| No deprecated NuGet packages | `./.kit/tools/Test-DeprecatedPackages.ps1 -Path {{Name}}.slnx` |
| Every C# project in the solution holds code of its own, and none keeps the class library template's empty `Class1` (ARC-009) | `./.kit/tools/Test-EmptyProjects.ps1 -Solution {{Name}}.slnx` |
| Every ADR has its required sections | `./.kit/tools/Test-AdrSections.ps1 -AdrPath ./docs/adr` |
| The runbook has every section, and no placeholder once it's In use (OPS-004) | `./.kit/tools/Test-Runbook.ps1 -Path ./docs/runbook.md` |
| No migration drops or renames what the running version uses without a `// DAT-003:` reason (DAT-003) | `./.kit/tools/Test-SafeMigrations.ps1 -Path .` |
| Benchmarks within their budget (kit TST-009): in CI, nightly in `.github/workflows/performance.yml`, not required; locally after a BenchmarkDotNet run with `--exporters json` | `dotnet run --project tests/<Name>.Benchmarks --configuration Release -- --filter '*' --exporters json`, then `./.kit/tools/Test-BenchmarkBudget.ps1 -Path BenchmarkDotNet.Artifacts/results -Budget tests/<Name>.Benchmarks/benchmark-budget.json` |
| A Locust load test within its budget (kit TST-009): in CI, in `.github/workflows/performance.yml` once it names the app to load; locally after a run with `--csv` | `./.kit/tools/Test-LoadBudget.ps1 -Path <the --csv prefix> -Budget tests/load/load-budget.json` |
| Regenerate agent rule files after editing this file | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` |
| Check generated files are current | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot . -Check` |
| PR title and commit subjects are Conventional Commits | `./.kit/tools/Test-ConventionalTitle.ps1 -Range origin/main..HEAD` |
| Every red commit is made green | `./.kit/tools/Test-RedGreenOrder.ps1 -Range origin/main..HEAD` |
| List a PR's open review findings; reply; resolve a thread | `Import-Module ./.kit/tools/KitReview.psm1`, then `Get-OpenFinding`, `Resolve-ReviewFinding`, `Add-ReviewReply` (see the `address-review` skill) |
| Wait for a PR's Copilot review or its CI after a push (`finish-work` step 4) | `Import-Module ./.kit/tools/KitReview.psm1`, then `Wait-PullRequest -Repository <owner/repo> -Number <pr> -For Review` (or `-For Checks`); it returns `Reviewed`, `ReviewFailed` (Copilot posted a reason, not a review), `ChecksPassed`, `ChecksFailed`, `HeadMoved`, `Merged`, `Closed` or `TimedOut`, with a message |

CI runs the kit's shared checks on every pull request: `.github/workflows/ci.yml` (restore, build, format, tests, the coverage gate, deprecated packages, empty projects (ARC-009), the code shape check of nesting, statement counts, file length and LCOM4 (CRF-011), the duplicate code check (CRF-003), an SBOM, and a gitleaks secret scan) and `.github/workflows/app-checks.yml` (the PR title, commit subjects, red→green order, ADR sections, the runbook, and each EF Core migration's `Up` (kit DAT-003)). The "main protection" ruleset requires them to pass. The code shape and duplicate code checks run only in CI for now (GAP-022 in the kit's scorecard), so read their findings in the PR's annotations. `.github/workflows/mutation.yml` runs Stryker.NET nightly and fails below a mutation score of 85% (kit TST-004); it isn't a required check, so read its `mutation-report` artifact when a night fails. `.github/workflows/performance.yml` runs each benchmarks project nightly against its budget, and the app's Locust load test once the file names the app to load (kit TST-009, ADR-0062); it isn't a required check either, so read its `benchmark-results` and `load-test-results` artifacts when a night fails. Each build keeps an SBOM (software bill of materials: every package the app ships, test and benchmarks projects left out) as its `sbom` artifact (kit SUP-009). `.github/workflows/scorecard.yml` runs OpenSSF Scorecard, which scores the repo's supply-chain practices, on every push to `main` and weekly (kit SUP-010); a public app's score is published, its findings go to the Security tab beside CodeQL's, and on a private app it's skipped. `.github/workflows/kit-sync.yml` runs only on Dependabot's kit-pin PRs (see "Kit-managed files" below). Until the solution has a project, the .NET steps skip, and a local `dotnet build` warns that there's no project to restore; that warning goes away with the first project.

The commit-msg hook in `.githooks/` rejects a commit whose subject isn't a Conventional Commit. `./.kit/tools/Initialize-DevMachine.ps1 -RepoRoot .` reports whether it's on for this clone. If the hook rejects a commit, fix the subject; never skip the hook.

Scripts target PowerShell 7.6 or later (`pwsh`), the current LTS.

## Where things are

| Path | What |
|---|---|
| `src/`, `tests/` | This app's projects and their tests, created with the first feature. `tests/Directory.Build.props` sets up every `*Tests` project (xUnit v3, coverage) and every `*.Benchmarks` project (BenchmarkDotNet, kit ADR-0062); a load test lives in `tests/load/` |
| `docs/app-profile.md` | What this app is, as the owner chose at the new-app intake: app type, data, database, sign-in, hosting and test tools, with their costs (kit ADR-0058). An app made before the intake has none. Where it exists, plans start from it, and changing an answer takes an ADR in `docs/adr/` |
| `docs/adr/` | This app's decisions, numbered from ADR-0001 |
| `docs/standards/` | The kit's rules, in full (managed by the kit) |
| `docs/runbook.md` | How to deploy, roll back, check, restore and run this app in an incident (OPS-004). A Draft until the first production deployment: fill in every `[fill in: ...]`, then set it to In use |
| `docs/corrections-log.md` | Every owner correction and what it became |
| `.claude/skills/`, `docs/code-review.md` | The kit's workflow skills, and what Copilot code review checks on every PR. Some skills are curated .NET skills that the kit copies unchanged from Microsoft's dotnet/skills at a pinned commit (kit ADR-0042): where one disagrees with a kit rule, the kit rule wins |
| `.kit/` | The kit's checking scripts (`.kit/tools/`) and the manifest of kit-managed files (`.kit/manifest.json`) |

**Kit ADRs:** "ADR-NNNN" inside a kit-managed file (`docs/standards/`, the skills, `docs/code-review.md`, the kit sections of this file) means the kit's ADR, at https://github.com/DerekFoulk/dotnet-agent-kit/tree/{{KitCommit}}/docs/adr. This app's own ADRs are in `docs/adr/`. Likewise, a path under `tools/` or `sample/` in `docs/standards/` describes how the kit enforces a rule in its own repo; this repo's commands are the Commands table above.

**Kit-managed files, don't edit:** every file listed in `.kit/manifest.json`, and this file between `kit:begin` and `kit:end`. With each kit release, Dependabot opens a PR that moves the kit pin, and `.github/workflows/kit-sync.yml` adds the release's other kit-managed files to it, merging the kit's changes into any edit this app made and commenting each file that needs a look (kit ADR-0044, ADR-0045). To change one for good, change the kit.

**Generated files, don't edit:** `.github/copilot-instructions.md`, `.claude/rules/` and `.github/instructions/`. After editing this file, run `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` and commit both.

## Done means

<!-- rules from docs/standards/definition-of-done.md: generated by Build-AgentRules.ps1; edit the standard, then regenerate -->
- DOD-001: Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR.
- DOD-002: Report done only with evidence (commands run, counts, links), and state "not verified" wherever something wasn't.
- DOD-003: Before the owner reviews, GitHub Copilot code review reviews every pull request and every push to it, against the kit's code-review instructions (.github/instructions/code-review.instructions.md) and rule files; the agent ranks each finding Blocking, Should fix or Consider and answers it (DOD-005), and reviews end at the first Copilot review of the head commit with nothing blocking or should-fix.
- DOD-004: Every PR uses the PR template, including the red-to-green evidence table; a PR whose description a bot writes carries the evidence as DOD-006 says, and a release PR is the owner's.
- DOD-005: Every review finding on a PR is checked against the code and answered with evidence; a fixed or already-fixed one is resolved as addressed, a wrong one as incorrect, and one left unfixed as won't fix: in review mode only with the owner's OK, in auto mode with the agent's reason in the reply.
- DOD-006: A PR whose description a bot writes, such as Dependabot's, keeps that description. In either mode, before the PR is merged, the agent handling it posts the template's sections as a PR comment: 'What and why'; 'Red → green evidence' for any behavior change an agent added, one row per test-list item (a bot's own commits need none); 'Checks run', with code review's findings and how each was answered; 'For the owner'; and 'Not verified'. The comment names the head commit its counts come from, which must be the commit the PR is merged at: when the head moves, as it does when a lock-file refresh pushes or Dependabot rebases, the agent posts a new one. That comment stands in for the complete description a merge needs, whoever merges the PR. Release PRs are the owner's, so this doesn't cover them.
<!-- end rules -->

The checks are the ones in "Commands": the coverage gate, ADR sections and the runbook among them. The PR template is `.github/pull_request_template.md`.

<!-- kit:end -->

## This app

What {{Name}} is, who uses it, and anything an agent must know that the kit doesn't say. This section is yours; the kit never changes it.
