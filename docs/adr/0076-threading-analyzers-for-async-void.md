# ADR-0076: Microsoft's threading analyzers check async void; the Async suffix stays advisory

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

The .NET best-practices pass (decision 6) and the C# guidance pass (decision S-D2), both read on 2026-11-15, found three async recommendations from Microsoft's pages that nothing in the build checks:

- **The Async suffix** on a method that returns an awaitable. The TAP page and the C# async page both say it. The C# page adds that names the code doesn't call itself, such as event handlers and web controller methods, needn't have it.
- **`async void` only for event handlers.** The C# async page says an exception thrown in one can't be caught outside the method, and the async return types page says that's likely to make the app fail.
- **No async lambda where a void-returning delegate is expected.** Such a lambda is an `async void` method nobody sees, as the vs-threading VSTHRD101 page explains.

No compiler warning and no CA rule checks any of them. The owner accepted both passes' decisions on 2026-11-16 ("Yes, accept them"), merged:

- **The suffix** from an IDE1006 naming rule, "subject to its fixture showing `Main`, middleware `Invoke` and Razor handlers don't trip it; if any does, keep it advisory" (decision 6).
- **`async void` and async lambdas** from `Microsoft.VisualStudio.Threading.Analyzers`, with VSTHRD100 and VSTHRD101 on and its other rules off.

The package is Microsoft's, from the vs-threading repo (https://github.com/microsoft/vs-threading), under the MIT license. It's a build-time analyzer with no runtime code.

**What the fixtures and the reviews of this ADR's PR found:**

- **The suffix rule tripped.** It fired on middleware whose async method is named `Invoke`, a name the middleware page documents.
  - It also fired on an async MVC controller action. MVC trims the suffix from action names, so a renamed `GetAsync` breaks `CreatedAtAction(nameof(GetAsync), ...)`: no route matches (MvcOptions.SuppressAsyncSuffixInActionNames, true by default).
  - It also fired on an `async void` event handler, where Microsoft's pages say not to add the suffix to a method that returns nothing awaitable.
  - It didn't fire on an async `Main` or a Razor Pages `OnGetAsync`.
  - VSTHRD200, the package's own suffix rule, keys on the return type but tripped middleware `Invoke` too, and test methods.
- **The threading analyzers are stricter than the C# page.** VSTHRD100 flags an `async void` event handler, and VSTHRD101 an async lambda subscribed to an event. Their pages suggest Visual Studio's JoinableTaskFactory instead, which an app doesn't have.
- **Two of the package's rules catch what nothing else does:**
  - VSTHRD110: a Task dropped in a method that isn't async. CS4014 looks only inside async methods, and CA2012 only at ValueTask.
  - VSTHRD107: a Task in a `using` statement, disposed instead of awaited.
- **The rest overlap or don't apply.**
  - Most concern JoinableTaskFactory.
  - Some repeat a rule the kit has from one source (CRF-003):
    - VSTHRD002: BannedSymbols.txt (STY-011)
    - VSTHRD103: CA1849
    - VSTHRD105: CA2008
    - VSTHRD111: CA2007
    - VSTHRD200: the suffix

## Options

### Option 1: The threading analyzers for VSTHRD100 and VSTHRD101 only; the suffix advisory

A `GlobalPackageReference` to `Microsoft.VisualStudio.Threading.Analyzers` in `Directory.Packages.props`. `.editorconfig` sets every other VSTHRD rule to `none` by ID, and code review checks the suffix (STY-007).

- **Trade-offs:** `async void` and async lambdas are gated with Microsoft's own tooling, each rule from one source; the suffix follows the owner's condition for when its fixture trips. One more build-time dependency, which Dependabot keeps current and apps get with the kit's other global analyzers. VSTHRD107 and VSTHRD110 stay off with the rest, a gap (GAP-045).
- **Reversibility:** Easy: one package line and the `.editorconfig` block.
- **Risk:** Low. A VSTHRD rule a later version adds is on at its default severity until `.editorconfig` lists it.

### Option 2: The suffix as a gate too, with each framework name suppressed

The IDE1006 rule, and a suppression with its reason at every middleware `Invoke`, controller action and async event handler.

