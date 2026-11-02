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
| `AGENTS.md` | Claude Code (through `CLAUDE.md`), VS Code, the Copilot coding agent | Hand |
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

## Run the tests

```powershell
Invoke-Pester -Path ./tools/tests
```

`tools/tests/BuildConfig.Tests.ps1` copies the root build config (`global.json`, `Directory.*.props`, `.editorconfig`, `nuget.config`) into isolated workspaces and builds small fixture projects against it. It proves that clean code builds with a MinVer version and a lock file, and that `var`, nullable violations and `latest-all` analyzer findings fail the build.
