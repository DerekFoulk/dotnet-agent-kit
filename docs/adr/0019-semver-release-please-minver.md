# ADR-0019: Semantic Versioning with release-please and MinVer

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

Every repo that uses the kit needs version numbers nobody edits by hand. The owner previously used a GitFlow-based tool that read versions from branch names (most likely GitVersion). The kit uses GitHub Flow (ADR-0007), so there are no release or hotfix branches to read.

## Options

### Option 1: Commit types drive versions; release-please opens a release PR; MinVer reads the tag

- **Trade-offs:** `fix:` is a patch, `feat:` a minor, `!` a major; merging the release PR tags `vX.Y.Z` and creates a GitHub Release; MinVer sets every version property at build time from the tag; builds between releases get `-alpha` versions automatically. Commit messages must follow a format (ADR-0006).
- **Reversibility:** Moderate.
- **Risk:** Medium. release-please recommends squash merges; ADR-0022 handles that.

### Option 2: GitVersion

- **Trade-offs:** Familiar; built around GitFlow branch names, which GitHub Flow doesn't have.
- **Reversibility:** Moderate.
- **Risk:** Medium. Mismatched with the chosen branching model.

### Option 3: The agent decides version numbers

- **Trade-offs:** No tooling; not repeatable or auditable.
- **Reversibility:** Easy.
- **Risk:** High.

## Recommendation

Option 1: tools detect breaking changes, the agent proposes the commit type, CI verifies it, and the owner approves by merging the release PR.

## Decision

Accepted as recommended, after discussion (owner, 2026-11-01).

## Consequences

- MinVer is a global package reference with tag prefix `v` (in place since build step 1).
- .NET package validation and an OpenAPI breaking-change check detect breaking changes.
- Release candidates are tagged `-rc.N` when wanted; a project stays at 0.x until its first production release.
- The release pipeline builds once and promotes the same artifact (ADR-0023).

## Pillars affected

Operational Excellence: versions and changelogs are automatic and auditable. Reliability: the artifact that was tested is the one that ships.

## Sources

- owner, 2026-11-01
- https://github.com/googleapis/release-please, retrieved 2026-11-01
- https://github.com/adamralph/minver, retrieved 2026-11-01
