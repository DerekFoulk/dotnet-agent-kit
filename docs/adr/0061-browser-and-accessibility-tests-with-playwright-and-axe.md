# ADR-0061: Browser and accessibility tests with Playwright and axe

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

UI-001 (ADR-0046) requires WCAG 2.2 level AA of every UI an app ships, but no tool checked it: the scorecard's GAP-004 said browser and accessibility tests weren't set up for apps with a web UI. TST-003 already names an `E2E.Tests` project for each app, and ADR-0003 already names the tools: Playwright for .NET, Deque's axe for Playwright (`Deque.AxeCore.Playwright`) and bUnit.

What had to be settled:
- **How the browser tests reach the app:** where it runs and on which port.
- **How CI gets the browser:** the shared `dotnet-ci.reusable.yml` runs every test in its "Test with coverage" step, in the required job. Playwright's browsers aren't on the runner, and the step must do nothing for an app without browser tests.
- **What the download is pinned to:** every tool the shared CI downloads must be visible to Dependabot (ADR-0060). ADR-0060 also checks the PMD zip against a SHA-256 committed in the repo.
- **What axe can check, and what stays with a person.**
- **How the kit proves it:** the kit's sample is a deliberately dull API with no UI.

Checked for this decision:
- **Microsoft's "Test Razor components" page:** unit-test a component with bUnit; use E2E tests, with Playwright for .NET, where a real browser matters. Accessibility needs the rendered page, so it's an E2E concern.
- **Hosting:** `WebApplicationFactory.UseKestrel(int port)` (.NET 10) hosts the app on a real server; port 0 lets the system pick one.
- **Installing the browser:** Playwright's CI guide installs browsers with the `playwright.ps1` the build puts beside the test assembly: `pwsh bin/<config>/<tfm>/playwright.ps1 install --with-deps`.
- **axe's tags:** WCAG 2.2 level A and AA is the tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` and `wcag22aa`. axe has no `wcag22a` tag.
- **A spike on this machine:** under the factory on Kestrel, static assets and `blazor.web.js` are served. After a link click, FocusOnNavigate leaves focus on the new page's `h1`. The tag set flags `target-size` on two 10-pixel buttons. Without `UseAntiforgery` the page answers 500, yet axe finds nothing wrong, so a test must check the page loaded.

## Options

**Hosting, for every option below.** The browser reaches the app through `WebApplicationFactory` on Kestrel, or through Aspire testing.
- **WebApplicationFactory:** needs no AppHost, runs in the test process (so the coverage gate counts the web project), and uses the same factory pattern as the sample's functional tests.
- **Aspire testing:** suits an app that has an Aspire AppHost, where it starts the whole distributed app.

The intake now offers WebApplicationFactory by default, and Aspire testing for an app with an AppHost.
### Option 1: Playwright's own Chromium, installed by the build's `playwright.ps1`

The app is hosted in the test process by `WebApplicationFactory` on Kestrel (port 0). A kit script, `tools/Install-PlaywrightBrowser.ps1`, finds every project whose restore graph holds Microsoft.Playwright. For each, it runs that project's `playwright.ps1 install --with-deps chromium`, once per Playwright version, as a CI step just before the tests.
- **Trade-offs:** the same browser everywhere, but an unverified download.
  - The browser build is the one the Microsoft.Playwright version pins. Locally and in CI the tests run the same Chromium, and Dependabot moves it with the package, so there's no new pin to keep.
  - It's the route Playwright documents.
  - Playwright's installer checks no hash. The zip comes over HTTPS from Playwright's CDN, unverified, which is weaker than ADR-0060's PMD check.
  - `--with-deps` installs the browser's system libraries from the runner's Ubuntu archive. Those are the runner's OS packages, not a tool the kit pins.
  - Dependabot's alerts don't cover Chromium, or the Node.js runtime the package bundles into every build output.
- **Reversibility:** easy. One script and one step per workflow.
- **Risk:** low.
  - A download replaced on Playwright's CDN would run in CI (GAP-033).
  - An outage there fails the required job of an app with browser tests. No retry is added (CRF-001).

### Option 2: The Chrome the runner already has (`Channel = "chrome"`)

- **Trade-offs:** no download, but a browser nothing in the repo pins.
  - Nothing is downloaded, so there's nothing to verify.
  - The version floats with GitHub's runner image, not with anything in the repo. Dependabot can't see it.
  - Locally the tests run whatever Chrome or Edge the machine has, so a result can differ between a laptop and CI.
- **Reversibility:** easy.
- **Risk:** medium. A runner image update can change results with no change in the repo.

### Option 3: Microsoft's Playwright .NET container image, pinned by tag and digest

The digest goes in a `.config/` Dockerfile that Dependabot's docker updater moves, as ADR-0060 does for gitleaks.
- **Trade-offs:** a verified browser, at the cost of the required job's shape.
  - The browser is verified by digest and seen by Dependabot, so it's stronger than Option 1.
  - The image carries its own .NET SDK, not the one `global.json` pins.
  - The tests (or the whole job) would have to run inside it, which splits the required job.
  - It needs a check that the image's Playwright version matches the package's.
- **Reversibility:** moderate.
- **Risk:** medium. The SDK mismatch, and a bigger change to the required job.

### Option 4: Hash the Chromium zip ourselves

Download the zip the package names and check it against a SHA-256 committed in the repo.
- **Trade-offs:** a hash, but one taken on trust.
  - Playwright publishes no hashes, so the first hash would be taken from the same CDN: trust on first use.
  - The kit would rebuild Playwright's installer, against CRF-010.
- **Reversibility:** easy.
- **Risk:** medium. It relies on Playwright's undocumented download layout.

## Recommendation

