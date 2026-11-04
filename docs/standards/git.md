---
topic: git
rules:
  - id: GIT-001
    statement: "Pull requests merge into main with a merge commit; squash and rebase merges are disabled."
    why: "Keeps each red and green commit and the PR boundary in history; an agent-chosen rebase merge once forced three history rewrites."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0007"]
    enforcement: "ruleset: main protection allows merge commits only (pull_request rule, allowed_merge_methods merge)"
    scope: core
    paths: ["**"]
  - id: GIT-002
    statement: "Work on short-lived branches from main (GitHub Flow) and merge through a pull request."
    why: "The owner accepted GitHub Flow; it fits continuously delivered software."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-26", "ADR-0007"]
    enforcement: "ruleset: main protection requires a pull request"
    scope: core
    paths: ["**"]
  - id: GIT-003
    statement: "Nobody pushes directly to main or force-pushes it; agents merge a PR only when the owner says so for that PR."
    why: "Branch protection was approved in one project; the owner has told agents to merge specific PRs, so the rule is per PR, not never."
    layer: owner
    status: proposed
    sources: ["ADR-0007", "ADR-0010"]
    enforcement: "ruleset: main protection blocks force-pushes and deletion and requires a pull request; merging only when told is advisory, backed by the gh pr merge ask rule in .claude/settings.json"
    scope: core
    paths: ["**"]
  - id: GIT-004
    statement: "Commit subjects and PR titles are Conventional Commits, with type feat, fix, docs, style, refactor, perf, test, build, ci, chore or revert; ! or BREAKING CHANGE marks a major change. git revert's own 'Revert \"<subject>\"' form is accepted when the reverted subject is."
    why: "Commit types drive automatic versions (ADR-0019), and the merge commit message is the PR title (ADR-0022)."
    layer: owner
    status: accepted
    sources: ["ADR-0006", "ADR-0022", "ADR-0027"]
    enforcement: "ci: pr-title.yml checks the PR title, re-run when it's edited; kit-checks.reusable.yml checks every commit subject; the commit-msg hook (.githooks, ADR-0027) applies the same rule before each commit"
    scope: core
    paths: ["**"]
  - id: GIT-005
    statement: "A test-first commit carries the trailer 'TDD: red' and the commit that makes it pass carries 'TDD: green', in the message's final paragraph."
    why: "Makes the red-then-green order visible and checkable in history."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "ADR-0006"]
    enforcement: "ci: kit-checks.reusable.yml runs tools/Test-RedGreenOrder.ps1 on the branch's own commits in every pull request; commits made after 2026-11-02 count only with a real trailer"
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

## Pending ratification

GIT-003 was approved in one project, and the brief recommends it for all of them (brief §7). It stays `proposed` until you accept it.
