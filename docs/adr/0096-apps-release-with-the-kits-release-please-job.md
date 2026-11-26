# ADR-0096: Apps release with the kit's release-please job, versioned by Semantic Versioning 2.0.0

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

The owner, 2026-11-25: "I prefer to strictly adhere to Semantic Versioning 2.0.0 (https://semver.org/). Whatever gets me that... if there's a pre-existing tool, library and/or mechanism of any kind that can reliably set semantic versions automatically in .NET solutions- I'd be interested."

What the kit has:

- The kit releases with release-please (ADR-0022): on every push to `main` it keeps a release PR open with the next version, worked out from the Conventional Commits merged since the last release, and merging that PR tags `vX.Y.Z` and publishes a GitHub Release. Every commit subject and PR title is a Conventional Commit, enforced by the commit hook and CI (GIT-004, ADR-0027), and each merge commit carries its PR's title, so the history holds what release-please needs.
- MinVer stamps every build with the version of the newest `vX.Y.Z` tag (SUP-006, ADR-0019), and every app gets the `Directory.Build.props` that does it.
- But an app gets no release workflow and no release-please config (`templates/app/.github/workflows/`, `tools/Export-KitApp.ps1`). Nothing tags an app, so MinVer gives every app build `0.0.0-alpha.0.<height>`, and an app can't version itself.

What SemVer 2.0.0 asks: "Major version zero (0.y.z) is for initial development. Anything MAY change at any time." and "Version 1.0.0 defines the public API." After 1.0.0, a breaking change bumps the major, a backward-compatible feature the minor, and a fix the patch (items 6 to 8).

How release-please maps Conventional Commits to versions, from its default versioning strategy (`src/versioning-strategies/default.ts`) and its docs:

- A breaking change (`!` or a `BREAKING CHANGE` footer) bumps the major; a `feat` the minor; anything else, such as `fix`, the patch.
- Below 1.0.0, `bump-minor-pre-major: true` makes a breaking change bump the minor instead: the docs say "BREAKING CHANGE only bumps semver minor if version < 1.0.0". The kit sets it, so a breaking change during initial development doesn't jump to 1.0.0 by itself.
- `bump-patch-for-minor-pre-major: true` would also make a `feat` bump only the patch below 1.0.0 ("feat commits bump semver patch instead of minor if version < 1.0.0"). The kit doesn't set it: a new feature is a new minor version, before 1.0.0 as after it.
- With `bump-minor-pre-major` set, release-please never reaches 1.0.0 on its own. Declaring the public API stable is a person's decision. release-please takes it two ways: `"release-as": "1.0.0"` in the config ("manually set next version"), or a `Release-As: 1.0.0` footer on a commit, which its default strategy reads before any bump (`if (releaseAs)`). Every app shares the kit's config (Consequences), so a `release-as` there would force 1.0.0 on every app at its next sync. The kit and each app use the footer instead, on a commit of their own: `git commit --allow-empty -m "chore: release 1.0.0" -m "Release-As: 1.0.0"`, merged through a PR. `tools/tests/ReleaseConfig.Tests.ps1` fails if the config ever holds `release-as`.

So the kit's config is SemVer 2.0.0, strictly: during 0.y.z it bumps the minor for a feature or a breaking change and the patch for a fix, and from 1.0.0 on it follows items 6 to 8.

## Options

### Option 1: release-please for apps, through one shared workflow the kit uses too

The kit's release job moves into `.github/workflows/release-please.reusable.yml`. The kit's `release.yml` calls it locally; every app's `release.yml` (`templates/app/.github/workflows/release.yml`) calls it pinned to the kit's release commit, as its CI does. An app gets the kit's `release-please-config.json` unchanged, and its own `.release-please-manifest.json` at `0.0.0`.

