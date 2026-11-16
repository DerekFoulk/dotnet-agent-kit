# ADR-0076: Microsoft's threading analyzers check async void, and IDE1006 the Async suffix

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

The .NET best-practices pass (decision 6) and the C# guidance pass (decision S-D2), both read on 2026-11-15, found three async rules from Microsoft's pages that nothing in the build checks:
- **The Async suffix.** An async method's name ends in Async (the TAP page; the C# async page). The C# page also says names the code doesn't call itself, such as event handlers and web controller methods, needn't have it.
- **`async void`** only for event handlers. An exception thrown in one can't be caught, and it crashes the process (the C# async page).
- **No async lambda where a void delegate is expected**, which makes an `async void` method nobody sees (the C# async page's caution on async lambdas).

No compiler warning and no CA rule checks any of them. The owner accepted both passes' decisions on 2026-11-16 ("Yes, accept them"), merging the two:
- the suffix comes from IDE1006, a naming rule in `.editorconfig`;
- `async void` and async lambdas come from `Microsoft.VisualStudio.Threading.Analyzers`, with only VSTHRD100 and VSTHRD101 on.

The package is Microsoft's, from the vs-threading repo (https://github.com/microsoft/vs-threading), under the MIT license. It's a build-time analyzer with no runtime code. Its other rules mostly concern Visual Studio's JoinableTaskFactory, which an app doesn't use. The rest repeat rules the kit already has:
- VSTHRD002 (synchronous waits): BannedSymbols.txt's bans (STY-011)
- VSTHRD103 (blocking calls): CA1849
- VSTHRD105 (TaskScheduler.Current): CA2008
- VSTHRD110 (unobserved results): CS4014 and CA2012
- VSTHRD111 (ConfigureAwait): CA2007
- VSTHRD200 (the Async suffix): IDE1006

CRF-003 asks for one source per rule.

Fixtures showed which names the suffix rule trips, as decision 6 asked:
- **Doesn't trip:** IDE1006 with `required_modifiers = async` leaves alone an async `Main`, a Razor Pages handler's `OnGetAsync`, and test projects, which `.editorconfig` exempts as it does for CA2007.
- **Trips:** middleware whose async method is named `Invoke`. ASP.NET Core documents both `Invoke` and `InvokeAsync`, so the rule asks for `InvokeAsync`, and no framework-fixed name is refused.
- **VSTHRD200 trips test methods,** which TST-010 names for the behavior they check. That's one more reason to leave it off and use IDE1006.

## Options

### Option 1: The threading analyzers for VSTHRD100 and VSTHRD101 only, and IDE1006 for the suffix

A `GlobalPackageReference` to `Microsoft.VisualStudio.Threading.Analyzers` in `Directory.Packages.props`. `.editorconfig` sets every other VSTHRD rule to `none` by ID, and adds an IDE1006 naming rule for `async` methods and local functions, off in test projects.

- **Trade-offs:** Each of the three page rules gets a gate, and each rule stays with one source. It's one more build-time dependency, which Dependabot keeps current and apps get with the kit's other global analyzers. A VSTHRD rule that a later version adds is on at its default severity until `.editorconfig` lists it; the fixtures catch it only if it fires on one.
- **Reversibility:** Easy: one package line and the `.editorconfig` block.
- **Risk:** Low. The package is Microsoft's and widely used. A version that renames or splits a rule would show in the fixtures.

### Option 2: Extend the kit's CodeShape tool to flag `async void` outside event handlers

- **Trade-offs:** No new dependency, but the kit would write and maintain an analyzer Microsoft already ships, including the hard part, async lambdas bound to void delegates, where the compiler picks the delegate type. It would report in CI's code shape step, not in the build or the editor.
- **Reversibility:** Easy.
- **Risk:** Medium: a hand-written check misses cases the shipped one handles.

### Option 3: Leave `async void` and async lambdas to code review

- **Trade-offs:** No cost now, and the defect that crashes a process stays unchecked.
- **Reversibility:** Easy.
- **Risk:** High for reliability.

## Recommendation

Option 1: it gates all three rules with Microsoft's own tooling, and turning the overlapping rules off keeps one source per rule (CRF-003).

## Decision

Accepted as recommended (owner, 2026-11-16, "Yes, accept them": best-practices decision 6 merged with C# decision S-D2).

## Consequences

- **Rule homes:**
  - STY-007 names the Async suffix.
  - STY-011 names `async void` and async lambdas.
  - `Directory.Packages.props` adds the package as a global reference, which every project and every new app gets (`New-KitApp` copies global references outside the sample's group).
- **Tests:** `tools/tests/BuildConfig.Tests.ps1` has:
  - a failing fixture for IDE1006 (an async method without the suffix), VSTHRD100 and VSTHRD101;
  - a clean fixture with an async `Main`, middleware's `InvokeAsync`, a Razor Pages `OnGetAsync`, and a test method without the suffix.
  - VSTHRD002 being off shows in the fixture that builds with `GetAwaiter().GetResult()`, which STY-011 allows and VSTHRD002 would flag.
- **Lock files:** every project's `packages.lock.json` lists the new package.
- **Event handlers are stricter than the page.**
  - **What fires:** VSTHRD100 flags an `async void` event handler too, and VSTHRD101 flags an async lambda subscribed to an event. A probe on 18.12.1 showed both, and VSTHRD100's page suggests JoinableTaskFactory instead, which an app doesn't have.
  - **The C# page allows it:** `async void` is fine for an event handler.
  - **What an app does:** where a handler must be async, such as MAUI code-behind, it suppresses VSTHRD100 at that method with the reason, "an event handler, which the C# async page allows to be async void", as CRF-001 asks of any safety net that stays.
  - **What usually avoids it:** a MAUI app keeps its logic in view models (ARC-010), and their async commands (such as `AsyncRelayCommand`) return a `Task`, so most apps never need the suppression.
- **New VSTHRD rules:** a Dependabot update that adds a VSTHRD rule is the owner's to merge when it adds analyzer behavior (ADR-0041's new-build-time-behavior condition). Its review sets the new rule to `none` or argues for it.

## Pillars affected

Reliability: an `async void` method or lambda, whose exception crashes the process, fails the build. Operational Excellence: async method names say what they are, and each rule has one source.

## Sources

- owner, 2026-11-16
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios, retrieved 2026-11-16
- https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap, retrieved 2026-11-15
- https://learn.microsoft.com/aspnet/core/fundamentals/middleware/write, retrieved 2026-11-16
- https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD100.md, retrieved 2026-11-16
- https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD101.md, retrieved 2026-11-16
