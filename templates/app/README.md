# {{Name}}

Built with [dotnet-agent-kit](https://github.com/DerekFoulk/dotnet-agent-kit) {{KitVersion}}: its rules, checks and agent instructions apply here. Agents start from `AGENTS.md`.

## Set up a machine

```powershell
./.kit/tools/Initialize-DevMachine.ps1 -RepoRoot .
```

It checks the toolchain (PowerShell 7.6 or later, Git, GitHub CLI, the .NET SDK in `global.json`) and whether the commit-msg hook is on for this clone. Add `-Install` to install what's missing.

## Build and test

```powershell
dotnet build {{Name}}.slnx
dotnet test --solution {{Name}}.slnx
```

The solution starts empty; the first feature adds its projects.

## Releases

`.github/workflows/release.yml` runs release-please on every push to `main`: it keeps a release PR open with the next version and its notes, and merging that PR tags the release. The PR is the owner's to merge. It needs the repo setting "Allow GitHub Actions to create and approve pull requests" (Settings › Actions › General › Workflow permissions), which the kit turned on when it created this repo: release-please opens the release PR with the workflow's own token. What the release job approves is that PR's waiting CI runs, a different permission, never the PR itself. Turning the setting off means giving release-please a GitHub App or personal access token instead, and the kit's shared release job takes no token yet, so it also means changing `release.yml`; until then, no release PR opens. Turn it off before adding required approving reviews, because a workflow could otherwise approve a pull request to meet them. The kit's [ADR-0096](https://github.com/DerekFoulk/dotnet-agent-kit/blob/{{KitCommit}}/docs/adr/0096-apps-release-with-the-kits-release-please-job.md) says what changes and which files.
