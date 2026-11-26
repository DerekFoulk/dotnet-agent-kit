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
| If this app has an `E2E.Tests` project: its browser and accessibility tests (Playwright, axe) need the Chromium build the Microsoft.Playwright version pins. Installing it is the owner's step ("Always ask"). CI runs them inside the Playwright image `.config/playwright/Dockerfile` pins, whose version must match Microsoft.Playwright's in `Directory.Packages.props`: Dependabot moves the two in separate PRs, so bring them into one (kit ADR-0061; `docs/standards/testing.md`, "Browser and accessibility tests") | After a Debug build: `pwsh tests/{{Name}}.E2E.Tests/bin/Debug/<target framework>/playwright.ps1 install chromium` |
| List the solution's MAUI and desktop (UI) projects, which CI builds on Windows and macOS and the coverage gate exempts (ARC-010) | `./.kit/tools/Get-UiProject.ps1 -Solution {{Name}}.slnx` |
| No deprecated NuGet packages | `./.kit/tools/Test-DeprecatedPackages.ps1 -Path {{Name}}.slnx` |
| Every C# project in the solution holds code of its own, and none keeps the class library template's empty `Class1` (ARC-009) | `./.kit/tools/Test-EmptyProjects.ps1 -Solution {{Name}}.slnx` |
| Nesting, statements per member, file length, members per type, public types per file and LCOM4 within CRF-011's limits, and STY-005's nullable rules (kit ADR-0050). It builds the kit's checking tool from `.kit/tools/CodeShape` first; run it from the repo root | `./.kit/tools/Test-CodeShape.ps1 -Solution {{Name}}.slnx` |
| No duplicate code (CRF-003, kit ADR-0051). It needs Java and PMD, which are the developer's own install (installing them is the owner's call, "Always ask"); CI downloads the PMD release the kit pins | `./.kit/tools/Test-Duplication.ps1 -Solution {{Name}}.slnx -Pmd <PMD folder>/bin/pmd` (`pmd.bat` on Windows) |
| Every locked package's license is one the kit's policy or `.config/package-licenses.json` allows; that file also marks the app commercial (SEC-005). Restore first | `./.kit/tools/Test-PackageLicenses.ps1 -Solution {{Name}}.slnx` |
| Every ADR has its required sections | `./.kit/tools/Test-AdrSections.ps1 -AdrPath ./docs/adr` |
| The runbook has every section, and no placeholder once it's In use (OPS-004) | `./.kit/tools/Test-Runbook.ps1 -Path ./docs/runbook.md` |
| The architecture diagram is there (ARC-013) | `./.kit/tools/Test-ArchitectureDiagram.ps1 -Path ./docs/architecture/modules.md` |
| No migration drops or renames what the running version uses without a `// DAT-003:` reason (DAT-003) | `./.kit/tools/Test-SafeMigrations.ps1 -Path .` |
| Benchmarks within their budget (kit TST-009): in CI, nightly in `.github/workflows/performance.yml`, not required; locally after a BenchmarkDotNet run with `--exporters json` | `dotnet run --project tests/<Name>.Benchmarks --configuration Release -- --filter '*' --exporters json`, then `./.kit/tools/Test-BenchmarkBudget.ps1 -Path BenchmarkDotNet.Artifacts/results -Budget tests/<Name>.Benchmarks/benchmark-budget.json` |
| A Locust load test within its budget (kit TST-009): in CI, in `.github/workflows/performance.yml` once it names the app to load; locally after a run with `--csv` | `./.kit/tools/Test-LoadBudget.ps1 -Path <the --csv prefix> -Budget tests/load/load-budget.json` |
| Regenerate agent rule files after editing this file | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` |
| Check generated files are current | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot . -Check` |
| PR title and commit subjects are Conventional Commits | `./.kit/tools/Test-ConventionalTitle.ps1 -Range origin/main..HEAD` |
| Every red commit is made green | `./.kit/tools/Test-RedGreenOrder.ps1 -Range origin/main..HEAD` |
| List a PR's open review findings; reply; resolve a thread | `Import-Module ./.kit/tools/KitReview.psm1`, then `Get-OpenFinding`, `Resolve-ReviewFinding`, `Add-ReviewReply` (see the `address-review` skill) |
| Wait for a PR's CI after a push, or for a Copilot review the owner asked for (`finish-work` step 4) | `Import-Module ./.kit/tools/KitReview.psm1`, then `Wait-PullRequest -Repository <owner/repo> -Number <pr> -For Checks` (or `-For Review`), in the foreground, with its default time-out (`finish-work` step 4, "Wait cheaply"); it costs no model call while it polls. It returns `Reviewed`, `ReviewFailed` (Copilot posted a reason, not a review), `ChecksPassed`, `ChecksFailed`, `HeadMoved`, `Merged`, `Closed` or `TimedOut`, with a message. `ChecksFailed` comes as soon as a failure is final (no run still going can replace it), even while other checks still run; to wait for the rest, pass its `FailedChecks` as `-KnownFailures`, on every later wait for that commit |

