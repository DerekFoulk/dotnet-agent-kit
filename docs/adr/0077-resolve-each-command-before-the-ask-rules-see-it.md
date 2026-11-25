# ADR-0077: Resolve each command before the ask rules see it, with a PreToolUse hook

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

`.claude/settings.json` asks before the risky forms of routine commands: force-pushing, deleting a branch, `gh api` writes, `New-KitApp`, a path that leaves `tools/` (ADR-0026, ADR-0075). Its rules match the command's text. ADR-0075's Known limits name what text can't see:

- a quoted or escaped spelling, which the shell removes before the program runs: `git push --for'ce'`, `./tools/New-Kit'App'.ps1`, `./tools/zz/'..'/x.ps1`, a backtick escape;
- joined short options, which git and gh read one by one: `git push -qf` is `-q -f`, `-nuf` is `-n -u -f`, `-fd` is `-f -d`;
- a command nested in `( )`, `@( )` or `$( )` inside a wide PowerShell allow such as `git commit *`: `Add-ReviewReply -Body (Get-Content ./.env -Raw)` could post a secret. Claude Code's permissions page says it reads a PowerShell command's syntax tree (the structure PowerShell's own parser builds from the text) and checks each command that `|`, `;`, `&&` and `||` separate, but not what it does with a command inside an argument.

Claude Code's permissions page says a rule covers "the invocation Claude usually produces" and isn't a security boundary. It points to two mechanisms for more: a PreToolUse hook, which sees each command before it runs and can return `"ask"`, and the sandbox. GAP-044 in `docs/quality/scorecard.md` planned this choice.

Facts that shape the options, from Claude Code's hooks, permissions and sandboxing pages (retrieved 2026-11-15 and 2026-11-16):

- A PreToolUse hook gets the call as JSON on stdin (`tool_name`, and `tool_input.command` for Bash and PowerShell). It answers with `hookSpecificOutput.permissionDecision` (`allow`, `deny`, `ask` or `defer`) and a `permissionDecisionReason`, shown in the prompt for `ask`. Several hooks combine as deny > defer > ask > allow. Deny and ask rules still apply whatever a hook returns, and the hook's output can "force a prompt".
- A hook that exits 0 with no output leaves the call to the rules. By default, one that fails to start, times out or exits with another code is a non-blocking error, and the call goes on through the rules. A hook's `onFailure: "block"` (Claude Code 2.1.295 or later) blocks the call instead.
- Exec form (`command` with `args`) starts the program with no shell, and `${CLAUDE_PROJECT_DIR}` is substituted into each argument.
- Before matching a Bash rule, Claude Code strips the wrappers `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, `noglob` and bare `xargs`, and an ask rule matches past any leading `NAME=value` assignment. Its ask rules also apply inside a Bash substitution and a control-flow body.
- A project's `"disableAllHooks": false` overrides a `true` in the user's own settings.
- The sandbox runs on macOS, Linux and WSL2; "on native Windows, Claude Code runs commands unsandboxed". The owner works on native Windows. The sandbox limits writes and network hosts. It doesn't stop a force-push or a `gh api` write to a host it allows, and it leaves most reads open, `~/.ssh` included.

## Options

### Option 1: A PreToolUse hook that resolves each command and applies the existing ask rules to the result

- **Trade-offs:** It closes the three limits for both tools. PowerShell commands are resolved by PowerShell's own parser (`Parser.ParseInput`). Bash commands are resolved by a tokenizer that follows the POSIX shell's rules for splitting a command line into words and removing their quotes (for example, `g'it' push` becomes `git` and `push`), plus Bash's `$'...'` strings, heredocs (a command's input written inline, up to a closing word) and `case`. It keeps one list of asks (CRF-003): it reads the ask rules from `.claude/settings.json` and `.claude/settings.local.json`, and matches them against each command as the shell resolves it. A new ask then covers its quoted and joined spellings too. Its costs: one `pwsh` start per shell call (about 0.4 s, measured below), and a tokenizer of its own to maintain, since no Bash parser ships with PowerShell or .NET.
- **Reversibility:** Easy: remove the `hooks` entry, and the rules work as before.
- **Risk:** Low. A command the guard can't read, and anything else that goes wrong inside it, asks rather than lets the call through. A guard that can't start leaves the call to the text rules, the state before this ADR. The replay below measures the prompts it adds.

### Option 2: Claude Code's sandbox

- **Trade-offs:** It's enforced by the operating system, not by reading the command, so no spelling gets past it. But it doesn't run on native Windows, where the owner works. Where it runs, it limits files and hosts, not what a command does with a host it allows: `git push --force` to github.com is as open as `git push`, and a read of `./.env` isn't blocked by default.
- **Reversibility:** Easy: a setting.
- **Risk:** High for this need: on the owner's machine it does nothing, and elsewhere it guards a different thing. Worth adding beside the asks once it supports native Windows.

### Option 3: More text rules

- **Trade-offs:** No new code. But a wildcard can't say "a cluster of short options that holds `f`", and catching every quoted spelling means a rule per placement of every quote. ADR-0026 rejected this road. ADR-0075's nine review rounds showed each new rule exposing the next missed form.
- **Reversibility:** Easy.
- **Risk:** High: the same misses, more of them, and prompts for safe forms such as `--follow-tags` that the owner asked on 2026-11-11 to stop.

## Recommendation

Option 1: it closes every limit ADR-0075 names, on the owner's Windows machine, without a second list of asks. The sandbox guards a different thing and doesn't run there yet.

## Decision

Option 1. GAP-044 planned it, and the owner asked on 2026-11-16 to finish the scorecard gaps that cost nothing, GAP-044 among them (relayed by the session that coordinates them). The design is the agent's. It changes the guardrails (`.claude/settings.json`, and the guard itself), so the owner's yes for its PR, at the head commit, accepts it.

## Consequences

- `tools/KitCommandGuard.psm1` holds the guard and `tools/Invoke-CommandGuard.ps1` runs it as the hook. `.claude/settings.json` runs it before every Bash or PowerShell call (`"matcher": "Bash|PowerShell"`), in exec form through `pwsh` with a 30-second timeout, and sets `"disableAllHooks": false`, so the user's `~/.claude/settings.json` can't turn it off; `.claude/settings.local.json` outranks the shared file, and editing it asks. It only ever answers `"ask"`, never `"allow"`, so it can add prompts but never remove one.
- It matches each ask rule, without regard to case, against each command as its shell resolves it, in several spellings:
  - with quotes and escapes removed: `git push --for'ce'` is `git push --force`, and `./tools/zz/'..'/x.ps1` meets `*/..*`;
  - past what Claude Code strips before matching: Bash's wrappers, leading assignments and the reserved words that open a body (`then`, `do`, `{`, `!`), or PowerShell's `&` or `.`;
  - with a native command's joined short options split: `git push -qf` is also tried as `git push -q -f`. A cmdlet's, function's or script's `-fd` isn't split, since PowerShell binds it to one parameter;
  - with its expansions taken out, as an unset variable is empty: `git push --for${X}ce`, or PowerShell's `"--for${null}ce"`;
  - with each path in one plain form (`/./`, `//` and `\` as `/`), and a program named by its bare name (`C:\Git\cmd\git.exe` is `git`). Windows opens `./tools/new-kitapp.ps1` and runs `GIT`, hence the case;
  - with a glob in a path's last part expanded against the command's working directory: `./tools/New-K*.ps1`.
  - with each word that holds white space also in double quotes, as a rule may write it: the ask rule `pwsh -NoProfile -Command "Install-PSResource *` covers `pwsh -NoProfile -Command 'Install-PSResource Pester'` too, which reaches `pwsh` as the same text. Main added that rule while the guard waited in its clone (2026-11-25).
- It also asks when an argument is built only as the command runs:
  - always, for code inside a PowerShell argument (`( )`, `@( )`, `$( )` in a string too, `{ }`), which covers a nested command and a value such as `('--for'+'ce')`, and for a variable the same input fills from a command's output (`$b = Get-Content ./.env -Raw; Add-ReviewReply -Body $b`, or `-OutVariable`);
  - in a command an ask rule names, for any value known only as it runs: a variable, however the input or the environment set it; a Bash brace expansion (`{x,-f}`); `${...}`; `$((...))`; or a `$( )` or backquote substitution. The one fixed-text substitution doesn't count: `cat` reading a heredoc with a quoted delimiter, with nothing after the heredoc but `)`, which is how Claude Code writes a commit message. The heredoc ends, as Bash ends it, at its first delimiter line;
  - "names" means the rule's first word matches the program, and the plain text that starts its second word, if any, is one of the command's words: `*git *push*` names `git push`. A one-word rule names its first literal part (`*Initialize-DevMachine*-I*` names `Initialize-DevMachine`). A subcommand that is built itself counts too, where it sits after the program or after an option and its value (`git -C . $p`). So `git push origin $b` asks, but `git commit -F $M` and `gh run view $id` don't;
  - when the text doesn't parse as the tool's shell (a PowerShell parse error, or an unclosed Bash quote, substitution or parenthesis), or anything inside the guard fails.
- Each reason says what the guard found: the resolved command and the rule, the argument built as the command runs, or the error.
- Bash's commands inside `$( )`, backquotes, `<( )` and an unquoted heredoc's body are resolved and checked too. A command nested in Bash isn't asked for as such, since Claude Code's ask rules already apply inside a substitution.
- A guard that can't start (no `pwsh` on the PATH, or a PowerShell older than 7.6) leaves the call to the text rules, as a hook error Claude Code shows, rather than blocking it. `onFailure: "block"` would block every shell call on such a machine, including the commands that would fix it, for a guard whose purpose is mistakes, not a hostile agent (ADR-0075). Older Claude Code versions may not know the key, either (not verified).
- The hook runs `pwsh` without `-ExecutionPolicy Bypass`: every kit script runs under the machine's policy already, and a policy that stops this one stops them all.
- Known limits, planned as GAP-050 in `docs/quality/scorecard.md`:
  - a command run from a string (`bash -c "…"`, `pwsh -Command "…"`, `Invoke-Expression`, `eval`) isn't resolved. No allow rule covers these forms, so they prompt today;
  - a program that reads a file for itself, such as `gh pr create --body-file ./.env` or `git add -f` followed by a push, can still send a secret: the guard sees the path, not what it holds;
  - a built value in a command no ask rule names isn't asked for, even where it adds a parent segment to a path (`cat ./${P:-..}/x`). The kit's `./tools/*` allows run scripts, and a built program or an asked program such as `pwsh -File` still asks;
  - the guard reads the project's ask rules, not the user's or managed ones. And by a review's reading of Claude Code's settings page (not verified here), on macOS and Linux Claude Code reads the main checkout's `.claude/settings.local.json` from a worktree, where the guard reads the worktree's.
- Replayed over the Bash and PowerShell commands in the kit's own session transcripts (2026-11-16, the ask rules of this commit). The replay script reads the owner's local transcripts, so it stays outside the repo. Its "text rules" baseline matches each ask rule against a command's whole text without splitting it as Claude Code does, so it undercounts what Claude Code itself asks:
  - 15,918 commands: 5,382 Bash and 10,536 PowerShell. The baseline asks for 499 of them, the guard for 3,705.
  - Of the 3,305 the guard alone asks for (136 Bash, 3,169 PowerShell), nearly all already prompted for a part that no allow rule covers. A check of each part against the allow rules finds 14 that would have run without a prompt; for Bash, it treats an approximation of Claude Code's read-only commands as allowed. The 14 are 6 Bash, 1 PowerShell, and 7 PowerShell inputs that also assign a variable, for which Claude Code's docs don't say whether it prompts. They pass a value built as the command runs into `gh api`, `gh pr create` or `git push`, or nest `(git rev-parse HEAD)`. One is a needless prompt: a `grep` over `tools/*.ps1`, whose expanded file list meets `*Initialize-DevMachine*-I*`.
  - Before the guard asked only in commands an ask rule names, it added prompts for 231 of them, most in routine forms such as `M=… && git commit -F $M`.
  - Two rule asks only the guard found: `Install-PSResource` after `git switch` in one compound command. Claude Code's own splitting probably caught them, so the replay shows no asked command that ran without a prompt.
  - The guard can't read 12 inputs: 5 Bash commands that `bash -n` rejects too, and 7 PowerShell ones that PowerShell's parser rejects, so neither shell would have run them as written. The replay found two tokenizer bugs on the way, fixed test-first: a `$` before a closing quote, and `case` patterns.
  - In-process, the guard took 39 ms per command on average and 373 ms at most. As the hook, it took 360 to 415 ms per call over 10 runs (370 ms on average), mostly `pwsh` starting.
- `tools/tests/AgentConfig.Tests.ps1` now matches rules with the guard's matcher, so the rule syntax lives in one place.
- Editing either guard file asks, as editing the settings does: an edit could switch the guard off.
- Apps get both files in `.kit/tools` through `Export-KitApp.ps1`, which points the hook at `${CLAUDE_PROJECT_DIR}/.kit/tools/Invoke-CommandGuard.ps1`. It refuses to export a hook that runs a kit script the app doesn't get. An app's copy keeps the two `Edit(./tools/…)` asks, which name no file there; `Edit(./.kit/**)` already covers its copies.
- AGENTS.md "Working modes" and the `finish-work` skill list the guard among the guardrails. SEC-003's enforcement names it.
- GAP-044 is closed. ADR-0075's Known limits point here.
- What gets harder: a change to the rule syntax or the stripped wrappers Claude Code documents needs the same change in the guard, and a Bash construct the tokenizer doesn't know asks until it's taught.

## Pillars affected

- **Security:** the asks now hold for the spellings, clusters, wrappers, paths and built values that got past them. Every failure asks, except a guard that can't start: that call falls back to the text rules, which Claude Code still enforces.
- **Performance Efficiency:** about 0.4 s more per shell call.
- **Operational Excellence:** each prompt says what the guard found and why it asks.
- **Reliability:** a misread asks rather than blocks, and removing the hook entry turns the guard off.
- **Cost Optimization:** not affected.

## Sources

- owner, 2026-11-16 ("Finish the free gaps", relayed by another session)
- https://code.claude.com/docs/en/hooks, retrieved 2026-11-15 and 2026-11-16 (PreToolUse input and decision output, exit codes, `onFailure`, exec form, `${CLAUDE_PROJECT_DIR}`, matcher `Bash|PowerShell`, `disableAllHooks`)
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-15 (rules aren't a security boundary; compound commands; wrappers and assignments; PowerShell; hooks and rule precedence)
- https://code.claude.com/docs/en/sandboxing, retrieved 2026-11-15 (platforms; what the sandbox limits)
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html, retrieved 2026-11-15 (POSIX Shell Command Language: 2.2 Quoting, 2.3 Token Recognition, 2.6.7 Quote Removal)
- https://www.gnu.org/software/bash/manual/bash.html, retrieved 2026-11-15 (3.1.2.4 ANSI-C Quoting, 3.6.6 Here Documents, case)
- https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser.parseinput, retrieved 2026-11-15
- ADR-0026, ADR-0068, ADR-0075
