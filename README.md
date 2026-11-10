# dotnet-agent-kit

A versioned, vendor-neutral engineering method for .NET: rules, enforcement, agent instructions, workflow and templates, so any repo gets the same quality bar from any supported coding agent.

Work in progress (v0.1).

This repo is public so its CI, and the CI of any public app that uses it, runs free (ADR-0031). It isn't licensed for reuse: all rights reserved. A few files are based on the .NET projects' MIT-licensed work; their notices are in `THIRD-PARTY-NOTICES.md`.

## Set up a machine

`tools/Initialize-DevMachine.ps1` checks the whole toolchain and, only when you pass `-Install`, installs what's missing, one tool at a time.

| Tool | Needed for | Required now |
|---|---|---|
| PowerShell 7.6 or later (the current LTS) | Every kit script, and CI | Yes |
| Pester 6 | The kit's script tests | Yes |
| powershell-yaml | Reading rule metadata in `docs/standards` | Yes |
| Git | Everything | Yes |
| GitHub CLI, signed in | Pushing, PRs and reviews | Yes |
| .NET SDK named in `global.json` | Building | Yes |
| Claude Code | Agent sessions | Yes |
| Git commit-msg hook (this clone) | Rejecting non-Conventional commit subjects before they're committed (ADR-0027) | Yes |
| VS Code + PowerShell extension | Running scripts yourself (ISE Mode, D11) | Later |
| Docker | Testcontainers in the sample solution | Later |

**On a new machine**, Git and GitHub CLI come first: you clone, push and open PRs with them. In Windows PowerShell:

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

