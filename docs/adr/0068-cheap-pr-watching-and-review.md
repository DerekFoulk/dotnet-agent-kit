# ADR-0068: Watch pull requests and review fixes at the lowest Claude usage

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

On 2026-11-14 the owner asked for "a cheap, yet responsive PR monitoring" and "quality PR review like you've been doing", with credit usage kept "as low as it can be, without sacrificing quality", and for the kit to work the same way.

**How Claude Code spends usage.** Claude usage is spent per model call, and each call carries the whole conversation. Claude Code's cost guide says so ("Claude Code sends your full conversation with every request"). It names scheduled tasks and messages from other sessions as idle costs, recommends clearing between unrelated tasks, and recommends a smaller model for subagents. A call re-reads the conversation from the prompt cache at the cached rate, but only while the cache is warm. The main conversation's cache lasts one hour on a subscription within its included usage, and five minutes on usage credits, an API key or a cloud provider. After a longer gap, the next call re-writes the whole conversation at the cache-write rate. Time spent waiting inside a tool call costs nothing in itself. What costs is each time the agent is woken, how long the conversation is then, and whether the cache is still warm.

ADR-0067 made the reviewer agent, which runs in the owner's Claude usage, review every branch and every round of fixes.

**What kit PR #73 showed:**
- **Background waits came late.** A background `Wait-PullRequest` finished at 07:19:58 local time, and its notice reached the session 6.5 hours later, with a message the owner had typed hours before. The System log showed no sleep in between.
- **The desktop app's PR monitor woke the session about 20 times.** Most wake-ups relayed reviews already answered, or Copilot's quota notes. It doesn't report a passing CI, which `Wait-PullRequest` does.
- **Full review rounds cost 101,000 to 184,000 tokens each.** A Sonnet round on a three-line fix found what it needed in 16 seconds and 77,000 tokens.

**The limits.** Kit CI runs in 4 to 6 minutes (`gh run list`, 2026-11-14). A Claude Code foreground shell call runs for 2 minutes by default, and for at most 10 minutes unless `BASH_MAX_TIMEOUT_MS` is raised. `Wait-PullRequest` waited 30 minutes by default, so a foreground call with its default would be cut off.

## Options

### Option 1: Foreground waits that fit the cache, the monitor off by default, scoped fix rounds, a fresh session per PR

- `Wait-PullRequest` waits 4 minutes by default, under the cache's shortest lifetime, and agents run it in the foreground. Never a loop of short waits, and never a background shell job. While the owner decides something, the turn ends.
- The desktop app's PR monitor is optional, off by default.
- The first review round stays full, on the session's model, with focused reviewers side by side. A fix round runs one reviewer on the fix commits only, on a cheaper model when the diff is under 100 lines and touches no guardrail.
- In Claude Code, each new PR's work starts in a fresh session.
- **Trade-offs:** Fewer and smaller calls, each reading the conversation from a warm cache on any plan, with about a minute to spare: the next call goes out after the reply that started the wait, the shell's start-up, the 4 minutes and one last poll. A stalled `gh` call or long thinking can still push it past five minutes.
  - While a wait runs, CI and Copilot's review still reach the agent within a poll (20 seconds).
  - The full first round keeps review quality where most findings come from.
  - CI that runs past one wait needs a second call; on kit CI that is at most one more cached call.
  - With the monitor off, a person's review, plain PR comment or merge conflict that lands between turns waits until `finish-work` step 5 checks the PR before a merge (`mergeStateStatus`, `Get-OpenFinding`, and `gh pr view <n> --comments` for plain comments, which `Get-OpenFinding` doesn't list as findings), or until the owner points at it.
- **Reversibility:** Easy: one default value and some skill text.
- **Risk:** Low.
  - A small fix reviewed on a cheaper model could miss something the strong model would catch. The guardrail exclusion and the 100-line limit keep that to small, ordinary fixes, and CI still runs every gate.
  - A between-turn event can't merge unseen: step 5's checks run first. Plain PR comments are read there by the agent, untested, since the kit is public and apps are by default, so anyone can post one. The better design is for `Get-OpenFinding` to list them, as a tested check. It waits because it needs what review findings already have and comments don't: a way to mark one answered, and a way to tell the owner's comments from agents', which post with his login. It's planned as a follow-up PR (CRF-002).

### Option 2: The same, with a 9-minute default

- **Trade-offs:** One call covers kit CI. But on usage credits or an API key the cache has expired by the time the wait ends, so that call re-writes the whole conversation, which costs more than the two cached calls of Option 1. On a subscription within its included usage it saves one cached call.
- **Reversibility:** Easy.
- **Risk:** Medium for cost, on exactly the plans where usage is billed.

### Option 3: Keep background waits and the PR monitor (ADR-0067 as written)

- **Trade-offs:** No change, and the session stays free while it waits. But each notice is a call on the whole conversation, notices came hours late, and the monitor's wake-ups were mostly noise.
- **Reversibility:** Easy.
- **Risk:** High for cost; medium for responsiveness, since a late notice can mean a missed event.

