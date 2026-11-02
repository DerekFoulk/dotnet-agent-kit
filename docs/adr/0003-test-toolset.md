# ADR-0003: Test toolset: name-brand tools while they are free

- **Status:** Accepted
- **Date:** 2026-11-01

## Context

The owner prefers the industry-standard tool while it is free for the project's use, and a move to the best free alternative if a project ever needs a paid license. He named xUnit, Moq, FluentAssertions, Bogus, bUnit, Playwright and FluentValidation. The agent-written skills had substituted NSubstitute and NetArchTest. All current projects are personal or volunteer work, with no payment involved.

## Options

### Option 1: The owner's name-brand set, with a swap plan for commercial work

- **Trade-offs:** The tools he knows and named. FluentAssertions 8 is free only for non-commercial use, so commercial repos need a swap.
- **Reversibility:** Easy for FluentAssertions: AwesomeAssertions keeps the same API and namespace. Moq is BSD-licensed and never needs a swap.
- **Risk:** Low, given the license check for commercial repos (ADR-0004).

### Option 2: Only permissively licensed tools everywhere (NSubstitute, AwesomeAssertions)

- **Trade-offs:** No license condition anywhere; but it overrides the owner's stated preference.
- **Reversibility:** Easy.
- **Risk:** Low technically; it contradicts the owner layer (ADR-0002).

## Recommendation

Option 1: it follows the owner's stated preference, and ADR-0004 covers the license risk.

## Decision

Decided by the owner: name-brand tools while free (owner, 2026-11-01).

## Consequences

- Core test set: xUnit v3, Moq (a current 4.20.x), FluentAssertions 8, Bogus, bUnit, Playwright, FluentValidation, Testcontainers, ArchUnitNET, FsCheck, Stryker, WireMock.Net.
- Added: WebApplicationFactory (`Microsoft.AspNetCore.Mvc.Testing`), Aspire testing (`Aspire.Hosting.Testing`), `FakeTimeProvider` and `FakeLogger`, Respawn, Deque axe for Playwright (`Deque.AxeCore.Playwright`), BenchmarkDotNet.
- Code coverage: `Microsoft.Testing.Extensions.CodeCoverage`, Microsoft's free collector for Microsoft Testing Platform.

## Pillars affected

Reliability: one consistent test toolset across repos. Cost Optimization: free tools, with a planned exit if that changes.

## Sources

- owner, 2026-11-01
- https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-code-coverage, retrieved 2026-11-01
- https://learn.microsoft.com/dotnet/core/extensions/timeprovider-testing, retrieved 2026-11-01
