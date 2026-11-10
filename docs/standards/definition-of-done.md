---
topic: definition-of-done
rules:
  - id: DOD-001
    statement: "Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR."
    why: "A shared, checkable meaning of done stops premature done reports."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
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
    statement: "Every PR uses the PR template, including the red-to-green evidence table; a PR whose description a bot writes carries the evidence as DOD-006 says, and a release PR is the owner's."
    why: "The owner reviews TDD evidence without digging through commits."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement: "advisory: .github/pull_request_template.md pre-fills every PR and the reviewer agent checks the evidence table; no CI check reads PR descriptions"
    scope: core
    paths: ["**"]
  - id: DOD-005
    statement: "Every review finding on a PR is checked against the code and answered with evidence; a fixed or already-fixed one is resolved as addressed, a wrong one as incorrect, and one left unfixed as won't fix: in review mode only with the owner's OK, in auto mode with the agent's reason in the reply."
    why: "The owner asked agents to react to every Copilot review on their own, with an honest resolution on each thread, and then chose auto mode by default (ADR-0035)."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-03", "ADR-0028", "owner, 2026-11-07", "ADR-0035"]
    enforcement: "ruleset: in the kit, main protection requires review conversations resolved before merging (since 2026-11-09), and apps' rulesets don't yet; answering each with evidence stays advisory: the address-review skill and tools/KitReview.psm1 guide it; the module refuses won't fix without -OwnerApproved, a switch it takes on trust, passed in auto mode under ADR-0035's standing approval"
    scope: core
    paths: ["**"]
  - id: DOD-006
    statement: "A PR whose description a bot writes, such as Dependabot's, keeps that description. In either mode, before the PR is merged, the agent handling it posts the template's sections as a PR comment: 'What and why'; 'Red → green evidence' for any behavior change an agent added, one row per test-list item (a bot's own commits need none); 'Checks run', with the reviewer agent's findings and how each was answered; 'For the owner'; and 'Not verified'. The comment names the head commit its counts come from, which must be the commit the PR is merged at: when the head moves, as it does when a lock-file refresh pushes or Dependabot rebases, the agent posts a new one. That comment stands in for the complete description a merge needs, whoever merges the PR. Release PRs are the owner's, so this doesn't cover them."
    why: "Dependabot writes its own description, so DOD-004's template can't apply to its PRs, yet the owner still needs the evidence, and a merge needs a complete description; PRs 25 and 26 were merged with the evidence in a PR comment instead."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-07", "ADR-0035", "owner, 2026-11-09", "ADR-0041"]
    enforcement: "advisory: the agent handling the PR posts the comment; no CI check reads PR comments"
    scope: core
    paths: ["**"]
---

# Definition of done

Done means verified, with the evidence shown. The `finish-work` skill (`.claude/skills/finish-work/SKILL.md`) walks through this list before a PR is opened.
