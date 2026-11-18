# ADR-0084: An app gets the core ruleset and the rulesets of its app types

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

The owner, 2026-11-17: "make different rulesets to cover all of the supported project types. Have one that holds rules for all project types." Until then every app got every rule. The kit's sample is a web API, so a .NET MAUI app's agent read rules about Program.cs, Problem Details and server databases that didn't apply to it, and some general rules carried web assumptions (ADR-0082).

This branch first gave every rule a `projectTypes` field with ten types: ASP.NET Core Web API, Blazor Web App, Razor Pages and MVC, .NET MAUI, Blazor Hybrid, WinUI 3, WPF, Windows Forms, console or worker, and class library. The owner then decided, the same day, that the kit's rulesets cover only the app types it supports: the ones the new-app intake offers (`templates/app-intake.json`), which New-KitApp can create. Rules for types no app can be made as yet would be unchecked guidance that no app reads.

What's left is which types there are, how a rule names them, and how an app gets only its own rules.

## Options

### Option 1: Rules name a scope; the app's profile names its app types; the app's own Build-AgentRules filters by them

- **How it works:**
  - Every rule names its `scope`: `core`, for every app type, or a list of ids from `docs/standards/app-types.yml`, the one list of app types (CRF-003). `Test-RuleSources.ps1` checks it.
  - The new-app intake maps each app type it offers to its app types. New-KitApp writes them on the `App types:` line under `## App types` in `docs/app-profile.md` (`App types: web-api, blazor`), and Export-KitApp writes the profile before generating the app's rule files.
  - The app's own `Build-AgentRules.ps1` reads that line and writes only the rules whose scope is `core` or names one of the app's types into `.claude/rules/`, `.github/instructions/` and the rule blocks in the app's AGENTS.md.
  - Sync-KitApp passes the app's profile to both exports it compares, the kit's old version and its new one, and reruns Build-AgentRules, so a synced app follows its profile too.
- **Trade-offs:** one list of types, read by every tool. The app still gets every standard's full text in `docs/standards/`, and the gates are the same for every type; only the always-loaded agent instructions shrink. Types the kit doesn't support get no rules until they're added.
- **Reversibility:** easy. Delete the profile's line and the app gets every rule; add a type to `app-types.yml` with its ADR and rules.
- **Risk:** low. A rule scoped to too few types misses apps it should reach; each ruleset's ADR lists its rules, so a reviewer can see that.

### Option 2: Keep all ten project types, supported or not

- **Trade-offs:** guidance is ready when a type is added. But no app of the six unsupported types can be made, so their rules are read by no one and checked against no code, and every rule needs a longer list.
- **Reversibility:** easy.
- **Risk:** medium. Untested guidance for types the kit can't build looks as trustworthy as the rest.

### Option 3: Export only the standards files for the app's types

- **Trade-offs:** smaller apps. But a rule names several types and lives in a topic file, so files can't be split by type without copying rules, and a later type change would need a re-export.
- **Reversibility:** medium.
- **Risk:** medium.

## Recommendation

Option 1. It keeps each rule written once, makes the profile the one place an app's types are chosen, and keeps the kit's rules to the types it can build.

## Decision

Option 1 (owner, 2026-11-17):

- **Scope:** `scope` is `core` or a list of app types from `docs/standards/app-types.yml`, never every type (write `core`, so a type added later is covered). It replaces `projectTypes`, which this branch introduced and `Test-RuleSources.ps1` now rejects. Every rule in force names one.
- **Supported app types:** `web-api` (ASP.NET Core Web API), `blazor` (Blazor Web App) and `maui` (.NET MAUI). The intake's "Web API and Blazor" app has both `web-api` and `blazor`.
- **Not supported yet:** WPF, Windows Forms, WinUI 3, Blazor Hybrid, Razor Pages and MVC, and workers and console apps. Their rules were removed; their pages in `docs/inventory/` stay, marked as not a supported type yet. Class-library guidance became core, since every app holds libraries.
- **The profile:** the `App types:` line under `## App types` in `docs/app-profile.md`, written by `tools/KitIntake.psm1` from the intake's answer. With no profile, or no such line (the kit itself, an app made before this, or an Other app type), every rule applies, as before. A type `app-types.yml` doesn't list stops the build, so a typo can't drop a ruleset.
- **Ruleset ADRs:** the core ruleset's ADR is ADR-0085; the per-type ADRs are ADR-0086 (`web-api`), ADR-0087 (`blazor`) and ADR-0088 (`maui`). Each holds a block, `<!-- ruleset: core -->` or `<!-- ruleset: <type> -->` to `<!-- end ruleset -->`, that `Build-AgentRules.ps1` fills with every rule of that scope, proposed rules marked. `-Check` fails a stale block, as it does a stale rule file.
- **Rule files:** the generated files keep one file per topic and path set, as before.
- **Guardrail rules:** the process rules, the guardrails among them, are `core`, so every app gets them: git.md, definition-of-done.md, communication.md, and SEC-003.

## Consequences

- A .NET MAUI app's agents read the core rules and the MAUI rules, not the web rules.
- An app made before this keeps every rule until its profile gains the line.
- Adding a supported type means an entry in `app-types.yml`, an intake option, rules scoped to it and a ruleset ADR.
- **Not done:**
  - The gates aren't per type. Analyzers, BannedSymbols and the shared CI run the same for every app; most web checks only fire in web projects anyway.
  - WPF, Windows Forms, WinUI 3, Blazor Hybrid, Razor Pages and MVC, and workers and console apps have no rules; their inventory pages hold what Microsoft's guidance says, for when one becomes a supported type.

## Pillars affected

- **Operational excellence:** agents get fewer, relevant rules; one list of types.
- **Performance:** smaller always-loaded instructions for apps that aren't web apps.
- **Reliability, security, cost:** n/a; the security rules that apply to every type stay `core`.

## Sources

- owner, 2026-11-17
- ADR-0058
- ADR-0065
- ADR-0082
