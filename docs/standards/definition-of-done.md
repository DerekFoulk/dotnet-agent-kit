---
topic: definition-of-done
rules:
  - id: DOD-001
    statement: "Work is done when it builds with zero warnings, every test passes, every CI gate passes, and docs and ADRs are updated in the same PR."
    why: "A shared, checkable meaning of done stops premature done reports."
    layer: owner
    status: proposed
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: until required CI checks on main (build step 4)"
    scope: core
    paths: ["**"]
  - id: DOD-002
    statement: "Report done only with evidence (commands run, counts, links), and state \"not verified\" wherever something wasn't."
    why: "Done was reported before it was verified at least three times."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: until the finish-work skill and reviewer agent (build step 3); scored on practice tasks"
    scope: core
    paths: ["**"]
  - id: DOD-003
    statement: "Before the owner reviews, an independent read-only reviewer that hasn't seen the work runs the gates and reports ranked findings."
    why: "A reviewer with fresh eyes caught four blocking issues in one project."
    layer: owner
    status: accepted
    sources: ["ADR-0010"]
    enforcement: "advisory: until the reviewer agent (build step 3)"
    scope: core
    paths: ["**"]
  - id: DOD-004
    statement: "Every PR uses the PR template, including the red-to-green evidence table."
    why: "The owner reviews TDD evidence without digging through commits."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: until .github/pull_request_template.md and the PR checks (build steps 3 and 4)"
    scope: core
    paths: ["**"]
---

# Definition of done

Done means verified, with the evidence shown. The `finish-work` skill (build step 3) walks through this list before a PR is opened.

## Pending ratification

DOD-001 was written by an agent. It's consistent with your stated rules, but you never stated it as one rule, so it stays `proposed` until you accept it.