CI runs the kit's shared checks on every pull request: `.github/workflows/ci.yml` (restore, build, format, tests, the coverage gate, deprecated packages, empty projects (ARC-009), the code shape check of nesting, statement counts, file length, members per type, public types per file and LCOM4 (CRF-011), with STY-005's nullable rules (no `#nullable` directive, a `// CRF-001 safety net:` label on each `!`, no generated-code marker outside `Migrations` or a `.resx` file's designer), the duplicate code check (CRF-003), an SBOM, and a gitleaks secret scan) and `.github/workflows/app-checks.yml` (the PR title, commit subjects, red→green order, ADR sections, the runbook, and each EF Core migration's `Up` (kit DAT-003)). The "main protection" ruleset requires them to pass. Their findings show in the PR's annotations; in a check script that judges the app's code (the code shape, empty projects, runbook and safe migrations checks, and the UI project reference check), a finding of a rule the kit marks `should`, such as CRF-011, is a warning and doesn't fail the check, a `must` rule's finding fails it, and a rule this app's `docs/app-profile.md` rules out (by its app types, or a condition its Conditions line answers `no`) is skipped with a notice, while the kit's shared authorization checks (kit SEC-017) still fail, in an app whose endpoints mostly require sign-in (kit ADR-0089, ADR-0090); run the code shape and duplicate code checks locally first (see Commands). `.github/workflows/mutation.yml` runs Stryker.NET nightly and fails below a mutation score of 85% (kit TST-004); it isn't a required check, so read its `mutation-report` artifact when a night fails. `.github/workflows/performance.yml` runs each benchmarks project nightly against its budget, and the app's Locust load test once the file names the app to load (kit TST-009, ADR-0062); it isn't a required check either, so read its `benchmark-results` and `load-test-results` artifacts when a night fails. Each build keeps an SBOM (software bill of materials: every package the app ships, test and benchmarks projects left out) as its `sbom` artifact (kit SUP-009). `.github/workflows/scorecard.yml` runs OpenSSF Scorecard, which scores the repo's supply-chain practices, on every push to `main` and weekly (kit SUP-010); a public app's score is published, its findings go to the Security tab beside CodeQL's, and on a private app it's skipped. `.github/workflows/secret-scan.yml` runs the same gitleaks scan on every push to a branch other than `main` and every tag push (kit ADR-0024): a secret is exposed once it's pushed, pull request or not. It isn't a required check; a red run means the secret is already exposed, so tell the owner to rotate it, since rewriting the branch doesn't take it back. `.github/workflows/kit-sync.yml` runs only on Dependabot's kit-pin PRs (see "Kit-managed files" below). Until the solution has a project, the .NET steps skip, and a local `dotnet build` warns that there's no project to restore; that warning goes away with the first project.

The commit-msg hook in `.githooks/` rejects a commit whose subject isn't a Conventional Commit. `./.kit/tools/Initialize-DevMachine.ps1 -RepoRoot .` reports whether it's on for this clone. If the hook rejects a commit, fix the subject; never skip the hook.

Scripts target PowerShell 7.6 or later (`pwsh`), the current LTS.

## Where things are

