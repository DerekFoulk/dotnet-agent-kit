# ADR-0031: Make the kit repo public, with no license

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

ADR-0013 kept the kit private. ADR-0030 then shared the private kit with private app repos through GitHub Actions, and named making the kit public as the fallback (its Option 4).

Three findings since then (owner, 2026-11-05):

- GitHub-hosted standard runners are free in public repositories, Windows and macOS included. Private repos draw on the $12 a month that GitHub Free includes, at $0.006 a minute on Linux, $0.010 on Windows and $0.062 on macOS. MAUI apps need Windows and macOS runners.
- Each repo pays for its own runs, by its own visibility. A public kit makes only the kit's own CI free; an app's CI is free only if the app repo is public too.
- A public repo very likely can't use actions or reusable workflows from a private repo. GitHub's sharing docs, as quoted in search results on 2026-11-05, say they "cannot be used in public repositories"; the current page no longer says either way, and it wasn't tested. So any public app needs a public kit.

GitHub secret scanning, unavailable for private personal repos (ADR-0024), "runs automatically for free" on public repositories.

The owner wants the kit public, but doesn't want others reusing it for now.

## Options

### Option 1: Public repo, no license

- **Trade-offs:** The kit's CI is free, and app repos can be public with free CI on every runner, macOS included. Any repo can call the shared workflows, so ADR-0030's access setting no longer matters, and Dependabot can update an app's pin like any public action. Secret scanning is free. With no license, "the default copyright laws apply, meaning that you retain all rights to your source code", so nobody may reproduce or build on it; GitHub's terms still let other users "view and fork your repository". Everything becomes visible: files, history, PRs, reviews and the corrections log.
- **Reversibility:** Hard. The repo can be made private again, but copies already made stay.
- **Risk:** Low to medium. The kit holds no secrets (the gitleaks scan of the full history passes in CI) and the audit for this PR found no personal data beyond the owner's name and the commit email his GitHub profile already shows. Workflows in a public repo can be triggered by pull requests from forks; none of the kit's workflows uses `pull_request_target`, and the two that approve runs approve only runs for their own commit.

### Option 2: Public repo with an open-source license (for example MIT)

- **Trade-offs:** The same benefits, and others may reuse the kit. The owner doesn't want reuse for now.
- **Reversibility:** Hard. A license granted on a published version can't be taken back for that version.
- **Risk:** Low.

### Option 3: Stay private (ADR-0013 and ADR-0030 as they are)

- **Trade-offs:** Nothing becomes visible. Every CI minute counts against the $12 a month, about $1.07 for a rough MAUI PR estimate with macOS, and no app repo can be public while using the kit.
- **Reversibility:** Easy.
- **Risk:** Low, but CI costs grow with MAUI apps.

## Recommendation

Option 1: free CI for the kit and for any public app, at the owner's wish not to license reuse.

## Decision

Accepted (owner, 2026-11-05: "I think we should make this repo public"; no license, "I don't really want people to use it. At least not right now"; keep the name `dotnet-agent-kit`).

## Consequences

- Supersedes ADR-0013. Amends ADR-0030 (the kit is shared because it's public; the `$/` route to its scripts stays) and ADR-0024 (GitHub secret scanning runs on the public kit; gitleaks stays the required check, and the only one on private app repos).
- No LICENSE file. The README says: all rights reserved, not licensed for reuse.
- The owner switches the visibility after this PR merges (a repo setting he changes or tells the agent to change). Afterwards, check what GitHub turned on (secret scanning, push protection) and record it; turning on anything more is a settings change that needs his OK.
- Files copied in from licensed projects, such as `dotnet/skills` (MIT), keep their own license notices.
- `New-KitApp` (PR D2) lets each app be public or private; private stays the default.
- ADR-0023 (manual production promotion, because environment reviewers need a public repo or a paid plan) stays as decided for private apps; a public app could use environment reviewers instead.
- The repo is never renamed once an app pins it: GitHub doesn't redirect Actions calls after a rename ("repository not found"). The owner kept the name.

## Pillars affected

Cost Optimization: CI is free for the kit and for public apps. Security: everything in the kit becomes public, so the floor rules (no secrets, no personal data) now also guard against publication; secret scanning is added. Operational Excellence: no access setting to maintain for sharing.

## Sources

- owner, 2026-11-05
- https://docs.github.com/en/billing/concepts/product-billing/github-actions, retrieved 2026-11-05
- https://docs.github.com/en/billing/reference/actions-runner-pricing, retrieved 2026-11-05
- https://Help.GitHub.com/en/actions/creating-actions/sharing-actions-and-workflows-from-your-private-repository, retrieved 2026-11-05
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository, retrieved 2026-11-05
- https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning, retrieved 2026-11-05
- https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository, retrieved 2026-11-05
