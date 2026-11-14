# Changelog

## 0.1.0 (2026-11-14)

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

## New Contributors
* @DerekFoulk made their first contribution in https://github.com/DerekFoulk/dotnet-agent-kit/pull/1
* @dependabot[bot] made their first contribution in https://github.com/DerekFoulk/dotnet-agent-kit/pull/26

**Full Changelog**: https://github.com/DerekFoulk/dotnet-agent-kit/commits/v0.1.0
