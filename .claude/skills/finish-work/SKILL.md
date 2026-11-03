---
name: finish-work
description: Verify a finished change against the definition of done, get an independent review, and open the pull request with evidence. Use when the test list is empty and before telling the owner anything is done.
---

# Finish work

## 1. Verify, with evidence

Run every check and keep the output for the PR:

```powershell
dotnet build                               # zero warnings
Invoke-Pester -Path ./tools/tests          # all pass
./tools/Test-RuleSources.ps1               # exit 0
./tools/Test-AdrSections.ps1               # exit 0
./tools/Build-AgentRules.ps1 -Check        # exit 0; if not, run it without -Check and commit
./tools/Test-ConventionalTitle.ps1 -Range origin/main..HEAD   # exit 0
./tools/Test-RedGreenOrder.ps1 -Range origin/main..HEAD       # exit 0
```

CI runs the same checks on the PR; a local pass first saves a round trip.

Then confirm:
- Docs and ADRs are updated for the change.
- Every red commit has a green commit after it, and git reads both trailers (`git log --reverse --format='%h %s | %(trailers:key=TDD,valueonly)' main..HEAD`).
- Each red failed on an assertion, and each green passes from a clean checkout. Check that every new file is tracked (`git status --short --ignored`); an ignored config file passes locally and fails everywhere else.
- Anything you didn't verify is listed as "not verified".

## 2. Independent review

Run the `reviewer` subagent on the branch. Fix each finding test-first, or answer it with a reason. Then run step 1 again.

## 3. Check the PR state

If a PR already exists for this branch, run `gh pr view <n> --json state,mergedAt` **before pushing or reporting**. The owner merges on his own schedule. If it's merged, branch from the old branch, then open a new PR into `main` for the new commits. This step comes from `docs/corrections-log.md` (2026-11-02).

## 4. Open the PR

- The title is a Conventional Commit (it becomes the merge commit message).
- Use `.github/pull_request_template.md` and fill in the red→green table from `git log`.
- List the decisions the owner must make and any `proposed` rules he must ratify.
- Don't merge. The owner merges, or tells you to for that PR.
- **Watch for reviews.** In the Claude Code desktop app, turn on the PR monitor ("Auto-fix") for the new PR; the owner approves it. The app then wakes the session when a review, a CI failure or a merge conflict arrives. When a review lands, from Copilot or a person, run `address-review`. In other tools, check `Get-CopilotReview` (tools/KitReview.psm1) before reporting on the PR.

## 5. Report

Tell the owner what changed and what the evidence shows, with links. Say what wasn't verified. Ask one question, if one is pending.
