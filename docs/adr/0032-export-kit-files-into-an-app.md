# ADR-0032: Export the kit's files into a new app from one kit commit

- **Status:** Accepted
- **Date:** 2026-11-06

## Context

`New-KitApp` (PR D2) gives each new app repo the kit's rules, checks and agent files, wired to the kit's shared CI, with no projects (ADR-0030, ADR-0031; owner, 2026-11-05: "Option 3", kit-wired with no projects). The owner approved splitting it in two: D2a writes the files offline, D2b creates the GitHub repo and its settings.

D2a has to settle:

- where the files come from, so an app pinned to a kit version has exactly that version's files;
- which files the kit keeps managing (the sync job, PR D3, replaces them) and which become the app's;
- how an app's agents and commit hook run the kit's scripts locally, since CI fetches them through the `kit-tools` action and an app has no `tools/` of its own;
- how the app starts with central package versions without the kit's sample-app packages.

## Options

### Option 1: Export from a clean checkout of one commit, with templates and a manifest

`tools/Export-KitApp.ps1` checks the commit out into a temporary `git worktree` and copies from there. Kit files go across unchanged; the app's own files (AGENTS.md, README, solution, CI callers, Dependabot config) render from `templates/app/`, pinned to the commit. The checking scripts go to `.kit/tools/`. `.kit/manifest.json` lists every kit-managed file with its SHA-256.

- **Trade-offs:** An uncommitted edit in the kit can't reach an app, and the files match the pin byte for byte. The manifest tells the sync job what it may replace and whether someone edited it. A second copy of the scripts lives in each app, kept in step by the sync job. Templates add a folder to maintain.
- **Reversibility:** Easy before D3 ships: nothing reads the layout yet. After that, a layout change needs a sync-job migration.
- **Risk:** Low. Pester tests compare the export with a clean checkout, and check that the app's own checks pass on it.

### Option 2: Copy from the kit's working tree

- **Trade-offs:** Simpler, with no worktree. But an unfinished local edit would ship into an app, and line endings depend on the clone's settings.
- **Reversibility:** Easy.
- **Risk:** Medium: an app could carry files no kit version has.

### Option 3: A GitHub template repository or a `dotnet new` template package

- **Trade-offs:** Familiar tools. But a template repo has no version pin or manifest for the sync job, and a template package means publishing and versioning a package for a private method.
- **Reversibility:** Medium.
- **Risk:** Medium: drift between the template and the kit, the problem the sync job exists to solve.

## Recommendation

Option 1: the pin, the files and the manifest all name the same commit, which the sync job needs.

## Decision

Accepted (owner, 2026-11-05: approved the D2 plan, with D2a writing the files offline and D2b creating the GitHub repo; apps public or private, private by default).

## Consequences

- Who owns each file, recorded in `.kit/manifest.json`:
  - **Kit:** the build files, agent files, skills, reviewer, standards, hook, PR template, ADR template, `THIRD-PARTY-NOTICES.md`, the CI callers, `.github/dependabot.yml`, `.kit/tools/`, and the generated rule files (`.claude/rules/`, `.github/instructions/`). The sync job replaces them.
  - **The kit block of AGENTS.md:** the text between `kit:begin` and `kit:end`, hashed on its own. The rest of the file, under "This app", is the app's.
  - **App:** `README.md`, the solution, `docs/corrections-log.md` and `Directory.Packages.props`, never touched by the sync job. `.github/copilot-instructions.md` copies the app's AGENTS.md, so it's regenerated rather than synced.
- The export refuses a destination that isn't empty and a name that isn't a dotted .NET name (`Contoso.Orders`), before writing anything.
- `Directory.Packages.props` keeps the kit's build and test toolset and drops the `ItemGroup` labelled `Sample app` (MSBuild's `Label` attribute "identifies the `ItemGroup`" and changes nothing in the build).
- Files copied into apps must work there. The commit-msg hook looks in `.kit/tools/` before `tools/`; the skills and reviewer run the checks in AGENTS.md's Commands table instead of naming kit paths (`tools/tests/AgentFiles.Tests.ps1` checks this); `.claude/settings.json` allows running `./.kit/tools/*`.
- A kit ADR number inside a kit-managed file means the kit's ADR; the app's AGENTS.md links them at the pinned commit. An app numbers its own ADRs from 0001.
- D2b (`New-KitApp`) calls the export, then creates the GitHub repo, its settings and its ruleset. D3 reads the manifest.

## Pillars affected

Reliability: an app's files match its kit pin exactly, and its own checks pass from the first commit. Security: nothing uncommitted reaches an app, and the manifest exposes edits to kit-managed files. Operational Excellence: one command creates an app, and the manifest makes later syncs mechanical. Cost Optimization and Performance Efficiency: not affected.

## Sources

- owner, 2026-11-05
- https://learn.microsoft.com/visualstudio/msbuild/itemgroup-element-msbuild, retrieved 2026-11-06
