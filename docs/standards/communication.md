---
topic: communication
rules:
  - id: COM-001
    statement: "Lead every question or proposal with one recommendation and a one-line reason; list options only when the answer depends on the owner's personal preference."
    why: "Options without a recommendation left the owner to research and decide alone, three times in one project."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: conversation can't be checked by a tool; scored on every practice task (practice/)"
    scope: core
    paths: ["**"]
  - id: COM-002
    statement: "On first use, explain any term, tool or document the owner hasn't used himself, in plain words with an example; refer to documents by path, never by a nickname."
    why: "Unexplained terms and made-up names were corrected more than five times across three projects."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: conversation can't be checked by a tool; scored on every practice task (practice/)"
    scope: core
    paths: ["**"]
  - id: COM-003
    statement: "When the owner answers a batch of questions, restate them with his answers as a table."
    why: "It confirms each answer was understood before work depends on it."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: conversation can't be checked by a tool; scored on every practice task (practice/)"
    scope: core
    paths: ["**"]
  - id: COM-004
    statement: "Say in one line what a command or script does before running it, and run it yourself whenever you can instead of handing it to the owner."
    why: "Commands were handed over instead of run many times in two projects; the owner asked agents to run things for him."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-31", "ADR-0011"]
    enforcement: "advisory: conversation can't be checked by a tool; scored on every practice task (practice/)"
    scope: core
    paths: ["**"]
  - id: COM-005
    statement: "Point to a button, setting or screen only after confirming it exists (current docs or a screenshot); otherwise say you're not sure, do the step yourself, or say how to check."
    why: "The owner couldn't find UI that agents described, four times across two projects."
    layer: owner
    status: accepted
    sources: ["owner, 2026-11-01"]
    enforcement: "advisory: conversation can't be checked by a tool; scored on every practice task (practice/)"
    scope: core
    paths: ["**"]
  - id: COM-006
    statement: "Make an improvement now when it is cheap, instead of deferring it."
    why: "The owner asks \"Can we do that now?\" when a cheap fix is postponed."
    layer: owner
    status: accepted
    sources: ["owner, 2026-10-26"]
    enforcement: "advisory: a judgment call; the reviewer agent flags deferred cheap fixes"
    scope: core
    paths: ["**"]
---

# Communication

How agents talk to the owner. Each rule comes from repeated owner feedback (brief §1, themes 5–8). No tool can check a conversation, so these rules are advisory. The practice tasks score them on every run (checkpoint §4), and the advisory list is expected to stay here.

## In practice

- **A question:** "Should the import accept CSV only? Recommended: yes, because every source you named exports CSV. JSON can come later without breaking anything."
- **A new term:** "Pester (PowerShell's standard test framework) runs these tests."
- **A document:** say `docs/adr/0007-github-flow-merge-commits.md`, not "the git ADR".
- **UI:** "I'm not sure where that setting is in this app, so I changed it from the command line instead."
