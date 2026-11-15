# ADR-0075: Allow routine commands without a prompt, and leave reads to Claude Code's own checks

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

`.claude/settings.json` had 26 allow rules, 106 ask rules and 11 deny rules. Claude Code asks before any command that no rule allows, so every routine command outside the 26 prompted: `gh pr checks`, `gh api` reads, `git fetch`, `git merge origin/main`, the kit's scripts run as `.\tools\...` or `& ./tools/...`, the `KitReview` commands that wait for CI. The owner couldn't judge these prompts, so he turned on Bypass. Bypass also skips the asks that matter (deleting, force-pushing, releases), and he turned it off again. He agreed in the chat to "a wider allow list so routine commands stop prompting without Bypass" (owner, 2026-11-15).

ADR-0026 keeps the settings to rules that match a file path or a precise command. It rejected closing gaps with ever more text-matching rules, because a missed spelling gets through. A wide allow rule such as `git log *` is that same trade in reverse: every risky form of the command must then be carved out by an ask rule, and a missed one runs without a prompt.

Two review rounds of this change probed the wide forms and found such misses:

- `git log`, `git diff` and `git show` write any file with `--output`, including `.agent-mode` and the settings themselves. `git diff --no-index` and `git blame --contents` print any file.
- A pipeline such as `Get-ChildItem -Filter .env | Get-Content` reads a secret whose name only the first part holds. `Get-Content Env:` prints environment variables.
- `gh pr comment --delete-last` deletes a comment, and `--body-file ./.env` posts a secret: gh reads the file itself, which the Read deny rules don't cover.
- `gh api -iXPUT` sends a write past ask rules that look for ` -X`, since gh joins short flags.
- `& ./tools/New-KitApp` creates a repo, and `./tools/zz/../../x.ps1` runs a script outside `tools/`.
- `Select-Object`, `Measure-Object` and `Test-Path` run a script block (a calculated property or a delay-bind parameter).

Claude Code already has better mechanisms for reads. Its Read, Grep and Glob tools honor the Read deny rules. Its Bash tool runs a built-in set of read-only commands (`ls`, `cat`, `grep`, `find`, `head`, `wc`, read-only `git` and others) without a prompt, and refuses that set's risky forms itself.

## Options

### Option 1: Wide allows for reads and pipelines too, with ask and deny carve-outs

- **Trade-offs:** No prompt for PowerShell reads and pipelines (`Get-Content`, `git log`, `| ConvertFrom-Json`). But each command needs every risky form carved out by text, the list grows with each new flag, and a pipeline, a variable or a script block can do what no rule's text names.
- **Reversibility:** Easy: remove the rules.
- **Risk:** High. Two reviews found eight ways to write a file, read or post a secret, or run code without a prompt, and SEC-002 is a floor rule.

### Option 2: Allow routine commands whose risky forms are few and nameable; leave reads to Claude Code's tools

- **Trade-offs:** The allow list covers `gh pr list`, `checks` and `diff`, `gh run view` and `list`, and `gh api` reads, with an ask for every write form. It also covers the PowerShell git commands that print no file (`git status`, `git rev-parse`, `git merge-base`, `git ls-files`, `git branch --list` and `--show-current`, `git remote -v`), the exact `git fetch`, `git merge origin/main` and `git pull --ff-only` forms, and the kit's scripts and `KitReview` commands. Reading files and history goes through the Read, Grep and Glob tools or the Bash tool's read-only check, and filtering `gh` output goes through its own `--jq`. A PowerShell `Get-Content`, `git log` or `| ConvertFrom-Json` still prompts, so CLAUDE.md steers agents to those tools.
- **Reversibility:** Easy: remove the rules.
- **Risk:** Low. Each allow brings its known risky forms in as asks, and `tools/tests/AgentConfig.Tests.ps1` pins them. A form nobody thought of still runs unasked, and rules aren't a security boundary (ADR-0026).