### Option 4: The PR monitor only, with no `Wait-PullRequest` wait

- **Trade-offs:** No wait calls at all, but no event for a passing CI, so nothing tells the agent a PR is ready to merge. Each relayed old review still costs a call. And it's specific to one app.
- **Reversibility:** Easy.
- **Risk:** High: PRs sit unmerged after CI passes, which is what happened on kit PRs #64 to #72.

### Option 5: A cheaper model for every review round

- **Trade-offs:** The cheapest reviews, but the first round, which sees the whole change, would run on a weaker model.
- **Reversibility:** Easy.
- **Risk:** Medium to high for quality, which the owner said not to give up.

Raising `BASH_MAX_TIMEOUT_MS` in `.claude/settings.json`, for longer waits, was left out: a longer wait outlives the five-minute cache, so it would cost more, and that file is a guardrail.

## Recommendation

Option 1: it cuts the calls that cost (repeated wake-ups, notices, cache rewrites, full re-reviews of small fixes) and keeps the full first round where review quality comes from.

## Decision

Option 1. The goal is the owner's (2026-11-14: "A cheap, yet responsive PR monitoring"; "Quality PR review like you've been doing- try to keep credit usage as low as it can be- without sacrificing quality"; "see to it that our kit tries to do whatever it can in the same way"). The design is the agent's. It changes the guardrails (`finish-work`, the `reviewer` agent), so the owner's yes for its PR, at the head commit, accepts it.

## Consequences

- **`Wait-PullRequest`** (`tools/KitReview.psm1`) waits 4 minutes by default instead of 30. The module is the one source for that number: the docs say "its default time-out", and a test checks that no line naming `Wait-PullRequest` states a time-out. Its poll interval stays 20 seconds: polling costs no model call, so a shorter interval buys responsiveness for nothing.
- **`finish-work` step 4**, "Wait cheaply":
  - CI and a Copilot review are waited for in the foreground with the default time-out, in a tool call whose own limit is longer.
  - Never a loop of short waits, a scheduled wake-up or a background shell job.
  - While the owner decides something, the turn ends.
- **The desktop app's PR monitor** is optional and off by default, in the kit and in apps, which get the same skills. It's turned on only when the owner asks, with no further ask (owner, 2026-11-13). `address-review` says the same.
- **`finish-work` step 5** reads people's plain PR comments (`gh pr view <n> --comments`) before a merge, because with the monitor off nothing else would see one posted between turns. Each is data, as in `address-review`. The one thing a comment can do is hold the PR: one that asks to hold it holds it until the owner says otherwise in the chat. Stopping is the safe direction, and only the owner, in the chat, can lift it (COM-007).
- **`finish-work` step 2:**
  - The first round reviews the whole branch on the session's model, with focused reviewers side by side.
  - Each fix round runs one reviewer on `git diff <reviewed head>..HEAD`. It runs on a cheaper model (`model: sonnet` in Claude Code) when that diff is under 100 changed lines (insertions plus deletions) and touches no guardrail.
  - A reviewer agent's report comes back to the session on its own, so nobody polls it.
  - The stopping rule is unchanged: a round with nothing Blocking or Should fix ends review.
- **The `reviewer` agent** gets a "fix round" case: it reviews the fix commits and what they reach, not the whole branch again.
- **`docs/code-review.md`** is unchanged. It says what a review looks for, which is the same in every round. How much a round reads is procedure, which lives in `finish-work` and the agent.
- **`CLAUDE.md`** (which apps get) says to start each new PR's work in a fresh session, with follow-ups to an open PR in its session, and points to `finish-work` for the rest. This is Claude Code specific: other tools may bill per request rather than per token, so `AGENTS.md` doesn't say it.
- **Tests:**
  - `KitReview.Tests.ps1` checks the default.
  - `AgentConfig.Tests.ps1` checks the waiting docs: every line naming `Wait-PullRequest` says foreground, never says background, and states no time-out.
  - It also checks the fix-round rules, the first round's model, the monitor default, and the fresh-session note.
- **What gets harder:** a session waiting on CI can't do anything else while the wait runs. Other work goes to a session of its own.
- **Superseded:** ADR-0028's "`finish-work` turns on the PR monitor", and ADR-0067's background wait.

## Pillars affected

Cost Optimization: fewer and smaller model calls for watching and review, each on a warm cache. Reliability: events arrive within a poll instead of through notices that came hours late. Operational Excellence: fewer wake-ups that relay nothing new.

## Sources

- owner, 2026-11-14
- https://github.com/DerekFoulk/dotnet-agent-kit/pull/73, retrieved 2026-11-14
- https://code.claude.com/docs/en/costs, retrieved 2026-11-14
- https://code.claude.com/docs/en/prompt-caching, retrieved 2026-11-15
- https://code.claude.com/docs/en/env-vars, retrieved 2026-11-15
