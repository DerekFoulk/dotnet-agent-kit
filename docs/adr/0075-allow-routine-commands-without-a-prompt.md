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
- **Risk:** High. Two reviews found the fifteen forms listed under Context that write a file, read or post a secret, or run code without a prompt, and SEC-002 is a floor rule.

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

- The allow list grows from 26 to 78 rules, and the ask list from 106 to 147; the deny list is unchanged. The new asks cover:
  - every `gh api` write: `-X`, `--method`, `-f`, `-F`, `--field`, `--raw-field`, `--input`, and `-i`, since gh joins short flags, so `-iXPUT` is a PUT;
  - `& ./tools/New-KitApp`;
  - a parent segment written as `/..` or `\..`, which would leave `tools/`. It also prompts for a Bash read such as `ls ../..`, which no routine kit command uses;
  - `git push` with `--receive-pack` or `--exec`, which run a program. `git push *` was allowed before this ADR, and these asks close that gap;
  - `git push` with the likeliest joined short options, `-uf`, `-fu`, `-ud` and `-du`, each as a whole word, since git reads `-uf` as `-u -f` (a force-push) and `-ud` as `-u -d` (a delete).
- git takes any unique prefix of a long option, so `--rece=` is `--receive-pack=` and `--dele` is `--delete`. The push asks therefore spell each option as its shortest unique prefix, with no leading space, so a quoted `'--exec=…'` still matches: `--de`, `--m`, `--pru`, `--rece` and `--e`. That widens main's `--delete`, `--mirror` and `--prune` asks without dropping any form they caught. `--force` needs no change, because git rejects `--forc` as ambiguous. Any command whose text holds `git`, then `push`, then one of these prefixes or one of the joined options listed above also asks: a push matched as one string with a later `--debug`, `--merge` or `--exit-status`, or a commit message or review reply that quotes such a push. A needless prompt there is the safe way to fail.
- `KitReview.psm1` is allowed only by exact `Import-Module` commands, since `-Name` takes a list and a comma would import a second module.
- Still prompting, on purpose:
  - `git fetch` with options (`--upload-pack` runs a program);
  - `pwsh -Command "..."` (its quoted string isn't split into commands, so a wildcard would allow anything in it);
  - PowerShell cmdlets that read a file or `Env:`, or take a script block: `Get-Content`, `Select-String`, `Get-ChildItem`, `Get-Item`, `Select-Object`, `ForEach-Object` and the like;
  - PowerShell `git log`, `git diff`, `git show` and `git blame`;
  - `gh pr comment` and `gh pr merge`; posting each review round's report (`finish-work` step 4) therefore asks once per round;
  - `rg`, which isn't installed on the owner's machine.
- Known limits, true of every text rule before this ADR as well. ADR-0077's command guard closes the first three, for both tools: a PreToolUse hook that resolves each command before the ask rules see it, including a value passed through a variable. The fourth, a secret file a program reads for itself, stays open, planned with ADR-0077's other limits as GAP-048:
  - Rules match the command's text, and Claude Code's permissions page says a rule covers "the invocation Claude usually produces" and isn't a security boundary. A quoted or escaped spelling (`./tools/zz/'..'/x.ps1`, a backtick escape, `./tools/New-Kit'App'.ps1`) gets past an ask just as `git push --for'ce'` gets past main's. The asks guard against mistakes and the owner's surprise, not against a hostile agent.
  - A grouping, array or subexpression (`( )`, `@( )`, `$( )`) can hold any command inside any wide PowerShell allow (`git commit *`, `./tools/*` and the new ones alike), and Claude Code's docs don't say whether it checks the commands inside. So `Add-ReviewReply -Body (Get-Content ./.env -Raw)` could post a secret.
  - Other joined short options, such as `-qf`, `-nuf` or `-fd`, still get past the force-push and delete asks, as they did on main. A wildcard can't say "a cluster of short options that holds `f`". A rule that catches every cluster also asks for `--follow-tags`, `--dry-run` and a later `-Force`, and the owner asked on 2026-11-11 to stop those prompts. A quoted short option (`'-f'`) gets past them too, as any quoted spelling does.
  - `gh pr create --body-file`, and `git add -f` followed by a push, can send a secret file to GitHub without a prompt. GitHub's push protection, which is on for the kit, blocks a push holding a known provider's token. The gitleaks scan in CI only finds a secret after it has been pushed, when it must be rotated. Neither sees a PR's body.
  - The better design for the first three, planned as GAP-044 in `docs/quality/scorecard.md`, was a PreToolUse hook that resolves each command before it runs. ADR-0077 built it, and closed GAP-044. ADR-0077 also corrects this ADR on the sandbox: the sandbox covers the PowerShell tool, but it doesn't run on native Windows at all, and it limits files and network hosts, not what a command does with a host it allows.
- CLAUDE.md tells agents to read files with the Read, Grep and Glob tools, to run read-only git in the Bash tool, and to filter `gh` output with `--jq`.
- Apps get the same file through `Export-KitApp.ps1`, which drops only the rules that name kit-only scripts (`New-KitApp`, `Install-PlaywrightBrowser`). `KitReview.psm1` is an app tool, so apps keep its rules.
- VS Code is unchanged. The kit's `.vscode/settings.json` holds no approval settings, VS Code already auto-approves common read-only terminal commands, and its docs don't say whether a workspace value for `chat.tools.terminal.autoApprove` applies.
- ADR-0026 stays in force, amended by this ADR: wide allows are allowed for routine commands, each with its risky forms asked.

## Pillars affected

Security: the owner keeps the asks that matter instead of turning them all off with Bypass. Apart from the kit's own scripts (some of which write files, such as `Build-AgentRules.ps1`) and `Add-ReviewReply` and `Resolve-ReviewFinding`, whose posts are the review workflow's, no new allow reads a file the agent names, writes one or posts one. Operational Excellence: far fewer prompts in routine work, and the reason for each rule lives in the tests. Reliability, Cost Optimization, Performance Efficiency: not affected.

## Sources

- owner, 2026-11-15
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-15 (rule order, wildcards, compound commands, wrappers, read-only commands, PowerShell rules)
- https://code.claude.com/docs/en/tools-reference, retrieved 2026-11-15 (PowerShell tool)
- https://code.visualstudio.com/docs/agents/run/approvals, retrieved 2026-11-15 (terminal auto-approval)
- `gh api --help` and `gh pr comment --help`, gh 2.83.1, read 2026-11-15
- the kit repo's `security_and_analysis` settings (secret scanning and push protection on), read with `gh api` on 2026-11-15
