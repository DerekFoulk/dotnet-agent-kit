# ADR-0097: Protect release tags with a "release tags" ruleset that lets release-please create them

- **Status:** Accepted
- **Date:** 2026-11-25

## Context

A release is a `vX.Y.Z` tag. MinVer builds every version from it (SUP-006, ADR-0019), and an app's pin of the kit is trusted only when a kit release tag points to that SHA (ADR-0031). Anyone with write access can move or delete a tag today, including an agent working under the owner's `gh` sign-in. A moved tag changes what a released version is, and a moved kit tag makes an app trust a commit that was never released. The owner, 2026-11-25: "Yes, protect v* tags".

release-please must still create each new tag. It does so through the Releases API: release-please's `github-api.ts` calls `repos.createRelease` with `tag_name` and `target_commitish`, and GitHub creates the tag "from" the commitish when it doesn't exist. It never moves or deletes a tag unless asked to (`force-tag-creation` only creates one, and ignores one that exists). It runs with the workflow's own `GITHUB_TOKEN` (ADR-0022, ADR-0096).

What GitHub offers, from its docs (2026-11-25):

- Rulesets "target branches or tags in a repository" (`"target": "tag"`), and are available "in public repositories with GitHub Free" (the availability note ADR-0033 cites).
- The rules a tag ruleset can hold include "Restrict creations" (`creation`: "only users with bypass permissions can create branches or tags"), "Restrict updates" (`update`: "only users with bypass permissions can push to branches or tags") and "Restrict deletions" (`deletion`: "only users with bypass permissions can delete branches or tags"). The REST docs describe `update` as "Only allow users with bypass permission to update matching refs". The kit reads these as three separate events on a ref, so that creating a new tag is a creation, not an update; the docs don't say so in as many words (not verified).
- Bypass actors are set per ruleset, not per rule (`bypass_actors`, with `actor_type` Integration, RepositoryRole, Team, DeployKey, User or OrganizationAdmin, and `bypass_mode` always, pull_request or exempt). There's no bypass for creation alone.
- The older "tag protection rules" are gone: GitHub sunset them in 2024 and moved them into rulesets, and the old docs page now leads to the rulesets page.
- **Immutable releases**, a repo setting ("Enable release immutability", in the repo's settings under "Releases"): once a release is published, "its associated Git tag is locked to a specific commit, cannot be changed, and cannot be deleted while the release exists", and its assets are protected too. It "will only apply to future releases", and "If you delete the immutable release, you can delete the tag, but you cannot reuse the same tag name." It protects only tags that belong to a published release; every `v*` tag here does, since release-please makes each one with its release. The docs don't say whether a release stays immutable when the setting is turned off later, or whether GitHub Free offers it (not verified).
- `ref_name.include` takes fnmatch patterns; the REST examples use full refs (`refs/heads/main`), and "`*` wildcard does not match directory separators", so `refs/tags/v*` matches `refs/tags/v1.2.3`.

## Options

### Option 1: a "release tags" ruleset restricting updates and deletions, with no bypass

`target: tag`, `include: ["refs/tags/v*"]`, rules `update` and `deletion`, no bypass actors, enforcement active.

- **Trade-offs:** Nobody, the owner and every agent included, can move or delete a release tag, which is what makes a tag trustworthy. By the kit's reading of the rules (Context), creating one stays open to anyone with write access, so release-please creates tags through the Releases API with the plain `GITHUB_TOKEN`: no bypass, no stored token. A wrong tag can't be fixed by moving it, so it's fixed forward with the next version, as SemVer item 3 asks ("the contents of that version MUST NOT be modified"); the owner can still turn the ruleset off on GitHub to delete one, deliberately. Someone with write access could still create a stray `v*` tag, which then can't be deleted without turning the ruleset off; each repo has one writer, the owner, and his agents work under his sign-in, so this is a mistake to avoid, not an attack the ruleset meets. Restricting creation too is Option 2.
- **Reversibility:** Easy: the owner disables or deletes the ruleset.
- **Risk:** Low to medium. Not verified: that a ruleset with `update` but no `creation` lets the Releases API create a new tag, or a `git push` of a new `v*` tag. That rests on the kit's reading of the docs (Context), not on their words. The first release after the ruleset is applied proves the Releases API path (Consequences).

### Option 2: also restrict creations, with GitHub Actions as the bypass actor

- **Trade-offs:** Only release-please could make a `v*` tag. But the bypass list is per ruleset, so the bypass would also let any workflow in the repo move or delete release tags, the opposite of the goal. Adding GitHub Actions (integration 15368) as a bypass actor on a personal account's repo isn't documented either way. And the owner couldn't make a tag by hand without changing the ruleset.
- **Reversibility:** Easy.
- **Risk:** Medium: weaker protection against workflows, and the release may fail if the bypass isn't accepted.

### Option 3: immutable releases instead of a ruleset

- **Trade-offs:** GitHub's own feature for this: a published release's tag can't be moved or deleted while the release exists, and its assets are locked too, which a ruleset can't do. By the kit's reading, it doesn't touch tag creation, since a release-please release has no assets to add after it's published, so it carries no risk to release-please's path (not verified). But it protects only tags with a published release, so a `v*` tag made by hand without one isn't covered. Deleting the release frees its tag for deletion, so it guards against moving more than against deleting. And part of it is one-way: once an immutable release is deleted, its tag name can never be reused; whether a release stays immutable after the setting is turned off isn't documented (not verified), so it may be one-way too.
- **Reversibility:** The setting can be turned off for future releases; for those already published, possibly not (not verified).
- **Risk:** Low for releases. A repo setting that can't be fully undone is on the "Always ask" list.

### Option 4: no protection (today)

- **Trade-offs:** Nothing to set. A moved or deleted tag silently changes a release and the trust an app's kit pin rests on.
- **Reversibility:** Not applicable.
- **Risk:** Medium, growing with every app that pins the kit.

## Recommendation

Option 1: it blocks moving and deleting every `v*` tag, with or without a release, for everyone, can be turned off again, and leaves release-please its path, creation, with no bypass and no token. Immutable releases (Option 3) can be added on top later, for the assets' sake once the kit publishes any. That is the owner's choice, possibly one-way (Option 3), which this ADR doesn't make.

## Decision

The owner chose to protect `v*` tags on 2026-11-25 ("Yes, protect v* tags"); he hasn't seen the options above. The agent chose Option 1, as recommended, and the PR that adds it waits for his yes at its head commit, which settles the choice. Changing a ruleset stays the owner's step at the time it happens (AGENTS.md, "Always ask"), so the kit's is prepared here and applied by him.

## Consequences

- `templates/github/release-tags.json` holds the ruleset, for the kit and every app alike (one source, CRF-003).
- **The kit:** the owner applies it, from a kit checkout, with `gh api --method POST repos/DerekFoulk/dotnet-agent-kit/rulesets --input templates/github/release-tags.json`. Applying it before release PR 10 merges lets that release prove the creation path. README, "GitHub settings on this repo", lists it as prepared until it's applied. The README gives a check to run before posting it (it prints nothing if the ruleset isn't there yet) and after (it prints `active`). If the first release after it fails to create its tag (release-please's run fails, and the release PR stays labelled "autorelease: pending"), turn it off, in PowerShell, with `$id = gh api repos/DerekFoulk/dotnet-agent-kit/rulesets --jq '.[] | select(.name == "release tags") | .id'`, then `gh api --method PUT "repos/DerekFoulk/dotnet-agent-kit/rulesets/$id" -f enforcement=disabled` (GitHub's "Update a repository ruleset"; not run, so not verified that it leaves the rules as they are). Then re-run the release workflow, record the finding here, and mark the README's row disabled, with the date, until a fixed ruleset goes back on.
- **Apps:** `tools/New-KitApp.ps1` adds it right after "main protection", private or public, so a new app's release tags are protected from its first release (ADR-0033's note on rulesets for private repos on GitHub Free applies to it too). An app made before this ADR gets it only by hand, with the same command against its repo: a workflow's token can't change rulesets (ADR-0044).
- This is a guardrail change (AGENTS.md, "Working modes": a ruleset, and `New-KitApp`'s steps): its PR merges only on the owner's yes for its head commit.
- `tools/tests/New-KitApp.Tests.ps1` checks the file (target, pattern, exactly `update` and `deletion`, no bypass) and that `New-KitApp` posts it after the push and after "main protection".

## Pillars affected

Security: a release tag can't be moved to other code, so a version and a kit pin keep meaning one commit. Reliability: MinVer's versions stay reproducible. Operational Excellence: one more ruleset on each repo, set from data. Cost Optimization: none. Performance Efficiency: not affected.

## Sources

- owner, 2026-11-25
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets, retrieved 2026-11-25
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository, retrieved 2026-11-25
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets, retrieved 2026-11-25
- https://docs.github.com/en/rest/repos/rules, retrieved 2026-11-25
- https://docs.github.com/en/rest/releases/releases, retrieved 2026-11-25
- https://github.blog/changelog/2024-05-29-sunset-notice-tag-protections, retrieved 2026-11-25 (from a search result)
- https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases, retrieved 2026-11-26
- https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes, retrieved 2026-11-26
- https://raw.githubusercontent.com/googleapis/release-please/main/src/github-api.ts, retrieved 2026-11-25
- https://github.com/github/docs/blob/main/data/reusables/gated-features/repo-rules.md, retrieved 2026-11-07 (ADR-0033)
- https://semver.org/, retrieved 2026-11-25
