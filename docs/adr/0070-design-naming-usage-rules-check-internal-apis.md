# ADR-0070: The Design, Naming and Usage rules check internal APIs too

- **Status:** Accepted
- **Date:** 2026-11-15

## Context

The rules audit's Framework Design Guidelines pass (2026-11-13) mapped the guidelines' 369 DO, CONSIDER, AVOID and DO NOT lines to the kit's analyzers. 70 of the 100 guidelines an analyzer gates rest on rules whose `api_surface` option defaults to `public`: they check only public and protected APIs. Microsoft's options page lists 54 such rules, CA1000 to CA2234 (https://learn.microsoft.com/dotnet/fundamentals/code-analysis/code-quality-rule-options#api_surface).

CA1515, which the kit turns on, makes an app's public types internal. So in an app's executable projects, and for the internal types of its libraries, CA1051 (visible instance fields), CA1062 (validate arguments), CA1711 (incorrect suffixes), CA1716, CA1720, CA2225 (named alternatives for operators) and the rest never fire.

The option can be set for all rules, for a category of rules, or for one rule. Three rules on the list (CA1802, CA1822, CA1859) have their own reasons for their scope: CA1859 asks non-public code for concrete types, the opposite of the guidelines' "least derived type" for public APIs.

## Options

### Option 1: The Design, Naming and Usage categories, plus CA1815 and CA1819, at public and internal

`.editorconfig` sets `dotnet_code_quality.<Category>.api_surface = public, internal` for Design, Naming and Usage, and the same for CA1815 and CA1819 by rule ID (they're Performance rules).

- **Trade-offs:** The guidelines' rules reach an app's own types, as they reach a framework's public ones. CA1802, CA1822 and CA1859 keep their own scope. Private members stay out, because the guidelines are about a type's API. A category setting replaces each of its rules' own default, though, and two rules in these categories default to every member, private included: CA1068 (Design) and CA2208 (Usage), as the analyzers' source shows (`defaultRequiredVisibility: SymbolVisibilityGroup.All`). Setting the category alone would stop them checking private members, so they keep `all` by rule ID. A rule's own setting wins over its category's; Microsoft's options page lists the scopes without saying which wins, and the two private-member fixtures prove it. In the kit, the gate found two arguments a method used unchecked (CA1062), a type whose name ends in Exception but isn't one (CA1711), and a parameter named after a type (CA1720).
- **Reversibility:** Easy: seven lines.
- **Risk:** Low. A rule that doesn't honor the option on internal types would stay silent; the fixtures prove one rule from each category, and CA1815 and CA1819.

### Option 2: All rules at public and internal

`dotnet_code_quality.api_surface = public, internal`.

- **Trade-offs:** One line, but it replaces every rule's own default: CA1822, CA1068 and CA2208, which check every member, would stop checking private ones; CA1859, written for non-public code, would check public APIs too, where the guidelines ask for the least derived type; and CA1802 would widen for no guideline.
- **Reversibility:** Easy.
- **Risk:** Medium: findings that contradict the guidelines.

### Option 3: `all`, private members included

- **Trade-offs:** Checks private helpers against rules written for an API's callers, such as named alternatives for operators and argument validation, where the caller is the type itself.
- **Reversibility:** Easy.
- **Risk:** Medium: noise that teaches people to suppress.

### Option 4: Leave the default

- **Trade-offs:** Nothing changes, and 70 gated guidelines stay unchecked in every app.
- **Reversibility:** Easy.
- **Risk:** High for quality.

## Recommendation

Option 1: it's how Microsoft's own rules reach an app whose types CA1515 made internal, without turning CA1859 against the guidelines.

## Decision

Accepted as recommended (owner, 2026-11-13, "Yes, accept them": the Framework Design Guidelines pass's decisions 1 and 2, which also turn IDE0250, readonly structs, on at warning).

## Consequences

- **STY-009** states the rule. `.editorconfig` holds the settings, and an app gets the same file.
- **Tests:** `tools/tests/BuildConfig.Tests.ps1` has a failing fixture for a Design rule (CA1051), a Naming rule (CA1711), a Usage rule (CA2225), CA1815, CA1819 and IDE0250, each of which built clean before the settings, and for a private CA2208 and CA1068.
- **Two rules keep their wider default:** CA1068 and CA2208 check every member by default, private ones included, so `.editorconfig` sets them to `all` by rule ID, and a failing fixture for each (a private member) proves the category setting didn't narrow them. The review of this PR found the narrowing. The fixtures prove each category, not each of the 54 rules.
- **Left public-only:** CA1034, CA1712 and CA1724 aren't on the configurable list.
- **The kit's own code** changed in four places: `ArgumentNullException.ThrowIfNull` in the sample's OpenAPI transformer and the web UI fixture's test host, `LimitException` in `tools/CodeShape` renamed `LimitExemption` (it isn't an exception type), and a test helper's `signed` parameter renamed `isSigned`.
- **The advisory part** of the Framework Design Guidelines pass (decision 3: the guidelines no analyzer checks, with themes in `docs/code-review.md`) changes the code-review instructions, a guardrail, so it lands in its own PR.

## Pillars affected

Operational Excellence: an app's own types meet the same design, naming and usage rules as a framework's public ones, found by the build. Reliability: CA1062 now checks every internal method's reference arguments.

## Sources

- owner, 2026-11-13
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/code-quality-rule-options#api_surface, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/standard/design-guidelines/, retrieved 2026-11-13
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca1515, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/style-rules/ide0250, retrieved 2026-11-15
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2208, retrieved 2026-11-15
- https://github.com/dotnet/sdk/tree/main/src/Microsoft.CodeAnalysis.NetAnalyzers (CancellationTokenParametersMustComeLast.cs, InstantiateArgumentExceptionsCorrectly.cs, MarkMembersAsStatic.cs), retrieved 2026-11-15
