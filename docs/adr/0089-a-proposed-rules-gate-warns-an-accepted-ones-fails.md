# ADR-0089: A proposed rule's gate warns; an accepted one's fails

- **Status:** Accepted
- **Date:** 2026-11-18

## Context

A rule marked `status: proposed` in `docs/standards/` isn't in force until the owner accepts it (AGENTS.md, "Whose rules win"). Its gate ran anyway: `tools/Test-CodeShape.ps1` failed CI on CRF-011, which is proposed. The owner, 2026-11-18: a check must not fail CI for a rule that is still proposed. A proposed rule's findings become warnings, shown on the pull request as GitHub `::warning::` annotations, and they don't count toward the exit code. Once the rule is accepted, the same findings fail CI again, with no code change.

The inventory on 2026-11-18: 19 `kind: gate` enforcement parts on 18 proposed rules.

- **8 judge an app's own code**:
  - CRF-011 (`Test-CodeShape.ps1`);
  - ARC-009 (`Test-EmptyProjects.ps1`);
  - ARC-010 (`Get-UiProject.ps1`'s check that no project references a UI project);
  - DAT-003 (`Test-SafeMigrations.ps1`);
  - OPS-004 (`Test-Runbook.ps1`);
  - CS-023 and HST-003, whose gates are `build:` gates (see the table below);
  - SEC-007's shared part, the shared host checks in `tools/AppTests/Functional`. **Held for the owner**: it stays failing while he decides. Since then the owner retired SEC-007 (2026-11-18), and the checks moved to SEC-017, which keeps Microsoft's condition: they run only in an app whose `AppHost` part says most or all of its endpoints require sign-in (`MostEndpointsRequireSignIn`), and skip, with a reason, elsewhere. They still fail there while SEC-017 is proposed, held as before.
- **7 are the kit's own sample or fixture tests**, unchanged: API-006, SEC-007's sample part (SEC-017's now), SEC-008, SEC-009, SEC-010, UI-003, TST-007.
- **4 are CI machinery**, unchanged: SUP-009 (the SBOM), SUP-010 (Scorecard), SUP-011 (the workload pin), UI-002 (Playwright and axe).

Every analyzer a proposed rule's `build:` gate names today is already in force through an accepted rule. These are all the `kind: gate` parts on proposed rules whose `how` starts with `build:`, read from `docs/standards` on 2026-11-18:

| ID | Proposed rule | Accepted rule that puts it in force | How, with evidence |
|---|---|---|---|
| SYSLIB1045 | CS-023 | STY-003 | The root `.globalconfig` line `dotnet_diagnostic.SYSLIB1045.severity = warning`. `git log -S` shows it came in with 1721bff on 2026-11-16 ("feat: Async names, System.Threading.Lock and the source-generated regex and P/Invoke are gates ... (STY-003, STY-007, STY-011, ADR-0076)"), before CS-023 existed; 5f14fe7 added CS-023 on 2026-11-17. On `origin/main`, `docs/standards/code-style.md` has STY-003 `accepted`, with a `how` that names "the root .globalconfig for every rule latest-all leaves off, SYSLIB1045 ([GeneratedRegex]) and SYSLIB1054 ([LibraryImport]) among them". |
| CA2254 | HST-003 | STY-003 | `<AnalysisLevel>latest-all</AnalysisLevel>` in `Directory.Build.props`, there since a06a672 (2026-11-01). On `origin/main`, STY-003's `how` lists it among the families latest-all turns on ("logging, CA1848, CA2254, CA1727, CA1873"), and the `LoggingMisuse` fixture in `tools/tests/BuildConfig.Tests.ps1` (1f38b0d, 2026-11-16) proves it fails the build. 5f14fe7 added HST-003 on 2026-11-17. |

Two constraints shape the design. The shared CI jobs that run these checks (`.github/workflows/dotnet-ci.reusable.yml`, `app-checks.reusable.yml`) don't install powershell-yaml, so a check can't read the standards' YAML front matter there. And in an app's CI, `$env:KIT` is a checkout of the kit at the version the app pins, so the kit's own copy of the statuses decides.

## Options

### Option 1: Each check script reads its rule's status per finding (recommended)

`tools/Build-AgentRules.ps1` writes `tools/rule-status.json` (`.kit/tools/` in an app), every rule's status, from `docs/standards`. A small module, `tools/KitRuleStatus.psm1`, reads it: `Get-RuleStatus` returns a rule's status and throws on an id it doesn't list, and `Write-RuleFinding` writes one finding, as a `::warning` annotation for a proposed rule or as the error it was for an accepted one, and returns whether it counts. Each check exits non-zero only when a counted finding exists.

- **Trade-offs:** per finding, so one check can hold both kinds: Test-CodeShape's STY-005 findings (accepted) still fail beside CRF-011's warnings. Accepting a rule is the only step that turns its findings into failures. One more generated file, which `-Check` keeps current. The checks need the module and the file beside them, so an app gets both in `.kit/tools`.
- **Reversibility:** easy: drop the module calls.
- **Risk:** low. A typo in a check's rule id throws rather than silently warning. A retired rule's finding throws too, since its check should be gone.

### Option 2: Also lower a proposed rule's build diagnostics in a generated `.globalconfig` block (rejected)

The first version of this change had `Build-AgentRules.ps1` write a block at the end of `.globalconfig` that set each diagnostic a proposed rule's `build:` gate names to `suggestion`, unless an accepted rule's gate named the same ID.

- **Trade-offs:** "accepted wins" protects only the IDs an accepted rule names, but accepted rules put whole families in force: STY-003 turns on every analyzer through AnalysisLevel latest-all and the root `.globalconfig`, and SEC-014 relies on every CA2xxx, CA3xxx and CA5xxx security rule. The branch review showed that a proposed rule naming CA3001 got it lowered to `suggestion`, which switched off part of accepted SEC-014. The ID pattern also missed bans (RS0030), compiler warnings (CS), EF Core and NuGet diagnostics, and gates that are build properties. And `suggestion` doesn't show in a command-line build, so it isn't a warning anyone sees.
- **Reversibility:** easy.
- **Risk:** high: a generated line could silently switch off an accepted security rule. And it had nothing safe to do: every ID it would lower today is in force through STY-003 (the table above). Removed in the same PR (CRF-004).

### Option 3: `continue-on-error` on the CI steps

- **Trade-offs:** no code. But it isn't per finding: it would hide the accepted rules' findings in the same step too (STY-005 in the code shape step), and it doesn't follow the status: accepting a rule would need a workflow edit, in the kit and in the shared workflows every app calls.
- **Reversibility:** easy.
- **Risk:** high: a guardrail that's off for everything in the step.

### Option 4: Leave it as it is

- **Trade-offs:** nothing to build, but a proposed rule keeps failing CI, against the owner's ruling and AGENTS.md's "aren't in force".
- **Reversibility:** n/a.
- **Risk:** apps fail on rules nobody has accepted.

## Recommendation

Option 1: the status decides per finding, from one generated source, so accepting a rule is the only change that makes its findings fail.

## Decision

Option 1, as the owner set out on 2026-11-18 (accepted on his ruling of that date):

- `tools/rule-status.json` maps every rule id to proposed, accepted or retired, sorted by id. `Build-AgentRules.ps1` writes it, and `-Check` fails when it's stale. It lists every rule, whatever an app's types, since a status doesn't depend on them. A missing or empty file stops the check with a message that says so.
- `tools/KitRuleStatus.psm1` exports `Get-RuleStatus` and `Write-RuleFinding`. A warning can name the finding's file, line and column (GitHub's `file`, `line` and `col`), so it shows on that line of the diff; the message and the properties are escaped, so a finding stays one annotation.
- `Test-CodeShape.ps1` maps each finding to its rule from the tool's error code (CRF011 is CRF-011, STY005 is STY-005), and a test checks that every code in `RuleCodes.cs` names a rule `rule-status.json` lists; Kit.CodeShape already tagged its findings, so the C# tool is unchanged. Its warnings name the file relative to the repo root. `Test-EmptyProjects.ps1` (ARC-009), `Test-SafeMigrations.ps1` (DAT-003), `Test-Runbook.ps1` (OPS-004) and `Get-UiProject.ps1`'s reference check (ARC-010) use the module too; `Get-UiProject.ps1`'s listing of UI projects is CI machinery and unchanged, and so is `Test-EmptyProjects.ps1`'s failure on a project the solution lists but that isn't there, which is a broken solution rather than ARC-009's concern. Each takes `-RuleStatusPath`, for a test's own statuses, and its summary says how many findings were warnings because their rule is proposed.
- **The per-finding warning covers the check scripts only.** A build gate isn't per finding: the compiler fails the build on a diagnostic, whichever rule asked for it. So a proposed rule's `build:` gate must name only diagnostics, bans or build properties that an accepted rule already puts in force: STY-003's AnalysisLevel latest-all and root `.globalconfig`, SEC-014's security analyzers, CRF-010's `BannedSymbols.txt`, and STY-004's `TreatWarningsAsErrors`. A new diagnostic, ban or property a proposed rule needs is turned on only in the pull request that accepts the rule. Code review checks this, and the same for a change that touches no rule to `.globalconfig`, `.editorconfig`, a `BannedSymbols*.txt`, any `Directory.Build.props` or project file, or `Directory.Packages.props` with a new analyzer package; a breach of either is Blocking (`docs/code-review.md`; owner, 2026-11-18).
- SEC-007's shared host check isn't lowered to a warning; it's held for the owner. With SEC-007 retired, it is SEC-017's, and skips in an app whose endpoints are mostly public.
- The shared host checks are xUnit tests in an app's FunctionalTests, not check scripts, so they don't read `rule-status.json`: a failing one fails the app's tests whatever its rule's status. Since 2026-11-18, ADR-0081's GAP-037 update added such checks for SEC-008, which is proposed: `TokenTests`, and `OpenApiDocumentTests`' bearer check. They're held the same way, for the owner to decide with SEC-008 and SEC-017. **The owner, 2026-11-27: they keep failing** ("Fix gap, keep failing"). SEC-008's and SEC-017's shared checks fail an app's CI while those rules are proposed, as an exception to this ADR's warnings. The gap he fixed with it: a host that signs nobody in now says so (`SignsUsersIn`, ADR-0081's 2026-11-27 update), and the token checks skip there, with a reason, as the fallback checks skip where most endpoints are public.

