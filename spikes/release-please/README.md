# Spike: release-please with merge commits and MinVer (D22, ADR-0022)

**Question:** with merge commits only, Conventional PR titles and the merge commit titled with the PR title, does release-please produce a release PR, a `vX.Y.Z` tag and a GitHub Release, and does MinVer build the same version from that tag? Can the release PR pass the required checks without a stored token?

**Where:** a throwaway private repo, `DerekFoulk/kit-spike-release`, set up like the kit: merge commits only, merge commit title = PR title with a blank body, branches deleted after merge, and a "main protection" ruleset requiring the `build` and `PR title` checks. It copies the kit's `global.json`, `Directory.Build.props`, `Directory.Packages.props` (MinVer 8.0.0, `v` tag prefix), `nuget.config` and `.editorconfig`.

**Versions:** `googleapis/release-please-action` v5.0.0 (`45996ed1f6d02564a971a2fa1b5860e934307cf7`, release-please 17.6.0), checkout v7.0.1 and setup-dotnet v6.0.0 at the kit's SHAs. **Date:** 2026-11-04.

## What happened

| Run | What I did | Result |
|---|---|---|
| 1 | Merged PR 1, `feat: add a greeter`, whose branch held a `fix:` and a `feat:` commit | release-please opened release PR 2, `chore(main): release 1.0.0` |
| 2 | Release PR 2's CI | The `pull_request` CI run was created but waited for approval (`action_required`), because the PR was opened with `GITHUB_TOKEN`. The PR stayed blocked, even after a `workflow_dispatch` run reported passing `build` and `PR title` checks on the same commit. Approving the waiting run let it pass and unblocked the PR |
| 3 | Merged PR 3: the release workflow approves its own release PR's waiting run, and `initial-version: 0.1.0` | The release PR became `release 0.1.0`; the workflow approved its CI run and the PR turned CLEAN with no one touching it |
| 4 | Merged release PR 2 | Tag `v0.1.0` and a GitHub Release; the release job built the tag and MinVer gave `0.1.0`, matching |
| 5 | Merged PR 4, `feat: add a farewell`, with `changelog-type: github` | Release PR 5, `release 0.2.0`, approved automatically, with one line per merged PR |
| 6 | Merged release PR 5 | Tag `v0.2.0`; MinVer `0.2.0`, matching |

## Findings

1. **The flow works with merge commits.** Release PR → tag → GitHub Release → MinVer version, twice, with the version bump right each time (`feat:` before 1.0 → minor).
2. **CI on the release PR needs no stored token.** Contrary to the action's README (which says to use a personal access token), a PR opened with `GITHUB_TOKEN` does create `pull_request` runs today; they wait for approval. The release workflow approves them with `POST /repos/{owner}/{repo}/actions/runs/{id}/approve`, filtered to `action_required` runs on release-please's branch. `workflow_dispatch` alone was not enough: the waiting run kept the PR blocked.
3. **The repo setting "Allow GitHub Actions to create and approve pull requests" must be on**, or release-please can't open its PR.
4. **The first version defaults to 1.0.0.** `initial-version: 0.1.0` is needed for a `0.x` start.
5. **Commit-based release notes are wrong with merge commits.** release-please reads the branch's own commits as well as the merge commit, so the PR's green `feat:` commit and its merge commit both appear, and a `fix:` commit made inside a feature PR is listed as a bug fix. **`changelog-type: github`** builds the notes from GitHub's list of merged PRs instead: one line per PR, titled with the PR title.
6. **release-please stores the current version in `.release-please-manifest.json`.** No build reads it (MinVer reads the tag), but it conflicts with SUP-006's wording, "no version number is stored in any file".
7. `GITHUB_TOKEN` tags don't trigger other workflows, so building or publishing a release happens in the same `release.yml` run, after release-please reports `release_created`.

## Workflow and config that worked

The final `release.yml` and `release-please-config.json` from the spike repo are the basis for the kit's own (step 5 PR).
