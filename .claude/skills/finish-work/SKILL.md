---
name: finish-work
description: Verify a finished change against the definition of done, open the pull request with evidence, answer Copilot's code review, and merge when the mode allows. Use when the test list is empty and before telling the owner anything is done.
---

# Finish work

## 1. Verify, with evidence

Run every command in the **Commands table of `AGENTS.md`**, which gives this repo's paths, and keep the output for the PR. Each must pass:
- the build, with zero warnings;
- every test suite, with the coverage gate where the table has one;
- every check: generated files current (if not, regenerate them and commit), ADR sections, Conventional Commit subjects and red→green order for `origin/main..HEAD`, and any other the table lists.

Skip only the commands that write, such as regenerating without `-Check`, unless a check failed and asks for it. CI runs the same checks on the PR; a local pass first saves a round trip.

Then confirm:
- Docs and ADRs are updated for the change.
- Every red commit has a green commit after it, and git reads both trailers (`git log --reverse --format='%h %s | %(trailers:key=TDD,valueonly)' main..HEAD`).
- Each red failed on an assertion, and each green passes from a clean checkout. Check that every new file is tracked (`git status --short --ignored`); an ignored config file passes locally and fails everywhere else.
- Anything you didn't verify is listed as "not verified".

## 2. Code review, by Copilot

It starts when you open the PR (step 4). GitHub Copilot code review reviews every pull request when it opens, and again after every push to it, through the "main protection" ruleset (DOD-003, ADR-0064). It reviews against the code-review instructions (`docs/code-review.md`, generated into `.github/instructions/code-review.instructions.md`) and the rule files. CI runs the build, the tests and every check, so there's no separate gate run.

**When a review lands, run `address-review`.** Rank each finding Blocking, Should fix or Consider (Copilot starts each comment with one; check it against the code, and re-rank it when it's wrong). Fix each real one test-first, or answer it with a reason. Push the fixes in one push where you can: each push starts another review, which uses the owner's AI credits.

**Reviews end at the first Copilot review of the head commit with nothing blocking or should-fix** (owner, 2026-11-09). Answer its Consider findings with a reason, or note them for a later PR. Fix one only when it's cheap and changes no behavior: that push gets its own review, and a new blocking or should-fix finding in it reopens the reviews.

**If Copilot can't review** (no review appears, or it fails, as it does when the owner's AI credits run out), tell the owner and wait. Don't merge without a review.

**Don't wait idle.** While a review runs, start the next task on its own branch.

## 3. Check the PR state

If a PR already exists for this branch, run `gh pr view <n> --json state,mergedAt` **before pushing or reporting**. The owner may merge on his own schedule. If it's merged, branch from the old branch, then open a new PR into `main` for the new commits. This step comes from `docs/corrections-log.md` (2026-11-02).

## 4. Open the PR

- The title is a Conventional Commit (it becomes the merge commit message).
- Use `.github/pull_request_template.md` and fill in the red→green table from `git log`. A PR whose description a bot writes, such as Dependabot's, keeps it: post the template's sections as a PR comment instead, naming the head commit (DOD-006), and a new one whenever the head moves.
- List the decisions the owner must make and any `proposed` rules he must ratify. **Ask each one in the chat too, with its recommendation** (COM-007): he may not read the PR before it merges.
- In review mode, don't merge: the owner merges, or tells you to for that PR.
- **Watch for the review and for CI, in any tool, with `Wait-PullRequest`** (from `KitReview.psm1`). After each push, run one wait with `-For Review` and one with `-For Checks`, in the background where the tool allows. Each returns as soon as its event happens: `Reviewed`, `ChecksPassed` or `ChecksFailed`, `HeadMoved`, `Merged` or `Closed`. `ReviewFailed` means Copilot posted a reason instead of a review, such as running out of quota: the commit isn't reviewed, so tell the owner the reason. If it returns `TimedOut`, its message says what's still missing; look at once, and don't assume CI is still running. When a review lands, from Copilot or a person, run `address-review`; when CI finishes, check the merge conditions below.
  - In the Claude Code desktop app, also turn on the PR monitor with auto-fix for the new PR (the owner said it needs no ask, 2026-11-14). It wakes the session on review comments, CI failures and merge conflicts, but not on a passing CI, so `Wait-PullRequest` still tells you when the PR is ready.

## 5. Merge, in auto mode

