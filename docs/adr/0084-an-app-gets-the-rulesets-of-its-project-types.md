# ADR-0084: An app gets the common ruleset and the rulesets of its project types

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

The owner, 2026-11-17: "make different rulesets to cover all of the supported project types. Have one that holds rules for all project types." Until then every app got every rule. The kit's sample is a web API, so a .NET MAUI app's agent read rules about Program.cs, Problem Details and server databases that didn't apply to it, and some general rules carried web assumptions (ADR-0082).

ADR-0082 makes every rule name its `projectTypes`: `[all]`, or ids from `docs/standards/project-types.yml`. The ten types are ASP.NET Core Web API, Blazor Web App, Razor Pages and MVC, .NET MAUI, Blazor Hybrid, WinUI 3, WPF, Windows Forms, console or worker, and class library. Each type's ruleset has an ADR that lists its rules and the framework's own Microsoft guidance (ADR-0085 to ADR-0095). What's left is how an app gets only its own.

## Options

### Option 1: The app's profile names its types, and the app's own Build-AgentRules filters by them

- **How it works:**
  - The new-app intake maps each app type to its project types (`templates/app-intake.json`). New-KitApp writes them on a line of `docs/app-profile.md` (`Project types: web-api, blazor`) and hands the profile to Export-KitApp, which writes it before generating the app's rule files.
  - The app's own `Build-AgentRules.ps1` reads that line. It writes only the rules with `[all]` or one of the app's types into `.claude/rules/`, `.github/instructions/` and the rule blocks in the app's AGENTS.md. Sync-KitApp reruns it, so a synced app follows its profile too.
  - With no profile, or no such line (the kit itself, an app made before this, or an Other app type), every rule applies, as before.
  - A type the list doesn't know stops the build, so a typo can't drop a ruleset.
- **Trade-offs:** one list of types, read by every tool (CRF-003). The app still gets every standard's full text in `docs/standards/`, and the gates are the same for every type; only the always-loaded agent instructions shrink.
- **Reversibility:** easy. Delete the line and the app gets every rule.
- **Risk:** low.

### Option 2: Export only the standards files for the app's types

- **Trade-offs:** smaller apps. But a rule names several types and lives in a topic file, so files can't be split by type without copying rules, and a later type change would need a re-export.
- **Reversibility:** medium.
- **Risk:** medium.

### Option 3: One standards folder per type

- **Trade-offs:** each ruleset reads on its own, but a rule for several types is written several times. The owner's brief rules that out ("written once and names every type it applies to").
- **Reversibility:** hard.
- **Risk:** high.

## Recommendation

Option 1. It keeps each rule written once, needs no change to how apps get the standards, and makes the profile the one place an app's types are chosen.

## Decision

Option 1. In addition:

- **Ruleset ADRs:** each one holds a block, `<!-- ruleset: <type> -->` to `<!-- end ruleset -->`, that `Build-AgentRules.ps1` fills with every rule naming that type, proposed rules marked. The common ruleset's ADR (ADR-0085) lists the `[all]` rules. `-Check` fails a stale block, as it does a stale rule file.
- **Rule files:** the generated files keep one file per topic and path set, as before.
- **Choosing types:** the intake offers the four app types the kit can create today: Web API and Blazor, Web API, Blazor and .NET MAUI. An app of another type names its types in an ADR and adds the line to its profile by hand.
- **Guardrail rules:** the process rules, the guardrails among them, are `[all]`, so every app gets them: git.md, definition-of-done.md, communication.md, and SEC-003.

## Consequences

- A .NET MAUI app's agents read the common rules and the MAUI rules, not the web rules.
- An app made before this keeps every rule until its profile gains the line.
- **Not done:**
  - The gates aren't per type. Analyzers, BannedSymbols and the shared CI run the same for every app; most web checks only fire in web projects anyway.
  - The intake doesn't yet offer WinUI 3, WPF, Windows Forms, console or class-library apps, which New-KitApp can't create yet.

## Pillars affected

- **Operational excellence:** agents get fewer, relevant rules; one list of types.
- **Performance:** smaller always-loaded instructions for apps of non-web types.
- **Reliability, security, cost:** n/a; the security rules that apply to every type stay `[all]`.

## Sources

- owner, 2026-11-17
- ADR-0058
- ADR-0065
- ADR-0082
