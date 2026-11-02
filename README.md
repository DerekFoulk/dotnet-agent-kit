# dotnet-agent-kit

A versioned, vendor-neutral engineering method for .NET: rules, enforcement, agent instructions, workflow and templates, so any repo gets the same quality bar from any supported coding agent.

Work in progress (v0.1).

## Set up a machine

`tools/Initialize-DevMachine.ps1` checks the whole toolchain and, only when you pass `-Install`, installs what's missing, one tool at a time.

| Tool | Needed for | Required now |
|---|---|---|
| PowerShell 7 | Every kit script, and CI | Yes |
| Pester 6 | The kit's script tests | Yes |
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

## Run the tests

```powershell
Invoke-Pester -Path ./tools/tests
```

`tools/tests/BuildConfig.Tests.ps1` copies the root build config (`global.json`, `Directory.*.props`, `.editorconfig`, `nuget.config`) into isolated workspaces and builds small fixture projects against it. It proves that clean code builds with a MinVer version and a lock file, and that `var`, nullable violations and `latest-all` analyzer findings fail the build.
