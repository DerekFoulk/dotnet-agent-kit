# ADR-0033: Create app repos through the GitHub API, with the settings as data in the kit

- **Status:** Accepted
- **Date:** 2026-11-06

## Context

D2b finishes `New-KitApp` (ADR-0032 wrote the files). One command has to take an empty folder to a GitHub repo whose first commit passes CI and whose `main` is protected from right after its first push where the plan allows it (Consequences, for GitHub Free), set up the way the kit is:

- merge commits only, titled with the PR title and an empty body, branches deleted after merging (GIT-001, ADR-0022);
- the "main protection" ruleset: no deletion or force-push, a pull request, merge commits only, nobody bypasses it, and the app's required checks (ADR-0026);
- for a public app, what the kit has as a public repo: secret scanning, push protection, and no fork PR runs until the owner approves it (ADR-0031).

ADR-0031 left each app public or private, private by default; this ADR makes public the default (Consequences). The ruleset must come after the first push, or it rejects that push. Agents never handle tokens; the owner's `gh` sign-in is the only credential (SEC-002). The sync job (PR D3) will need the same settings to bring older apps up to date.

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

Accepted (owner, 2026-11-06: approved the D2b plan, including the throwaway end-to-end repo `DerekFoulk/kit-app-test` and the ask rule for `New-KitApp`). Amended 2026-11-07: apps are public unless `-Private` is given (owner: "Let's get that set to default to 'public'").

## Consequences

