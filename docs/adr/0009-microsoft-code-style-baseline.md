# ADR-0009: Microsoft code-style baseline, enforced on build

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner adheres to the guidance on Microsoft Learn (owner, 2026-10-27). In one project, `.editorconfig` allowed `var`, and option severities were silently ignored by `dotnet build`. About 185 violations were found late. Style rules (IDExxxx) don't run on command-line builds unless `EnforceCodeStyleInBuild` is true.

## Options

### Option 1: Microsoft's own `.editorconfig`, every adopted rule at warning, enforced on build

- **Trade-offs:** The dotnet/runtime baseline plus dotnet/docs additions; `EnforceCodeStyleInBuild` and warnings as errors make every rule fail the build; `AnalysisLevel latest-all` turns every analyzer rule on. Noisier at first; some rules may need documented opt-outs.
- **Reversibility:** Easy. Severities are configuration.
- **Risk:** Low. Exceptions are possible, each by ADR.

### Option 2: Defaults only, style as suggestions in the IDE

- **Trade-offs:** No noise; violations accumulate unseen, which is what happened before.
- **Reversibility:** Easy.
- **Risk:** High. Repeats the late discovery of ~185 violations.

## Recommendation

Option 1: the build is the only place every tool and agent can't skip.

## Decision

Accepted as recommended (owner, 2026-11-01).

## Consequences

- Root `.editorconfig` holds the Microsoft baseline with sources pinned by commit; `var` is never used.
- `Directory.Build.props` sets `EnforceCodeStyleInBuild`, `AnalysisLevel latest-all` and `TreatWarningsAsErrors`.
- `tools/tests/BuildConfig.Tests.ps1` proves that violations fail the build.
- The step-5 spike measures `latest-all` noise; each opt-out needs an ADR.
- **Spike result (2026-11-04):** workable. 31 warnings in about 200 lines of ordinary code, nearly all pointing to real fixes; CA2007 is limited to libraries by ADR-0029, and CA1303 stays on (owner). Step 6 re-measures on the sample solution. Details: `spikes/latest-all/README.md`.
- **Update (2026-11-10, ADR-0043):** `latest-all` leaves some rules off: the code metric rules and legacy rules Microsoft lists, and CA1516, which the SDK's all-mode file sets to none. A root `.globalconfig` turns them on, all but the one GAP-021 holds back, and lists them.
- **Update (2026-11-11, ADR-0049):** CA1014 is on too, so `.globalconfig` turns on every rule `latest-all` leaves off. `Directory.Build.props` declares every assembly not CLS-compliant, as Microsoft's CA1014 page advises for an assembly that isn't meant to be.
- A repo's `.editorconfig` overrides settings shipped in a package, so the sync step owns it and CI flags local changes.
- **Update (2026-11-13, rules audit):** "`var` is never used" was stricter than Microsoft's own repos. STY-002 now follows dotnet/runtime: `var` is allowed where the type is named on the right side (`csharp_style_var_when_type_is_apparent = false:none`), and the type is written everywhere else, at warning (owner, 2026-11-12).

## Pillars affected

Operational Excellence: consistent code that agents and people read the same way. Reliability: analyzer rules catch real defects.

## Sources

- owner, 2026-10-27
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview, retrieved 2026-11-01
- https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props, retrieved 2026-11-01
- https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig, retrieved 2026-11-01
