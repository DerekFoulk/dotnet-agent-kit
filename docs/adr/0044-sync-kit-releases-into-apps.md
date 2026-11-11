# ADR-0044: Sync kit releases into apps with a three-way merge of the app's edits

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

PR D3 is the sync job: when the kit has a newer release than an app's `.kit/manifest.json` records, it brings that release into the app as one pull request (ADR-0012, ADR-0030). ADR-0032 set what it works from: the manifest lists every kit-managed file, and the kit block of `AGENTS.md` and `THIRD-PARTY-NOTICES.md`, with the SHA-256 of the text the kit gave the app. A file whose text no longer has that hash was edited in the app. App-owned files (`README.md`, the solution, `docs/corrections-log.md`, `Directory.Packages.props`, `.github/dependabot.yml`) are never touched; this ADR makes one exception for `Directory.Packages.props` (Consequences). **Amended by ADR-0046 (2026-11-11):** `docs/runbook.md` is app-owned too, and the sync adds a file a release starts every app with, when the app lacks it. ADR-0032's update of 2026-11-09 adds that `.claude/settings.json` must be made again with the new version's tools, not copied.

Three questions are left:

- **Where the new text comes from.** Several kit-managed files aren't copies. The CI callers and the kit block are rendered from `templates/app/` with the app's name, `.claude/settings.json` is filtered by the tools the app gets, and the rule files are generated.
- **What happens to a kit-managed file the app edited.** The app's `AGENTS.md` says not to edit them. Still, ADR-0032 named `global.json`, `.gitignore` and `.claude/settings.json` as files an app may want to add lines to, and left it to D3 to say how. The owner's brief for D3 says an edited file is reported in the PR, never silently overwritten.
- **Which release counts.** ADR-0031 trusts a kit pin only when a release tag in the kit's own repo points to it, and says the sync job must check a pin before moving it.

## Options

### Option 1: Export the app at both versions, then merge each edited file three ways

`tools/Sync-KitApp.ps1` exports the app twice, each time with that version's own `Export-KitApp`: once at the app's kit commit (the base) and once at the release. So every file, rendered, filtered or generated, comes out exactly as that version makes it. For each path in either manifest:

