# dotnet-agent-kit

A versioned, vendor-neutral engineering method for .NET: rules, enforcement, agent instructions, workflow and templates, so any repo gets the same quality bar from any supported coding agent.

Work in progress (v0.1).

## Set up a machine

`tools/Initialize-DevMachine.ps1` checks the whole toolchain and, only when you pass `-Install`, installs what's missing, one tool at a time.

| Tool | Needed for | Required now |
|---|---|---|
| PowerShell 7 | Every kit script, and CI | Yes |
| Pester 6 | The kit's script tests | Yes |
| powershell-yaml | Reading rule metadata in `docs/standards` | Yes |
| Git | Everything | Yes |
| GitHub CLI, signed in | Cloning this private repo, PRs | Yes |
| .NET SDK named in `global.json` | Building | Yes |
| Claude Code | Agent sessions | Yes |
| Git commit-msg hook (this clone) | Rejecting non-Conventional commit subjects before they're committed (ADR-0027) | Yes |
| VS Code + PowerShell extension | Running scripts yourself (ISE Mode, D11) | Later |
| Docker | Testcontainers in the sample solution | Later |

**On a new machine**, the repo is private, so Git and GitHub CLI come first. In Windows PowerShell:

```powershell
winget install --id Git.Git --exact
winget install --id GitHub.cli --exact
```

Open a new PowerShell window so both are on PATH, then sign in to GitHub and clone the repo. Sign-in is always yours to do; no script handles credentials.

```powershell
gh auth login
gh repo clone DerekFoulk/dotnet-agent-kit "$env:USERPROFILE\source\repos\DerekFoulk\dotnet-agent-kit"
cd "$env:USERPROFILE\source\repos\DerekFoulk\dotnet-agent-kit"
```

