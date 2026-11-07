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

`tools/Export-KitApp.ps1` checks the commit out into a temporary `git worktree` and copies from there. Kit files go across unchanged; the app's own files (AGENTS.md, THIRD-PARTY-NOTICES.md, README, solution, CI callers, Dependabot config) render from `templates/app/`, pinned to the commit. The checking scripts go to `.kit/tools/`. `.kit/manifest.json` lists every kit-managed file with its SHA-256.

- **Trade-offs:** An uncommitted edit in the kit can't reach an app, and the files have the pinned commit's content. Their line endings follow the exporting clone's settings, as any checkout's do, so the manifest hashes each file's text with LF line endings, the same on every machine. The manifest tells the sync job what it may replace and whether someone edited it. A second copy of the scripts lives in each app, kept in step by the sync job. Templates add a folder to maintain.
- **Reversibility:** Easy before D3 ships: nothing reads the layout yet. After that, a layout change needs a sync-job migration.
- **Risk:** Low. Pester tests compare the export with a clean checkout, check that the app's own checks pass on it, and check the hashes against the LF form of each file. The tests run on Windows; an export on Linux hasn't been tried.

### Option 2: Copy from the kit's working tree

- **Trade-offs:** Simpler, with no worktree. But an unfinished local edit would ship into an app, under a pin that says it came from a commit.
- **Reversibility:** Easy.
- **Risk:** Medium: an app could carry files no kit version has.

### Option 3: A GitHub template repository or a `dotnet new` template package

- **Trade-offs:** Familiar tools. But a template repo has no version pin or manifest for the sync job, and a template package means publishing and versioning a package for a private method.
- **Reversibility:** Medium.
- **Risk:** Medium: drift between the template and the kit, the problem the sync job exists to solve.

## Recommendation

Option 1: the pin, the files and the manifest all name the same commit, which the sync job needs.

## Decision

Accepted (owner, 2026-11-05: approved the D2 plan, with D2a writing the files offline and D2b creating the GitHub repo; apps public or private, private by default). ADR-0033 later made public the default (owner, 2026-11-07).

## Consequences

- Who owns each file, recorded in `.kit/manifest.json`:
  - **Kit:** the build files, agent files, skills, reviewer, standards, hook, PR template, ADR template, the CI callers, `.kit/tools/`, and the generated rule files (`.claude/rules/`, `.github/instructions/`). The sync job replaces them.
  - **A kit block:** in `AGENTS.md` and `THIRD-PARTY-NOTICES.md`, the text between `kit:begin` and `kit:end` is the kit's, hashed on its own. The rest is the app's: its own notes, and the notices for licensed work it adopts.
  - **App:** `README.md`, the solution, `docs/corrections-log.md`, `Directory.Packages.props` and `.github/dependabot.yml`, never touched by the sync job. `.github/copilot-instructions.md` copies the app's AGENTS.md, so it's regenerated rather than synced.
- The app's Dependabot config lists only NuGet: the sync job moves the kit pin and the `global.json` SDK pin with each kit release, so Dependabot doesn't propose edits to kit-managed files. An app's SDK moves when the kit's does.
- Still kit-managed in v0.1, though an app may want to add to them: `global.json`, `.gitignore` and `.claude/settings.json`. The sync job (PR D3) decides how an app adds its own lines, for example with a kit block.
- Each manifest hash is the SHA-256 of the file's decoded text, with CRLF changed to LF, encoded as UTF-8 without a byte-order mark. The text is decoded as .NET's `File.ReadAllText` does: UTF-8 unless a byte-order mark says otherwise, the mark dropped, and invalid bytes replaced (U+FFFD); every kit file is UTF-8 text today. For a kit block, the hash is of the text from `<!-- kit:begin` to `<!-- kit:end -->` inclusive. git stores text as LF while a checkout may give CRLF, so this is the same on every checkout, and the sync job must compute it the same way.
- The version label in the manifest and the CI pin comments comes only from a release tag that points to the commit, otherwise `unreleased`, since a pin is trusted only when a release tag points to it (ADR-0031).
- The export refuses a destination that isn't empty, a name that isn't a dotted .NET name (`Contoso.Orders`) or that contains a Windows device name (`Con`, `Nul`, `Com1`), and a ref that isn't a commit or tag, before writing anything. A failure partway removes what the run wrote.
- Apps don't get the kit's `dependabot-lockfiles.yml`. Whether an app's Dependabot NuGet PRs pass locked restore without it isn't tested yet. D2b's end-to-end app has no projects, so no lock files, and can't show it; the first app with a project will.
- `Directory.Packages.props` keeps the kit's build and test toolset and drops the `ItemGroup` labelled `Sample app` (MSBuild's `Label` attribute "identifies the `ItemGroup`" and changes nothing in the build).
- Files copied into apps must work there. The commit-msg hook looks in `.kit/tools/` before `tools/`; the skills and reviewer run the checks in AGENTS.md's Commands table instead of naming kit paths (`tools/tests/AgentFiles.Tests.ps1` checks this); `.claude/settings.json` allows running `./.kit/tools/*`.
- A kit ADR number inside a kit-managed file means the kit's ADR; the app's AGENTS.md links them at the pinned commit. An app numbers its own ADRs from 0001.
- D2b (`New-KitApp`) calls the export, then creates the GitHub repo, its settings and its ruleset. It must commit `.githooks/commit-msg` as executable (`git add --chmod=+x`): Windows doesn't record the bit, and git on Linux and macOS ignores a hook without it. D3 reads the manifest. ADR-0033 records how D2b does this.

## Pillars affected

Reliability: an app's files match its kit pin exactly, and its own checks pass from the first commit. Security: nothing uncommitted reaches an app, and the manifest exposes edits to kit-managed files. Operational Excellence: one command creates an app, and the manifest makes later syncs mechanical. Cost Optimization and Performance Efficiency: not affected.

## Sources

- owner, 2026-11-05
- https://learn.microsoft.com/visualstudio/msbuild/itemgroup-element-msbuild, retrieved 2026-11-06
