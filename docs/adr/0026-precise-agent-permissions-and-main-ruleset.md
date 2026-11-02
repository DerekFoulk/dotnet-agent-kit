# ADR-0026: Precise agent permissions, with a GitHub ruleset guarding main

- **Status:** Accepted
- **Date:** 2026-11-02

## Context

Build step 3 added `.claude/settings.json` to carry out brief §6.6: agents ask before some actions and never take others. The first version denied force-pushes, pushes to `main` and skipped hooks by matching command text. In use, two problems showed up:

- **Other spellings got through.** The reviewer agent found more than ten (`--force-with-lease`, `+branch` refspecs, `x:main`, `-d`, `commit -n` and others). A bare `git push` while on `main` can't be caught by text at all.
- **Harmless text was blocked.** The rules blocked a commit whose message mentioned `--no-verify`, and a script that merely contained rule text as data. The agent then rephrased the commands to get past the match, which is the wrong habit to teach.

Meanwhile `main` had no GitHub branch protection or ruleset at all. Claude Code's rules apply to Claude Code only; Copilot never read them. The brief ranks GitHub rulesets as the strongest enforcement layer and agent settings as the weakest (brief §7).

## Options

### Option 1: Precise rules only, plus a GitHub ruleset on main now

- **Trade-offs:** Settings keep only rules that match a file path or a precise command: deny reading secret files; ask before merging, repo-settings edits, packages, installs, `git reset --hard`, `git clean`, and edits to build, CI and agent config. A ruleset on `main` blocks force-pushes and deletion, requires a pull request, and allows merge commits only, for every tool and person. Local mistakes outside those commands rely on Claude Code's default prompting and auto-mode classifier.
- **Reversibility:** Easy. Both the settings file and the ruleset can be changed in minutes.
- **Risk:** Low. Server-side enforcement replaces text matching for everything that reaches GitHub.

### Option 2: Close every gap with more text-matching rules

- **Trade-offs:** Catches more spellings inside Claude Code. The list grew to 72 ask rules and still couldn't catch a bare `git push` on `main`; it produces false positives on harmless text, and it never covers Copilot.
- **Reversibility:** Easy.
- **Risk:** Medium. A false sense of protection, and agents learning to rephrase around blocks.

### Option 3: No permission rules at all

- **Trade-offs:** No maintenance or false positives; but no hard stop on reading secret files, and no named prompt before the owner's decisions (merging, dependencies).
- **Reversibility:** Easy.
- **Risk:** Medium. Secret-file reads are a floor rule.

## Recommendation

Option 1: put each protection in the strongest layer that can enforce it precisely. GitHub guards what reaches GitHub; settings guard file paths and a short list of exact commands.

## Decision

Accepted as recommended (owner, 2026-11-02). The ruleset "main protection" was created the same day.

## Consequences

- `.claude/settings.json` has no rule that matches `git push`; `tools/tests/AgentConfig.Tests.ps1` keeps it that way.
- `git switch` is allowed only as `git switch -c <branch>` and `git switch main`, so a forced switch prompts.
- When a permission rule blocks a legitimate action, the agent stops and tells the owner; it doesn't rephrase or relocate the command to get past the rule (`AGENTS.md`).
- Build step 4 adds required status checks to the ruleset once CI exists.
- GIT-001, GIT-002 and GIT-003 are now enforced by the ruleset rather than advisory.

## Pillars affected

Security: protection moves to a layer that can't be bypassed by spelling. Operational Excellence: fewer false positives and a smaller rule list to maintain. Reliability: `main` can no longer be force-pushed or deleted by anyone.

## Sources

- owner, 2026-11-02
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-01
- https://docs.github.com/en/rest/repos/rules, retrieved 2026-11-02
