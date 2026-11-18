# ADR-0089: A proposed rule's gate warns; an accepted one's fails

- **Status:** Proposed
- **Date:** 2026-11-18

## Context

A rule marked `status: proposed` in `docs/standards/` isn't in force until the owner accepts it (AGENTS.md, "Whose rules win"). Its gate ran anyway: `tools/Test-CodeShape.ps1` failed CI on CRF-011, which is proposed. The owner, 2026-11-18: a check must not fail CI for a rule that is still proposed. A proposed rule's findings become warnings, shown on the pull request as GitHub `::warning::` annotations, and they don't count toward the exit code. Once the rule is accepted, the same findings fail CI again, with no code change.

The inventory on 2026-11-18: 19 `kind: gate` enforcement parts on 18 proposed rules.

- **8 judge an app's own code**, which this changes:
  - CRF-011 (`Test-CodeShape.ps1`);
  - ARC-009 (`Test-EmptyProjects.ps1`);
  - ARC-010 (`Get-UiProject.ps1`'s check that no project references a UI project);
  - DAT-003 (`Test-SafeMigrations.ps1`);
  - OPS-004 (`Test-Runbook.ps1`);
  - CS-023 (SYSLIB1045) and HST-003 (CA2254), build gates;
  - SEC-007's shared part, the shared host checks in `tools/AppTests/Functional`. **Held for the owner**: it stays failing while he decides.
- **7 are the kit's own sample or fixture tests**, unchanged: API-006, SEC-007's sample part, SEC-008, SEC-009, SEC-010, UI-003, TST-007.
- **4 are CI machinery**, unchanged: SUP-009 (the SBOM), SUP-010 (Scorecard), SUP-011 (the workload pin), UI-002 (Playwright and axe).

Two constraints shape the design. The shared CI jobs that run these checks (`.github/workflows/dotnet-ci.reusable.yml`, `app-checks.reusable.yml`) don't install powershell-yaml, so a check can't read the standards' YAML front matter there. And in an app's CI, `$env:KIT` is a checkout of the kit at the version the app pins, so the kit's own copy of the statuses decides.

## Options

### Option 1: Each check reads its rule's status per finding (recommended)

`tools/Build-AgentRules.ps1` writes `tools/rule-status.json` (`.kit/tools/` in an app), every rule's status, from `docs/standards`. A small module, `tools/KitRuleStatus.psm1`, reads it: `Get-RuleStatus` returns a rule's status and throws on an id it doesn't list, and `Write-RuleFinding` writes one finding, as a `::warning::` annotation for a proposed rule or as the error it was for an accepted one, and returns whether it counts. Each check exits non-zero only when a counted finding exists. For build gates, the same build writes a block at the end of `.globalconfig` that sets each diagnostic a proposed rule's build gate names to `suggestion`.

- **Trade-offs:** per finding, so one check can hold both kinds: Test-CodeShape's STY-005 findings (accepted) still fail beside CRF-011's warnings. Accepting a rule is the only step that turns its findings into failures. One more generated file and one more generated block, which `-Check` keeps current. The checks need the module and the file beside them, so an app gets both in `.kit/tools`.
- **Reversibility:** easy: drop the module calls and the block.
- **Risk:** low. A typo in a check's rule id throws rather than silently warning. A retired rule's finding throws too, since its check should be gone.

### Option 2: `continue-on-error` on the CI steps

- **Trade-offs:** no code. But it isn't per finding: it would hide the accepted rules' findings in the same step too (STY-005 in the code shape step), and it doesn't follow the status: accepting a rule would need a workflow edit, in the kit and in the shared workflows every app calls.
- **Reversibility:** easy.
- **Risk:** high: a guardrail that's off for everything in the step.

### Option 3: Leave it as it is

- **Trade-offs:** nothing to build, but a proposed rule keeps failing CI, against the owner's ruling and AGENTS.md's "aren't in force".
- **Reversibility:** n/a.
- **Risk:** apps fail on rules nobody has accepted.

## Recommendation

Option 1: the status decides per finding, from one generated source, so accepting a rule is the only change that makes its findings fail.

## Decision

Option 1, as the owner set out on 2026-11-18:

- `tools/rule-status.json` maps every rule id to proposed, accepted or retired, sorted by id. `Build-AgentRules.ps1` writes it, and `-Check` fails when it's stale. It lists every rule, whatever an app's types, since a status doesn't depend on them.
- `tools/KitRuleStatus.psm1` exports `Get-RuleStatus` and `Write-RuleFinding`. A warning escapes `%`, CR and LF, so a finding stays one annotation.
- `Test-CodeShape.ps1` maps each finding to its rule from the tool's error code (CRF011 is CRF-011, STY005 is STY-005); Kit.CodeShape already tagged them, so the C# tool is unchanged. `Test-EmptyProjects.ps1` (ARC-009), `Test-SafeMigrations.ps1` (DAT-003), `Test-Runbook.ps1` (OPS-004) and `Get-UiProject.ps1`'s reference check (ARC-010) use the module too; `Get-UiProject.ps1`'s listing of UI projects is CI machinery and unchanged. Each takes `-RuleStatusPath`, for a test's own statuses, and its summary says how many findings were warnings because their rule is proposed.
- The `.globalconfig` block lowers a diagnostic only when no accepted rule's build gate names it: accepted wins. On 2026-11-18 it lowers nothing. CS-023's SYSLIB1045 and HST-003's CA2254 are both also named by STY-003's build gate, which is accepted and turns every analyzer rule on, so they stay warnings, and the block says "None today". A test checks that the kit's block lowers no diagnostic an accepted rule names.
- SEC-007's shared host check is unchanged, held for the owner.

## Consequences

- A check that judges an app's code warns on a proposed rule's findings and fails on an accepted one's. Accepting a rule, then running `Build-AgentRules.ps1`, turns its warnings into failures in the kit at once, and in an app when it moves to that kit version.
- `rule-status.json` and the `.globalconfig` block are generated files (AGENTS.md lists them). Editing a rule's status without regenerating fails `Build-AgentRules.ps1 -Check`.
- A new check that judges an app's code calls `Write-RuleFinding` with its rule's id, and a new error code from Kit.CodeShape needs a rule id that `rule-status.json` lists, or the check throws.
- Known limits, written down rather than built now (CRF-002):
  - `.editorconfig` wins over `.globalconfig`, so a proposed rule's diagnostic that `.editorconfig` also sets isn't lowered by the block. None is today; it would fail the build, which errs toward the gate.
  - When the block first lowers a diagnostic that `tools/tests/BuildConfig.Tests.ps1` has a failing fixture for, that fixture will stop failing, and the test must learn to expect the lowered severity in the same PR.
  - `Get-UiProject.ps1` runs in several CI steps, so a proposed ARC-010 warning can show once per step.

## Pillars affected

- **Operational excellence:** CI fails only on rules in force; a proposed rule's findings still show, as warnings, so nothing goes unseen while the owner decides.
- **Reliability:** an unknown rule id or status throws, so a typo can't turn a gate into warnings.
- **Security, cost, performance:** n/a. No security check changes: SEC-007's shared check is held, and every accepted rule's gate still fails.

## Sources

- owner, 2026-11-18
- ADR-0063
- ADR-0084
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands, retrieved 2026-11-18
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/configuration-files, retrieved 2026-11-18
