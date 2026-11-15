# ADR-0067: The reviewer agent replaces Copilot code review

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

ADR-0064 (2026-11-12) made GitHub Copilot code review the kit's independent reviewer: the "main protection" ruleset's `copilot_code_review` rule requested a review on every PR and every push to it, and the read-only reviewer agent was removed. Each Copilot review draws on the PR author's GitHub AI credits, and the review fails when they run out.

By 2026-11-14 the owner's credits had run out. On PR 74, Copilot's review failed ("insufficient remaining quota"), and a read-only reviewer agent working from `docs/code-review.md` stood in for it, as before ADR-0064. The owner said Copilot review should be off, and approved removing the rule from the kit's live ruleset; that's done (checked 2026-11-14: the ruleset's rules are `deletion`, `non_fast_forward`, `pull_request`, `required_status_checks` and `code_scanning`).

The kit's rules still described the Copilot design: DOD-003, AGENTS.md, CLAUDE.md, README, the `finish-work`, `start-work` and `address-review` skills, the PR template, and `templates/github/main-protection.json`, which gave every new app the rule. Two sources stating different facts is what CRF-003 forbids.

## Options

### Option 1: The read-only reviewer agent reviews every branch, against `docs/code-review.md`

The agent ADR-0010 defined comes back as `.claude/agents/reviewer.md`. It reviews a plan before any code, and a branch before its PR opens and after each round of fixes, against `docs/code-review.md`, the checklist Copilot read.

- **Trade-offs:** Independent eyes on every change again, and on plans, which Copilot never saw. The agent can run commands, so it can rerun a gate or probe a Pester test with `Invoke-Mutant.ps1`. Each round runs in the owner's Claude usage (the three rounds of PR 63 took about 150,000 to 200,000 tokens each), and its findings reach the PR only as a comment the agent posts.
- **Reversibility:** Easy: the agent is one file, and Copilot's rule is one ruleset entry.
- **Risk:** Low. It's the design the kit ran from 2026-11-01 to 2026-11-12, and PR 74 used it.

### Option 2: Keep the Copilot design, and wait for the credits to return

- **Trade-offs:** No change to the docs, but no review at all until the credits return, and then the same failure each time they run out. The rule is already off, so the docs would keep describing something that doesn't happen.
- **Reversibility:** Easy.
- **Risk:** High: PRs either wait indefinitely or merge with no review.

### Option 3: The agent runs Claude Code's built-in `/code-review` skill

- **Trade-offs:** Lighter, but it doesn't know the kit's checklist unless told, and it runs in the session that wrote the change, so it isn't independent.
- **Reversibility:** Easy.
- **Risk:** Medium: it misses the kit-specific checks, such as a rule's `basis` and `in` values.

### Option 4: CI only, no review

- **Trade-offs:** Cheapest, but nothing looks for what the checks can't see: design, misleading docs, a test that passes when the code is wrong.
- **Reversibility:** Easy.
- **Risk:** High for quality.

## Recommendation

Option 1: it's what PR 74 already did, it can run the gates itself, which Copilot can't, and it reviews plans too.

## Decision

Accepted (owner, 2026-11-14), with these answers:

| Question | Owner's answer |
|---|---|
| Which review replaces Copilot on every kit PR | The reviewer agent, against `docs/code-review.md` |
| Do new apps still get the `copilot_code_review` rule | No, remove it from `templates/github/main-protection.json` |
| Keep generating `.github/instructions/code-review.instructions.md` | Yes |

## Consequences

- **DOD-003:** the read-only reviewer agent reviews every branch against `docs/code-review.md` and the rule files, before its PR opens and after each round of fixes; reviews end at the first round with nothing blocking or should-fix. Every part of its enforcement is advisory: tests check the agent exists and apps get it, but nothing makes an agent run it.
- **Files:**
  - `.claude/agents/reviewer.md` comes back. Its procedure is its own (plan review, one focus per reviewer, TDD evidence, mutation probes in the kit); what it looks for, and how it ranks findings, is `docs/code-review.md`'s, so the checklist has one source.
  - `docs/code-review.md` stays, and `Build-AgentRules.ps1` keeps generating `.github/instructions/code-review.instructions.md` from it, so a Copilot review the owner asks for by hand uses the same checklist.
  - `Export-KitApp` copies the reviewer agent to apps again.
  - `templates/github/main-protection.json` drops the `copilot_code_review` rule.
- **Process:**
  - `finish-work` step 2 is the reviewer agent's rounds again, before the PR opens, with each report posted on the PR. Its merge condition is a clean round on the head commit, or on the commit before the final round's nit fixes, when those change no behavior and are listed in its PR comment.
  - `start-work` step 5 runs the reviewer on a non-trivial plan again (owner, 2026-11-10).
  - The guardrail list (AGENTS.md "Working modes", `finish-work` step 5) names the `reviewer` agent again, beside the code-review instructions: it enforces DOD-003, so a change to it needs the owner's yes.
  - `finish-work` step 4 waits for CI with `Wait-PullRequest -For Checks` after each push. It waits with `-For Review` only when the owner has asked for a Copilot review, because otherwise none comes (`Wait-PullRequest` came in PR 73, while this ADR was being written).
  - `address-review` stays for a review that lands on the PR, from a person or from a Copilot review requested by hand; `KitReview.psm1` still reads Copilot's.
  - AGENTS.md, CLAUDE.md, README, the PR template and the app template say the same.
- **Cost:** each round runs in the owner's Claude usage, not GitHub AI credits.
- **Apps made before this change** get the agent through the kit sync. A ruleset that already has the Copilot rule keeps it until the owner removes it, because `New-KitApp` sets rulesets once.
- **ADR-0064** is superseded. ADR-0010's reviewer is back in force.
- **Update (2026-11-14):** ADR-0068 changes how this runs, to spend less Claude usage. `Wait-PullRequest` runs in the foreground (9 minutes by default), not in the background. Fix rounds review only the fix commits, on a cheaper model when the diff is small. The first round and the stopping rule are unchanged.

## Pillars affected

Operational Excellence: reviews happen again on every change, and the docs match the repo's real settings. Cost Optimization: reviews use Claude usage per round instead of GitHub AI credits per push.

## Sources

- owner, 2026-11-14
- https://github.com/DerekFoulk/dotnet-agent-kit/pull/74, retrieved 2026-11-14
