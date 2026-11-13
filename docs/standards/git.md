---
topic: git
rules:
  - id: GIT-001
    statement: "Pull requests merge into main with a merge commit; squash and rebase merges are disabled."
    why: "Keeps each red and green commit and the PR boundary in history; an agent-chosen rebase merge once forced three history rewrites."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0007"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ruleset: main protection allows merge commits only (pull_request rule, allowed_merge_methods merge)"
    scope: core
    paths: ["**"]
  - id: GIT-002
    statement: "Work on short-lived branches from main (GitHub Flow); every change reaches main through a pull request, never a direct push."
    why: "The owner accepted GitHub Flow; it fits continuously delivered software."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0007"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ruleset: main protection requires a pull request"
    scope: core
    paths: ["**"]
  - id: GIT-003
    statement: "Nobody force-pushes main or deletes it (GIT-002 keeps direct pushes out); agents merge a PR only as the working mode allows (in review mode, when the owner says so for that PR), never a release PR, and a change to the guardrails only on the owner's yes for that PR at its head commit."
    why: "Branch protection was approved in one project; the owner then chose auto mode by default, where the agent merges its own PRs once they're green and reviewed, and kept releases his (ADR-0035)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0007", "ADR-0010", "ADR-0035", "owner, 2026-11-09", "owner, 2026-11-10"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ruleset: main protection blocks force-pushes and deletion"
      - kind: advisory
        in: [kit, app]
        how: "merging by mode, backed in review mode by the gh pr merge ask rule Set-AgentMode.ps1 adds to .claude/settings.local.json"
    scope: core
    paths: ["**"]
  - id: GIT-004
    statement: "Commit subjects and PR titles are Conventional Commits, with type feat, fix, docs, style, refactor, perf, test, build, ci, chore or revert; ! or BREAKING CHANGE marks a major change. git revert's own 'Revert \"<subject>\"' form is accepted when the reverted subject is."
    why: "Commit types drive automatic versions (ADR-0019), and the merge commit message is the PR title (ADR-0022)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0006", "ADR-0022", "ADR-0027"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: pr-title.yml checks the PR title, re-run when it's edited; kit-checks.reusable.yml checks every commit subject"
      - kind: gate
        in: [app]
        how: "ci: app-checks.reusable.yml checks the PR title and every commit subject"
      - kind: advisory
        in: [kit, app]
        how: "early feedback, not a gate: the commit-msg hook (.githooks, ADR-0027) applies the same rule before each commit; CI is the gate"
    scope: core
    paths: ["**"]
  - id: GIT-005
    statement: "A test-first commit carries the trailer 'TDD: red' and the commit that makes it pass carries 'TDD: green', in the message's final paragraph."
    why: "Makes the red-then-green order visible and checkable in history."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "ADR-0006"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: kit-checks.reusable.yml runs tools/Test-RedGreenOrder.ps1 on the branch's own commits in every pull request; commits made after 2026-11-02 count only with a real trailer"
      - kind: gate
        in: [app]
        how: "ci: app-checks.reusable.yml runs tools/Test-RedGreenOrder.ps1 the same way"
    scope: core
    paths: ["**"]
---

# Git

GitHub Flow with merge commits only (ADR-0007). History should tell the story as it happened, so every red and green commit stays visible.

## Commit message shape

```text
test: reject empty bookmark titles

TDD: red
Co-Authored-By: ...
```

Trailers must share the final paragraph. Git reads only the last paragraph as trailers, so a `TDD:` line in its own paragraph followed by `Co-Authored-By:` isn't one (ADR-0006). The red→green check also accepts the line anywhere in the body, so build steps 1 and 2 still count.