- **Not edited** (its hash is the manifest's): the app gets the release's text, a new path is added, and a dropped path is removed.
- **Edited:** if the kit didn't change it, the app's text stays and needs no look. Otherwise `git merge-file` merges the app's text with the kit's change from base to release. A clean merge is applied and listed for a look. If the changes overlap, or if the rebuilt base doesn't hash to the manifest's value, the app's text stays and is listed as a conflict. No conflict markers are written.
- **The app's choice stands, and is listed:** a kit file the app deleted stays deleted; a dropped file the app edited stays as the app's own; and where the kit adds a path the app already has its own file, the app's file stays.
- **Generated rule files** are rebuilt, never merged. An edit to one is listed as lost, because the next `Build-AgentRules` would lose it anyway, and a deleted one comes back.

The new manifest is the release's, with the kit's hashes. So a file whose edit was kept still shows as edited at the next sync, and is merged again against that release's text. The pull request's description lists every file that needs a look, with what happened and what to do.

- **Trade-offs:** No app edit is lost, and every kit change that doesn't collide with one arrives. This also answers ADR-0032's open point: an app adds its lines to `.gitignore`, `global.json` or `.claude/settings.json` in place, and the sync merges the kit's changes around them. Two exports cost a few seconds per run. Each kit version's `Export-KitApp` must still run, which the sync relies on to rebuild the base; if it can't, the sync stops before changing anything.
- **Reversibility:** Easy. The rule lives in one function (`Get-KitSyncAction`); nothing outside the script depends on it.
- **Risk:** Low. A line-based merge can produce text that's valid line by line but wrong as a whole (for example, JSON with a missing comma), and the PR's CI and its listed "Merged" files are where that shows. A wrong base is refused rather than merged.

### Option 2: Overwrite edited files and list them

- **Trade-offs:** The simplest, and the app always matches the release exactly. But an app's edit is lost unless whoever reviews the PR spots it in the list and restores it by hand, every release. There's also no way for an app to add a line to `.gitignore`.
- **Reversibility:** Easy.
- **Risk:** Medium: a reviewer of a large sync PR misses a reverted edit, and the app silently loses it on merge.

### Option 3: Leave edited files alone and list them

- **Trade-offs:** Safe for the app's text, and simple. But an edited file never gets the kit's changes, even ones that don't touch the edit, so the app drifts from the kit file by file. That's the drift the sync exists to stop.
- **Reversibility:** Easy.
- **Risk:** Medium: a stale `.kit/tools` script or skill beside newer ones it depends on.

## Recommendation

Option 1: it keeps every app edit and delivers every kit change that doesn't collide with one, and it lists the rest for a person to settle.

## Decision

Accepted, in auto mode (ADR-0035): the plan with this rule was posted in the D3 chat on 2026-11-10, and the owner's answer to it chose the route (ADR-0045) without changing the rule. The owner can reverse it, as with any merged change; that means changing `Get-KitSyncAction` alone.

## Consequences

- `tools/Sync-KitApp.ps1 -AppRoot <app> -KitRoot <kit clone with tags> [-KitRef <vX.Y.Z>] -ReportPath <file>` does the file work. Without `-KitRef`, the release is the one the app's workflows pin the kit to, which Dependabot moves (ADR-0045). It refuses, before changing anything:
  - a ref that isn't a release tag (`vX.Y.Z`) in the kit clone;
  - pins that disagree, or that no release tag points to (ADR-0031);
  - a release that doesn't come after the app's kit commit, so a sync never goes back;
  - a manifest that's missing, has no `appName`, names no full commit SHA, or lists a path outside the app (its paths decide what the sync deletes).

  When the app is already at the release, it changes nothing and writes no report.
- The sync never writes `.github/workflows/`: Dependabot moves the kit pin there, and a workflow's own token can't push a workflow change (ADR-0045). A release that adds, changes or removes a workflow beyond its pin lists it as "WorkflowByHand", for a person to apply on the PR's branch. A workflow whose only kit change is the pin needs nothing, even if the app edited it.
- It runs only the kit's own scripts (its exports, and its own `Build-AgentRules` for the generated files), never the app's `.kit/tools`, so the job that holds a write token runs no code from the app's repo.
- `.kit/manifest.json` gains `appName`, the name the app was made with: the sync renders the app's files again under it. An app made before this ADR needs it added by hand.
- The app's `AGENTS.md` names its kit version inside the kit block, so each sync updates that line.
- `Export-KitApp.ps1` keeps the kit block pattern and the folders of generated rule files in one place each, `$KitBlockPattern` and `$GeneratedFolders`, which the sync reads.
- A sync that changes the app's guardrails (its `AGENTS.md` "Working modes" or "Always ask", `.claude/settings.json`, the `finish-work` skill or the `reviewer` agent) is the owner's to merge, as any guardrail change is. Most will.
- `Directory.Packages.props` stays the app's, with one exception: a kit file can need a package, such as an analyzer for `BannedSymbols.txt`. So the sync adds each `PackageVersion` and `GlobalPackageReference` that the release's export adds, compared with the base export, and that the app's file lacks. They go in an `ItemGroup` labelled `dotnet-agent-kit`, and the PR lists them. It never changes or removes the app's entries, so a package the app removed or re-versioned stays as the app has it. A package the app lists in the other form (a `PackageVersion` where the kit has a `GlobalPackageReference`, or the reverse) isn't added, since NuGet rejects one listed both ways; the PR lists it instead. The sync runs no restore, so the PR says to refresh the lock files (`dotnet restore --force-evaluate`); automating that is a follow-up.
- How the sync reaches an app as a pull request is ADR-0045.
- Not in scope: applying `templates/github/` settings and rulesets to an existing app, which needs an admin token (ADR-0033).

## Pillars affected

- **Reliability:** each version exports its own files, so the sync reproduces exactly what a new app at the release gets. It's idempotent: a second run for the same release changes nothing. And it never goes back to an earlier kit.
- **Security:** only a release tag in the kit's own repo is trusted, and the PR tells the reviewer how to check the pin. No app text is lost or merged with an unproven base.
- **Operational Excellence:** one PR per release, with a list of what needs a person.
- **Cost Optimization and Performance Efficiency:** two exports take seconds.

## Sources

- owner, 2026-11-10 (the D3 brief: an edited kit-managed file is reported in the PR, not silently overwritten)
- https://git-scm.com/docs/git-merge-file, retrieved 2026-11-10