Check the mode first (`Set-AgentMode.ps1` prints it). In auto mode, merge your own PR, or a Dependabot PR this step allows, when all of these hold; otherwise fix what's missing, or report and stop:

- **It isn't a release PR.** `gh pr view <n> --json headRefName` doesn't start with `release-please--`. Never merge one, in either mode: releases are the owner's (ADR-0035).
- **If it changes the guardrails, the owner has said yes for this head commit.** Run `gh pr diff <n> --name-only`, then read those files' changes. The guardrails are:
  - `AGENTS.md`'s "Working modes" or "Always ask" sections, or SEC-003 in `docs/standards/security.md`;
  - `.claude/settings.json` or the `Set-AgentMode.ps1` script;
  - this skill or the code-review instructions (`docs/code-review.md`, generated into `.github/instructions/code-review.instructions.md`);
  - a ruleset, branch protection or the merge settings;
  - a CI check, if removed or weakened;
  - the Dependabot cooldown in `.github/dependabot.yml` (in the kit, `templates/app/.github/dependabot.yml` too), if shortened (any `*-days` value lowered, or any wait below 7 days, 14 for a NuGet or SDK major) or narrowed (an `exclude` or `include` list);
  - `New-KitApp`'s step that turns on Dependabot alerts and security updates, if removed or weakened.

  A PR that changes any of them needs the owner's yes for that PR, at its head commit. Once every other condition below holds, ask him in the chat (COM-007), naming the head commit. On his yes, record it in a PR comment before you merge, because GitHub and Copilot can't see the chat: "Owner's yes, given in chat on <date>, at <head commit>", with his words quoted. Then merge it as below. A commit pushed after his yes needs a new yes. Start your next task while you wait.
- **If it's Dependabot's, it's only a patch or minor update of NuGet packages, .NET tools or the .NET SDK** (ADR-0041). All of these must hold, or the PR is the owner's to merge:
  - **GitHub says it's Dependabot's.** `gh pr view <n> --json author,isCrossRepository,headRefName` shows the author `app/dependabot`, `isCrossRepository` false, and a head branch starting `dependabot/`. A title or a commit author alone proves nothing: anyone can set them.
  - **The version change is a patch or minor.** Read it in the title and in the diff of `Directory.Packages.props`, `.config/dotnet-tools.json` or `global.json`. A major update, a GitHub Actions bump, a grouped PR with any major in it, or one you can't classify is the owner's. Any update of a 0.x package (0.13.5 → 0.13.6 as much as 0.13 → 0.14) is the owner's, since SemVer lets a 0.x version break anything. For the SDK, the third number holds the feature band: 10.0.403 → 10.0.500 is a minor, and 10.x → 11.x a major.
  - **It changes only those files and `packages.lock.json` files, and every commit is Dependabot's or the lock-file workflow's** (`github-actions[bot]`). Check with `gh pr view <n> --json files,commits`. A security update that fixes a transitive package may add a direct reference to a `.csproj`; that makes it the owner's.
  - **You've read the new version's release notes and checked its license and deprecation status.** A license change, new telemetry, or new build-time behavior (MSBuild targets, analyzers, source generators) makes it the owner's.

  Any other bot's PR is the owner's too.
- **It's open, and CI has passed at its head commit:** `gh pr view <n> --json state,headRefOid,mergeStateStatus` shows `OPEN` and `CLEAN`, and `gh pr checks <n>` passes.
- **Copilot has reviewed that head commit,** and no blocking or should-fix finding from it is unanswered. `Get-OpenFinding` lists nothing open from Copilot or a person.
- **No question the PR depends on is waiting for the owner** (COM-007). A question that a later PR can settle doesn't hold this one; say so in the chat.
- **The description is complete:** the template's sections are filled in, with the red→green table and counts from the head commit. For a PR whose description a bot writes, DOD-006's comment holds them, and it names this head commit.

Then run `gh pr merge <n> --merge --match-head-commit <sha>` on its own, never inside a script, with the head commit the conditions were checked at (for a guardrail PR, the one the owner said yes to): GitHub refuses the merge if the head has moved since. Run `git switch main` and `git pull --ff-only`. If the merge updated the release PR, check its CI.

## 6. Report

Tell the owner what changed and what the evidence shows, with links. In auto mode, say what merged. Say what wasn't verified. Ask every pending question in the chat, one at a time (COM-007).
