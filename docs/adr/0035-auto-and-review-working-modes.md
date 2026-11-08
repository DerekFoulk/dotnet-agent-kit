# ADR-0035: Two working modes: auto by default, review on request

- **Status:** Accepted
- **Date:** 2026-11-07

## Context

Until now, every non-trivial plan, every dependency, CI or settings change, and every merge waited for the owner (`AGENTS.md`, SEC-003, GIT-003, DOD-005). `.claude/settings.json` made Claude Code ask before each of them (ADR-0026). On 2026-11-07 the owner asked for the opposite default: "a mode where you just keep doing what needs to be done, so I don't have to approve things and I don't have to merge PRs". He also asked that the old way stay one step away: "Make it easy for me to switch back… But default to the auto mode." He added one exception: "I do wish for you to not automatically complete/merge release PRs. I wish to maintain control of releases."

Some steps stay the owner's whatever the mode:
- the floor: secrets and sign-in;
- anything that costs money or can't be undone;
- new app repos, which he said are each his call;
- releases.

Claude Code combines the permission lists of `.claude/settings.json` and a person's own `.claude/settings.local.json`, which stays out of commits, and an ask rule from any file wins over an allow rule (Claude Code docs, "Settings" and "Configure permissions"). Other agents, such as Copilot and Visual Studio, read only the instructions, so the mode has to be readable as a file too.

## Options

### Option 1: Two modes, switched by a script that writes a gitignored mode file and the owner's local settings

`tools/Set-AgentMode.ps1 -Mode Review` writes `review` to `.agent-mode` and adds the review-only ask rules to `.claude/settings.local.json`. Both files are gitignored. `-Mode Auto` removes exactly those rules and the mode file, keeping the owner's own local settings. With no mode file, the mode is auto. `.claude/settings.json` keeps only the asks that apply in both modes, plus asks before running the script and before editing the mode files.

- **Trade-offs:** The default is auto everywhere, including CI and new clones, because nothing has to be set. Review mode is one command, and Claude Code enforces it with real prompts, not just instructions. The mode is per person and per machine, so a review-mode clone doesn't change anyone else's. It costs a script and its tests. An agent in review mode can't switch itself back without a prompt.
- **Reversibility:** Easy. Running the script switches the mode, and removing ADR-0035's rules would restore the old single mode.
- **Risk:** Medium. In auto mode the owner no longer reviews before a merge, so design choices the `reviewer` agent can't judge reach `main` unseen. The hard limits, CI, the ruleset and the reviewer stay.

### Option 2: A committed mode setting

The mode would be a line in `AGENTS.md` or a tracked file.

- **Trade-offs:** It's visible in history. But switching mode needs a commit and a PR, and in review mode that PR would wait for the owner, which is the opposite of easy. Every clone and app shares the one mode.
- **Reversibility:** Easy.
- **Risk:** Low, but it doesn't meet "easy to switch back".

### Option 3: Rely on Claude Code's own permission modes

The owner would pick a permission mode in Claude Code that prompts less, and the instructions would stay as they are.

- **Trade-offs:** No kit change. But the instructions would still say to wait for the owner, so agents would keep asking in chat. Other agents ignore Claude Code's modes. And a broad permission mode removes the precise asks that guard the hard limits too.
- **Reversibility:** Easy.
- **Risk:** High: it loosens the hard limits along with everything else.

## Recommendation

Option 1. Auto is the default, review is one command away, and the hard limits keep their prompts in both modes.

## Decision

Accepted (owner, 2026-11-07: "Yes, set it up… default to the auto mode", and keep releases his).

## Consequences

- **`AGENTS.md`** gets a "Working modes" section, an "Always ask" list for both modes, and an "Also ask in review mode" list. The "Always ask" list covers:
  - cost and cloud resources;
  - deleting or rewriting anything on GitHub, and unmerged work;
  - new app repos, and making anything public;
  - release PRs and releases;
  - connectors;
  - installs on the owner's machine;
  - switching the mode.

  Apps get the same sections, through the kit block of their `AGENTS.md`.
- **In auto mode an agent:**
  - posts its plan and builds it;
  - adds a dependency only when the kit's standards, ADRs or the official docs they cite name it, and says so in the PR;
  - decides a "won't fix", with the reason;
  - merges its own PR once CI has passed at the head commit, the latest `reviewer` run on that commit has no unanswered blocking or should-fix finding, and the description is complete. It then reports what merged.
- **Release PRs** (release-please's, on a `release-please--` branch) are never merged by an agent. The `finish-work` skill refuses one before merging. Only the instructions enforce this, because a rule can't match a PR number.
- **`.claude/settings.json`** drops its asks for merging, `gh repo edit`, `dotnet add package`, and edits to the build, NuGet, SDK, tool, workflow and Dependabot files. `Set-AgentMode.ps1` holds those as its review rules. A test checks that every rule removed is one that review mode adds back.
- **New asks in both modes:** running `Set-AgentMode` (from `tools/` or `.kit/tools/`), and editing `.claude/settings.local.json` or `.agent-mode`. So an agent can't switch modes or drop its prompts on its own.
- **Rules updated:**
  - SEC-003 is restated as the two lists.
  - GIT-003 (proposed) says merges follow the mode and never include a release PR.
  - DOD-005 lets an agent in auto mode resolve "won't fix" with its reason.
  - `KitReview.psm1`'s `-OwnerApproved` is passed in auto mode under this standing approval.
- **Files:**
  - `.gitignore` lists `.agent-mode` and `.claude/settings.local.json`; apps copy it.
  - Apps get `Set-AgentMode.ps1` in `.kit/tools`.
- **What changes for the brief:** the brief's success measure counts how often the owner has to correct an agent. In auto mode he sees work after it merges, not before, so corrections come later and may be fewer only because he looks less. The practice run should be done in review mode, or say which mode it used.

## Pillars affected

- **Operational Excellence:** work flows without waiting for the owner, and the mode is one command to change.
- **Security:** the hard limits and the floor keep their prompts in both modes, and an agent can't switch modes without asking. The owner no longer reviews before each merge, so CI, the ruleset and the `reviewer` agent carry more of the weight.
- **Reliability:** an agent merges only on green CI and a clean review.
- **Cost Optimization:** spending money always asks.
- **Performance Efficiency:** not affected.

## Sources

- owner, 2026-11-07
- https://code.claude.com/docs/en/settings, retrieved 2026-11-07
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-07
