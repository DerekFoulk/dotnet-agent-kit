# ADR-0046: Every UI an app ships meets WCAG 2.2 level AA

- **Status:** Accepted
- **Date:** 2026-11-11

## Context

The quality scorecard's "UI and accessibility" area says a perfect app's UI meets WCAG 2.2 AA (ADR-0034). No rule says so, though. Only the plan checklist asks about accessibility (ARC-006), so an agent building a page has nothing to check its work against. That's GAP-018. GAP-004 is a separate gap: it adds Playwright browser tests with axe, which can check part of WCAG automatically.

WCAG (the Web Content Accessibility Guidelines) is W3C's accessibility standard. Version 2.2 has been a W3C Recommendation since 5 October 2023; the current edition, with errata, is dated 12 December 2024. It removes 4.1.1 Parsing and adds nine criteria. Six of them are level A or AA, among them 2.4.11 Focus Not Obscured (Minimum) and 2.5.8 Target Size (Minimum). Level AA conformance means meeting every level A and AA criterion. Microsoft's .NET MAUI accessibility guide calls WCAG "the global accessibility standard and legal benchmark for web and mobile". WCAG is written for web content. W3C's WCAG2ICT Group Note (11 December 2025) says how each level A and AA criterion of WCAG 2.2 applies to software that isn't web, such as MAUI and desktop apps. For example, it reads "CSS pixels" as the platform's density-independent unit.

The kit's apps are Blazor web apps or native MAUI apps (ADR-0008). This ADR was decided in auto mode (ADR-0035).

## Options

### Option 1: WCAG 2.2 level AA, with native UI measured through WCAG2ICT

- **Trade-offs:** The current standard, and the level the scorecard already names. It includes the 2.2 criteria that matter most for touch and keyboard users (target size, focus not obscured). It's a little stricter than 2.1 AA: a page that meets 2.2 AA also meets 2.1 AA, except for 4.1.1, which 2.2 dropped as obsolete.
- **Reversibility:** Easy. It's one rule and a page of guidance, and no code depends on it yet.
- **Risk:** Low. Some regulations still cite 2.1 AA. Meeting 2.2 AA covers them: the one 2.1 criterion that 2.2 dropped, 4.1.1 Parsing, is treated as always met for HTML and XML in 2.1's own errata.

### Option 2: WCAG 2.1 level AA

- **Trade-offs:** The version that some regulations and procurement standards still reference. It leaves out target size and focus not obscured, which are cheap to meet when they're designed in.
- **Reversibility:** Easy, as above.
- **Risk:** Apps would aim below the current Recommendation, and moving up later means rework.

### Option 3: WCAG 2.2 level AAA

- **Trade-offs:** The strictest level. W3C itself doesn't recommend requiring AAA for whole sites, because some content can't meet every AAA criterion. WCAG2ICT doesn't cover AAA for native software.
- **Reversibility:** Easy to relax.
- **Risk:** Some AAA criteria (sign language for prerecorded audio, for example) don't fit every app, so agents would make exceptions page by page.

## Recommendation

Option 1. It's the current standard at the level the scorecard already names, and WCAG2ICT extends it to the kit's native apps.

## Decision

Option 1, decided in auto mode on 2026-11-11. UI-001 stays `proposed` until the owner ratifies it. The owner can reverse this, as with any merged change.

## Consequences

- **Rule:** UI-001, proposed, in `docs/standards/ui.md`. It names six checks an agent applies when it builds UI (keyboard, names and labels, contrast, focus, target size, reflow), and the page explains how to meet each one in Blazor and MAUI. Its `paths` are UI files only (`.razor` and its `.razor.cs` code-behind, `.cshtml`, `.css`, `.html`, `.xaml` and its `.xaml.cs` code-behind). Once it's accepted, the rule file it generates loads only for those.
- **Plans:** the `plan-checklist` skill's Accessibility heading points at UI-001 instead of restating the criteria, and asks how each check is tested. A Pester test (`RuleDrift.Tests.ps1`) fails if the pointer goes missing.
- **Checks:** none automated yet. GAP-004 adds axe checks for web UI. Even then, axe finds only some WCAG failures, so keyboard and screen-reader passes stay manual. Native UI has no CI check. Each platform's tools (Accessibility Insights, Accessibility Inspector) and screen reader cover it. Until GAP-004, the rule is advisory and rests on the plan checklist and the reviewer agent.
- **Scorecard:** GAP-018 is closed. GAP-004 stays open.

## Pillars affected

- **Operational Excellence:** a clear bar that every plan and review checks against, instead of a question in the plan checklist.
- **Reliability, Security, Cost Optimization, Performance Efficiency:** not affected. It adds no service, package or runtime code.

## Sources

- https://www.w3.org/TR/WCAG22/, retrieved 2026-11-11
- https://www.w3.org/TR/wcag2ict-22/, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/accessibility, retrieved 2026-11-11
- https://learn.microsoft.com/en-us/aspnet/core/blazor/fundamentals/routing#focus-an-element-on-navigation, retrieved 2026-11-11
