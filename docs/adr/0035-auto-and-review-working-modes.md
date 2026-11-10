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

Option 1. Auto is the default, review is one command away, and the hard limits stay in force in both modes, with prompts for their common forms.

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
- **New asks in both modes:**
  - any `Set-AgentMode` run that passes `-Mode`, whatever the path. Neither the script nor its function takes positional arguments, so `-M` is the only way to switch;
  - editing `.claude/settings.local.json` or `.agent-mode`;
  - the common forms of the hard limits:
    - pushes (`git push` or `git -C … push`) with `--delete`, `-d`, `--force`, `-f`, a `:` or `+` refspec (quoted or not), `--mirror` or `--prune`. Bundled short flags such as `-uf` aren't caught (review 3 of PR 19);
    - `gh repo edit` with `--visibility`, `--enable-…`, `--delete-branch-on-merge` or `--default-branch`;
    - `gh repo delete` and `gh release`;
    - `gh api` calls on rulesets, branch protection, merge settings, visibility, `private`, `delete_branch_on_merge` or `default_branch`, and DELETE calls.

    No rule ends in `:*`: Claude Code reads that as its older prefix syntax, where `*` is literal, so the `:` refspec rules end in `:**`. A test models that syntax and forbids mixing the two (review 4 of PR 19). Review 5 read Claude Code 2.1.310's rule parser and found that `:**` is matched as a wildcard. For each of the six rules, Claude Code warns that a `:*` that isn't at the end is matched as a wildcard. That's expected, and it confirms the rules work: don't change them back to `:*`. Whether they prompt in a live session isn't verified.

    Some ordinary commands prompt as a side effect, such as a commit message that names one of these forms, or `gh release view`. A prompt errs on the safe side.

  These are prompts for the common forms, not a security boundary. Claude Code's docs say such rules aren't one: a shell `Set-Content` on `.agent-mode`, an unusual path, or another agent can still get past them, and the instructions cover the rest. Showing the mode (`Set-AgentMode.ps1` with no `-Mode`) doesn't prompt, so checking it at the start of a task costs nothing.
- **Amends ADR-0026:** pushes still have no deny rule, and an ordinary push still runs unasked. Deleting or force-pushing a branch now asks, because the "main protection" ruleset guards only `main`.
- **Guardrail changes are the owner's to merge.** In auto mode an agent may change CI and repo settings, so it could otherwise loosen the checks this ADR relies on and merge that itself. The owner merges any PR that changes:
  - `AGENTS.md`'s "Working modes" or "Always ask";
  - SEC-003;
  - `.claude/settings.json` or `tools/Set-AgentMode.ps1`;
  - the `finish-work` skill or the `reviewer` agent, which enforce the release-PR and guardrail rules and decide when a PR is ready (review 2 of PR 19);
  - a ruleset, branch protection or the merge settings;
  - a CI check, by removing or weakening it. The `finish-work` skill checks this before merging.
- **Per checkout, and per person:**
  - The mode belongs to one checkout. A new git worktree has neither file, so it starts in auto until `Set-AgentMode` runs there; on Windows, Claude Code also reads the local settings from the session's own folder.
  - Auto mode removes the review rules by their text. If the owner had added the same rule to his local settings himself, it goes too.
- **Rules updated:**
  - SEC-003 is restated as the two lists.
  - GIT-003 (proposed) says merges follow the mode and never include a release PR.
  - **Update (2026-11-09):** the owner accepted GIT-003.
  - DOD-005 lets an agent in auto mode resolve "won't fix" with its reason.
  - `KitReview.psm1`'s `-OwnerApproved` is passed in auto mode under this standing approval.
- **Files:**
  - `.gitignore` lists `.agent-mode` and `.claude/settings.local.json`; apps copy it.
  - Apps get `Set-AgentMode.ps1` in `.kit/tools`.
- **What changes for the brief:** the brief's success measure counts how often the owner has to correct an agent. In auto mode he sees work after it merges, not before, so corrections come later and may be fewer only because he looks less. The practice run should be done in review mode, or say which mode it used.
- **Amended by ADR-0041 (2026-11-09):** in auto mode an agent may also merge a Dependabot PR for a patch or minor update of NuGet packages, .NET tools or the .NET SDK, on its own PR's conditions plus DOD-006's comment; majors, any update of a 0.x package, and GitHub Actions bumps stay the owner's. Shortening or narrowing the Dependabot cooldown in `.github/dependabot.yml` joins the guardrails.

## Pillars affected

- **Operational Excellence:** work flows without waiting for the owner, and the mode is one command to change.
- **Security:** the hard limits and the floor apply in both modes, with prompts for their common forms, and changes to the guardrails wait for the owner. The owner no longer reviews before each merge, so CI, the ruleset and the `reviewer` agent carry more of the weight.
- **Reliability:** an agent merges only on green CI and a clean review.
- **Cost Optimization:** spending money always asks.
- **Performance Efficiency:** not affected.

## Sources

- owner, 2026-11-07
- https://code.claude.com/docs/en/settings, retrieved 2026-11-07
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-07
