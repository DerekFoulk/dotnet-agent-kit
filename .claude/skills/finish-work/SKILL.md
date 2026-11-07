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

**Every fix gets its own review.** After fixing findings, run the `reviewer` again on the new commits (`git log <reviewed head>..HEAD`), and repeat until a run finds nothing blocking or should-fix. A fix that nobody reviewed can break something the first review passed.

Keep each review's report: it goes on the PR (step 4).

## 3. Check the PR state

If a PR already exists for this branch, run `gh pr view <n> --json state,mergedAt` **before pushing or reporting**. The owner merges on his own schedule. If it's merged, branch from the old branch, then open a new PR into `main` for the new commits. This step comes from `docs/corrections-log.md` (2026-11-02).

## 4. Open the PR

- The title is a Conventional Commit (it becomes the merge commit message).
- Use `.github/pull_request_template.md` and fill in the red→green table from `git log`.
- List the decisions the owner must make and any `proposed` rules he must ratify.
- **Post the reviews on the PR.** Add each `reviewer` report, with how every finding was fixed or answered, as a PR comment (`gh pr comment <n> --body-file <file>`), so the owner sees what was checked without reading the session. Post a new comment for each later review.
- Don't merge. The owner merges, or tells you to for that PR.
- **Watch for reviews.** In the Claude Code desktop app, turn on the PR monitor with auto-fix for the new PR; the owner approves it. Per the app's tool description, the app then wakes the session when a review, a CI failure or a merge conflict arrives. When a review lands, from Copilot or a person, run `address-review`. In other tools, run `Get-OpenFinding` (from `KitReview.psm1`) before reporting on the PR.

## 5. Report

Tell the owner what changed and what the evidence shows, with links. Say what wasn't verified. Ask one question, if one is pending.
