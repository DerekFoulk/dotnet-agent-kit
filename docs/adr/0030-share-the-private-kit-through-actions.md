# ADR-0030: Share the private kit with app repos through GitHub Actions

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

The owner wants the kit packaged and self-updating: one command per new app, and kit updates reaching each app repo as pull requests, with as little maintenance as possible. He chose to keep the kit repo private and to try that first (owner, 2026-11-04).

A private repo limits sharing. An app repo's workflow token can't read another private repo: checking out the kit at a shared workflow's commit failed with "Repository not found" (`spikes/kit-sharing/README.md`, run 2). A private NuGet feed (GitHub Packages) would need a token on every machine, in every app repo and for Dependabot, and tokens expire.

The spike found a route with no token. With the kit's Actions access set to "Accessible from repositories owned by DerekFoulk", an app repo can use the kit's actions and shared workflows; GitHub downloads the whole kit repo at the pinned ref with its own short-lived token. Inside a shared workflow, `uses: $/.github/actions/...` resolves to the kit at that shared workflow's own commit.

## Options

### Option 1: Shared workflows and actions, scripts fetched through `$/` (no token)

- **Trade-offs:** App repos call `dotnet-ci.reusable.yml` and `app-checks.reusable.yml` at a kit version tag. Those reach the kit's scripts through the `kit-tools` action, always at the same version. One repo setting; no token, secret or feed. The kit's files (agent instructions, build config) still have to reach app repos another way (a sync job, PR D3), using the same download.
- **Reversibility:** Easy. Turn the setting off and copy files instead.
- **Risk:** Low. It relies on `$/` and the access setting, both shown working on 2026-11-05. Outside collaborators on app repos could indirectly read the kit (GitHub's docs say so); the kit holds no secrets.

### Option 2: Private NuGet feed and a token per repo

- **Trade-offs:** Build config as a NuGet package that Dependabot updates. Needs GitHub Packages, a token on each machine and in each repo, a Dependabot secret, and renewals.
- **Reversibility:** Medium.
- **Risk:** Medium. Expired tokens break builds; tokens are the maintenance the owner wants to avoid.

### Option 3: Copy the kit by hand (the v0.1 plan)

- **Trade-offs:** No access setting at all. Every kit update means copying files into every repo by hand.
- **Reversibility:** Easy.
- **Risk:** Low, but it's the manual work the owner asked to remove.

### Option 4: Make the kit public

- **Trade-offs:** Removes every access question; packages could go to nuget.org.
- **Reversibility:** Easy to make private again, but anything already copied stays public.
- **Risk:** Low; the kit holds no secrets or personal data. The owner prefers private for now.

## Recommendation

Option 1: it's automatic, needs no token, and keeps the kit private, as the owner asked.

## Decision

Accepted (owner, 2026-11-04: packaged and self-updating, kit private; owner, 2026-11-05: approved the plan and the access setting).

## Consequences

- The kit repo's Actions access is "Accessible from repositories owned by DerekFoulk" (turned on 2026-11-04).
- `.github/actions/kit-tools` returns the kit's folder; shared workflows use it as `uses: $/.github/actions/kit-tools` and never run a caller's `./tools`. `tools/tests/SharedCi.Tests.ps1` checks that.
- App repos call the shared workflows at a kit tag (README, "Using the kit's CI from an app repo").
- PR D2 (`New-KitApp`) and PR D3 (the sync job) build on this. If the private route fails, Option 4 is the fallback the owner named.

## Pillars affected

Operational Excellence: app repos get CI and kit updates without hand copying or token renewals. Security: no tokens or secrets; the access setting exposes the kit only to the owner's repos and their collaborators.

## Sources

- owner, 2026-11-04
- owner, 2026-11-05
- https://docs.github.com/en/actions/how-tos/reuse-automations/share-across-private-repositories, retrieved 2026-11-04
- https://github.blog/changelog/2026-09-03-github-actions-early-september-2026-updates/, retrieved 2026-11-05
