# ADR-0092: Pester runs only in a child process, through one launcher, and the PowerShell tool asks before Invoke-Pester

- **Status:** Accepted
- **Date:** 2026-11-21

## Context

Twice, on 2026-11-03 and on 2026-11-18, an agent ran `Invoke-Pester` inside Claude Code's PowerShell tool session, which keeps its variables between calls. Each time the agent had saved a script's text and its path in session variables (`$p`, `$orig`) to put the script back later. Pester runs code in its caller's session state (its runtime runs `Pester.ScriptScope.ps1` to push a script scope there), and afterwards the path variable pointed at a file in Pester's own module folder. The agent's "restore" then wrote the script's text over `Pester.ScriptScope.ps1` in `~/OneDrive/Documents/PowerShell/Modules/Pester/6.2.0`. After that every Pester run on the machine failed with empty errors, until the owner reinstalled Pester. Which of Pester's variables changed the path isn't confirmed.

A memory note after the first incident ("run Pester in a fresh `pwsh -NoProfile`") didn't stop the second: the subagent that caused it never read the note, and its brief didn't repeat it. A rule that lives only in an agent's memory or a brief protects only the agents that happen to read it. The owner approved a structural fix on 2026-11-21: a launcher, a permission rule, an early warning in `Initialize-DevMachine.ps1`, and restores through git only.

Claude Code's permission rules match a command's text (ADR-0026, ADR-0075). A rule can't stop a determined spelling, but an ask rule on the plain command turns the habit into a prompt that names the safe path.

## Options

### Option 1: A launcher, plus an ask rule on Invoke-Pester in the PowerShell tool

- **Trade-offs:** `tools/Invoke-KitTests.ps1` is the one way the kit runs its script tests locally. It always starts a child `pwsh -NoProfile -NonInteractive` process with `$ErrorActionPreference = 'Stop'`, the repo root as its working directory and literal (escaped) paths, so nothing Pester does reaches the caller's session, and returns the counts and an exit code. `.claude/settings.json` moves `PowerShell(Invoke-Pester *)` from the allow list to the ask list (a trailing ` *` also matches the bare command, as Claude Code's permissions page says), and the launcher stays allowed through the existing `./tools/*` rules. An agent that types `Invoke-Pester` gets a prompt the owner can refuse; the instructions name the launcher. `Invoke-Mutant` runs its test runs through the launcher too, so the child-process run has one source (CRF-003). Costs one more process start per run, about a second.
- **Reversibility:** Easy: move the rule back, and the launcher is one script.
- **Risk:** Low. Taking `Invoke-Pester` off the allow list is what makes every spelling of it prompt; the ask rule matches the plain form's text and adds an ask that beats a wider allow. Spellings it doesn't match (an assignment such as `$r = Invoke-Pester ...`, `Pester\Invoke-Pester`, `& Invoke-Pester`, `& (Get-Command Invoke-Pester)`) prompt only because no allow rule covers them, which `tools/tests/AgentConfig.Tests.ps1` pins. What could still get past is `Invoke-Pester` nested inside a command a wide allow covers, such as a `./tools/` script's argument in `( )` or `$( )`: Claude Code's docs don't say whether it checks the commands inside (ADR-0075's known limits, GAP-044). A `pwsh -Command "Invoke-Pester ..."` string isn't caught either, but that already runs in a child process, and no allow rule covers it, so it prompts.

### Option 2: The launcher only

- **Trade-offs:** The same launcher and instructions, with `Invoke-Pester` left allowed. No new prompt for anyone. Nothing stops an agent that hasn't read the instructions, which is how the second incident happened.
- **Reversibility:** Easy.
- **Risk:** Medium: it depends on every agent and subagent reading the instructions, as the memory note did.

### Option 3: Claude Code's sandbox

- **Trade-offs:** Claude Code's sandbox limits which folders a command may write to, which would keep any write out of the module folders whatever the command's text. It isn't verified for the PowerShell tool on Windows, where the owner works: ADR-0075 and GAP-044 record that it doesn't support that tool there yet, and this ADR didn't test it. It would also change how every other command runs.
- **Reversibility:** Medium: a settings change, but every workflow would need re-checking under it.
- **Risk:** Unknown on Windows; not verified.

### Option 4: A PreToolUse hook that parses each command

- **Trade-offs:** GAP-044's hook would resolve each command with PowerShell's own parser and ask for `Invoke-Pester` in any spelling. It's a project of its own, with its own ADR, and a guardrail.
- **Reversibility:** Easy once it exists.
- **Risk:** Low, but it doesn't exist yet. It complements Option 1 later rather than replacing it.

## Recommendation

Option 1: the launcher makes the safe run the easy one, and the ask rule catches the habit that caused both incidents, without waiting for the sandbox or the hook.

## Decision