- **Trade-offs:** The tool already proven for the kit, end to end (`spikes/release-please/README.md`), with merge commits (ADR-0022): no new dependency. It decides the next SemVer number from the commits, writes the notes, tags and publishes the release, and keeps a reviewable release PR, so the owner sees the version before it's made. One release job for the kit and every app (CRF-003): a fix to it reaches each app with the kit pin, through Dependabot (ADR-0045). The cost: release-please is a Node tool in a GitHub Action, not a .NET library; and the repo setting "Allow GitHub Actions to create and approve pull requests" must be on, as in the kit (ADR-0022), which `New-KitApp` now sets.
- **Reversibility:** Easy. Delete the app's `release.yml` and config; the tags it made stay valid for MinVer.
- **Risk:** Low. It's the kit's own release path. Not yet run in an app: the first app release proves it there.

### Option 2: Nerdbank.GitVersioning

- **Trade-offs:** A .NET Foundation MSBuild package that stamps assemblies and packages. But its version is "based on an author-defined major.minor version" in `version.json`, plus the git height; it reads no commit messages, so a person still decides every minor and major bump, which isn't the automatic SemVer the owner asked about. It has "No dependency on tags", which replaces MinVer and SUP-006's tag rule, and it makes no release, notes or tag by itself.
- **Reversibility:** Medium: every project's version source changes.
- **Risk:** Medium: two version sources while switching, and SemVer decided by hand.

### Option 3: GitVersion, set to read Conventional Commits

- **Trade-offs:** It "calculates semantic versions from your Git history", and its message patterns (`major-version-bump-message`, `minor-version-bump-message`) can match Conventional Commits; its docs show how. But it only computes the number: tagging the commit is left to you, so a release still needs a workflow that pushes a tag, and notes and GitHub Releases need yet another tool. It would replace MinVer, and its regexes would repeat what release-please already knows about Conventional Commits.
- **Reversibility:** Medium.
- **Risk:** Medium: a hand-written tag step with a write token, and regexes to keep right.

### Option 4: MinVer alone, tags made by hand

- **Trade-offs:** No new file. MinVer only versions from "the latest tag found in the commit history" and, between tags, increments the patch with a height, which is "intended only for ad-hoc internal testing, not for release". Choosing each next number is left to a person reading the history, which is what the owner wants automated.
- **Reversibility:** Easy.
- **Risk:** High that numbers drift from what the commits earn.

## Recommendation

Option 1: release-please already sets SemVer numbers from the kit's Conventional Commits, reliably, and MinVer already builds from its tags; apps only lacked the workflow.

## Decision

The owner set the goal on 2026-11-25 (quoted in Context) and asked for an existing tool. In auto mode the agent chose Option 1, as recommended, since it is the tool the kit already releases with (ADR-0022); the owner can reverse it.

## Consequences

