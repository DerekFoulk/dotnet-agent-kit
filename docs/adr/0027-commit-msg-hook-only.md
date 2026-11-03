# ADR-0027: Git hooks: a commit-msg hook only

- **Status:** Accepted
- **Date:** 2026-11-03

## Context

Build step 4 made CI check every commit subject on a pull request (GIT-004). A commit whose subject isn't a Conventional Commit can only be fixed by rewriting history, which needs a force-push, and agents never force-push (GIT-003). So one bad subject could leave a PR red for good. ADR-0024 also planned a pre-commit secret scan. A local gitleaks run on Windows needs Docker Desktop running for every commit, while CI already scans the full history on every pull request. The brief ranks git hooks as early feedback only: they can be bypassed, and CI is the real check (brief §7).

## Options

### Option 1: A commit-msg hook only

- **Trade-offs:** Catches a bad subject before the commit exists, with the same rule CI uses (`Get-TitleProblem`). It's fast and needs only PowerShell 7. Each clone turns it on once (`git config core.hooksPath .githooks`, offered by `Initialize-DevMachine -Install`). Secret scanning stays in CI only.
- **Reversibility:** Easy. Unset `core.hooksPath`, or delete the hook.
- **Risk:** Low. A secret is caught at the PR, before merge, rather than at commit time.

### Option 2: A commit-msg hook and a pre-commit secret scan

- **Trade-offs:** Secrets are caught before they're committed. Every commit needs Docker Desktop running and waits for a container; when Docker is off, commits fail.
- **Reversibility:** Easy.
- **Risk:** Medium. Slow, fragile commits invite bypassing hooks, which the kit forbids.

### Option 3: No hooks

- **Trade-offs:** No setup. A bad commit subject reaches CI, where only a history rewrite fixes it.
- **Reversibility:** Easy.
- **Risk:** Medium. PRs stuck red, or pressure to force-push.

## Recommendation

Option 1: it prevents the one failure CI can't let you recover from, and nothing more.

## Decision

Accepted as recommended (owner, 2026-11-03).

## Consequences

- `.githooks/commit-msg` (a `sh` wrapper, stored executable and with LF line endings) runs `.githooks/commit-msg.ps1`. It must never accept a subject CI rejects, so it skips only a real merge in progress (git sets `MERGE_HEAD`), as CI skips merge commits, and rejects `fixup!`/`squash!`/`amend!` subjects.
- `git revert` never runs the commit-msg hook (checked 2026-11-03). Its default `Revert "<subject>"` is accepted by the shared rule, in the hook and in CI, when the reverted subject is a Conventional Commit.
- `tools/Initialize-DevMachine.ps1` reports the hook as a required item and turns it on with `-Install`.
- ADR-0024's pre-commit secret scan isn't built; the CI gitleaks scan of the full history is the secret check.

## Pillars affected

Operational Excellence: mistakes are caught when they're cheapest to fix. Security: unchanged, because secret scanning stays in CI.

## Sources

- owner, 2026-11-03
- https://git-scm.com/docs/githooks, retrieved 2026-11-03
