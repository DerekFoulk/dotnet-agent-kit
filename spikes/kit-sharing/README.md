# Spike: sharing the private kit with private app repos (step 6, PR D)

**Question:** the owner wants the kit packaged and self-updating, with the kit repo kept private. Can another private repo use the kit's scripts and CI with no token to create, store or renew?

**Date:** 2026-11-05. **Where:** the kit repo (throwaway branch `spike/kit-action`, deleted after) and the throwaway private repo `DerekFoulk/kit-spike-release` (branches `spike/use-kit` and `spike/use-kit-2`, deleted after).

**Setting:** the kit repo's Actions access is "Accessible from repositories owned by DerekFoulk" (Settings › Actions › General › Access; API `access_level: user`), turned on with the owner's OK on 2026-11-04. Before, it was `none`.

## Run 1: using the kit's action

The throwaway repo called a composite action in the kit, `DerekFoulk/dotnet-agent-kit/.github/actions/kit-spike@spike/kit-action`, directly and through a kit shared workflow. Both jobs passed (run 42106740965):

- GitHub downloaded the **whole kit repo** at that ref to `/home/runner/work/_actions/DerekFoulk/dotnet-agent-kit/spike/kit-action`: `tools/`, `.claude/skills/`, `AGENTS.md`, `Directory.Build.props` and `.editorconfig` were all present.
- A kit script ran from there against the calling repo: `tools/Test-ConventionalTitle.ps1` printed "1 title(s), all Conventional Commits."
- No token: GitHub fetches actions with its own short-lived, read-only token.

## Run 2: reaching the kit at a shared workflow's own version

A shared workflow called at version X must use the kit's scripts at version X. Run 42108339320 tried three ways inside the kit's shared workflow:

| Approach | Result |
|---|---|
| `job.workflow_repository` / `job.workflow_sha` (GitHub, September 2026) | Works: `DerekFoulk/dotnet-agent-kit` at `48ccfa7`, the shared workflow's own commit |
| `actions/checkout` of the kit at `job.workflow_sha` | **Fails**: "Repository not found". The calling repo's token can't read the private kit |
| `uses: $/.github/actions/kit-spike` | **Works**: downloaded the kit at exactly `48ccfa7`, with no token |

## Conclusion

The kit can stay private. Its shared workflows reach the kit's scripts with `uses: $/.github/actions/kit-tools`, which resolves to the kit repo at the shared workflow's own commit, so an app pinned to `@v0.1.0` runs `v0.1.0`'s scripts. No token, secret or package feed is needed; only the one access setting.

Not tested: whether Dependabot can update an app's reference to a private kit version (GitHub's docs describe granting Dependabot access to private repos only for organizations). The self-update job (PR D3) bumps the version itself, so nothing depends on it.

Sources: [Sharing actions and workflows from your private repository](https://docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories), [GitHub Actions: early September 2026 updates](https://github.blog/changelog/2026-09-03-github-actions-early-september-2026-updates/), retrieved 2026-11-04 and 2026-11-05.
