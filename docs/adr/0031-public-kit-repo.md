# ADR-0031: Make the kit repo public, with no license

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

ADR-0013 kept the kit private. ADR-0030 then shared the private kit with private app repos through GitHub Actions, and named making the kit public as the fallback (its Option 4).

Three findings since then (research for the owner, 2026-11-05; sources below):

- GitHub-hosted standard runners are free in public repositories, Windows and macOS included. Private repos draw on the $12 a month that GitHub Free includes, at $0.006 a minute on Linux, $0.010 on Windows and $0.062 on macOS. MAUI apps need Windows and macOS runners.
- Each repo pays for its own runs, by its own visibility. A public kit makes only the kit's own CI free; an app's CI is free only if the app repo is public too.
- A public repo very likely can't use actions or reusable workflows from a private repo. A search-result snippet of GitHub's sharing docs (2026-11-05) says they "cannot be used in public repositories"; the current page no longer says either way, and it wasn't tested. So any public app needs a public kit.

GitHub secret scanning, unavailable for private personal repos (ADR-0024), "runs automatically for free" on public repositories.

The owner wants the kit public, but doesn't want others reusing it for now.

## Options

### Option 1: Public repo, no license

- **Trade-offs:** The kit's CI is free, and app repos can be public with free CI on every runner, macOS included. Any repo can call the shared workflows, so ADR-0030's access setting no longer matters, and Dependabot should be able to update an app's pin like any public action (not verified). Secret scanning is free. With no license, "the default copyright laws apply, meaning that you retain all rights to your source code", so nobody may reproduce or build on it; GitHub's terms still let other users "view and fork your repository". Everything becomes visible: files, history, PRs, reviews and the corrections log.
- **Reversibility:** Hard. The repo can be made private again, but copies already made stay.
- **Risk:** Low to medium. The kit holds no secrets (the gitleaks scan of the full history passes in CI) and the audit for this PR found no personal data beyond the owner's name and the commit email his GitHub profile already shows. Workflows in a public repo can be triggered by pull requests from forks; none of the kit's workflows uses `pull_request_target`, and the two that approve runs approve only runs for one known commit (the release PR's head, or the commit the workflow just pushed); a fork's PR on that same commit would run the kit's own code with a read-only token. Anyone can also push commits to a fork, and a pin by SHA can resolve to a fork's commit through the fork network, so a pin is only trusted when a kit release tag points to it (Consequences).

### Option 2: Public repo with an open-source license (for example MIT)

- **Trade-offs:** The same benefits, and others may reuse the kit. The owner doesn't want reuse for now.
- **Reversibility:** Hard. A license granted on a published version can't be taken back for that version.
- **Risk:** Low.

### Option 3: Stay private (ADR-0013 and ADR-0030 as they are)

- **Trade-offs:** Nothing becomes visible. Every CI minute counts against the $12 a month. A rough, unmeasured MAUI PR of about 6 Linux, 10 Windows and 15 macOS minutes costs about $1.07 ($0.036 + $0.10 + $0.93). And no app repo can be public while using the kit.
- **Reversibility:** Easy.
- **Risk:** Low, but CI costs grow with MAUI apps.

## Recommendation

Option 1: free CI for the kit and for any public app, at the owner's wish not to license reuse.

## Decision

Accepted (owner, 2026-11-05: "I think we should make this repo public"; no license, "I don't really want people to use it. At least not right now"; keep the name `dotnet-agent-kit`).

## Consequences

- Supersedes ADR-0013. Amends ADR-0030 (the kit is shared because it's public; the `$/` route to its scripts stays) and ADR-0024 (GitHub secret scanning runs on the public kit; gitleaks stays the required check, and the only one on private app repos).
- No LICENSE file. The README says: all rights reserved, not licensed for reuse.
- The owner switches the visibility right after this PR merges (a repo setting he changes or tells the agent to change); the Actions access setting stays on until then, for the private route. Afterwards:
  - check what GitHub turned on (secret scanning, push protection) and record it; turning on anything more is a settings change that needs his OK;
  - watch the next release PR and the next Dependabot NuGet PR, and confirm their CI runs still wait for approval and get approved: that behaviour was proven only on private repos;
  - the owner chooses the "Approval for running fork pull request workflows from contributors" option (Settings › Actions › General); the recommendation is "Require approval for all external contributors".
- An app's pin of the kit is trusted only when a kit release tag points to that SHA (`gh api repos/DerekFoulk/dotnet-agent-kit/commits/vX.Y.Z --jq .sha`); GitHub's guidance is to "verify it is from the action's repository and not a repository fork". The reviewer agent checks any pin a PR changes (`.claude/agents/reviewer.md`) in repos that have it: the kit today, and app repos once `New-KitApp` (PR D2) and the sync job (PR D3) give them the kit's agent files. The sync job must also check a pin before moving it.
- Files based on licensed projects keep those projects' notices in `THIRD-PARTY-NOTICES.md`: `.editorconfig` (dotnet/runtime and dotnet/docs, MIT) and `.gitignore` (dotnet/sdk, MIT). `New-KitApp` (PR D2) and the sync job (PR D3) must carry those notices with them (ADR-0032 puts them in a kit block of the app's `THIRD-PARTY-NOTICES.md`); the README and ADR-0030 list it among the files an app gets. Anything copied later, such as skills from `dotnet/skills` (MIT), adds its notice there.
- `New-KitApp` (PR D2) lets each app be public or private; private stays the default.
- ADR-0023 (manual production promotion, because environment reviewers need a public repo or a paid plan) stays as decided for private apps; a public app could use environment reviewers instead.
- The repo is never renamed once an app pins it: GitHub "will not redirect calls to an action hosted by a renamed repository" ("repository not found"), and reusable workflows very likely behave the same (the page doesn't say). The owner kept the name.

## Pillars affected

Cost Optimization: CI is free for the kit and for public apps. Security: everything in the kit becomes public, so the floor rules (no secrets, no personal data) now also guard against publication; secret scanning is added. Operational Excellence: no access setting to maintain for sharing.

## Sources

- owner, 2026-11-05
- https://docs.github.com/en/billing/concepts/product-billing/github-actions, retrieved 2026-11-05
- https://docs.github.com/en/billing/reference/actions-runner-pricing, retrieved 2026-11-05
- https://docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories, retrieved 2026-11-05 (the "cannot be used in public repositories" wording is from a search-result snippet of an older version of this page)
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository, retrieved 2026-11-05
- https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning, retrieved 2026-11-05
- https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository, retrieved 2026-11-05
- https://docs.github.com/en/actions/reference/security/secure-use, retrieved 2026-11-06 (pinning by SHA, and forks)
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository, retrieved 2026-11-06 (fork pull request approval)