- Apps are public unless `-Private` is given, which replaces ADR-0031's private default (owner, 2026-11-07). The reasons: CI is free on public repos on GitHub's standard runners, macOS included, which MAUI apps need, while private repos draw on the $12 a month GitHub Free includes (ADR-0031); and GitHub Free offers rulesets only on public repos (below), though whether the ruleset holds on Free, given that it's added while the repo is still private, isn't verified (below). The cost: anyone can read a public app's code, history and PRs. With no license, nobody may reuse them, as for the kit.
- The repo is named after the app unless `-RepoName` gives another name. The app name is a dotted .NET name (ADR-0032), because it becomes the root namespace, which can't contain hyphens; a repo name can, as `dotnet-agent-kit` does (owner, 2026-11-06: "add -RepoName"). The local folder defaults to the repo name, as `git clone` would name it.
- `New-KitApp` runs in this order: read-only checks (the app and repo names, an empty folder, the kit ref with its `templates/github`, the `gh` sign-in, and that the repo doesn't exist), export, first commit `chore: start from dotnet-agent-kit <version>` with `.githooks/commit-msg` stored as executable, create (always private), push `main`, the ruleset, Dependabot alerts and security updates (added 2026-11-09), actions pinned to a full commit SHA (added 2026-11-10), unless `-Private` is given the switch to public, then its public settings and the "code scanning" ruleset (added 2026-11-10), and `core.hooksPath` in the local copy. A public app goes public only once `main` is pushed and its ruleset is added, so a failure before then leaves a private repo (review 1 of PR 17). `-WhatIf` runs only the checks and lists the steps.
- It works on the signed-in owner's own account only, and only creates new repos: it refuses an existing one, so it never changes a real repo's settings. A failed step stops the run and reports what's done and what's left, and whether the repo or the local folder is kept. It never deletes a repo, which can't be undone.
- `.claude/settings.json` asks before running `New-KitApp` (`./tools/*` would otherwise allow it), because it acts outside the repo.
- The required checks are the app's CI jobs, `<caller job> / <shared workflow job name>`: `dotnet / Build, test and package checks`, `dotnet / Secret scan (gitleaks)` and `app / App checks`. `tools/tests/New-KitApp.Tests.ps1` derives them from the workflows.
- The kit's own ruleset and settings stay set by hand on GitHub (README, "GitHub settings on this repo"); the tests check that the app ruleset has the same rules. Storing the kit's as data too is possible later.
- GitHub documents no API for "only collaborators can open issues", so the owner sets it in the browser for a public app, as he did for the kit.
- Rulesets need a paid plan on private repos. GitHub's availability note for rulesets says they "are available in public repositories with GitHub Free and GitHub Free for organizations, and in public and private repositories with GitHub Pro, GitHub Team, and GitHub Enterprise Cloud" (the note on the rulesets page, from its docs source). So a `-Private` app on a Free personal account gets no protected `main`. Under the owner's account, the end-to-end private app's ruleset rejected a direct push to `main` (GH013), so his plan enforces it. On a plan that doesn't, the ruleset step may fail after the push, and the report then lists the ruleset as left. Or GitHub may accept the ruleset without enforcing it, and then nothing flags it: `New-KitApp` reports success while `main` is unprotected (review 2 of PR 17). Which of the two happens on Free isn't verified. A public app on Free meets the same question, because its ruleset goes on while the repo is still private; whether it's enforced once the repo turns public isn't verified either (review 4 of PR 17). So before handing `New-KitApp` to another account, check its plan, or try a direct push to `main` in its first app.
- The sync job (PR D3) can apply `templates/github/` to existing apps. **Update (2026-11-10):** it doesn't yet: a workflow's own token can't change repo settings or rulesets (ADR-0042, a follow-up). A kit version from before this ADR has no such folder, and `New-KitApp` refuses it before any change.
- **Update (2026-11-09):** after the ruleset, `New-KitApp` also turns on Dependabot alerts and security updates, for private and public apps alike (owner, 2026-11-09; ADR-0041).
- **Update (2026-11-10):** new apps get the kit's three merge protections (owner, 2026-11-10). Every app's "main protection" ruleset requires review threads resolved, and every app requires actions pinned to a full commit SHA (`templates/github/actions.json`). A public app also gets a second ruleset, "code scanning", once it's public (`templates/github/code-scanning.json`): a rule requiring a tool the repo doesn't run blocks every merge (GitHub's "Available rules for rulesets"), and a private app doesn't run CodeQL. Not verified: whether GitHub accepts that ruleset before code scanning has ever run in the repo, and whether a new public app's first pull request merges while `main`, pushed while private, has no CodeQL analysis. GitHub's three blocking conditions don't include a missing base analysis, and the first pull request's own run configures CodeQL. If the ruleset is refused, the run stops at that step, the last one on GitHub: the report lists it and the local commit-hook step as left, so turn the hook on too (`git config core.hooksPath .githooks`).

## Pillars affected

Security: every app is given the ruleset right after its first push (whether GitHub Free accepts and enforces it isn't verified), goes public only once its ruleset is added, gets Dependabot alerts and security updates, gets secret scanning and push protection when public, and an agent asks before creating one; a public app's code is visible to anyone. Reliability: checks run before any change, and a failure says exactly what's left. Operational Excellence: one command creates a ready repo, and the settings are versioned data. Cost Optimization: no new service; a public app's CI is free, and a `-Private` app's uses the plan's included minutes. Performance Efficiency: not affected.

## Sources

- owner, 2026-11-06 and 2026-11-07
- https://docs.github.com/en/rest/repos/repos#create-a-repository-for-the-authenticated-user, retrieved 2026-11-06
- https://docs.github.com/en/rest/repos/rules, retrieved 2026-11-02
- https://docs.github.com/en/rest/repos/repos#enable-vulnerability-alerts, retrieved 2026-11-09
- https://docs.github.com/en/rest/actions/permissions#set-github-actions-permissions-for-a-repository, retrieved 2026-11-10
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets, retrieved 2026-11-10
- https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets, retrieved 2026-11-07
- https://docs.github.com/en/get-started/learning-about-github/githubs-plans, retrieved 2026-11-07
- https://github.com/github/docs/blob/main/data/reusables/gated-features/repo-rules.md (the rulesets availability note, last changed 2026-06-09), retrieved 2026-11-07
