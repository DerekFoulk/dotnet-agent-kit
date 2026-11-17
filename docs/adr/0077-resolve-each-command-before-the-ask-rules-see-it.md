# ADR-0077: Resolve each command before the ask rules see it, with a PreToolUse hook

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

`.claude/settings.json` asks before the risky forms of routine commands: force-pushing, deleting a branch, `gh api` writes, `New-KitApp`, a path that leaves `tools/` (ADR-0026, ADR-0075). Its rules match the command's text. ADR-0075's Known limits name what text can't see:

- a quoted or escaped spelling, which the shell removes before the program runs: `git push --for'ce'`, `./tools/New-Kit'App'.ps1`, `./tools/zz/'..'/x.ps1`, a backtick escape;
- joined short options, which git and gh read one by one: `git push -qf` is `-q -f`, `-nuf` is `-n -u -f`, `-fd` is `-f -d`;
- a command nested in `( )`, `@( )` or `$( )` inside a wide PowerShell allow such as `git commit *`: `Add-ReviewReply -Body (Get-Content ./.env -Raw)` could post a secret. Claude Code's permissions page says it parses the PowerShell AST and checks each command that `|`, `;`, `&&` and `||` separate, but not what it does with the commands inside an argument.

Claude Code's permissions page says a rule covers "the invocation Claude usually produces" and isn't a security boundary. It points to two mechanisms for more: a PreToolUse hook, which sees each command before it runs and can return `"ask"`, and the sandbox. GAP-044 in `docs/quality/scorecard.md` planned this choice.

Facts that shape the options, from Claude Code's hooks, permissions and sandboxing pages (retrieved 2026-11-15):

- A PreToolUse hook gets the call as JSON on stdin (`tool_name`, and `tool_input.command` for Bash and PowerShell). It answers with `hookSpecificOutput.permissionDecision` (`allow`, `deny`, `ask` or `defer`) and a `permissionDecisionReason`, shown in the prompt for `ask`. Several hooks combine as deny > defer > ask > allow. Deny and ask rules still apply whatever a hook returns.
- A hook that exits 0 with no output leaves the call to the rules. One that fails to start, times out or exits with another code is a non-blocking error by default, and the call goes on through the rules.
- Exec form (`command` with `args`) spawns the program with no shell, and `${CLAUDE_PROJECT_DIR}` is substituted into each argument.
- The sandbox runs on macOS, Linux and WSL2; "on native Windows, Claude Code runs commands unsandboxed". The owner works on native Windows. The sandbox limits writes and network hosts. It doesn't stop a force-push or a `gh api` write to a host it allows, and it leaves most reads open, `~/.ssh` included.

## Options

### Option 1: A PreToolUse hook that resolves each command and applies the existing ask rules to the result

- **Trade-offs:** It closes the three limits for both tools. PowerShell commands are resolved by PowerShell's own parser (`Parser.ParseInput`). Bash commands are resolved by a tokenizer that follows POSIX token recognition and quote removal, plus Bash's `$'...'` quoting, heredocs and `case`. It keeps one list of asks (CRF-003): it reads the ask rules from `.claude/settings.json` and `.claude/settings.local.json` and matches them against the resolved command, so a new ask covers its quoted and joined spellings too. Its costs: one `pwsh` start per shell call (about 0.3 s, measured below), and a tokenizer of its own to maintain, since no Bash parser ships with PowerShell or .NET.
- **Reversibility:** Easy: remove the `hooks` entry, and the rules work as before.
- **Risk:** Low. A misread of valid Bash, or anything else that goes wrong inside the guard, asks rather than lets the call through. A guard that can't start leaves the call to the text rules, the state before this ADR. A replay of the kit's own sessions (below) found one new prompt in 10,082 PowerShell calls.

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

Accepted as recommended, in auto mode (ADR-0035), on 2026-11-15. GAP-044 in `docs/quality/scorecard.md` planned it, and the owner's 2026-11-15 instruction for auto mode is to make guardrail changes and log each one for his review.

## Consequences

