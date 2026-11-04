---
topic: definition-of-done
rules:
  - id: DOD-001
    statement: "Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR."
    why: "A shared, checkable meaning of done stops premature done reports."
    layer: owner
    status: proposed
    sources: ["owner, 2026-11-01"]
    enforcement: "ruleset: main protection requires the dotnet and kit CI checks to pass before merging; updating docs and ADRs in the same PR is advisory"
    scope: core
    paths: ["**"]
  - id: DOD-002
    statement: "Report done only with evidence (commands run, counts, links), and state \"not verified\" wherever something wasn't."
    why: "Done was reported before it was verified at least three times."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: the finish-work skill and reviewer agent ask for evidence; scored on practice tasks"
    scope: core
    paths: ["**"]
  - id: DOD-003
    statement: "Before the owner reviews, an independent read-only reviewer that hasn't seen the work runs the gates and reports ranked findings."
    why: "A reviewer with fresh eyes caught four blocking issues in one project."
    layer: owner
    status: accepted
    sources: ["ADR-0010"]
    enforcement: "advisory: the reviewer agent exists (.claude/agents/reviewer.md); running it is a finish-work step no tool enforces"
    scope: core
    paths: ["**"]
  - id: DOD-004
    statement: "Every PR uses the PR template, including the red-to-green evidence table."
    why: "The owner reviews TDD evidence without digging through commits."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: .github/pull_request_template.md pre-fills every PR and the reviewer agent checks the evidence table; no CI check reads PR descriptions"
    scope: core
    paths: ["**"]
  - id: DOD-005
    statement: "Every review finding on a PR is checked against the code and answered with evidence; a fixed or already-fixed one is resolved as addressed, a wrong one as incorrect, and one left unfixed as won't fix only with the owner's OK."
    why: "The owner asked agents to react to every Copilot review on their own, with an honest resolution on each thread."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-03", "ADR-0028"]
    enforcement: "advisory: the address-review skill and tools/KitReview.psm1 guide it; the module refuses won't fix without -OwnerApproved, a switch it takes on trust; the main ruleset doesn't yet require conversations resolved before merging"
    scope: core
    paths: ["**"]
---

# Definition of done

Done means verified, with the evidence shown. The `finish-work` skill (`.claude/skills/finish-work/SKILL.md`) walks through this list before a PR is opened.

## Pending ratification

DOD-001 was written by an agent. It's consistent with your stated rules, but you never stated it as one rule, so it stays `proposed` until you accept it.