Accepted as recommended, by the owner on 2026-11-21 ("Yes", to the four-part design: the launcher, the permission rule, the signature check, restores through git only).

## Consequences

- `tools/Invoke-KitTests.ps1` and its tests (`tools/tests/Invoke-KitTests.Tests.ps1`). AGENTS.md's Commands table, the README, the `tdd-cycle` and `finish-work` skills and `docs/standards/testing.md` name it. It's kit-only: apps get no Pester tests, so `Export-KitApp.ps1`'s list of tools doesn't change. An app's `.claude/settings.json` keeps the ask rule, since it names no kit script.
- **CI keeps calling `Invoke-Pester` directly** (`kit-checks.reusable.yml`): each run starts on a fresh runner in a fresh `pwsh` step, with no shared session for Pester to change. One difference follows: the launcher fails a run in which no test passed or failed, and CI's step doesn't. The launcher's own tests run in CI on Linux, so it's proven there.
- The launcher refuses to run dot-sourced, and so does `Invoke-Mutant.ps1`, which now runs its tests through the launcher (so its runs get `Stop` too, and the launcher's rule for "ran no tests"). Dot-sourced, either would leave its variables (`$file`, `$original`, `$exitCode` and the rest) in the caller's session: the kind of generic variable both incidents wrote through. PowerShell still binds their parameters there first. Run as `./` or `&`, `Invoke-Mutant`'s restore reads only its own script-scope variables, and nothing runs between the save and the restore except its own functions and the launcher script, which starts the child process. Both run their tests from the root of the repo the script is in, so a fresh clone runs its own copy. `Invoke-Mutant` refuses to mutate the launcher beside it, which would judge its own mutants; another clone's `Invoke-Mutant` probes it. It ends with exit code 0, since the launcher's exit code for a killed mutant isn't the caller's.
- Running a fresh clone's launcher by its full path from elsewhere prompts, since the allow rules cover only `./tools/` paths and a path anywhere would allow any script of that name. Run it from inside the clone, or approve the prompt.
- Files are put back with `git restore -- <path>`, never by writing saved text to a path held in a variable (`tdd-cycle`, `docs/standards/testing.md`, `Invoke-Mutant`'s help).
- `Initialize-DevMachine.ps1` checks, on Windows, that every file of a type Authenticode signs (`.ps1`, `.psm1`, `.psd1`, `.ps1xml`, `.dll`, `.cat`) in each installed Pester 6 or later is still validly signed, and names the files that aren't, with the command that reinstalls that version (`Install-PSResource ... -Reinstall`). Reinstalling is the owner's step, so `-Install` never runs it, and `.claude/settings.json` asks before the printed `pwsh -NoProfile -Command "Install-PSResource ..."` form in either tool. A probe that fails says the check couldn't run, not that Pester's files changed. An overwritten script is `NotSigned`, so it shows up the next time the check runs; the check can't prevent the damage. Off Windows `Get-AuthenticodeSignature` isn't available, so the check says it's skipped, and a skipped check doesn't make the machine not ready. Apps get `Initialize-DevMachine.ps1` (`Export-KitApp.ps1`'s list of tools), so they get the check too. Its limits:
  - it covers 7 of the Pester 6.2.0 package's 17 files; the help, schema and notice files (`.txt`, `.xsd`, `.dtd`), and the `PSGetModuleInfo.xml` the installer adds, can't be signed, so a change to them goes unseen;
  - it covers Pester only, not powershell-yaml or other modules;
  - whether `Get-AuthenticodeSignature` checks revocation online, and so could report a false failure offline, isn't verified;
  - its test against real signatures runs only on Windows, so not in CI, which runs on Linux.
- An agent that runs `Invoke-Pester` directly in the PowerShell tool now gets a prompt, as does one that pastes a module install `Initialize-DevMachine` prints.
- SEC-003's list of what agents ask before (`docs/standards/security.md`) doesn't name `Invoke-Pester`: it lists "Always ask" items, and a test run isn't one. CLAUDE.md's Permissions bullet lists the new ask.

## Pillars affected

- **Reliability:** a test run can no longer break the machine's Pester for every later run.
- **Security:** a test run can't write outside the repo through the session; the signature check detects a changed module file.
- **Operational Excellence:** one command to run the tests, with counts and an exit code; the machine check names the damage and the fix.
- **Performance Efficiency:** one more process start per local test run.
- **Cost Optimization:** none.

## Sources

- owner, 2026-11-21
- ADR-0026, ADR-0075 (how the permission rules match, and their known limits)
- https://code.claude.com/docs/en/permissions, retrieved 2026-11-15 (via ADR-0075: rule order, wildcards, PowerShell rules)
- https://learn.microsoft.com/powershell/module/microsoft.powershell.security/get-authenticodesignature, retrieved 2026-11-21 ("This cmdlet is only available on the Windows platform.")
