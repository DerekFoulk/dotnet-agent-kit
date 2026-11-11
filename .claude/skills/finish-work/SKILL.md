---
name: finish-work
description: Verify a finished change against the definition of done, get an independent review, and open the pull request with evidence. Use when the test list is empty and before telling the owner anything is done.
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

## 2. Independent review

Run the `reviewer` subagent on the branch. Fix each finding test-first, or answer it with a reason. Then run step 1 again.

**Give it what you've already run.** Pass the gate results from step 1 (each command and its count) in the reviewer's prompt, so it checks the code and the claims instead of repeating every gate. It reruns a gate only when what it reviews could change the result.

**Run focused reviewers side by side** (owner, 2026-11-10). For a change that touches code and docs, run two or three reviewers at once, each with one focus named in its prompt: the code and its tests; the documents, against each other and the rules; the guardrails and "Always ask". Together they make one round. A docs-only change needs one.

**Don't wait idle.** While a review runs, start the next task on its own branch.

**Every fix gets its own review.** After fixing findings, run the `reviewer` again on the new commits (`git log <reviewed head>..HEAD`), and repeat until a round finds nothing blocking or should-fix. A round is every reviewer you ran on that head, side by side or alone. A fix that nobody reviewed can break something the first review passed.

**A round with nothing blocking or should-fix, from any of its reviewers, ends the reviews** (owner, 2026-11-09). Fix its nits only when they're cheap and change no behavior, with no further round, and list those commits in that round's PR comment; answer the rest with a reason, or note them for a later PR. A nit whose fix would change behavior goes to a later PR: fixing it here would need another round, and each round finds new nits. The same rule ends a plan review.

Keep each review's report: it goes on the PR (step 4).

## 3. Check the PR state

If a PR already exists for this branch, run `gh pr view <n> --json state,mergedAt` **before pushing or reporting**. The owner may merge on his own schedule. If it's merged, branch from the old branch, then open a new PR into `main` for the new commits. This step comes from `docs/corrections-log.md` (2026-11-02).

## 4. Open the PR

- The title is a Conventional Commit (it becomes the merge commit message).
- Use `.github/pull_request_template.md` and fill in the red→green table from `git log`. A PR whose description a bot writes, such as Dependabot's, keeps it: post the template's sections as a PR comment instead, naming the head commit (DOD-006), and a new one whenever the head moves.
- List the decisions the owner must make and any `proposed` rules he must ratify. **Ask each one in the chat too, with its recommendation** (COM-007): he may not read the PR before it merges.
- **Post the reviews on the PR.** Add each `reviewer` report, with how every finding was fixed or answered, as a PR comment (`gh pr comment <n> --body-file <file>`), so the owner sees what was checked without reading the session. Post a new comment for each later review.
- In review mode, don't merge: the owner merges, or tells you to for that PR.
- **Watch for reviews.** In the Claude Code desktop app, turn on the PR monitor with auto-fix for the new PR; the owner approves it. Per the app's tool description, the app then wakes the session when a review, a CI failure or a merge conflict arrives. When a review lands, from Copilot or a person, run `address-review`. In other tools, run `Get-OpenFinding` (from `KitReview.psm1`) before reporting on the PR.

## 5. Merge, in auto mode

Check the mode first (`Set-AgentMode.ps1` prints it). In auto mode, merge your own PR, or a Dependabot PR this step allows, when all of these hold; otherwise fix what's missing, or report and stop:

- **It isn't a release PR.** `gh pr view <n> --json headRefName` doesn't start with `release-please--`. Never merge one, in either mode: releases are the owner's (ADR-0035).
- **If it changes the guardrails, the owner has said yes for this head commit.** Run `gh pr diff <n> --name-only`, then read those files' changes. The guardrails are:
  - `AGENTS.md`'s "Working modes" or "Always ask" sections, or SEC-003 in `docs/standards/security.md`;
  - `.claude/settings.json` or the `Set-AgentMode.ps1` script;
  - this skill or `.claude/agents/reviewer.md`;
  - a ruleset, branch protection or the merge settings;
  - a CI check, if removed or weakened;
  - the Dependabot cooldown in `.github/dependabot.yml` (in the kit, `templates/app/.github/dependabot.yml` too), if shortened (any `*-days` value lowered, or any wait below 7 days, 14 for a NuGet or SDK major) or narrowed (an `exclude` or `include` list);
  - `New-KitApp`'s step that turns on Dependabot alerts and security updates, if removed or weakened.

  A PR that changes any of them needs the owner's yes for that PR, at its head commit. Once every other condition below holds, ask him in the chat (COM-007), naming the head commit; on his yes, merge it as below. A commit pushed after his yes needs a new yes. Start your next task while you wait.
- **If it's Dependabot's, it's only a patch or minor update of NuGet packages, .NET tools or the .NET SDK** (ADR-0041). All of these must hold, or the PR is the owner's to merge:
  - **GitHub says it's Dependabot's.** `gh pr view <n> --json author,isCrossRepository,headRefName` shows the author `app/dependabot`, `isCrossRepository` false, and a head branch starting `dependabot/`. A title or a commit author alone proves nothing: anyone can set them.
  - **The version change is a patch or minor.** Read it in the title and in the diff of `Directory.Packages.props`, `.config/dotnet-tools.json` or `global.json`. A major update, a GitHub Actions bump, a grouped PR with any major in it, or one you can't classify is the owner's. Any update of a 0.x package (0.13.5 → 0.13.6 as much as 0.13 → 0.14) is the owner's, since SemVer lets a 0.x version break anything. For the SDK, the third number holds the feature band: 10.0.403 → 10.0.500 is a minor, and 10.x → 11.x a major.
  - **It changes only those files and `packages.lock.json` files, and every commit is Dependabot's or the lock-file workflow's** (`github-actions[bot]`). Check with `gh pr view <n> --json files,commits`. A security update that fixes a transitive package may add a direct reference to a `.csproj`; that makes it the owner's.
  - **You've read the new version's release notes and checked its license and deprecation status.** A license change, new telemetry, or new build-time behavior (MSBuild targets, analyzers, source generators) makes it the owner's.

  Any other bot's PR is the owner's too.
- **It's open, and CI has passed at its head commit:** `gh pr view <n> --json state,headRefOid,mergeStateStatus` shows `OPEN` and `CLEAN`, and `gh pr checks <n>` passes.
- **The latest `reviewer` round is on that head commit,** with no unanswered blocking or should-fix finding, and it's posted on the PR. The one exception is step 2's final round: the head may be a few commits past it when those commits only fix that round's nits, change no behavior, and are listed in its PR comment. `Get-OpenFinding` lists nothing open from Copilot or a person.
- **No question the PR depends on is waiting for the owner** (COM-007). A question that a later PR can settle doesn't hold this one; say so in the chat.
- **The description is complete:** the template's sections are filled in, with the red→green table and counts from the head commit. For a PR whose description a bot writes, DOD-006's comment holds them, and it names this head commit.

Then run `gh pr merge <n> --merge` on its own, never inside a script. Run `git switch main` and `git pull --ff-only`. If the merge updated the release PR, check its CI.

## 6. Report

Tell the owner what changed and what the evidence shows, with links. In auto mode, say what merged. Say what wasn't verified. Ask every pending question in the chat, one at a time (COM-007).