Option 1, hosted by WebApplicationFactory on Kestrel. It's the documented route, and it runs the same browser everywhere, moved by Dependabot through a package the repo already pins. The missing hash check is named as GAP-033, with Option 3 as the better design that waits: it changes how the required job runs, and its SDK mismatch needs solving first.

## Decision

Option 1 with WebApplicationFactory on Kestrel, decided in auto mode (ADR-0035) on 2026-11-12, closing GAP-004.

## Consequences

**Packages.** Both are named by ADR-0003. Both sit in the Tests group of `Directory.Packages.props`, so every app gets them:
- **Microsoft.Playwright 1.64.1** (MIT). It pins Chromium build 1248 and bundles Node.js.
- **Deque.AxeCore.Playwright 4.14.0** (MIT). Its engine, Deque.AxeCore.Commons 4.14.0, is MPL-2.0.
- **Transitive packages:** Newtonsoft.Json 13.0.1, System.IO.Abstractions 17.0.24, and Playwright's own (System.Text.Json and others).

**CI.**
- `dotnet-ci.reusable.yml` gains a "Playwright browser" step between the build and the tests. `mutation.reusable.yml` gains a Release build and the same step before Stryker, since Stryker runs every test project.
- `tools/Install-PlaywrightBrowser.ps1` reads the solution's C#, F# and Visual Basic projects. It skips the UI projects that `Get-UiProject.ps1` names, which don't evaluate on Linux.
- It fails when a project isn't restored, when a Playwright project isn't built, or when the install fails.
- An app without browser tests pays only the MSBuild evaluations, a few seconds.
- It isn't exported to an app's `.kit/tools`, because the app's CI reaches it through `kit-tools`.

**Rules.**
- **UI-002** (proposed, `docs/standards/ui.md`): every page of a web UI gets a test that opens it, checks it loaded, and runs axe's WCAG 2.2 A and AA rules. Keyboard and focus paths get their own tests.
- **UI-001's enforcement** and `ui.md`'s "How it's checked" say what axe checks and what stays with a person.
- **TST-003's enforcement** names the E2E tests.
- **testing.md** gains "Browser and accessibility tests", and **craft.md** says code in `.razor` files escapes the code shape, duplicate code and mutation checks.

**Fixture.** The kit's solution gains a web UI fixture, `fixtures/WebUi`, so the required job proves the pattern on every pull request.
- **Kit.WebUiFixture:** static server rendering with enhanced navigation; two pages, a stylesheet, `blazor.web.js` and FocusOnNavigate.
- **Kit.WebUiFixture.E2E.Tests:** axe on every page; a check that axe really finds a level A and a 2.2 AA failure; focus after a link; the first Tab and its outline; the port; and the content root under Stryker.
- **No bUnit project:** the fixture has no component with logic of its own (ARC-009).
- **In the kit's own outputs:** the fixture ships in the kit's SBOM, as the sample does, and Stryker mutates its `Program.cs`.

**Intake** (`templates/app-intake.json`):
- UI tests run on every PR.
- WebApplicationFactory on Kestrel is a default, and Aspire testing is for an app with an AppHost.
- axe's license is MIT, with its MPL-2.0 engine noted.

**New gaps:**
- **GAP-032:** native UI tests for MAUI and desktop.
- **GAP-033:** the unverified browser download.
- **GAP-034:** interactive render modes.

**Follow-ups:**
- **For the owner (a guardrail):** `.claude/settings.json` has no ask rule for installing a browser locally (`playwright.ps1 install`, the kit script). Until he adds one, AGENTS.md and testing.md say it's the owner's step.
- **Solution reading:** the kit's scripts read a solution in two ways. Six read the `.slnx` XML, and Test-CodeShape uses `dotnet sln list`. The new script adds one more XML reader, and repeats Test-CodeShape's first-framework fallback. Putting both in one module is a follow-up (CRF-003).
- **Updates:** agents may merge Playwright's minor updates (ADR-0041), and each one moves the browser build. That's intended.

## Pillars affected

- **Reliability:** browser tests are hosted on a port the system picks, and each test gets a fresh browser context. There are no sleeps; Playwright waits by itself. Playwright's CDN is now a dependency of an app's required job.
- **Security:** no secrets, data or sign-in are involved. The browser download isn't hash-checked (GAP-033). Package versions are at least 7 days old (SUP-008), with lock files and NuGet audit.
- **Cost Optimization:** free packages, and free runners on a public repo. CI takes about a minute more, only where browser tests exist.
- **Operational Excellence:** an axe failure names each broken rule, its impact, help link and elements. The install script says what it installed, or why it can't.
- **Performance Efficiency:** Chromium only, installed once per Playwright version. Each test starts its own browser, about a second each.

## Sources

- https://learn.microsoft.com/aspnet/core/blazor/test?view=aspnetcore-10.0, retrieved 2026-11-12
- https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.mvc.testing.webapplicationfactory-1.usekestrel?view=aspnetcore-10.0, retrieved 2026-11-12
- https://learn.microsoft.com/aspnet/core/test/integration-tests?view=aspnetcore-10.0, retrieved 2026-11-12
- https://playwright.dev/dotnet/docs/ci, retrieved 2026-11-12
- https://github.com/dequelabs/axe-core/blob/develop/doc/API.md, retrieved 2026-11-12 (the WCAG tags; no wcag22a)
- https://github.com/dequelabs/axe-core-nuget/blob/develop/packages/playwright/README.md, retrieved 2026-11-12 (RunAxe, RunOnly, the MIT and MPL licenses)
- https://www.nuget.org/packages/Microsoft.Playwright/1.64.1, https://www.nuget.org/packages/Deque.AxeCore.Playwright/4.14.0, retrieved 2026-11-12
- ADR-0003, ADR-0035, ADR-0039, ADR-0041, ADR-0046, ADR-0059, ADR-0060
