---
topic: definition-of-done
rules:
  - id: DOD-001
    statement: "Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR."
    why: "A shared, checkable meaning of done stops premature done reports."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ruleset: main protection requires the CI checks to pass before merging: in the kit, the dotnet and kit checks; in an app, the .NET CI's build and secret scan and the app checks (templates/github/main-protection.json)"
      - kind: advisory
        in: [kit, app]
        how: "updating docs and ADRs in the same PR, which no tool can judge"
    projectTypes: [all]
    paths: ["**"]
  - id: DOD-002
    statement: "Report done only with evidence (commands run, counts, links), and state \"not verified\" wherever something wasn't."
    why: "Done was reported before it was verified at least three times."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the finish-work skill asks for evidence, and code review checks the PR's claims; scored on practice tasks"
    projectTypes: [all]
    paths: ["**"]
  - id: DOD-003
    statement: "Before the owner reviews, an independent read-only reviewer agent that hasn't seen the work (.claude/agents/reviewer.md) reviews every branch against the kit's code-review instructions (docs/code-review.md) and rule files, before its pull request opens (for a PR a bot opens, before it merges) and again after each round of fixes; the reviewer ranks each finding Blocking, Should fix or Consider, the implementing agent answers it (DOD-005), and reviews end at the first round with nothing blocking or should-fix."
    why: "A reviewer with fresh eyes caught four blocking issues in one project, and reviewing every nit fix again turned PRs 32 and 33 into hours-long loops (owner, 2026-11-09). GitHub Copilot code review stood in for the reviewer agent from 2026-11-12 (ADR-0064) until the owner's AI credits ran out; on 2026-11-14 he turned it off and brought the agent back (ADR-0067)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["ADR-0010", "owner, 2026-11-09", "owner, 2026-11-14", "ADR-0067"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the reviewer agent exists, read-only and pointed at docs/code-review.md (tools/tests/AgentConfig.Tests.ps1), and Export-KitApp gives every app a copy (tools/tests/Export-KitApp.Tests.ps1); running it, ranking each finding and ending the reviews are finish-work steps no tool enforces. Answered findings are DOD-005's"
    projectTypes: [all]
    paths: ["**"]
  - id: DOD-004
    statement: "Every PR uses the PR template, including the red-to-green evidence table; a PR whose description a bot writes carries the evidence as DOD-006 says, and a release PR is the owner's."
    why: "The owner reviews TDD evidence without digging through commits."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-09"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: ".github/pull_request_template.md pre-fills every PR and code review checks the evidence table; no CI check reads PR descriptions"
    projectTypes: [all]
    paths: ["**"]
  - id: DOD-005
    statement: "Every review finding on a PR is checked against the code and answered with evidence; a fixed or already-fixed one is resolved as addressed, a wrong one as incorrect, and one left unfixed as won't fix: in review mode only with the owner's OK, in auto mode with the agent's reason in the reply."
    why: "The owner asked agents to react to every Copilot review on their own, with an honest resolution on each thread, and then chose auto mode by default (ADR-0035)."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-03", "ADR-0028", "owner, 2026-11-07", "ADR-0035"]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ruleset: main protection requires review conversations resolved before merging (since 2026-11-09)"
      - kind: gate
        in: [app]
        how: "ruleset: every app New-KitApp creates gets the same rule (on GitHub Free, available on public apps; enforcement there not yet verified, ADR-0033)"
      - kind: advisory
        in: [kit, app]
        how: "answering each finding with evidence: the address-review skill and tools/KitReview.psm1 guide it; the module refuses won't fix without -OwnerApproved, a switch it takes on trust, passed in auto mode under ADR-0035's standing approval"
    projectTypes: [all]
    paths: ["**"]
  - id: DOD-006
    statement: "A PR whose description a bot writes, such as Dependabot's, keeps that description. In either mode, before the PR is merged, the agent handling it posts the template's sections as a PR comment: 'What and why'; 'Red → green evidence' for any behavior change an agent added, one row per test-list item (a bot's own commits need none); 'Checks run', with code review's findings and how each was answered; 'For the owner'; and 'Not verified'. The comment names the head commit its counts come from, which must be the commit the PR is merged at: when the head moves, as it does when a lock-file refresh pushes or Dependabot rebases, the agent posts a new one. That comment stands in for the complete description a merge needs, whoever merges the PR. Release PRs are the owner's, so this doesn't cover them."
    why: "Dependabot writes its own description, so DOD-004's template can't apply to its PRs, yet the owner still needs the evidence, and a merge needs a complete description; PRs 25 and 26 were merged with the evidence in a PR comment instead."
    layer: owner
    basis: preference
    status: accepted
    sources: ["owner, 2026-11-01", "owner, 2026-11-07", "ADR-0035", "owner, 2026-11-09", "ADR-0041"]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "the agent handling the PR posts the comment; no CI check reads PR comments"
    projectTypes: [all]
    paths: ["**"]
---

# Definition of done

Done means verified, with the evidence shown. The `finish-work` skill (`.claude/skills/finish-work/SKILL.md`) walks through this list before a PR is opened.
