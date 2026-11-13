# ADR-0064: GitHub Copilot code review replaces the reviewer agent

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

Since ADR-0010, an independent read-only `reviewer` agent has reviewed every branch before its PR opens: it ran the gates in a fresh clone and reported ranked findings, and DOD-003 made a clean round the condition for a merge. Each round runs in the owner's Claude usage; the three rounds of PR 63 took about 150,000 to 200,000 tokens each.

On 2026-11-05 the owner turned off automatic GitHub Copilot code reviews, after they used 1,911 of his 7,000 GitHub AI credits. On 2026-11-12 he chose to switch reviews back to Copilot, and to let it replace the reviewer agent ("Yes, replace it").

What GitHub documents, checked 2026-11-12:
- A repository ruleset rule, "Automatically request Copilot code review" (`copilot_code_review` in the REST API), requests a review on every new PR. Its "Review new pushes" option (`review_on_push`) reviews each later push too; drafts are reviewed only when `review_draft_pull_requests` is on. Copilot posts one review even when several sources request it.
- Copilot code review reads path-specific instructions from `.github/instructions/*.instructions.md` on the PR's head branch. `excludeAgent: "cloud-agent"` keeps a file to code review alone.
- Each review uses the PR author's AI credits; the review fails when the quota runs out.

## Options

### Option 1: Copilot code review replaces the reviewer agent

The ruleset requests a Copilot review on every PR and push. The reviewer agent's checklist moves into `docs/code-review.md`, which `Build-AgentRules.ps1` turns into `.github/instructions/code-review.instructions.md`. CI keeps running every gate.

- **Trade-offs:** One review per push, on GitHub, with no Claude usage, and its threads sit on the PR where the owner sees them. Copilot can't run commands, so the reviewer's own gate runs and its mutation probes of Pester tests go away; CI runs the gates, and nightly Stryker covers C# tests. Copilot doesn't review plans, so the start-work plan review becomes a check against `plan-checklist`. Each push costs AI credits.
- **Reversibility:** Easy. The rule is one ruleset entry, and the checklist file can become an agent again.
- **Risk:** Medium. Copilot may miss what the reviewer agent caught, such as a wrong `in` value in a rule; the code-review instructions name those checks, and CI catches what a tool can.

### Option 2: Use both

- **Trade-offs:** Two independent reviews, but both costs, and two sets of findings to reconcile on every PR.
- **Reversibility:** Easy.
- **Risk:** Low for quality, high for cost and time.

### Option 3: Keep the reviewer agent

- **Trade-offs:** No change; the reviews keep running gates and probes, in Claude usage.
- **Reversibility:** Easy.
- **Risk:** Low; not what the owner chose.

## Recommendation

Option 1: the owner chose it, and CI already runs every gate the reviewer ran, so Copilot's review of the diff is the part that was independent.

## Decision

Accepted (owner, 2026-11-12: "Yes, replace it").

## Consequences

- **DOD-003:** Copilot reviews every PR and every push to it. The agent ranks each finding Blocking, Should fix or Consider, answers it (DOD-005), and the reviews end at the first Copilot review of the head commit with nothing blocking or should-fix.
- **Rulesets:** `templates/github/main-protection.json` gains the `copilot_code_review` rule, with `review_on_push` on and drafts off, so every new app gets it. The kit's own "main protection" ruleset gets the same rule, a ruleset change made on the owner's yes.
- **Files:**
  - `docs/code-review.md` holds the checklist.
  - `Build-AgentRules.ps1` generates `.github/instructions/code-review.instructions.md` from it. That way an app, which rebuilds that folder itself, gets it too.
  - `Export-KitApp` copies the source to apps.
  - `.claude/agents/reviewer.md` is removed.
- **Process:**
  - `finish-work` step 2 is Copilot's review, answered with `address-review`. Its merge condition is a Copilot review of the head commit.
  - The guardrail list names the code-review instructions in place of the reviewer agent.
  - The PR template's review line names Copilot.
  - CLAUDE.md, AGENTS.md, README and the app template say the same.
- **Advisory parts** of rules that said "checked by the reviewer agent" now say code review checks them.
- **If Copilot can't review,** for example when the owner's AI credits run out, the agent tells the owner and the PR waits.
- **Apps made before this change** get the instructions through the kit sync. Their ruleset gains the rule only when the owner adds it, because `New-KitApp` sets rulesets once.

## Pillars affected

Cost Optimization: reviews use GitHub AI credits per push, not Claude usage per round. Operational Excellence: review findings live on the PR, where the owner and the rulesets see them.

## Sources

- owner, 2026-11-12
- https://docs.github.com/en/copilot/how-tos/use-copilot-agents/request-a-code-review/configure-automatic-review, retrieved 2026-11-12
- https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions, retrieved 2026-11-12
- https://docs.github.com/en/rest/repos/rules, retrieved 2026-11-12
