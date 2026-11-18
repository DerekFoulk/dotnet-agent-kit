# Changelog

## 0.1.0 (2026-11-18)

## What's Changed
* feat: repo skeleton, build config and Initialize-DevMachine (step 1) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/1
* feat: standards, ADRs and their checks (step 2) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/2
* fix: land the PR 2 review fixes on main by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/3
* feat: agent layer: instructions, generated rules, skills, reviewer and permissions (step 3) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/4
* ci: CI gates, kit checks, secret scan and Dependabot (step 4) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/5
* feat: agents answer PR reviews with the address-review skill (ADR-0028) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/6
* feat: release-please releases, CA2007 for libraries, and the step 5 spikes by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/9
* feat: the bookmarks sample solution, coverage gate and stricter CI build (step 6, PR A) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/11
* ci: refresh NuGet lock files on Dependabot PRs (step 6, PR B) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/12
* feat: shared CI that private app repos call, with the kit kept private (step 6, PR D1) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/13
* docs: make the kit repo public with no license (ADR-0031) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/14
* docs: answer the re-review of the public-kit notices and pin checks by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/15
* feat: export the kit's files into a new app repo from one kit commit (D2a) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/16
* feat: create app repos on GitHub with the kit's settings and ruleset (D2b) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/17
* feat: add the quality scorecard and its check by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/18
* feat: add auto and review working modes, with auto as the default by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/19
* feat: add CodeQL code scanning for the kit and public apps (GAP-005) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/20
* feat: add service defaults: health checks, OpenTelemetry and HTTP resilience (GAP-007, GAP-009) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/21
* feat: choose the API style and give HTTP APIs Microsoft's built-in conventions (GAP-010, GAP-011) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/22
* fix: give every test repo one git setup, with background maintenance off by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/24
* feat: run mutation testing nightly with Stryker.NET (GAP-003) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/23
* fix!: require PowerShell 7.6, the current LTS, in the toolchain check and every kit script by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/27
* chore: Bump xunit.v3 from 4.0.2 to 4.0.3 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/26
* chore(deps): bump actions/setup-dotnet from 6.0.0 to 6.1.0 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/25
* test: run the commit-msg hook's checks in a repo of their own by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/28
* docs: propose DOD-006, the evidence comment for a PR a bot describes by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/29
* test: judge a file's ignore rule by the root .gitignore alone by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/30
* docs: accept 16 proposed rules the owner ratified by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/31
* feat: leave kit-only permission rules out of an app's settings by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/32
* feat!: accept DOD-006 and let auto mode merge Dependabot's patch and minor updates by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/33
* feat: ask the owner every pull request question in the chat (COM-007) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/34
* feat: give new apps the kit's three merge protections by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/35
* feat: enforce the craft standard (CRF-001 to CRF-010) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/36
* feat: sync each kit release into an app on Dependabot's kit-pin PR (D3) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/41
* feat: add a curated, pinned copy of Microsoft's dotnet/skills by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/38
* feat: catch rule drift in CI, and a script to break code on purpose by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/39
* feat: require WCAG 2.2 AA for every UI an app ships (UI-001) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/42
* feat: authorization by default, OIDC sign-in, per-user data and bounded input (GAP-006) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/43
* feat: ban Type.TypeInitializer, and make the build-config tests strict about git errors and .globalconfig by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/45
* docs: have the reviewer check what the craft checks miss by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/40
* feat: every app keeps a runbook, checked in CI (GAP-017) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/44
* feat: faster reviews: a plan review, focused reviewers, and guardrail merges on the owner's yes by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/37
* fix: ask before a force-push only when -f stands alone by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/46
* feat: every assembly declares it isn't CLS-compliant, and CA1014 is on (GAP-021) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/47
* feat: check nesting, statements per member, file length and LCOM4 in CI (GAP-019) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/51
* feat: find duplicate code with PMD CPD in CI (GAP-020) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/49
* feat: size an app's structure to its requirements (ARC-009, GAP-002) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/54
* feat: an SBOM for every build, and OpenSSF Scorecard for the kit and its apps (GAP-013, GAP-014) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/48
* fix: let the shared Scorecard workflow start: ask for nothing at workflow level by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/55
* feat: safe database migrations, a database guide with prices, and data rules (GAP-008) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/50
* feat: new-app intake: question cards with prices, and New-KitApp writes the app profile by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/52
* feat: MAUI and desktop apps: thin UI projects, built on Windows and macOS (GAP-001) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/53
* feat: Dependabot updates PMD and the gitleaks image (GAP-023) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/56
* feat: benchmarks and Locust load tests with budgets (GAP-012) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/57
* feat: browser and accessibility tests for web UI apps, with Playwright and axe (GAP-004) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/58
* fix: ask before installing a browser locally by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/61
* feat: the coverage gate points at a too-long Windows clone path, and the docs say to keep it short by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/60
* refactor: read solutions through one module, KitSolution.psm1 (CRF-003) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/59
* refactor: one source for the benchmarks project name rule, Test-BenchmarksProject (CRF-003) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/62
* feat: rules record their basis, and enforcement as gate or advisory parts by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/63
* feat: Copilot code review replaces the reviewer agent on every pull request by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/64
* docs: rules cite their sources and each fact has one home by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/65
* docs: agents never merge a release PR or publish a release, everywhere by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/66
* feat: a guardrail merge records the owner's yes on the PR by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/67
* feat: AGENTS.md's Git and Done means sections are generated from the standards by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/68
* feat: restores require nuget.org's repository signature by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/69
* feat: one cost rule with a budget in the intake, and Microsoft's unit-test practices by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/70
* feat: var only where the type is named on the right, as dotnet/runtime does by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/71
* feat: Microsoft's C# conventions and identifier names, as build gates by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/72
* fix: the web UI factory sets its address before Kestrel binds by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/74
* feat: Wait-PullRequest, the kit's own watcher for a PR's review and CI by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/73
* feat: the reviewer agent replaces Copilot code review (ADR-0067) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/75
* feat: XML documentation on every public member is a build gate (STY-008) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/77
* feat: the Framework Design Guidelines rules check internal APIs too (STY-009) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/78
* fix: the sample has SQLite wait for its own write lock (ADR-0072) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/80
* docs: a README for new users, and a generated list of every source the rules cite by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/79
* fix: the SQLite interceptor checks its connection argument, as CA1062 asks by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/83
* feat: the tests run the app with dependency injection validation in every environment (CRF-013) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/81
* docs: HTTP APIs follow HTTP's semantics as Azure's API design guidance sets them out (API-007) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/85
* feat: every repo keeps a Mermaid diagram of its modules, and CI checks it's there (ARC-013) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/86
* feat: the sample applies Microsoft's Kestrel production security checklist (SEC-011) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/87
* docs: data access is resilient, guards against lost updates, queries efficiently and parameterizes SQL (DAT-007 to DAT-010) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/88
* feat: the app shuts down within the platform's grace period, and validates its options at startup (OPS-005, OPS-006) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/89
* feat: every intake default names its source: the developer's, the authority's or the agent's (ADR-0074) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/84
* feat: cheap PR watching and review (ADR-0068) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/76
* feat: allow routine commands without a permission prompt (ADR-0075) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/91
* feat: the security analyzers fail the build, and BannedSymbols bans the cryptography, certificate and XML APIs they miss (SEC-014, SEC-015) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/90
* docs: the Framework Design Guidelines no analyzer checks are an advisory rule, checked by code review (STY-010) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/82
* feat: code shape enforces the owner's tighter ceiling: nesting 3, 30 statements, 400 lines, 20 members, one public type per file (CRF-011) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/92
* test: prove the analyzer families the .NET best-practices pages rely on fail the build by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/93
* feat: ban reading the clock, building an HttpClient, blocking on a task and the non-generic collections by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/94
* feat: the source-generated regex and P/Invoke, System.Threading.Lock and the threading analyzers' async void rules are gates by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/95
* feat: the code shape check keeps nullable on in every file: no #nullable, a label on each !, no generated marker on hand-written code (STY-005) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/97
* docs: one advisory rule for the .NET best-practices and C# guidance no analyzer checks, with its themes for code review (STY-012) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/96
* feat: VSTHRD107 and VSTHRD110 fail a Task disposed or dropped, and a static readonly field that isn't private is PascalCase (STY-011, STY-007) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/98
* feat: an app runs the code shape and duplicate code checks on its own machine (GAP-022) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/99
* feat: an assembly marked pure may not use randomness, files, the network, the environment or other processes (ARC-008, GAP-039) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/101
* feat: check PMD's signature, nuget.org's certificates and package licenses (GAP-029, GAP-038, GAP-040) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/100
* feat: the kit's shared architecture tests gate six rules in every app's Architecture.Tests (GAP-037, part 1) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/103
* feat: run browser tests in the pinned Playwright image, and test an interactive page (GAP-033, GAP-036) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/102
* test: Testcontainers starts a container inside the Playwright image, from the web UI fixture (GAP-047) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/106
* feat: the kit's shared host checks gate nine rules in every app's FunctionalTests (GAP-037, part 2) by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/107
* docs: GAP-046's multi-ecosystem group test: an unrelated NuGet bump joins the group, so the kit keeps the by-hand step by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/108
* test: the Sync-KitApp fixture bumps whatever SDK the kit pins by @DerekFoulk in https://github.com/DerekFoulk/dotnet-agent-kit/pull/109
* chore: Bump dotnet-stryker from 5.0.0 to 5.1.0 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/111
* chore: Bump Microsoft.AspNetCore.Authentication.JwtBearer from 10.0.14 to 10.0.15 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/112
* chore: Bump Microsoft.AspNetCore.Mvc.Testing from 10.0.14 to 10.0.15 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/113
* chore: Bump Microsoft.EntityFrameworkCore.Sqlite from 10.0.14 to 10.0.15 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/115
* chore(deps): bump dotnet-sdk from 10.0.403 to 10.0.404 by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/104
* chore(deps): bump click from 8.5.0 to 8.5.1 in /.config/locust by @dependabot[bot] in https://github.com/DerekFoulk/dotnet-agent-kit/pull/105

## New Contributors
* @DerekFoulk made their first contribution in https://github.com/DerekFoulk/dotnet-agent-kit/pull/1
* @dependabot[bot] made their first contribution in https://github.com/DerekFoulk/dotnet-agent-kit/pull/26

**Full Changelog**: https://github.com/DerekFoulk/dotnet-agent-kit/commits/v0.1.0