- `.github/workflows/release-please.reusable.yml` holds the release job: release-please, then the step that approves the release PR's waiting CI runs. Its job asks for `contents`, `pull-requests`, `issues` and `actions` write, and each caller's job grants exactly those, with `permissions: {}` at its top (OpenSSF Scorecard's Token-Permissions check, as main's `release.yml` has had since PR 139). The kit's `release.yml` calls it as `./.github/workflows/release-please.reusable.yml`.
- `templates/app/.github/workflows/release.yml` calls it at `{{KitCommit}} # {{KitVersion}}`, like the app's other callers. The kit manages the file. `tools/Export-KitApp.ps1` also copies the kit's `release-please-config.json` unchanged (kit-managed: one release policy, and the sync keeps it current) and renders `templates/app/.release-please-manifest.json`, `{ ".": "0.0.0" }`, as the app's own file: release-please writes each release's version there, so the sync never touches it. With the kit's `initial-version: 0.1.0`, an app's first release is `v0.1.0`, as the kit's is.
- `tools/New-KitApp.ps1` gains a step right after it creates the repo, before the push that starts the first `release.yml` run (review 1: set later, that run's release-please would be refused): `PUT /repos/{owner}/{repo}/actions/permissions/workflow` with `templates/github/workflow-permissions.json`, which lets GitHub Actions create and approve pull requests (release-please opens the release PR with the workflow's own token) and keeps workflow tokens read-only by default. A new repo on a personal account doesn't allow it by default, and GitHub warns that letting Actions approve pull requests "can be a security risk". One setting covers both creating and approving. No kit workflow approves a pull request: the release and kit-sync jobs approve only the waiting CI runs on one known commit, which is a different permission (`actions: write`; ADR-0022, ADR-0031), and the ruleset needs no approving review (ADR-0067). The kit has the same setting (read on 2026-11-25: `default_workflow_permissions: read`, `can_approve_pull_request_reviews: true`). This isn't on the guardrails list in AGENTS.md ("Working modes"). It's a settings change on every new app, so it's listed for the owner on the PR.
- `tools/Sync-KitApp.ps1` needs no change, because its generic rules cover the new files. For an app made before this ADR: it adds `release-please-config.json` (a new kit-managed file, "Added"); it adds `.release-please-manifest.json` when the app lacks it ("AppFileAdded", ADR-0047); and it lists `.github/workflows/release.yml` for a person to add, since a workflow's own token can't write workflows ("WorkflowByHand", ADR-0044). Turning on the Actions setting above in such an app is the owner's step: a workflow's token can't change repo settings.
- An app's release PR is its owner's to merge, as the kit's is: AGENTS.md's rule that agents never merge a release PR reaches apps in the kit block.
- No doc promises a version number for future work any more: each release takes the number its commits earn. ADR-0050, ADR-0078 and ADR-0081 said the kit's move to a .NET tool would be "v0.2.0"; they now say a later release.
- `tools/tests/ReleaseConfig.Tests.ps1` checks the shared workflow, both callers and the config, including that `bump-patch-for-minor-pre-major` stays unset. `tools/tests/Export-KitApp.Tests.ps1` and `tools/tests/New-KitApp.Tests.ps1` check the export and the new step.
- Not verified: that a `Release-As` footer on a PR's own commit is read through a merge commit, as release-please reads the PR's other commits (ADR-0022); and an app's first release end to end (release PR, approved CI runs, tag, MinVer version). The first app release proves it, as the kit's release PR 10 will for the shared workflow in the kit.
- Protecting the `v*` tags release-please makes is a separate change, a tag ruleset, which waits for the owner's yes (ADR-0097).

## Pillars affected

Operational Excellence: every app releases the same way as the kit, with version numbers that follow from its commits and a release PR the owner merges. Reliability: one shared job, proven in the kit, instead of a copy per app. Security: no stored token; one more repo setting on each app, the same one the kit has, with workflow tokens read-only by default. Cost Optimization: about two Linux minutes per push to `main` (release-please, then the approval step's 90-second wait), free on a public app; on a private app they count against the account's included minutes, then cost $0.006 a minute on Linux (GitHub's runner pricing, checked 2026-11-05 for ADR-0031). Performance Efficiency: not affected.

## Sources

- owner, 2026-11-25
- https://semver.org/, retrieved 2026-11-25
- https://github.com/googleapis/release-please/blob/main/docs/customizing.md, retrieved 2026-11-25
- https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md, retrieved 2026-11-25
- https://raw.githubusercontent.com/googleapis/release-please/main/src/versioning-strategies/default.ts, retrieved 2026-11-25 (the bumps, and the `Release-As` footer)
- https://docs.github.com/en/billing/reference/actions-runner-pricing, retrieved 2026-11-05 (ADR-0031)
- https://github.com/dotnet/Nerdbank.GitVersioning, retrieved 2026-11-25
- https://gitversion.net/7.0/docs/reference/version-increments, retrieved 2026-11-25
- https://gitversion.net/7.0/docs/, retrieved 2026-11-25
- https://github.com/adamralph/minver, retrieved 2026-11-25
- https://docs.github.com/en/rest/actions/permissions, retrieved 2026-11-25 (`default_workflow_permissions`, `can_approve_pull_request_reviews`)
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository, retrieved 2026-11-25 (on a personal account's new repo, "workflows are not allowed to create or approve pull requests" by default)