Then let the script install the rest. It runs in Windows PowerShell 5.1 as well, so it can install PowerShell 7.6 for you, or upgrade an older one:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Initialize-DevMachine.ps1 -Install
```

Add `-WhatIf` first if you want to see the install commands without running them. When the installs finish, open a new PowerShell 7.6 window (`pwsh`) and run the check again until every line says `[ok]`:

```powershell
./tools/Initialize-DevMachine.ps1
```

The exit code is 0 when every required tool is ready and 1 otherwise, so agents and CI can use it as a gate.

## Standards and decisions

- **`docs/standards/`**: one file per topic. Each rule sits in the file's YAML front matter with its `id`, `statement`, `why`, `layer` (floor, owner or outside), `status` (proposed, accepted or retired), `sources` and `enforcement`. A `proposed` rule isn't in force until the owner accepts it.
- **`docs/adr/`**: Architecture Decision Records. ADR numbers match the brief's decision numbers (D8 is ADR-0008). New ones start from `docs/adr/0000-template.md`.
- **`docs/quality/scorecard.md`**: the quality scorecard. It says what a "perfect" .NET app looks like in 14 areas (architecture, tests, security, API design and the rest), which rules cover each area, how many of them a tool checks, and the open gaps, each with an id a later PR can close (ADR-0034).
- **`docs/sources.md`** lists practitioner sources. **`docs/corrections-log.md`** records owner corrections and what each became.

Three checks keep these honest. Each exits 0 when clean and 1 otherwise:

```powershell
./tools/Test-RuleSources.ps1   # every rule has a valid source (owner + date, ADR, or URL + retrieval date) and an enforcement
./tools/Test-Scorecard.ps1     # every rule in force has a quality area, and the scorecard's table matches the rules
./tools/Test-AdrSections.ps1   # every ADR has its required sections and at least two options with trade-offs
```

After changing a rule or a scorecard area, run `./tools/Test-Scorecard.ps1 -Update` to rewrite the table, and commit it.

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
| `.agent-mode`, `.claude/settings.local.json` (gitignored) | Every agent; Claude Code | `Set-AgentMode.ps1` ("Working modes") |
| `.mcp.json`, `.vscode/mcp.json` | Claude Code and Visual Studio; VS Code | Hand |

The generated files carry only **accepted** rules. After editing a standard or `AGENTS.md`, regenerate them and commit the result:

```powershell
./tools/Build-AgentRules.ps1          # regenerate
./tools/Build-AgentRules.ps1 -Check   # exit 1 if any generated file is missing, hand-edited or stale
```

Two things need a one-time step per user:
- **Visual Studio:** it loads the instruction files only when an option is ticked. Microsoft's docs place it under Tools > Options > All Settings > GitHub > Copilot > Copilot Chat: "Enable custom instructions to be loaded from .github/copilot-instructions.md files and added to requests".
- **Claude Code:** it asks once before connecting to the Microsoft Learn server in `.mcp.json`. Its permission allow rules apply only after you trust the folder.

### Working modes

Agents work in **auto** mode unless you switch to **review** (ADR-0035):

| | Auto (the default) | Review |
|---|---|---|
| Plans | The agent posts its plan and builds it | You approve each non-trivial plan first |
| Packages | The agent adds one when the kit's sources name it, and says so in the PR | The agent asks you first |
| CI and repo settings | The agent goes ahead, except for removing or weakening a check, changing a ruleset or the merge settings, or turning off Dependabot alerts or security updates | The agent asks you first |
| Merging | The agent merges its own PR once CI passes and the reviewer's findings are answered, and Dependabot's patch and minor updates of NuGet packages, .NET tools and the SDK (ADR-0041). A PR that changes the guardrails, a major, a 0.x package or Actions bump, and a release PR are yours | You merge, or tell the agent to for that PR |
| "Won't fix" on a review finding | The agent decides, and gives the reason | You decide |

In both modes, the agent asks before:
- anything that costs money or uses cloud resources;
- deleting or rewriting anything;
- creating an app repo, or making something public;
- adding a connector, or installing software;
- changing a ruleset or merge settings, turning off Dependabot alerts or security updates, or weakening a CI check;
- switching the mode;
- anything else that can't be undone.

It never merges a release PR or publishes a release: releases are yours. Secrets and sign-in stay yours. Claude Code prompts for the common forms of these, and the rest rests on the agent's instructions (`AGENTS.md`, "Always ask").

This is the kit's own "auto mode", not Claude Code's permission mode of the same name, which you set in Claude Code itself.

```powershell
./tools/Set-AgentMode.ps1                # show the mode
./tools/Set-AgentMode.ps1 -Mode Review   # you approve plans and merge PRs
./tools/Set-AgentMode.ps1 -Mode Auto     # back to the default
```

The mode is yours alone. Review mode writes `review` to `.agent-mode`, which every agent reads. It also adds the prompts for merging, packages, repo settings and build or CI files to your `.claude/settings.local.json`, which Claude Code combines with `.claude/settings.json`. Both files are gitignored, and auto mode removes what review mode added. If you'd added one of those same prompts to your local settings yourself, auto mode removes it too. The mode belongs to the checkout, so a new git worktree starts in auto: run the script there too. In an app, the script is `./.kit/tools/Set-AgentMode.ps1 -RepoRoot .`.

## CI

`.github/workflows/ci.yml` runs on every pull request and every push to `main`. It calls three reusable workflows that other repos can call once they adopt the kit:

| Workflow | What it checks |
|---|---|
| `dotnet-ci.reusable.yml` | Locked restore with NuGet audit, a zero-warning build (`-warnaserror`), a format check, tests with coverage, the coverage gate (TST-004), and deprecated packages. It also runs a gitleaks secret scan of the full git history |
| `codeql.reusable.yml` | CodeQL code scanning of the GitHub Actions workflows, and of the C# once there is some, with no build (ADR-0036). Results go to the repo's Security tab. In the kit, the ruleset's code scanning rule blocks a merge on its results (see "GitHub settings on this repo") |
| `kit-checks.reusable.yml` | All Pester tests, rule sources, the quality scorecard, ADR sections, generated-file drift, and on pull requests the commit subjects and red→green order (the branch's own commits) |
| `pr-title.yml` | The PR title is a Conventional Commit. It also runs when the PR is edited, because the title becomes the merge commit's subject |

Two more workflows act rather than check:

| Workflow | What it does |
|---|---|
| `release.yml` | On every push to `main`, release-please keeps a release PR open with the next version and its notes; merging that PR tags `vX.Y.Z` (ADR-0022) |
| `dependabot-lockfiles.yml` | On Dependabot's NuGet PRs, refreshes every lock file (Dependabot misses the ones that get a package through a project reference) and pushes them as a `chore(deps)` commit |

Both push with the workflow's own token, so CI on the PR they create or update waits for approval, and they approve it. If a release or Dependabot PR is ever stuck with no checks reporting, close and reopen it: that runs CI as you. Expect the first CI run on each Dependabot NuGet PR to fail locked restore; the lock-file commit replaces it. Once that commit is on the branch, Dependabot may stop rebasing the PR on its own; comment `@dependabot rebase` on it, and the workflow adds the lock files again.

Each action is pinned by commit SHA, and the gitleaks image by digest. `.github/dependabot.yml` keeps NuGet packages, the actions and the `global.json` SDK pin current; bump the gitleaks image by hand. Dependabot waits 7 days before proposing a version (its own default is 3), and 14 for a NuGet or SDK major (by the first number, as SemVer counts it); security updates, which are on, don't wait. In auto mode an agent merges its patch and minor updates of NuGet packages, .NET tools and the SDK; majors, any update of a 0.x package, and Actions bumps are the owner's (ADR-0041). The "main protection" ruleset on GitHub requires a pull request and these checks to pass ("dotnet / Build, test and package checks", "dotnet / Secret scan (gitleaks)", "kit / Kit checks", "PR title"). It allows merge commits only, and blocks force-pushes and deletion of `main`. It doesn't require a branch to be up to date with `main` before merging, so the merge result itself isn't re-tested; with merge commits that's a deliberate trade against rebuilding after every merge.

### Using the kit's CI from an app repo

An app repo, public or private, calls the kit's shared workflows. Its CI doesn't use the copy of the checking scripts the app keeps in `.kit/tools/` for local runs (below): the shared workflows fetch the kit's scripts through the `kit-tools` action (`uses: $/.github/actions/kit-tools`), which GitHub downloads at the shared workflow's own commit, so an app pinned to a version runs that version's scripts (`spikes/kit-sharing/README.md`, ADR-0030). The kit is public (ADR-0031), so no access setting or token is involved. Each repo pays for its own CI minutes: a public app's runs are free, while a private app's count against its owner's included Actions usage.

The kit's repo name must stay as it is once an app pins it: GitHub doesn't redirect calls to an action in a renamed repo (and very likely not to its reusable workflows), so every app's CI would fail with "repository not found".

Trust a pin only when a kit release tag points to that SHA. In a public repo, a SHA from someone's fork can also resolve ([GitHub's guidance](https://docs.github.com/en/actions/reference/security/secure-use): "verify it is from the action's repository and not a repository fork"), so check it: `gh api repos/DerekFoulk/dotnet-agent-kit/commits/v0.1.0 --jq .sha` prints the commit the tag points to (ADR-0031).

Pin the kit like any other action (SUP-008): by the full commit SHA of a kit release, with the version in a comment. `v0.1.0` is the first release, once release PR 10 merges; until then there's no tag to pin. Two small caller workflows keep a renamed PR from rebuilding the whole app:

```yaml
# .github/workflows/ci.yml in an app repo: the .NET gates
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  dotnet:
    uses: DerekFoulk/dotnet-agent-kit/.github/workflows/dotnet-ci.reusable.yml@<commit SHA> # v0.1.0
    with:
      solution: MyApp.slnx
  codeql:
    if: ${{ !github.event.repository.private }} # code scanning needs a paid licence on a private repo
    permissions:
      contents: read
      security-events: write
    uses: DerekFoulk/dotnet-agent-kit/.github/workflows/codeql.reusable.yml@<commit SHA> # v0.1.0