### Option 3: Narrow allows only, such as `gh api repos/*/pulls/*`

- **Trade-offs:** Fewer carve-outs. But a pattern on the path doesn't stop `-X PUT` on that path, so the writes still need the same asks, and every new endpoint the workflow reads prompts until someone adds it.
- **Reversibility:** Easy.
- **Risk:** Medium. The prompts the owner can't judge come back, and with them the pull toward Bypass.

## Recommendation

Option 2: allow what is routine and has few, nameable risky forms, and leave reading files and history to the mechanisms Claude Code built for it, which see the paths and flags that a rule's text can't.

## Decision

Accepted as recommended. The owner agreed to a wider allow list in the chat on 2026-11-15; this ADR records how it was built after two reviews found the gaps of Option 1.

## Consequences

- The allow list grows from 26 to 78 rules, and the ask list from 106 to 127; the deny list is unchanged. The new asks cover:
  - every `gh api` write: `-X`, `--method`, `-f`, `-F`, `--field`, `--raw-field`, `--input`, and `-i`, since gh joins short flags, so `-iXPUT` is a PUT;
  - `& ./tools/New-KitApp`;
  - any parent segment (`/..` or `\..`) in a command, which would leave `tools/`.
- `KitReview.psm1` is allowed only by exact `Import-Module` commands, since `-Name` takes a list and a comma would import a second module.
- Still prompting, on purpose:
  - `git fetch` with options (`--upload-pack` runs a program);
  - `pwsh -Command "..."` (its quoted string isn't split into commands, so a wildcard would allow anything in it);
  - PowerShell cmdlets that read a file or `Env:`, or take a script block: `Get-Content`, `Select-String`, `Get-ChildItem`, `Get-Item`, `Select-Object`, `ForEach-Object` and the like;
  - PowerShell `git log`, `git diff`, `git show` and `git blame`;
  - `gh pr comment` and `gh pr merge`;
  - `rg`, which isn't installed on the owner's machine.
- Known limits, unchanged from before this ADR:
  - A `$( )` subexpression can hold any command inside any wide PowerShell allow (`git commit *`, `./tools/*` and the new ones alike), and Claude Code's docs don't say whether it checks the commands inside.
  - `gh pr create --body-file`, and `git add -f` followed by a push, can send a secret file to GitHub without a prompt. The gitleaks scan in CI is the backstop (SEC-001).
- CLAUDE.md tells agents to read files with the Read, Grep and Glob tools, to run read-only git in the Bash tool, and to filter `gh` output with `--jq`.
- Apps get the same file through `Export-KitApp.ps1`, which drops only the rules that name kit-only scripts (`New-KitApp`, `Install-PlaywrightBrowser`). `KitReview.psm1` is an app tool, so apps keep its rules.
- VS Code is unchanged. The kit's `.vscode/settings.json` holds no approval settings, VS Code already auto-approves common read-only terminal commands, and its docs don't say whether a workspace value for `chat.tools.terminal.autoApprove` applies.
- ADR-0026 stays in force, amended by this ADR: wide allows are allowed for routine commands, each with its risky forms asked.

## Pillars affected

Security: the owner keeps the asks that matter instead of turning them all off with Bypass, and no new allow reads a file the agent names, writes one, or posts one. Operational Excellence: far fewer prompts in routine work, and the reason for each rule lives in the tests. Reliability, Cost Optimization, Performance Efficiency: not affected.

## Sources

- owner, 2026-11-15
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-15 (rule order, wildcards, compound commands, wrappers, read-only commands, PowerShell rules)
- https://code.claude.com/docs/en/tools-reference, retrieved 2026-11-15 (PowerShell tool)
- https://code.visualstudio.com/docs/agents/run/approvals, retrieved 2026-11-15 (terminal auto-approval)
- `gh api --help` and `gh pr comment --help`, gh 2.83.1, read 2026-11-15
