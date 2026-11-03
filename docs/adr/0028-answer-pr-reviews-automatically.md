# ADR-0028: Agents answer PR reviews themselves

- **Status:** Accepted
- **Date:** 2026-11-03

## Context

GitHub Copilot reviews every pull request in kit repos and posts a summary ("Changes recommended" or "Approval recommended") with one thread per issue. On PR 5, answering that review took four steps: check each finding against the code, fix the real ones test-first, push, then reply with evidence and resolve each thread. The owner asked for this to happen automatically on every PR, by every agent working in a kit repo, with each thread resolved as addressed, won't fix or incorrect.

Facts that shape the design (checked 2026-11-03):
- GitHub's GraphQL `resolveReviewThread` takes a `resolutionReason` of `ADDRESSED`, `WONT_FIX` or `INVALID` (read from the live API schema). The API has no field to read a reason back.
- On PRs 1–5, Copilot left one review per pull request, and its findings could refer to commits older than the branch head. Whether a re-review adds a new review or updates the old one isn't confirmed, so the module reads the latest.
- Copilot's summary can list an issue that has no inline thread.
- An agent can only react if something wakes it. The Claude Code desktop app offers a PR monitor. Its tool description says it wakes a session when review comments, CI failures or merge conflicts arrive; that hasn't been observed on a kit PR yet. The owner approves turning it on.

## Options

### Option 1: A skill and a tested module, woken by the app's PR monitor

- **Trade-offs:** `.claude/skills/address-review` carries the procedure, read by Claude Code, Visual Studio and VS Code. `tools/KitReview.psm1` lists what's open, combining Copilot's summary with every thread, and resolves a thread only after replying with evidence. It refuses a closed PR, an already-resolved thread, an empty reply, or won't fix without the owner's OK. In Claude Code the monitor wakes the session; other tools run the skill when pointed at a review. It needs a running session; no review is handled while nothing runs.
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
- `tools/KitReview.psm1` (`Get-CopilotReview`, `Get-ReviewThread`, `Get-OpenFinding`, `Resolve-ReviewThread`, `Add-ReviewReply`) is the one way agents read, answer and resolve review threads.
- DOD-005 records the rule. It stays advisory unless the ruleset requires conversations resolved before merging, which is a separate decision for the owner.
- "Won't fix" is never an agent's decision alone. The module refuses it without `-OwnerApproved`, but it can't check that the owner really approved, so that switch is a safeguard taken on trust, backed by the skill and the reviewer agent. Because agents post with the owner's GitHub account, the skill accepts that approval only in chat, never from a thread comment.
- A summary issue with no thread is answered with a PR comment that names it (`Copilot summary issue "<title>":`), so it isn't listed again.

## Pillars affected

Reliability: every reported problem gets checked, and fixed test-first if real. Operational Excellence: reviews are answered without the owner chasing them. Security: review text is treated as data, and no new secrets or push-capable automation are added.

## Sources

- owner, 2026-11-03
- https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/manage-pull-requests, retrieved 2026-11-03
- Claude Code desktop app, PR-monitor tool description (auto-fix), read 2026-11-03
- GitHub GraphQL schema, `PullRequestReviewThreadResolutionReason`, read from the live API 2026-11-03
