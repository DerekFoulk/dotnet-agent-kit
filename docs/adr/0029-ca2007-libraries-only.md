# ADR-0029: CA2007 applies to class libraries only

- **Status:** Accepted
- **Date:** 2026-11-04

## Context

The kit turns on every analyzer rule (`AnalysisLevel` `latest-all`, STY-003) and treats warnings as errors; an opt-out needs an ADR. The step 5 spike (`spikes/latest-all/README.md`) measured 31 warnings in about 200 lines of ordinary code. Most pointed to a real improvement. CA2007, "Do not directly await a Task", was the second most frequent (7 of 31): it asks for `ConfigureAwait` on every `await`.

Microsoft's guidance for CA2007: the warning "is intended for libraries"; "it is generally appropriate to suppress the warning entirely for projects that represent application code rather than library code"; and in ASP.NET Core, which has no synchronization context, "a `ConfigureAwait` wouldn't actually change any behavior". The rule can be limited to some output kinds with `dotnet_code_quality.CA2007.output_kind`.

The spike also flagged CA1303 (localizable literals). The owner kept CA1303 on.

## Options

### Option 1: Keep CA2007 for class libraries; turn it off for apps and test projects

- **Trade-offs:** Libraries, which may run under any caller's context, still get `ConfigureAwait(false)` everywhere. App and test code stays free of calls that change nothing there. Test projects are libraries to the compiler, so they need their own rule: CA2007 is off in any folder whose name ends in `Tests`, following the kit's test project names (`*.Tests`, `IntegrationTests`, `FunctionalTests`).
- **Reversibility:** Easy: two settings in the root `.editorconfig`.
- **Risk:** Low. A test project in a folder not named `*Tests` would still get CA2007 warnings, which is noise, not a hidden bug.

### Option 2: Keep CA2007 everywhere

- **Trade-offs:** No exception. Every `await` in app and test code needs `ConfigureAwait`, which Microsoft says is the wrong advice for app code and does nothing in ASP.NET Core.
- **Reversibility:** Easy.
- **Risk:** Low, but the noise trains people and agents to add calls by rote.

### Option 3: Turn CA2007 off everywhere

- **Trade-offs:** Least noise. Libraries lose a check that matters for them.
- **Reversibility:** Easy.
- **Risk:** Medium: a library used from a UI app could deadlock or lose performance.

## Recommendation

Option 1: it follows Microsoft's guidance exactly, keeping the rule where it protects and dropping it where it's noise.

## Decision

Accepted as recommended (owner, 2026-11-04). CA1303 stays on.

## Consequences

- The root `.editorconfig` sets `dotnet_code_quality.CA2007.output_kind = DynamicallyLinkedLibrary`, and `dotnet_diagnostic.CA2007.severity = none` for `*Tests` folders at any depth.
- `tools/tests/BuildConfig.Tests.ps1` proves it: a library with a plain `await` fails the build on CA2007; an app and test projects (top-level and under `tests/`) build clean.
- Step 6 re-measures `latest-all` on the sample solution, test projects included, and may raise more opt-outs, each with its own ADR.

## Pillars affected

Reliability: libraries keep the check that prevents context deadlocks. Operational Excellence: less rote noise in app and test code.

## Sources

- owner, 2026-11-04
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/quality-rules/ca2007, retrieved 2026-11-04