- `tools/KitCommandGuard.psm1` holds the guard and `tools/Invoke-CommandGuard.ps1` runs it as the hook. `.claude/settings.json` runs it before every Bash or PowerShell call (`"matcher": "Bash|PowerShell"`), in exec form through `pwsh` with a 30-second timeout. It asks when:
  - an ask rule covers the command once its quotes and escapes are removed (`git push --for'ce'` is `git push --force`), with a parent segment unquoted too (`./tools/zz/'..'/x.ps1` meets `*/..*`);
  - an ask rule covers a native command once its joined short options are split (`git push -qf` is also tried as `git push -q -f`). A cmdlet's, function's or script's `-fd` isn't split, since PowerShell binds it to one parameter;
  - a PowerShell command computes an argument inside `( )`, `@( )`, `$( )` (in a string too) or `{ }`. That covers a nested command and also a value built at run time, such as `('--for'+'ce')`, which no rule can read;
  - the text doesn't parse as the tool's shell (PowerShell's parser errors, or an unclosed Bash quote, substitution or parenthesis), or anything inside the guard fails.
  Each prompt's reason names the resolved command and the rule.
- Bash's commands inside `$( )`, backquotes, `<( )` and an unquoted heredoc's body are resolved and checked too. A command nested in Bash isn't asked for as such, since Claude Code's permissions page says its ask rules already apply inside a substitution.
- The guard doesn't ask for a variable's value (`git push $f`), since it is known only when the command runs, as is anything a program reads for itself (`gh --body-file`). The PowerShell tool keeps no shell state between calls, so a variable comes from the same command, where an assignment is a statement of its own. These stay ADR-0075's limits, as do the secrets `git add -f` or `--body-file` could send.
- Replayed over the 14,844 Bash and PowerShell commands in the kit's session transcripts (2026-11-15, the ask rules of this commit):
  - The guard asked for 2,843 commands. The text rules alone ask for 487 of them.
  - It found 4 real misses: two `Install-PSResource` and two `git clean` commands inside a compound command or a `foreach` loop.
  - Of the PowerShell commands it newly asks for, one would otherwise have run without a prompt: every top-level command matched an allow rule (`gh run list --commit (git rev-parse HEAD)`). The others already prompted for a part no allow rule covers.
  - The replay found two tokenizer bugs, fixed test-first: a `$` before a closing quote, and `case` patterns. After the fixes, the guard can't read 4 of the 4,762 Bash commands, and `bash -n` rejects those 4 too.
  - The guard took 30 ms per command on average (280 ms at most) in-process. The hook takes about 310 ms per call, measured over 10 runs, mostly `pwsh` starting.
- `tools/tests/AgentConfig.Tests.ps1` now matches rules with the guard's matcher, so the rule syntax lives in one place.
- Editing either guard file asks, as editing the settings does: an edit could switch the guard off.
- Apps get both files in `.kit/tools` through `Export-KitApp.ps1`, which points the hook at `${CLAUDE_PROJECT_DIR}/.kit/tools/Invoke-CommandGuard.ps1`. It refuses to export a hook that runs a kit script the app doesn't get.
- AGENTS.md "Working modes" and the `finish-work` skill list the guard among the guardrails. SEC-003's enforcement names it.
- GAP-044 is closed. ADR-0075's Known limits point here.
- What gets harder: a change to the rule syntax Claude Code documents needs the same change in `Test-PermissionRuleMatch`, and a Bash construct the tokenizer doesn't know asks until it's taught.

## Pillars affected

- **Security:** the asks now hold for the spellings, clusters and nested commands that got past them. Every failure asks, except a guard that can't start: that call falls back to the text rules, which Claude Code still enforces.
- **Performance Efficiency:** about 0.3 s more per shell call.
- **Operational Excellence:** each prompt says what the guard resolved and which rule covers it.
- **Reliability:** a misread asks rather than blocks, and removing the hook entry turns the guard off.
- **Cost Optimization:** not affected.

## Sources

- owner, 2026-11-15 (auto mode: make guardrail changes and log them)
- https://code.claude.com/docs/en/hooks, retrieved 2026-11-15 (PreToolUse input and decision output, exit codes, exec form, `${CLAUDE_PROJECT_DIR}`, matcher `Bash|PowerShell`)
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-15 (rules aren't a security boundary; compound commands; PowerShell AST; hooks and rule precedence)
- https://code.claude.com/docs/en/sandboxing, retrieved 2026-11-15 (platforms; what the sandbox limits)
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html, retrieved 2026-11-15 (POSIX Shell Command Language: token recognition, quoting, quote removal)
- https://www.gnu.org/software/bash/manual/bash.html, retrieved 2026-11-15 (ANSI-C quoting, here documents, case)
- https://learn.microsoft.com/en-us/dotnet/api/system.management.automation.language.parser.parseinput, retrieved 2026-11-15
- ADR-0026, ADR-0075
