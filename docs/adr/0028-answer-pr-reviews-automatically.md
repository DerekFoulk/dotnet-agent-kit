# ADR-0028: Agents answer PR reviews themselves

- **Status:** Accepted
- **Date:** 2026-11-03

## Context

GitHub Copilot reviews every pull request in kit repos and posts a summary ("Changes recommended" or "Approval recommended") with one thread per issue. On PR 5, answering that review took four steps: check each finding against the code, fix the real ones test-first, push, then reply with evidence and resolve each thread. The owner asked for this to happen automatically on every PR, by every agent working in a kit repo, with each thread resolved as addressed, won't fix or incorrect.

Facts that shape the design (checked 2026-11-03):
- GitHub's GraphQL `resolveReviewThread` takes a `resolutionReason` of `ADDRESSED`, `WONT_FIX` or `INVALID` (read from the live API schema). The API has no field to read a reason back.
- Copilot keeps one review per pull request and updates it in place, so its findings can refer to commits older than the branch head.
- Copilot's summary can list an issue that has no inline thread.
- An agent can only react if something wakes it. The Claude Code desktop app has a PR monitor that wakes a session when review comments, CI failures or merge conflicts arrive. The owner approves turning it on.

## Options

### Option 1: A skill and a tested module, woken by the app's PR monitor

- **Trade-offs:** `.claude/skills/address-review` carries the procedure, read by Claude Code, Visual Studio and VS Code. `tools/KitReview.psm1` reads Copilot's verdict and threads, and resolves a thread only after replying with evidence, refusing a closed PR, an empty reply, or won't fix without the owner's OK. In Claude Code the monitor wakes the session; other tools run the skill when pointed at a review. It needs a running session; no review is handled while nothing runs.
- **Reversibility:** Easy. A skill, a module and an instruction.
- **Risk:** Low. The kit's own discipline (test-first, evidence, owner's call on won't fix) applies to every fix.

### Option 2: A GitHub Action that runs an agent whenever Copilot reviews

- **Trade-offs:** Fully automatic, even with no session open (for example, an action that runs Claude Code headless). Costs API usage, needs an API key stored as a repository secret, and gives an agent push rights, triggered by review text that someone could try to manipulate.
- **Reversibility:** Easy to remove; a leaked secret or a bad push is not.
- **Risk:** Medium. Cost, secret handling and prompt injection.

### Option 3: Copilot's own fixers (Copilot CLI `/pr fix feedback` or `/pr auto`, or "Fix with Copilot" on a comment)

- **Trade-offs:** Built in. `/pr fix feedback` applies requested changes, commits and pushes, then replies in each addressed thread and resolves it. It follows Copilot's process, not the kit's: nothing requires a red test first, evidence for an "incorrect", or the owner's OK before leaving a finding unfixed.
- **Reversibility:** Easy.
- **Risk:** Medium. Fixes that bypass the kit's rules.

### Option 4: Leave it to the owner to ask each time

- **Trade-offs:** No new parts. Every review waits for the owner to notice it and ask.
- **Reversibility:** Easy.
- **Risk:** Low, but it's the friction the owner asked to remove.

## Recommendation

Option 1: it makes every agent answer reviews the kit's way, and it costs nothing. Revisit Option 2 once the skill has proven itself by hand.

## Decision

Accepted as recommended (owner, 2026-11-03).

## Consequences

- `AGENTS.md` adds step 7, "Answer the review"; `finish-work` turns on the PR monitor and hands each review to `address-review`.
- `tools/KitReview.psm1` (`Get-CopilotReview`, `Get-ReviewThread`, `Resolve-ReviewThread`) is the one way agents read and resolve review threads.
- DOD-005 records the rule. It stays advisory unless the ruleset requires conversations resolved before merging, which is a separate decision for the owner.
- "Won't fix" is never an agent's decision alone: the module refuses it without `-OwnerApproved`.

## Pillars affected

Reliability: every reported problem gets checked, and fixed test-first if real. Operational Excellence: reviews are answered without the owner chasing them. Security: review text is treated as data, and no new secrets or push-capable automation are added.

## Sources

- owner, 2026-11-03
- https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/manage-pull-requests, retrieved 2026-11-03
