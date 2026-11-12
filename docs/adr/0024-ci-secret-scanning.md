# ADR-0024: Secret protection on private repos

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

No secrets in the repo is a floor rule. GitHub secret scanning for private repos needs GitHub Secret Protection, a paid add-on for organizations on Team or Enterprise Cloud, and it isn't available for repos owned by a personal account. Personal push protection only blocks pushes to public repos.

## Options

### Option 1: A free secret scanner in CI on every PR, plus a pre-commit hook locally

- **Trade-offs:** Covers private personal repos at no cost; the CI scan covers the full PR history; the hook gives earlier warning but can be bypassed.
- **Reversibility:** Easy.
- **Risk:** Low to medium. A scanner can miss an unusual secret format. The scanner and its license terms for private repos are confirmed in build step 4.

### Option 2: Move the repos to an organization with Secret Protection

- **Trade-offs:** GitHub's own scanning and push protection; ongoing cost and a repo move.
- **Reversibility:** Moderate.
- **Risk:** Low, at a cost.

### Option 3: No scanning

- **Trade-offs:** Nothing to run.
- **Reversibility:** Easy.
- **Risk:** High. A committed secret must be treated as leaked.

## Recommendation

Option 1, revisited if the owner's repos move to an organization.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- `dotnet-ci.reusable.yml` runs a secret scanner on every PR (build step 4).
- ~~A pre-commit hook runs the same scanner locally.~~ Not built: ADR-0027 (2026-11-03) keeps secret scanning in CI only, because a local scan needs Docker Desktop running for every commit.
- GitHub secret scanning stays off for these repos.
- **Amended by ADR-0031 (2026-11-05):** the kit repo is public, where GitHub secret scanning runs for free. The CI gitleaks scan stays the required check for every repo, and the only scan on private app repos.
- **Amended by ADR-0060 (2026-11-11):** the gitleaks image is pinned by tag and digest in the kit's `.config/gitleaks/Dockerfile`, where Dependabot's docker updater moves both; the scan runs the image that file names.

## Pillars affected

Security: secrets are caught before they are merged.

## Sources

- owner, 2026-11-01
- https://docs.github.com/en/enterprise-server@3.18/code-security/concepts/secret-security/push-protection, retrieved 2026-11-01
