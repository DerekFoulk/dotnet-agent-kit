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
    statement: "Every PR uses the PR template, including the red-to-green evidence table."
    why: "The owner reviews TDD evidence without digging through commits."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
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
    status: proposed
    sources: ["owner, 2026-11-01", "owner, 2026-11-07", "ADR-0035"]
    enforcement: "advisory: the agent handling the PR posts the comment; no CI check reads PR comments"
    scope: core
    paths: ["**"]
---

# Definition of done

Done means verified, with the evidence shown. The `finish-work` skill (`.claude/skills/finish-work/SKILL.md`) walks through this list before a PR is opened.

## Pending ratification

DOD-006 was written by an agent. It adds an exception to DOD-004, a rule you stated, for PRs whose description a bot writes. It stays `proposed` until you accept it. Release PRs are bot PRs as well, but you merge those yourself. Accepting it also means changing the places that say a PR's description must use the template, so they point to DOD-006:
- DOD-004 itself, which should also say release PRs are yours, since release-please writes their description too;
- "Done means" in `AGENTS.md` and `templates/app/AGENTS.md`;
- "Working modes" in `AGENTS.md`, where auto mode merges only when "the description is complete", and the same words in ADR-0035;
- steps 4 and 5 of the `finish-work` skill.

"Working modes" and the `finish-work` skill are guardrails, so that PR is yours to merge.

DOD-006 doesn't decide who merges a bot's PR. Auto mode lets an agent merge only its own PR ("Working modes", ADR-0035, `finish-work` step 5), so today an agent merges a Dependabot PR only when you say so for that PR, as you did for PRs 25 and 26. Letting agents merge them in auto mode would change those three places too: a separate decision for you.
