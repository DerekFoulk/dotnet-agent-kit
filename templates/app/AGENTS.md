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
| .NET tests with coverage, then the coverage gate (TST-004) | Delete `TestResults` first (the gate merges every report it finds), then `dotnet test --solution {{Name}}.slnx --coverage --coverage-output-format cobertura --results-directory TestResults` and `./.kit/tools/Test-CoverageGate.ps1 -Path TestResults -Solution {{Name}}.slnx` |
| No deprecated NuGet packages | `./.kit/tools/Test-DeprecatedPackages.ps1 -Path {{Name}}.slnx` |
| Every ADR has its required sections | `./.kit/tools/Test-AdrSections.ps1 -AdrPath ./docs/adr` |
| Regenerate agent rule files after editing this file | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` |
| Check generated files are current | `./.kit/tools/Build-AgentRules.ps1 -RepoRoot . -Check` |
| PR title and commit subjects are Conventional Commits | `./.kit/tools/Test-ConventionalTitle.ps1 -Range origin/main..HEAD` |
| Every red commit is made green | `./.kit/tools/Test-RedGreenOrder.ps1 -Range origin/main..HEAD` |
| List a PR's open review findings; reply; resolve a thread | `Import-Module ./.kit/tools/KitReview.psm1`, then `Get-OpenFinding`, `Resolve-ReviewFinding`, `Add-ReviewReply` (see the `address-review` skill) |

CI runs the kit's shared checks on every pull request: `.github/workflows/ci.yml` (restore, build, format, tests, the coverage gate, deprecated packages and a gitleaks secret scan) and `.github/workflows/app-checks.yml` (the PR title, commit subjects, red→green order and ADR sections). The "main protection" ruleset requires them to pass. `.github/workflows/mutation.yml` runs Stryker.NET nightly and fails below a mutation score of 85% (kit TST-004); it isn't a required check, so read its `mutation-report` artifact when a night fails. `.github/workflows/kit-sync.yml` runs only on Dependabot's kit-pin PRs (see "Kit-managed files" below). Until the solution has a project, the .NET steps skip, and a local `dotnet build` warns that there's no project to restore; that warning goes away with the first project.

The commit-msg hook in `.githooks/` rejects a commit whose subject isn't a Conventional Commit. `./.kit/tools/Initialize-DevMachine.ps1 -RepoRoot .` reports whether it's on for this clone. If the hook rejects a commit, fix the subject; never skip the hook.

Scripts target PowerShell 7.6 or later (`pwsh`), the current LTS.

## Where things are

| Path | What |
|---|---|
| `src/`, `tests/` | This app's projects and their tests, created with the first feature. `tests/Directory.Build.props` sets up every `*Tests` project (xUnit v3, coverage) |
| `docs/adr/` | This app's decisions, numbered from ADR-0001 |
| `docs/standards/` | The kit's rules, in full (managed by the kit) |
| `docs/corrections-log.md` | Every owner correction and what it became |
| `.claude/skills/`, `.claude/agents/reviewer.md` | The kit's workflow skills and independent reviewer |
| `.kit/` | The kit's checking scripts (`.kit/tools/`) and the manifest of kit-managed files (`.kit/manifest.json`) |

**Kit ADRs:** "ADR-NNNN" inside a kit-managed file (`docs/standards/`, the skills, the reviewer, the kit sections of this file) means the kit's ADR, at https://github.com/DerekFoulk/dotnet-agent-kit/tree/{{KitCommit}}/docs/adr. This app's own ADRs are in `docs/adr/`. Likewise, a path under `tools/` or `sample/` in `docs/standards/` describes how the kit enforces a rule in its own repo; this repo's commands are the Commands table above.

**Kit-managed files, don't edit:** every file listed in `.kit/manifest.json`, and this file between `kit:begin` and `kit:end`. With each kit release, Dependabot opens a PR that moves the kit pin, and `.github/workflows/kit-sync.yml` adds the release's other kit-managed files to it, merging the kit's changes into any edit this app made and commenting each file that needs a look (kit ADR-0044, ADR-0045). To change one for good, change the kit.

**Generated files, don't edit:** `.github/copilot-instructions.md`, `.claude/rules/` and `.github/instructions/`. After editing this file, run `./.kit/tools/Build-AgentRules.ps1 -RepoRoot .` and commit both.

## Done means

- The build has zero warnings and every test passes.
- Every check passes: the coverage gate, ADR sections, and generated files current.
- Docs and ADRs are updated in the same PR.
- The `reviewer` agent has reviewed the change, and its findings are fixed or answered.
- The PR uses `.github/pull_request_template.md`, including the red→green evidence table. A PR whose description a bot writes gets DOD-006's comment instead.

<!-- kit:end -->

## This app

What {{Name}} is, who uses it, and anything an agent must know that the kit doesn't say. This section is yours; the kit never changes it.