| Path | What |
|---|---|
| `src/`, `tests/` | This app's projects and their tests, created with the first feature. `tests/Directory.Build.props` sets up every `*Tests` project (xUnit v3, coverage) and every `*.Benchmarks` project (BenchmarkDotNet, kit ADR-0062), and compiles the kit's shared tests into an `*.Architecture.Tests` project (kit ADR-0081): that project names this app's assemblies by layer in its own `AppLayers.cs`, as the kit's sample does in `sample/tests/Bookmarks.Architecture.Tests/AppLayers.cs`, and builds only once it does; and the kit's host checks into a `*.FunctionalTests` project, which says how to start this app, which routes are public, a route a signed-in user may GET and whether it serves an HTTP API, in its own `AppHost.cs`, as the sample does in `sample/tests/Bookmarks.FunctionalTests/AppHost.cs`; a load test lives in `tests/load/` |
| `docs/app-profile.md` | What this app is, as the owner chose at the new-app intake: app type, data, database, sign-in, hosting and test tools, with their costs (kit ADR-0058). An app made before the intake has none. Where it exists, plans start from it, and changing an answer takes an ADR in `docs/adr/` |
| `docs/adr/` | This app's decisions, numbered from ADR-0001 |
| `docs/standards/` | The kit's rules, in full (managed by the kit) |
| `docs/runbook.md` | How to deploy, roll back, check, restore and run this app in an incident (OPS-004). A Draft until the first production deployment: fill in every `[fill in: ...]`, then set it to In use |
| `docs/corrections-log.md` | Every owner correction and what it became |
| `docs/architecture/modules.md` | A Mermaid diagram of this app's modules and their dependencies (ARC-013); update it with any change that adds a module, a project or a dependency |
| `.claude/skills/`, `.claude/agents/reviewer.md`, `docs/code-review.md` | The kit's workflow skills, its independent reviewer, and what the reviewer checks on every branch. Some skills are curated .NET skills that the kit copies unchanged from Microsoft's dotnet/skills at a pinned commit (kit ADR-0042): where one disagrees with a kit rule, the kit rule wins |
| `.kit/` | The kit's checking scripts (`.kit/tools/`), the source of its code shape tool and shared tests, with the kit's build files that build them, and the manifest of kit-managed files (`.kit/manifest.json`) |

**Kit ADRs:** "ADR-NNNN" inside a kit-managed file (`docs/standards/`, the skills, the reviewer agent, `docs/code-review.md`, the kit sections of this file) means the kit's ADR, at https://github.com/DerekFoulk/dotnet-agent-kit/tree/{{KitCommit}}/docs/adr. This app's own ADRs are in `docs/adr/`. Likewise, a path under `tools/` or `sample/` in `docs/standards/` describes how the kit enforces a rule in its own repo; this repo's commands are the Commands table above.

**Kit-managed files, don't edit:** every file listed in `.kit/manifest.json`, and this file between `kit:begin` and `kit:end`. With each kit release, Dependabot opens a PR that moves the kit pin, and `.github/workflows/kit-sync.yml` adds the release's other kit-managed files to it, merging the kit's changes into any edit this app made and commenting each file that needs a look (kit ADR-0044, ADR-0045). To change one for good, change the kit.

**Generated files, don't edit:** `.github/copilot-instructions.md`, `.claude/rules/`, `.github/instructions/` and `.kit/tools/rule-strength.json` (kit ADR-0090). After editing this file, run `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` and commit both.

## Done means

<!-- rules from docs/standards/definition-of-done.md: generated by Build-AgentRules.ps1; edit the standard, then regenerate -->
- DOD-001 (must): Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR.
- DOD-002 (must): Report done only with evidence (commands run, counts, links), and state "not verified" wherever something wasn't.
- DOD-003 (must): Before the owner reviews, an independent read-only reviewer agent that hasn't seen the work (.claude/agents/reviewer.md) reviews every branch against the kit's code-review instructions (docs/code-review.md) and rule files, before its pull request opens (for a PR a bot opens, before it merges) and again after each round of fixes; the reviewer ranks each finding Blocking, Should fix or Consider, the implementing agent answers it (DOD-005), and reviews end at the first round with nothing blocking or should-fix.
- DOD-004 (must): Every PR uses the PR template, including the red-to-green evidence table; a PR whose description a bot writes carries the evidence as DOD-006 says, and a release PR is the owner's.
- DOD-005 (must): Every review finding on a PR is checked against the code and answered with evidence; a fixed or already-fixed one is resolved as addressed, a wrong one as incorrect, and one left unfixed as won't fix: in review mode only with the owner's OK, in auto mode with the agent's reason in the reply.
- DOD-006 (must): A PR whose description a bot writes, such as Dependabot's, keeps that description. In either mode, before the PR is merged, the agent handling it posts the template's sections as a PR comment: 'What and why'; 'Red → green evidence' for any behavior change an agent added, one row per test-list item (a bot's own commits need none); 'Checks run', with code review's findings and how each was answered; 'For the owner'; and 'Not verified'. The comment names the head commit its counts come from, which must be the commit the PR is merged at: when the head moves, as it does when a lock-file refresh pushes or Dependabot rebases, the agent posts a new one. That comment stands in for the complete description a merge needs, whoever merges the PR. Release PRs are the owner's, so this doesn't cover them.
<!-- end rules -->

The checks are the ones in "Commands": the coverage gate, ADR sections and the runbook among them. The PR template is `.github/pull_request_template.md`.

<!-- kit:end -->

## This app

What {{Name}} is, who uses it, and anything an agent must know that the kit doesn't say. This section is yours; the kit never changes it.