```

```yaml
# .github/workflows/app-checks.yml in an app repo: also runs when the PR is edited
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  app:
    uses: DerekFoulk/dotnet-agent-kit/.github/workflows/app-checks.reusable.yml@<commit SHA> # v0.1.0
```

| Shared workflow | What it checks in the app |
|---|---|
| `dotnet-ci.reusable.yml` | Restore, build, format, tests with coverage, the coverage gate, deprecated packages, and the secret scan. `solution` is required |
| `codeql.reusable.yml` | CodeQL code scanning of the workflows, and the C# once there is some. Skipped on a private app |
| `app-checks.reusable.yml` | On pull requests: the PR title, the commit subjects and red→green order. Always: ADR sections, when the app has `docs/adr`. Called from any other event, it fails rather than pass having checked nothing |

The gates assume the app has the kit's build files: `global.json` (SDK pin and the Microsoft Testing Platform runner), `Directory.Build.props` (warnings as errors, analyzers, lock files, NuGet audit), `Directory.Packages.props`, `.editorconfig` (with `THIRD-PARTY-NOTICES.md`, which carries its MIT notices), and a committed `packages.lock.json` per project. Without them, "locked restore" has no lock files to enforce. `New-KitApp` (PR D2) creates them, and the sync job (PR D3) keeps them current.

### Create an app repo's files

`tools/Export-KitApp.ps1` writes a new app's files into an empty folder, taken from the kit at one commit or tag (ADR-0032). `tools/New-KitApp.ps1` calls it and then creates the GitHub repo (see "Start a new app" below).

```powershell
./tools/Export-KitApp.ps1 -Name Contoso.Orders -Destination ../Contoso.Orders -KitRef v0.1.0
```

- The files come from a clean checkout of `-KitRef` (a temporary git worktree), never from your working tree, so an uncommitted edit can't reach an app.
- The app gets the kit's build files, agent files, skills, reviewer, standards and commit hook unchanged; the checking scripts in `.kit/tools/`; and its own `AGENTS.md`, `THIRD-PARTY-NOTICES.md`, `README.md`, `<Name>.slnx` (no projects yet), CI callers pinned to the kit commit, and a NuGet-only `.github/dependabot.yml`, rendered from `templates/app/`. Its agent rule files are generated during the export.
- `Directory.Packages.props` keeps the kit's build and test packages and drops the ones in the `ItemGroup` labelled `Sample app`.
- `.kit/manifest.json` records the kit version (the release tag on the commit, or `unreleased`) and commit, and the SHA-256 of every file the kit manages, taken over the text with LF line endings so it's the same on every checkout. The sync job (PR D3) uses it to know what it may replace. In `AGENTS.md` and `THIRD-PARTY-NOTICES.md`, only the block between `kit:begin` and `kit:end` is the kit's.
- It refuses a folder that isn't empty, a name that isn't a dotted .NET name (or contains a Windows device name such as `Con`), and a ref that isn't a commit or tag, before writing anything. If it fails partway, it removes what it wrote.

### Start a new app

`tools/New-KitApp.ps1` creates an app repo on your own GitHub account, with the kit's files, settings and ruleset, using your existing `gh` sign-in (ADR-0033). Try it with `-WhatIf` first: it runs the checks and lists the steps, and changes nothing.

```powershell
./tools/New-KitApp.ps1 -Name Contoso.Orders -WhatIf
./tools/New-KitApp.ps1 -Name Contoso.Orders
```

| Parameter | Default |
|---|---|
| `-RepoName` | The app name. Set it for a repo name a .NET namespace can't have, such as `contoso-orders` (GitHub allows letters, digits, `-`, `_` and `.`) |
| `-KitRef` | The kit's newest release tag (`vX.Y.Z`). Until one exists, pass a kit commit or tag |
| `-Destination` | A folder named after the repo, next to the kit's folder |
| `-Private` | Off: the repo is public, so its CI runs free on GitHub's standard runners (ADR-0033). Anyone can read a public app's code, history and PRs; with no license, nobody may reuse them. On GitHub Free, rulesets work only on public repos, so a private repo's ruleset may not hold; and whether a public app's holds isn't verified either, since it's added while the repo is still private. `New-KitApp` may then report success while `main` is unprotected, so on a new account, try a direct push to `main` in its first app (ADR-0033) |

The app name (`-Name`) must be a dotted .NET name, because it becomes the solution's name and the root namespace, which can't contain hyphens.

It checks first, before changing anything: the app and repo names, an empty folder, the kit ref (which must have `templates/github`), that `gh` is signed in, and that the repo doesn't exist yet. Then, in order:

1. Exports the files (`Export-KitApp`).
2. Makes the first commit, `chore: start from dotnet-agent-kit <version>`, with the commit hook stored as executable for Linux and macOS.
3. Creates the repo, private for now, with the kit's merge settings (`templates/github/repo.json`): merge commits only, titled with the PR title and an empty body, branches deleted after merging, no wiki.
4. Pushes `main`.
5. Adds the "main protection" ruleset (`templates/github/main-protection.json`), after the push so it doesn't reject it. It requires `dotnet / Build, test and package checks`, `dotnet / Secret scan (gitleaks)` and `app / App checks`.
6. Turns on Dependabot alerts and security updates, so a known vulnerability gets its fix PR without waiting for the cooldown (ADR-0041). Turning alerts on also turns on the dependency graph, private repos included.
7. Unless `-Private` is set: makes it public only now, so a failure before this leaves a private repo, then turns on secret scanning and push protection, and requires approval before any fork's PR runs (`templates/github/public.json`). Set "only collaborators can open issues" yourself in the repo's settings; GitHub has no API for it.
8. Turns the commit hook on in the local copy.

If a step fails, it stops and says what's done and what's left, and whether the repo or the folder is kept. It never deletes a repo. Claude Code asks before running it.

### GitHub settings on this repo

Applied 2026-11-06 with the owner's OK, after the repo went public:

| Setting | Value | Why |
|---|---|---|
| Secret scanning, push protection | On | Free on public repos (ADR-0031); gitleaks stays the required check |
| Approval for running fork pull request workflows from contributors | Require approval for all external contributors | A fork's PR runs nothing until the owner approves it (ADR-0031) |
| Issues | Only collaborators can open them (set by the owner in the browser; GitHub documents no API for it) | The repo isn't open for outside contributions |
| Pull requests | Anyone can open them (unchanged) | Left open so Dependabot and release-please keep opening PRs; fork PRs still wait for approval |
| Wiki | Off | Until it's published from the repo (planned after D2a) |
| Dependabot security updates | Off (unchanged); turned on 2026-11-09, see below | Reviewed 2026-11-09: the cooldown on version updates relies on them (ADR-0041) |

Applied 2026-11-09 with the owner's OK:

| Setting | Value | Why |
|---|---|---|
| Actions: require actions pinned to a full-length commit SHA | On | Enforces SUP-008. The shared workflows' `$/.github/actions/kit-tools` resolves to a full SHA, so it passes |
| "main protection" ruleset: require code scanning results | CodeQL; blocks on an alert of severity error, or a security alert high or higher, on lines the pull request changes, or while CodeQL's analysis is in progress or missing | Enforces SEC-006 at merge time; CodeQL runs on every pull request |
| "main protection" ruleset: require conversation resolution | On | Every review thread is resolved before merging; that each one was answered with evidence (DOD-005) is still the agents' and the reviewer's job |
| Dependabot alerts and security updates | On | A known vulnerability gets its fix PR at once, without the 7- and 14-day wait version updates have (ADR-0041); New-KitApp turns both on for every app |

## Run the tests

```powershell
Invoke-Pester -Path ./tools/tests
```

`tools/tests/BuildConfig.Tests.ps1` copies the root build config (`global.json`, `Directory.*.props`, `.editorconfig`, `nuget.config`) into isolated workspaces and builds small fixture projects against it. It proves that clean code builds with a MinVer version and a lock file, and that `var`, nullable violations and `latest-all` analyzer findings fail the build.
