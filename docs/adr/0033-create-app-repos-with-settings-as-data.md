# ADR-0033: Create app repos through the GitHub API, with the settings as data in the kit

- **Status:** Accepted
- **Date:** 2026-11-06

## Context

D2b finishes `New-KitApp` (ADR-0032 wrote the files). One command has to take an empty folder to a GitHub repo whose first commit passes CI and whose `main` is protected from the start, set up the way the kit is:

- merge commits only, titled with the PR title and an empty body, branches deleted after merging (GIT-001, ADR-0022);
- the "main protection" ruleset: no deletion or force-push, a pull request, merge commits only, nobody bypasses it, and the app's required checks (ADR-0026);
- for a public app, what the kit has as a public repo: secret scanning, push protection, and no fork PR runs until the owner approves it (ADR-0031).

Apps are private unless the owner asks for public (ADR-0031). The ruleset must come after the first push, or it rejects that push. Agents never handle tokens; the owner's `gh` sign-in is the only credential (SEC-002). The sync job (PR D3) will need the same settings to bring older apps up to date.

## Options

### Option 1: GitHub REST calls through `gh api`, with the settings as JSON in `templates/github/`

`tools/New-KitApp.ps1` creates the repo with `POST /user/repos`, sending the merge settings in the same call, pushes, then sends the ruleset with `POST /repos/{owner}/{repo}/rulesets`. The bodies are files in the kit: `repo.json`, `main-protection.json` and `public.json`, read from the same kit commit as the exported files.

- **Trade-offs:** One way of calling GitHub for everything, settings and ruleset alike. The settings are reviewable files, versioned with the kit, that tests check against the app's CI (a renamed job fails a test instead of leaving every app PR waiting) and that the sync job can apply again. The calls are plain REST, so a failure shows GitHub's own message. It costs a short wrapper so tests can replace `gh`.
- **Reversibility:** Easy. Nothing outside the kit depends on the files' layout yet.
- **Risk:** Low. The same calls set up the kit itself (ADR-0026, ADR-0031); the end-to-end app proves them on a new repo.

### Option 2: `gh repo create` and `gh repo edit` flags

- **Trade-offs:** Shorter commands, no JSON. But `gh` has no command for rulesets or the fork-approval policy, so those still need `gh api`, and the settings end up split between flags in a script and API bodies. Nothing reusable for the sync job.
- **Reversibility:** Easy.
- **Risk:** Low, but the settings drift more easily, because no test can read them.

### Option 3: A GitHub template repository

- **Trade-offs:** GitHub's own "Use this template" button. But a repo made from a template gets the files only: none of the settings, the ruleset or the security settings, so a script is still needed. It also adds a second repo to keep in step with the kit, the drift ADR-0032 avoided.
- **Reversibility:** Medium.
- **Risk:** Medium: the template and the kit drift apart.

## Recommendation

Option 1: the settings become reviewed, tested, versioned data that `New-KitApp` and the sync job share.

## Decision

Accepted (owner, 2026-11-06: approved the D2b plan, including the throwaway end-to-end repo `DerekFoulk/kit-app-test` and the ask rule for `New-KitApp`).

## Consequences

- `New-KitApp` runs in this order: read-only checks (the name, an empty folder, the kit ref, the `gh` sign-in, and that the repo doesn't exist), export, first commit `chore: start from dotnet-agent-kit <version>` with `.githooks/commit-msg` stored as executable, create, push `main`, the ruleset, the public settings for a public app, and `core.hooksPath` in the local copy. `-WhatIf` runs only the checks and lists the steps.
- It works on the signed-in owner's own account only, and only creates new repos: it refuses an existing one, so it never changes a real repo's settings. A failed step stops the run and reports what's done and what's left. It never deletes a repo, which can't be undone.
- `.claude/settings.json` asks before running `New-KitApp` (`./tools/*` would otherwise allow it), because it acts outside the repo.
- The required checks are the app's CI jobs, `<caller job> / <shared workflow job name>`: `dotnet / Build, test and package checks`, `dotnet / Secret scan (gitleaks)` and `app / App checks`. `tools/tests/New-KitApp.Tests.ps1` derives them from the workflows.
- The kit's own ruleset and settings stay set by hand on GitHub (README, "GitHub settings on this repo"); the tests check that the app ruleset has the same rules. Storing the kit's as data too is possible later.
- GitHub documents no API for "only collaborators can open issues", so the owner sets it in the browser for a public app, as he did for the kit.
- GitHub's docs list rulesets for Team and Enterprise plans. The release-please spike's private repo enforced its required checks under the owner's account, and the end-to-end private app checks it again.
- The sync job (PR D3) can apply `templates/github/` to existing apps. A kit version from before this ADR has no such folder, and `New-KitApp` refuses it before any change.

## Pillars affected

Security: every app is protected from its first push, private by default, and an agent asks before creating one. Reliability: checks run before any change, and a failure says exactly what's left. Operational Excellence: one command creates a ready repo, and the settings are versioned data. Cost Optimization: no new service; a private app's CI uses the plan's included minutes. Performance Efficiency: not affected.

## Sources

- owner, 2026-11-06
- https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user, retrieved 2026-11-06
- https://docs.github.com/en/rest/repos/rules, retrieved 2026-11-02
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets, retrieved 2026-11-06
