# ADR-0045: Dependabot moves an app's kit pin, and the kit sync adds the rest to its PR

- **Status:** Accepted
- **Date:** 2026-11-10

## Context

The kit sync (ADR-0044) must reach each app as one pull request per kit release. That PR has to move the kit pin in the app's workflows (`uses: DerekFoulk/dotnet-agent-kit/.github/workflows/<file>@<commit SHA> # vX.Y.Z`), since the pin moves only with kit releases (ADR-0030, ADR-0032).

A workflow's own token can't do that. GitHub refuses a push that creates or changes a file under `.github/workflows/` unless the token has the "workflows" permission, and `GITHUB_TOKEN` can't be given it. That's reported consistently in GitHub's community forum; no official page was found that says it outright. The owner has kept every app free of stored tokens so far (ADR-0030: tokens are the maintenance he wants to avoid). Agents never handle secrets (SEC-002).

GitHub's documentation says Dependabot keeps "reusable workflows used inside workflows" up to date. Its changelog says Dependabot updates reusable workflows pinned "either by commit SHA or by tag", and "will now update the semver version in comments when updating Actions workflows with a commit SHA version" (sources below). Dependabot's own PRs may change workflow files.

## Options

### Option 1: A weekly issue, and an agent runs the sync locally

A scheduled workflow opens an issue when a newer kit release exists. An agent on the owner's machine runs `Sync-KitApp` and opens the PR with the owner's `gh` sign-in, which may change workflow files.

- **Trade-offs:** No stored token, and CI runs normally on a PR the owner opened. But nothing updates until someone acts, for every app and every release.
- **Reversibility:** Easy.
- **Risk:** Low, but apps drift while issues wait.

### Option 2: A GitHub App the owner owns

A private app with write access to contents, pull requests and workflows, installed on the owner's repos. Each run turns its key into a one-hour token with `actions/create-github-app-token`.

- **Trade-offs:** Fully automatic, with one PR from one workflow, and the key doesn't expire. But each app repo stores the key as a secret, which the owner adds by hand.
- **Reversibility:** Medium: uninstall the app and delete the secrets.
- **Risk:** Low to medium: a leaked key can write to every repo the app is installed on.

### Option 3: A fine-grained personal access token

- **Trade-offs:** Simple to create. But it's a stored secret in every app, and it expires and needs renewing.
- **Reversibility:** Easy.
- **Risk:** Medium: an expired token silently stops every sync.

### Option 4: Dependabot moves the pin, and the kit sync adds the rest to the same PR

The app's `.github/dependabot.yml` has a `github-actions` entry with the 7-day cooldown (ADR-0041), grouping every `DerekFoulk/dotnet-agent-kit*` reference into one PR. On that PR, the app's `kit-sync.yml` calls `kit-sync.reusable.yml`. That workflow:

- takes the release from the moved pins, checked against its release tag;
- runs that release's `Sync-KitApp`;
- pushes the other kit-managed changes to Dependabot's branch with `GITHUB_TOKEN`, without touching `.github/workflows/`;
- comments the report on the PR;
- approves the CI runs its push leaves waiting.

It runs only on Dependabot's own GitHub Actions PRs from the app's repo, the same checks `dependabot-lockfiles.yml` makes.

- **Trade-offs:** Automatic, with no stored token or secret. Dependabot moves the pin in the caller too, so the sync that runs is always the new release's own. Two costs. A kit change to a workflow beyond the pin can't be pushed, so the PR lists it for a person to apply. And a kit release reaches apps no sooner than Dependabot's 7-day wait.
- **Reversibility:** Easy: remove the `github-actions` entry and `kit-sync.yml`.
- **Risk:** Low to medium. It relies on Dependabot proposing a SHA pin's next release and updating its version comment, which GitHub documents but which hasn't run for this kit yet: the kit has no release yet (v0.1.0 isn't tagged). It also relies on approving the CI runs its push leaves waiting, proven in the kit (`spikes/release-please`, `dependabot-lockfiles.yml`) but not yet in an app.

## Recommendation

Option 2, a GitHub App: fully automatic with one PR and no expiry. Option 4 needs no secret at all, at the cost of listing workflow changes for a person.

## Decision

Option 4 (owner, 2026-11-10: "Option 4, please- Dependabot"): no stored token, no GitHub App, no personal access token.

## Consequences

- `templates/app/.github/dependabot.yml` gains a `github-actions` entry with `default-days: 7` and the `dotnet-agent-kit` group. The kit pin no longer moves only through the sync (ADR-0032's note is updated). There's still no `dotnet-sdk` entry: `global.json` moves with the sync.
- `templates/app/.github/workflows/kit-sync.yml` (kit-managed) and `.github/workflows/kit-sync.reusable.yml`. The caller grants `contents`, `pull-requests` and `actions` write, on Dependabot's PRs only. It isn't a required check, because it runs only on those PRs.
- A Dependabot github-actions PR that moves the kit pin is the owner's to merge, as every GitHub Actions bump is (ADR-0041), and as a guardrail change is.
- Dependabot stops rebasing a PR once another commit is on it. Comment `@dependabot rebase` and the sync runs again on the rebased branch, as the lock-file workflow does.
- If the sync fails, nothing stops the pin-only PR from merging: `kit-sync` isn't a required check, since it runs only on these PRs. Then the next GitHub Actions PR from Dependabot carries the whole sync, because the pins are ahead of the manifest. So a kit-pin PR is merged only with the sync's comment on it.
- Not verified until the kit's second release:
  - that Dependabot proposes it for an app's SHA pin with the right version comment, and groups every kit reference into one PR;
  - that the CI approval works in an app repo.

  Check them on the first app that gets such a PR.

## Pillars affected

- **Security:** no stored token or secret. The write token runs only the kit's own scripts on Dependabot's PRs from the app's repo. The sync refuses a pin no release tag points to, which catches a mistaken pin. That check runs code from the pinned commit itself, so against a malicious pin the guard is Dependabot proposing only a release's commit, and the owner's `gh api` check before merging, which the PR comment gives.
- **Operational Excellence:** kit releases reach apps on their own, as PRs.
- **Reliability:** the sync that runs is the release's own.
- **Cost Optimization:** one short job per kit release, free on public apps.
- **Performance Efficiency:** not affected.

## Sources

- owner, 2026-11-10
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/keeping-your-actions-up-to-date-with-dependabot, retrieved 2026-11-10
- https://github.blog/changelog/2023-03-13-dependabot-updates-support-reusable-workflows-for-github-actions/, retrieved 2026-11-10
- https://github.blog/changelog/2022-10-31-dependabot-now-updates-comments-in-github-actions-workflows-referencing-action-versions/, retrieved 2026-11-10
- https://github.community/t/refusing-to-allow-a-github-app-to-create-or-update-workflow-without-workflows-permission/182573, retrieved 2026-11-10
