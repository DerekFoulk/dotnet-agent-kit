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
- **Hosting:** `WebApplicationFactory.UseKestrel(int port)` (.NET 10) hosts the app on a real server; port 0 lets the system pick one. (Replaced on 2026-11-14: it races the app's own start; see the update under Consequences.)
- **Installing the browser:** Playwright's CI guide installs browsers with the `playwright.ps1` the build puts beside the test assembly: `pwsh bin/<config>/<tfm>/playwright.ps1 install --with-deps`.
- **axe's tags:** WCAG 2.2 level A and AA is the tags `wcag2a`, `wcag2aa`, `wcag21a`, `wcag21aa` and `wcag22aa`. axe has no `wcag22a` tag.
- **A spike on this machine:** under the factory on Kestrel, static assets and `blazor.web.js` are served. After a link click, FocusOnNavigate leaves focus on the new page's `h1`. The tag set flags `target-size` on two 10-pixel buttons. Without `UseAntiforgery` the page answers 500, yet axe finds nothing wrong, so a test must check the page loaded.

## Options

**Hosting, for every option below.** The browser reaches the app through `WebApplicationFactory` on Kestrel, or through Aspire testing.
- **WebApplicationFactory:** needs no AppHost, runs in the test process (so the coverage gate counts the web project; on Windows, only from a clone in a short folder, as testing.md says), and uses the same factory pattern as the sample's functional tests.
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

**Update (2026-11-16):** Option 3 replaces Option 1 in CI, decided in auto mode, closing GAP-033. The SDK mismatch is solved by running the runner's own SDK inside the image. See "Update (2026-11-16): the pinned Playwright image" under Consequences.

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
- **Kit.WebUi:** static server rendering with enhanced navigation; two pages, a stylesheet, `blazor.web.js` and FocusOnNavigate.
- **Kit.WebUi.E2E.Tests:** axe on every page; a check that axe really finds a failure for each WCAG version and level it runs; focus after a link; the first Tab and its outline; the port; and the content root under Stryker.
- **One list of tags:** UI-002 names the WCAG tags, and `tools/tests/WebUiFixture.Tests.ps1` fails when the fixture's `Wcag.cs` runs any others.
- **No bUnit project:** the fixture has no component with logic of its own (ARC-009).
- **In the kit's own outputs:** the fixture ships in the kit's SBOM, as the sample does, and Stryker mutates its `Program.cs`.

**Update (2026-11-14): hosting.** The fixture no longer calls `UseKestrel(int port)`. It calls `UseKestrel()` and registers a startup filter, `LoopbackAddressFilter`, that sets the server's address to `http://127.0.0.1:0` with `PreferHostingUrls`.
- **Why:** in .NET 10, `UseKestrel(int port)` clears and re-adds the server's addresses after the app has built its host, while the app's own `Program` starts Kestrel on another thread. When Kestrel binds first, the addresses are read-only and `StartServer()` throws, as it did in CI run 43602912316 and in ASP.NET Core's own tests (dotnet/aspnetcore#67340).
- **Why a startup filter:** it runs on the app's thread while the app builds its pipeline, before Kestrel binds, so there's no race. `PreferHostingUrls` makes the address win over any endpoint the app configures itself. ASP.NET Core made the same change to `UseKestrel(port)` after .NET 10, with no 10.0 backport (dotnet/aspnetcore#70520, which replaced #67714's `Listen` call because `Listen` lost that precedence).
- **Tests:** `AppFactoryTests` holds the factory's thread back until Kestrel has bound, which failed every time before the change, and gives the app an endpoint of its own on port 5000, which was bound alongside the factory's with `Listen`.

**Intake** (`templates/app-intake.json`):
- UI tests run on every PR.
- WebApplicationFactory on Kestrel is a default, and Aspire testing is for an app with an AppHost.
- axe's license is MIT, with its MPL-2.0 engine noted.

**New gaps:**
- **GAP-032:** native UI tests for MAUI and desktop.
- **GAP-033:** the unverified browser download.
- **GAP-036:** interactive render modes.

**Follow-ups:**
- **For the owner (a guardrail):** installing a browser locally is the owner's step (AGENTS.md, testing.md). Since 2026-11-12, `.claude/settings.json` asks before it, in both modes, when a command runs `playwright.ps1 install` (by `pwsh`, `&`, `./`, `.\`, or any path through `bin`, bare or not), `npx … playwright … install`, or the kit's `Install-PlaywrightBrowser.ps1`. A command that only names them (git, grep, a commit message, Pester) doesn't ask, unless it quotes the full path through `bin` with `install` after it, or starts with `pwsh`, `./`, `.\` or `&` and quotes `playwright.ps1 install` later: then it asks too, because a missed install is worse than an extra prompt. Not caught, and left to "Always ask" and the reviewer (ADR-0026): an install run through a variable or a pipeline, a quoted path, a wrapper such as `bash -c`, and the kit script by an absolute path, without `./` or `.\` in some forms (such as `pwsh tools/…`, `tools\…` or `& tools/…`), by `pwsh` with `.\` or with flags other than `-File` and `-NoProfile`, or dot-sourced and then called. Whether Claude Code checks each command of a compound line on its own isn't verified. `tools/tests/AgentConfig.Tests.ps1` pins both sides.
- **Solution reading:** the kit's scripts read a solution in two ways. Six read the `.slnx` XML, and Test-CodeShape uses `dotnet sln list`. The new script adds one more XML reader, and repeats Test-CodeShape's first-framework fallback. Putting both in one module is a follow-up (CRF-003).
  - **Update (2026-11-12):** done. `tools/KitSolution.psm1` lists a `.slnx`'s projects for seven scripts (the count above was one too many) and the performance workflow's benchmarks step, and picks the first framework for the two scripts that need it.
- **Updates:** agents may merge Playwright's minor updates (ADR-0041), and each one moves the browser build. That's intended. (Changed on 2026-11-16: a Playwright update now moves the image too, so it's the owner's; see below.)

**Update (2026-11-16): the pinned Playwright image (GAP-033).** CI no longer downloads a browser. When a project uses Playwright, the tests run inside Microsoft's Playwright .NET image, pinned by tag and digest. Docker checks every layer against the digest, so the browser, and the system libraries `--with-deps` used to fetch from the runner's Ubuntu archive, are the ones the pin names.
- **The SDK mismatch:**
  - **The problem:** the image is built `FROM mcr.microsoft.com/dotnet/sdk:10.0-noble`, so its SDK is that image's 10.0.1xx band. `global.json` pins 10.0.403 with `latestPatch`, which only a 10.0.4xx SDK at patch 403 or later satisfies, so the image's own SDK can't run the kit's build.
  - **How Playwright handles it:** its Docker page installs another SDK into the image with Microsoft's `dotnet-install.sh`. `actions/setup-dotnet` already runs that script on the runner, for the SDK `global.json` names.
  - **The fix:** the container gets the runner's install, shared read-only at the same path (`DOTNET_ROOT`), and puts it first on `PATH`. There's still one SDK download per run, and the SDK that built the code runs the tests.
- **The pin:** `.config/playwright/Dockerfile`, in the repo that runs CI, as for the gitleaks image (ADR-0060). One `FROM mcr.microsoft.com/playwright/dotnet:v<version>-noble@sha256:<digest>` line. Dependabot's docker updater watches it with the same 7-day cooldown, in the kit and in the app template.
  - **Why it's the repo's own, not the kit's:** the image must hold the browsers of the repo's own Microsoft.Playwright version, since Playwright finds only its own version's browsers. An app owns that version, in its `Directory.Packages.props`.
  - **Apps:** `Export-KitApp` gives a new app the kit's pin as an app-owned file. An app made earlier gets it from the kit sync, as an app-owned file it lacks (`Add-KitAppOwnedFile`). Its `dependabot.yml` is its own, so it adds the docker entry itself.
- **How:** `tools/Invoke-WithPlaywrightImage.ps1` replaces `tools/Install-PlaywrightBrowser.ps1`. "Test with coverage" in `dotnet-ci.reusable.yml`, and the Stryker step in `mutation.reusable.yml`, run their command through it.
  - **Which projects:** like the old script, it reads each project's restore graph to find the ones that use Playwright.
  - **Without any:** the command runs on the runner, as before, so an app without browser tests pulls nothing.
  - **With some:** it fails, naming what to fix, when the projects use more than one Playwright version, when there's no pin, when the pin isn't one FROM line with a tag and a digest, or when the pin's version isn't the projects'.
  - **The container:** `docker run` with `--init` and `--ipc=host`, as Playwright's Docker page recommends: Chromium runs out of shared memory without the latter. It also gets the runner's network and its user and group, so what it writes stays the runner's. The home, working, temp and kit folders are shared at the same paths, so the build's absolute paths, the NuGet folder and the results folder mean the same inside. The runner's SDK goes first on the image's own `PATH`, inside the container (`sh -c`), so the kit keeps no copy of the image's `PATH`.
  - **Tests that start containers of their own:** an app with a database uses Testcontainers by default (DAT-002), and with a web UI too, its integration tests now run in the image. They reach the runner's Docker through its socket, shared with its group. Inside a container, Testcontainers looks for its containers' ports at a network gateway. On the runner's network they're on localhost, so the container gets `TESTCONTAINERS_HOST_OVERRIDE=localhost`, unless the repo sets its own.
- **Updates:** Dependabot moves Microsoft.Playwright (nuget) and the image (docker) in separate PRs, and CI fails each until both move. Bring the two into one PR: push the image's change to the package's PR branch, then close the image's PR. Image bumps are the owner's to merge, as gitleaks' are (`.github/dependabot.yml`), so a Microsoft.Playwright update is now the owner's too.
  - **The better design that waits:** Dependabot's multi-ecosystem groups would open one PR for both. GitHub's page doesn't say what happens to the NuGet entry's other packages, those outside the group's patterns, so adopting it could change every NuGet update. It waits for that to be checked (GAP-046).
- **Trade-offs:**
  - Pulling the image costs CI time, but only where browser tests exist: 22 seconds in PR 102's required job (run 43994753335), and 23 in its mutation run. The whole "Test with coverage" step took 53 seconds, all 339 tests included.
  - Chromium runs without its sandbox, as it did on the runner (Playwright's default). The tests load only the app's own pages, which Playwright's Docker page counts as the trusted case.
  - Locally nothing changes: the owner installs the browser with `playwright.ps1`, so local runs still use Playwright's unchecked download (the owner's step, "Always ask").
- **Left as it is:** `.claude/settings.json` still asks before `tools/Install-PlaywrightBrowser*`, which this change removes. Those rules can never fire now, and dropping them is a guardrail change, left for a PR of its own.
- **Not verified:** Testcontainers inside the image. No kit test starts a container of its own, so nothing proves it yet (GAP-047).
  - **Update (2026-11-16):** verified. The fixture's E2E project adds Testcontainers (named by ADR-0003) and `ContainerTests`, which starts Testcontainers' own `helloworld` image, pinned by tag and digest, and asks its `/uuid` endpoint for a GUID on the mapped port. CI runs it inside the image, so it proves the Docker socket, Testcontainers' resource reaper (Ryuk) and `TESTCONTAINERS_HOST_OVERRIDE=localhost` there. The image is pinned in the test, where Dependabot doesn't see it: it's a fixed sample server, so a newer one adds nothing. Run locally, the fixture's tests now need Docker running, as an app's database tests do (DAT-005).
- **Apps made earlier:** an app whose Microsoft.Playwright version differs from the kit's gets a red "Test with coverage" on the kit update's PR until its pin matches its own version, with CI's message saying so. Its `dependabot.yml` gains no docker entry, so the pin moves only when someone moves it.

**Update (2026-11-16): interactive render modes (GAP-036).** The fixture gains `/interactive`, an Interactive Server page whose "Add one" button counts clicks. The server prerenders it, so the button shows before Blazor's circuit is up, and a click then would be lost.
- **The page:** it renders the button `disabled` until `RendererInfo.IsInteractive`, the pattern Microsoft's render modes page shows.
- **The test:** it asserts the button is enabled (`Expect(button).ToBeEnabledAsync()`) before it clicks, which is the actionability wait Playwright makes before a click anyway, and then checks the count, which a `role="status"` paragraph announces.
- **Pinned behavior:** a second test checks that the prerendered HTML sends the button disabled, and axe checks the page as it does every page.
- **Probed:** with the attribute removed, both tests fail. The click is lost, and the prerendered button isn't disabled.
- **WebAssembly and Auto:** they need a `.Client` project, which the fixture doesn't have. The same pattern applies to them, since `RendererInfo.IsInteractive` reports interactivity in every render mode.

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
- https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/endpoints?view=aspnetcore-10.0, retrieved 2026-11-14 (port 0 binds dynamically; the bound address is in IServerAddressesFeature)
- https://learn.microsoft.com/dotnet/api/microsoft.aspnetcore.hosting.server.features.iserveraddressesfeature.preferhostingurls?view=aspnetcore-10.0, retrieved 2026-11-14 (prefer the host's URLs over the server's own endpoints)
- https://github.com/dotnet/aspnetcore/issues/67340, https://github.com/dotnet/aspnetcore/pull/67714 and https://github.com/dotnet/aspnetcore/pull/70520, retrieved 2026-11-14 (the UseKestrel(port) race, and its fix after .NET 10)
- https://github.com/dotnet/aspnetcore/blob/v10.0.0/src/Mvc/Mvc.Testing/src/WebApplicationFactory.cs and https://github.com/dotnet/runtime/blob/v10.0.0/src/libraries/Microsoft.Extensions.HostFactoryResolver/src/HostFactoryResolver.cs, retrieved 2026-11-14 (TryConfigureServerPort; the entry point running on its own thread)
- https://playwright.dev/dotnet/docs/ci, retrieved 2026-11-12
- https://playwright.dev/dotnet/docs/docker, retrieved 2026-11-16 (the image's tags, --init and --ipc=host, the image's version must match the package's, installing another SDK with dotnet-install.sh, root and the sandbox)
- https://github.com/microsoft/playwright-dotnet/blob/main/utils/docker/Dockerfile.noble, retrieved 2026-11-16 (the image is built FROM mcr.microsoft.com/dotnet/sdk:10.0-noble; browsers in /ms-playwright)
- https://docs.github.com/en/code-security/dependabot/working-with-dependabot/configuring-multi-ecosystem-updates, retrieved 2026-11-16 (multi-ecosystem groups; patterns required on each entry)
- https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0, retrieved 2026-11-16 (prerendering; RendererInfo.IsInteractive; disabling a button until the component is interactive)
- https://github.com/dequelabs/axe-core/blob/develop/doc/API.md, retrieved 2026-11-12 (the WCAG tags; no wcag22a)
- https://github.com/dequelabs/axe-core-nuget/blob/develop/packages/playwright/README.md, retrieved 2026-11-12 (RunAxe, RunOnly, the MIT and MPL licenses)
- https://www.nuget.org/packages/Microsoft.Playwright/1.64.1, https://www.nuget.org/packages/Deque.AxeCore.Playwright/4.14.0, retrieved 2026-11-12
- ADR-0003, ADR-0035, ADR-0039, ADR-0041, ADR-0046, ADR-0059, ADR-0060