Then let the script install the rest. It runs in Windows PowerShell 5.1 as well, so it can install PowerShell 7 for you:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Initialize-DevMachine.ps1 -Install
```

Add `-WhatIf` first if you want to see the install commands without running them. When the installs finish, open a new PowerShell 7 window (`pwsh`) and run the check again until every line says `[ok]`:

```powershell
./tools/Initialize-DevMachine.ps1
```

The exit code is 0 when every required tool is ready and 1 otherwise, so agents and CI can use it as a gate.

## Standards and decisions

- **`docs/standards/`**: one file per topic. Each rule sits in the file's YAML front matter with its `id`, `statement`, `why`, `layer` (floor, owner or outside), `status` (proposed, accepted or retired), `sources` and `enforcement`. A `proposed` rule isn't in force until the owner accepts it.
- **`docs/adr/`**: Architecture Decision Records. ADR numbers match the brief's decision numbers (D8 is ADR-0008). New ones start from `docs/adr/0000-template.md`.
- **`docs/sources.md`** lists practitioner sources. **`docs/corrections-log.md`** records owner corrections and what each became.

Two checks keep these honest. Each exits 0 when clean and 1 otherwise:

```powershell
./tools/Test-RuleSources.ps1   # every rule has a valid source (owner + date, ADR, or URL + retrieval date) and an enforcement
./tools/Test-AdrSections.ps1   # every ADR has its required sections and at least two options with trade-offs
```

## Agent layer

| File | Read by | Written by |
|---|---|---|
| `AGENTS.md` | Claude Code (through `CLAUDE.md`), the Copilot coding agent. VS Code can read it too, but this repo turns that off (`.vscode/settings.json`) because VS Code already gets the same text from `.github/copilot-instructions.md` | Hand |
| `CLAUDE.md` | Claude Code; imports `AGENTS.md` | Hand |
| `.github/copilot-instructions.md` | Visual Studio, VS Code, Copilot on GitHub | Generated copy of `AGENTS.md` |
| `.claude/rules/*.md` | Claude Code (and VS Code Claude sessions), loaded by path | Generated from `docs/standards` |
| `.github/instructions/*.instructions.md` | Copilot, loaded by `applyTo` | Generated from `docs/standards` |
| `.claude/skills/*/SKILL.md` | Claude Code, Visual Studio, VS Code | Hand |
| `.claude/agents/reviewer.md` | Claude Code | Hand |
| `.claude/settings.json` | Claude Code: permissions | Hand, owner-approved |
| `.mcp.json`, `.vscode/mcp.json` | Claude Code and Visual Studio; VS Code | Hand |

The generated files carry only **accepted** rules. After editing a standard or `AGENTS.md`, regenerate them and commit the result:

```powershell
./tools/Build-AgentRules.ps1          # regenerate
./tools/Build-AgentRules.ps1 -Check   # exit 1 if any generated file is missing, hand-edited or stale
```

Two things need a one-time step per user:
- **Visual Studio:** it loads the instruction files only when an option is ticked. Microsoft's docs place it under Tools > Options > All Settings > GitHub > Copilot > Copilot Chat: "Enable custom instructions to be loaded from .github/copilot-instructions.md files and added to requests".
- **Claude Code:** it asks once before connecting to the Microsoft Learn server in `.mcp.json`. Its permission allow rules apply only after you trust the folder.

## CI

`.github/workflows/ci.yml` runs on every pull request and every push to `main`. It calls two reusable workflows that other repos can call once they adopt the kit:

| Workflow | What it checks |
|---|---|
| `dotnet-ci.reusable.yml` | Locked restore with NuGet audit, a zero-warning build (`-warnaserror`), a format check, tests with coverage, the coverage gate (TST-004), and deprecated packages. It also runs a gitleaks secret scan of the full git history |
| `kit-checks.reusable.yml` | All Pester tests, rule sources, ADR sections, generated-file drift, and on pull requests the commit subjects and red→green order (the branch's own commits) |
| `pr-title.yml` | The PR title is a Conventional Commit. It also runs when the PR is edited, because the title becomes the merge commit's subject |

Two more workflows act rather than check:

| Workflow | What it does |
|---|---|
| `release.yml` | On every push to `main`, release-please keeps a release PR open with the next version and its notes; merging that PR tags `vX.Y.Z` (ADR-0022) |
| `dependabot-lockfiles.yml` | On Dependabot's NuGet PRs, refreshes every lock file (Dependabot misses the ones that get a package through a project reference) and pushes them as a `chore(deps)` commit |

Both push with the workflow's own token, so CI on the PR they create or update waits for approval, and they approve it. If a release or Dependabot PR is ever stuck with no checks reporting, close and reopen it: that runs CI as you. Expect the first CI run on each Dependabot NuGet PR to fail locked restore; the lock-file commit replaces it. Once that commit is on the branch, Dependabot may stop rebasing the PR on its own; comment `@dependabot rebase` on it, and the workflow adds the lock files again.

### Using the kit's CI from an app repo

An app repo calls the kit's shared workflows at a kit version tag; nothing from the kit's `tools/` is copied into it. This works while the kit repo stays private: its Actions access setting allows repositories owned by DerekFoulk, and the shared workflows fetch the kit's scripts through the `kit-tools` action (`uses: $/.github/actions/kit-tools`), which GitHub downloads at the shared workflow's own commit with no token (`spikes/kit-sharing/README.md`).

```yaml
# .github/workflows/ci.yml in an app repo
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  dotnet:
    uses: DerekFoulk/dotnet-agent-kit/.github/workflows/dotnet-ci.reusable.yml@v0.1.0
    with:
      solution: MyApp.slnx
  app:
    uses: DerekFoulk/dotnet-agent-kit/.github/workflows/app-checks.reusable.yml@v0.1.0
```

| Shared workflow | What it checks in the app |
|---|---|
| `dotnet-ci.reusable.yml` | The .NET gates and the secret scan above. The app's `global.json` must select Microsoft Testing Platform |
| `app-checks.reusable.yml` | On pull requests: the PR title, the commit subjects and red→green order. Always: ADR sections, when the app has `docs/adr` |

Each action is pinned by commit SHA, and the gitleaks image by digest. `.github/dependabot.yml` keeps NuGet packages, the actions and the `global.json` SDK pin current; bump the gitleaks image by hand. The "main protection" ruleset on GitHub requires a pull request and these checks to pass ("dotnet / Build, test and package checks", "dotnet / Secret scan (gitleaks)", "kit / Kit checks", "PR title"). It allows merge commits only, and blocks force-pushes and deletion of `main`. It doesn't require a branch to be up to date with `main` before merging, so the merge result itself isn't re-tested; with merge commits that's a deliberate trade against rebuilding after every merge.

## Run the tests

```powershell
Invoke-Pester -Path ./tools/tests
```

`tools/tests/BuildConfig.Tests.ps1` copies the root build config (`global.json`, `Directory.*.props`, `.editorconfig`, `nuget.config`) into isolated workspaces and builds small fixture projects against it. It proves that clean code builds with a MinVer version and a lock file, and that `var`, nullable violations and `latest-all` analyzer findings fail the build.