- **Trade-offs:** The suffix gets a gate, but against the owner's stated condition. The suppressions would sit in exactly the places Microsoft's pages exempt, so most of them say only that the page exempts it.
- **Reversibility:** Easy.
- **Risk:** Medium: an app renames a controller action to satisfy the rule and breaks link generation at run time.

### Option 3: Extend the kit's CodeShape tool to flag `async void` instead of taking the package

- **Trade-offs:** No new dependency, but the kit would write and maintain an analyzer Microsoft already ships, including the hard part, async lambdas bound to void delegates, where the compiler picks the delegate type. It would report in CI's code shape step, not in the build or the editor.
- **Reversibility:** Easy.
- **Risk:** Medium: a hand-written check misses cases the shipped one handles.

## Recommendation

Option 1: it gates `async void` with Microsoft's own tooling and keeps the suffix advisory, as the owner's decision says to when its fixture trips.

## Decision

Accepted as recommended (owner, 2026-11-16, "Yes, accept them": best-practices decision 6 merged with C# decision S-D2). The suffix is advisory under decision 6's own condition, since its fixture tripped middleware `Invoke`.

## Consequences

- **Rule homes.**
  - STY-011 names `async void` and async lambdas, and the event-handler exception.
  - STY-007's advisory part names the suffix and where it doesn't apply.
  - `Directory.Packages.props` adds the package as a global reference, which every project and every new app gets: `New-KitApp` copies global references outside the sample's group.
- **Tests.** `tools/tests/BuildConfig.Tests.ps1` has:
  - a failing fixture for VSTHRD100 and VSTHRD101;
  - a clean fixture with an async `Main`, middleware named `InvokeAsync` and `Invoke`, a Razor Pages `OnGetAsync` and an unsuffixed test method: VSTHRD200 would flag the async `Invoke` and the test method if it were on;
  - the fixture that builds with `GetAwaiter().GetResult()`, which shows VSTHRD002 is off.
- **Event handlers.** Where a handler must be async, such as MAUI code-behind, it suppresses the rule where it lives with the reason: VSTHRD100 on a method, VSTHRD101 on a lambda with `#pragma warning disable`, since a SuppressMessage attribute on a lambda compiles but doesn't suppress it. A MAUI app keeps its logic in view models (ARC-010), whose async commands return a `Task`, so most apps rarely need it.
- **The gap.** VSTHRD107 and VSTHRD110 are off by the owner's choice of 100 and 101 only. GAP-045 records them, for the owner to turn on.
- **Lock files.** Every project's `packages.lock.json` lists the new package.
- **Existing apps.** An app that syncs this kit release gets the package and the `.editorconfig` block, so an `async void` method or lambda in it fails its next build until it's changed or suppressed with its reason.
- **New VSTHRD rules.** A Dependabot update that adds a VSTHRD rule adds analyzer behavior, which makes it the owner's to merge (ADR-0041). Its review sets the new rule to `none` or argues for it.
- **The naming overlap.** Microsoft's naming rules page documents an overlap between the kit's naming rules: `const` implies `static`, so the `s_` rule for static fields can claim a private constant. It showed only while the suffix rule was in the file, so nothing here changes it. The page's fix, an intersection rule for non-public constants, is the answer if a later naming rule brings the overlap back.

## Pillars affected

Reliability: an `async void` method or lambda, whose exception the caller can't catch, fails the build. Operational Excellence: each rule has one source, and the suffix's exceptions are written down for code review.

## Sources

- owner, 2026-11-16
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios, retrieved 2026-11-16
- https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-return-types, retrieved 2026-11-16
- https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap, retrieved 2026-11-15
- https://learn.microsoft.com/aspnet/core/fundamentals/middleware/write, retrieved 2026-11-16
- https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.mvc.mvcoptions.suppressasyncsuffixinactionnames, retrieved 2026-11-16
- https://learn.microsoft.com/dotnet/fundamentals/code-analysis/style-rules/naming-rules#rule-order, retrieved 2026-11-16
- https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD100.md, retrieved 2026-11-16
- https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD101.md, retrieved 2026-11-16
- https://github.com/microsoft/vs-threading/blob/main/docfx/analyzers/VSTHRD110.md, retrieved 2026-11-16
