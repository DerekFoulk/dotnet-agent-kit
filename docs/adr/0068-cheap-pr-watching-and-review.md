# ADR-0068: Watch pull requests and review fixes at the lowest Claude usage

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

On 2026-11-14 the owner asked for "a cheap, yet responsive PR monitoring" and "quality PR review like you've been doing", with credit usage kept "as low as it can be, without sacrificing quality", and for the kit to work the same way.

Claude usage is spent per model call, and each call carries the whole conversation. Claude Code's cost guide says so ("Claude Code sends your full conversation with every request"). It names scheduled tasks and messages from other sessions as idle costs, recommends clearing between unrelated tasks, and recommends a smaller model for subagents. Time spent waiting in a tool call costs nothing. What costs is each time the agent is woken, and how long the conversation is when it is. ADR-0067 made the reviewer agent, which runs in the owner's Claude usage, review every branch and every round of fixes.

What PR #73 showed:
- **Background waits came late.** A background `Wait-PullRequest` finished at 07:19:58 local time, and its notice reached the session 6.5 hours later, with a message the owner had typed hours before. The System log showed no sleep in between.
- **The desktop app's PR monitor woke the session about 20 times.** Most wake-ups relayed reviews already answered, or Copilot's quota notes. It doesn't report a passing CI, which `Wait-PullRequest` does.
- **Full review rounds cost 101,000 to 184,000 tokens each.** A Sonnet round on a three-line fix found what it needed in 16 seconds and 77,000 tokens.

Kit CI runs in 4 to 6 minutes (`gh run list`, 2026-11-14). A Claude Code tool call can run for at most 10 minutes, and `Wait-PullRequest` waited 30 minutes by default, so a foreground call with the default would be cut off.

## Options

### Option 1: Foreground waits, the monitor off by default, scoped fix rounds, a fresh session per PR

- `Wait-PullRequest` waits 9 minutes by default, and agents run it in the foreground: one call covers kit CI. Never a loop of short waits, and never a background job. While the owner decides something, the turn ends.
- The desktop app's PR monitor is optional, off by default for kit PRs.
- The first review round stays full, on the session's model, with focused reviewers side by side. A fix round runs one reviewer on the fix commits only, on a cheaper model when the diff is under 100 lines and touches no guardrail.
- In Claude Code, each new PR's work starts in a fresh session.
- **Trade-offs:** Fewer and smaller calls, while every event still reaches the agent within a poll (20 seconds). The full first round keeps review quality where most findings come from. A wait now ties up the session for up to 9 minutes, and longer CI needs a second call.
- **Reversibility:** Easy: one default value and some skill text.
- **Risk:** Low. A small fix reviewed on a cheaper model could miss something the strong model would catch. The guardrail exclusion and the 100-line limit keep that to small, ordinary fixes, and CI still runs every gate.

### Option 2: Keep background waits and the PR monitor (ADR-0067 as written)

- **Trade-offs:** No change, and the session stays free while it waits. But each notice is a call on the whole conversation, notices came hours late, and the monitor's wake-ups were mostly noise.
- **Reversibility:** Easy.
- **Risk:** High for cost; medium for responsiveness, since a late notice can mean a missed event.

### Option 3: The PR monitor only, with no `Wait-PullRequest` wait

- **Trade-offs:** No wait calls at all, but no event for a passing CI, so nothing tells the agent a PR is ready to merge. Each relayed old review still costs a call. And it's specific to one app.
- **Reversibility:** Easy.
- **Risk:** High: PRs sit unmerged after CI passes, which is what happened on PRs #64 to #72.

### Option 4: A cheaper model for every review round

- **Trade-offs:** The cheapest reviews, but the first round, which sees the whole change, would run on a weaker model.
- **Reversibility:** Easy.
- **Risk:** Medium to high for quality, which the owner said not to give up.

## Recommendation

Option 1: it cuts the calls that cost (repeated wake-ups, notices, full re-reviews of small fixes) and keeps the full first round where review quality comes from.

## Decision

The goal is the owner's (2026-11-14: "A cheap, yet responsive PR monitoring"; "Quality PR review like you've been doing- try to keep credit usage as low as it can be- without sacrificing quality"; "see to it that our kit tries to do whatever it can in the same way"). This design is the agent's answer. It changes the guardrails (`finish-work`, the `reviewer` agent), so the owner's yes for its PR, at the head commit, accepts it.

## Consequences

- **`Wait-PullRequest`** (`tools/KitReview.psm1`) waits 9 minutes by default instead of 30, so one wait fits one Claude Code tool call (whose limit the agent sets to 600000 ms). Its poll interval stays 20 seconds: polling costs no model call, so a shorter interval buys responsiveness for nothing.
- **`finish-work` step 4**, "Wait cheaply":
  - GitHub work that takes minutes is waited for in the foreground, in as few calls as the time limit allows.
  - Never a loop of short waits, a scheduled wake-up or a background job.
  - While the owner decides something, the turn ends.
- **The desktop app's PR monitor** is optional and off by default for kit PRs. It's turned on only when the owner asks. `address-review` says the same.
- **`finish-work` step 2:**
  - The first round reviews the whole branch on the session's model, with focused reviewers side by side.
  - Each fix round runs one reviewer on `git diff <reviewed head>..HEAD`, on a cheaper model (`model: sonnet` in Claude Code) when that diff is under 100 changed lines and touches no guardrail.
  - The stopping rule is unchanged: a round with nothing Blocking or Should fix ends review.
- **The `reviewer` agent** gets a "fix round" case: it reviews the fix commits and what they reach, not the whole branch again.
- **`docs/code-review.md`** is unchanged. It says what a review looks for, which is the same in every round; how much a round reads is the procedure's, in `finish-work` and the agent.
- **`CLAUDE.md`** (which apps get) says to start each new PR's work in a fresh session, with follow-ups to an open PR in its session. This is Claude Code specific: other tools may bill per request rather than per token, so `AGENTS.md` doesn't say it.
- **Tests:** `KitReview.Tests.ps1` checks the 9-minute default. `AgentConfig.Tests.ps1` checks that every doc on waiting says foreground and none says to wait in the background, and that `finish-work` leaves the monitor off by default.
- **What gets harder:** a session waiting on CI can't do anything else for up to 9 minutes. Other work goes to a session of its own.
- **ADR-0028's** "`finish-work` turns on the PR monitor" and **ADR-0067's** background wait are superseded by this ADR.

## Pillars affected

Cost Optimization: fewer and smaller model calls for watching and review. Reliability: events arrive within a poll instead of through notices that came hours late. Operational Excellence: fewer wake-ups that relay nothing new.

## Sources

- owner, 2026-11-14
- https://github.com/DerekFoulk/dotnet-agent-kit/pull/73, retrieved 2026-11-14
- https://code.claude.com/docs/en/costs, retrieved 2026-11-14
