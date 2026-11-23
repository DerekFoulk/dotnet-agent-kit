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
- **Update (2026-11-21):** the scan covers every commit HEAD reaches, not every branch. With no `--log-opts`, gitleaks runs `git log -p -U0 --full-history --all --diff-filter=tuxdb` (`sources/git.go` at v8.30.1), and the checkout's `fetch-depth: 0` fetches every branch, so PR 117's scan failed on two known false positives that only PR 116's branch had, and that branch's `.gitleaksignore` skips. The step now passes `--log-opts="--full-history --diff-filter=tuxdb HEAD"`, gitleaks' own default with HEAD in place of `--all`: on a pull request that is the merge commit (main's history plus the PR's commits), on a push to main it is main. Options weighed:
  - **HEAD's history (chosen, owner 2026-11-21):** the same depth as before for the commit under test; one branch can't fail another's scan.
  - **Only the PR's own commits (`base..head`):** faster, but main's history isn't rescanned when the rules or `.gitleaksignore` change, and each event (pull request, push) needs its own range.
  - **Leave `--all`:** every branch is scanned on every run, and any branch's false positive fails every PR until that branch merges.

  Every branch is still scanned: in its own pull request, and main on every push. On the kit, a public repo, GitHub secret scanning and push protection also check pushes to every branch (ADR-0031). On a private app repo, a branch that never gets a pull request is no longer scanned by CI; before, it was scanned only as a side effect of other PRs. When the gitleaks image's version moves, recheck these options against `sources/git.go`.
- **Update (2026-11-23):** every push to any branch or tag is scanned too. A secret is exposed once it's pushed, whether or not the branch ever gets a pull request or merges (owner, 2026-11-23), and on a private repo owned by a personal account GitHub's push protection isn't available, so the 2026-11-21 update left such a branch unscanned. The scan moves into one composite action, `.github/actions/secret-scan`, which refuses a shallow checkout. The .NET CI's required "Secret scan (gitleaks)" job runs it unchanged, and `secret-scan.reusable.yml` runs it on every push to a branch other than `main` (CI's push run scans main) and on every tag push, from `secret-scan.yml` in the kit and in every app. A push that deletes a branch or tag is skipped: a branch deletion's run has the default branch's SHA. Runs are never cancelled, since a force-push doesn't take back a commit an earlier push exposed. Its run shows on a pull request's head commit, but it isn't a required check, so no ruleset changes. Options weighed:
  - **Scan each push's HEAD history (chosen):** a finding fails a run on the ref that holds it, within minutes, where whoever pushed it sees it; one branch's false positive can't fail another's run.
  - **A nightly `--all` scan that opens an issue:** one run a day, but a secret can sit unnoticed for a day, and the finding isn't tied to its push or its pusher.
  - **Scan only each push's new commits (`before..after`):** faster, but a new branch or a force-push has no usable `before`, so each case needs its own range.

  Cost: free on public repos, where standard GitHub-hosted runners are free. On a private repo, each run is a Linux job of under a minute, which GitHub rounds to a whole minute at $0.006, within GitHub Free's $12 a month of included compute (about 2,000 Linux minutes); a push to a branch with an open pull request runs both scans. Limits: a scan finds a secret after it's pushed, so a red run means rotating the secret. A push runs the workflow file in its own commit, so a branch cut before `secret-scan.yml` existed, an orphan branch, or a branch that edits or deletes that file isn't scanned on push (it still is in its pull request). An existing app gets `secret-scan.yml` by hand: the kit sync reports a new workflow as one to add, because a workflow's token can't write workflow files. Pushes made with a workflow's `GITHUB_TOKEN`, such as release-please's, start no run, and GitHub creates no push event for tags when more than three are pushed at once.

## Pillars affected

Security: secrets are caught before they are merged, and, since the 2026-11-23 update, minutes after any push to any branch or tag, when the secret is already exposed and must be rotated.

Cost Optimization (2026-11-23 update): free on public repos; on a private repo, about one Linux minute per push to a branch other than main ($0.006 a minute beyond GitHub Free's $12 a month).

## Sources

- owner, 2026-11-01
- owner, 2026-11-21 (scan HEAD's history, not every branch)
- https://github.com/gitleaks/gitleaks/blob/v8.30.1/sources/git.go, retrieved 2026-11-21
- owner, 2026-11-23 (scan every push to every branch)
- https://docs.github.com/en/webhooks/webhook-events-and-payloads, retrieved 2026-11-23 (the push event fires when a branch is deleted; `deleted`: "Whether this push deleted the ref")
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows, retrieved 2026-11-23 (on a branch deletion, the run's SHA is the default branch's; no push event for tags when more than three are pushed at once)
- https://docs.github.com/en/billing/concepts/product-billing/github-actions and https://docs.github.com/en/billing/reference/actions-runner-pricing, retrieved 2026-11-23 (standard runners free on public repos; Linux $0.006 a minute; GitHub Free includes $12 a month; minutes rounded per job)
- https://docs.github.com/en/enterprise-server@3.18/code-security/concepts/secret-security/push-protection, retrieved 2026-11-01