## Consequences

- A check script that judges an app's code warns on a proposed rule's findings and fails on an accepted one's. Accepting a rule, then running `Build-AgentRules.ps1`, turns its warnings into failures in the kit at once, and in an app when it moves to that kit version.
- `rule-status.json` is a generated file (AGENTS.md lists it). Editing a rule's status without regenerating fails `Build-AgentRules.ps1 -Check`.
- A new check that judges an app's code calls `Write-RuleFinding` with its rule's id, and a new error code from Kit.CodeShape needs a rule id that `rule-status.json` lists, which a test checks.
- A proposed rule whose gate would need a new analyzer, ban or property stays advisory until it's accepted; the accepting pull request turns the gate on.
- Later: ADR-0090 (rule layers, approved by the owner, not yet written) replaces `proposed` with a `strength` of must, should or consider, and will base the warn-or-fail choice on a rule's strength instead of its status: a gate fails on must, warns on should and doesn't run for consider. `Get-RuleStatus` becomes `Get-RuleStrength`; `Write-RuleFinding` stays.
- Known limits (CRF-002):
  - `Get-UiProject.ps1` runs in several CI steps, so a proposed ARC-010 warning can show once per step. No follow-up: GitHub shows each annotation with its step, a repeat doesn't fail anything, and it ends when ARC-010 is accepted or the reference goes.
  - The warnings of Test-EmptyProjects, Test-SafeMigrations, Test-Runbook and Get-UiProject don't name a file and line yet, since their findings carry only a message; each knows the file (a project, a migration with its line, the runbook). Follow-up: a small follow-up pull request passes `-File` and `-Line` from each, after the code shape check's inline warnings have been seen on a real pull request, so the path form is proven first.

## Pillars affected

- **Operational excellence:** CI fails only on rules in force. A check script's findings for a proposed rule still show, as warnings on the pull request, so nothing it finds goes unseen while the owner decides. A build gate never lowers anything, so every analyzer that's on stays a build failure.
- **Reliability:** an unknown rule id or status, or a missing statuses file, throws, so a typo can't turn a gate into warnings.
- **Security:** no security check is lowered to a warning: the shared authorization check (SEC-007's, now SEC-017's) is held, and skips only where SEC-017 doesn't apply; every accepted rule's gate still fails, and no analyzer severity is lowered.
- **Cost, performance:** n/a.

## Sources

- owner, 2026-11-18
- owner, 2026-11-27 ("Fix gap, keep failing")
- ADR-0063
- ADR-0084
- https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands, retrieved 2026-11-18
