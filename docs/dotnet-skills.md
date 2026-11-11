# Curated .NET skills from dotnet/skills

The kit carries a few of the agent skills that Microsoft's .NET team publishes in [dotnet/skills](https://github.com/dotnet/skills), copied unchanged into `.claude/skills/` next to the kit's own (ADR-0042). Claude Code, Visual Studio, VS Code and the Copilot coding agent read them there, and every app gets them with the rest of the kit's skills.

- **Pinned to:** commit [`96c3d68`](https://github.com/dotnet/skills/tree/96c3d68dad2855e3ab5178aa1a262789d86a1466) (2026-11-06), retrieved 2026-11-10. `tools/dotnet-skills.json` records it, with git's blob id for every copied file.
- **License:** MIT, Copyright (c) .NET Foundation and Contributors; the notice is in `THIRD-PARTY-NOTICES.md`.
- **Checked by:** `tools/tests/DotnetSkills.Tests.ps1`, part of the script tests in AGENTS.md's Commands table. It fails when a copied file differs from the pinned commit, is missing, or isn't upstream.

## When a skill and a kit rule disagree

The kit rule wins (AGENTS.md, "Whose rules win"). The copies are never edited, so the rule is applied when the agent writes the code, and the build enforces most of them. Known differences:

- **`var`.** Many upstream code samples use `var`. The kit never does (STY-002), and the build fails on it.
- **Packages and dependencies.** A package a curated skill names isn't approved by being named there: the kit's standards and ADRs approve dependencies, not the copies. Examples: `YTest.MTP.XUnit2` (a 0.x community package) and three `Microsoft.Testing.Extensions` packages in `migrate-vstest-to-mtp`, and Swashbuckle in `dotnet-webapi`. Adding one follows AGENTS.md's dependency rules: in auto mode only when the kit's standards, ADRs or the docs they cite name it for the task; in review mode, with the owner's OK. Every version goes in `Directory.Packages.props` (SUP-002), never inline as some samples show.
- **Other skills named in the text.** Some curated skills hand work to an upstream skill the kit left out (for example, `run-tests` names `platform-detection` and `mtp-hot-reload`). The agent won't find those; it carries on with the curated skill or asks.

## In

| Skill | Upstream plugin | Why it's in | Kit rules that say more |
|---|---|---|---|
| `dotnet-webapi` | `dotnet-aspnetcore` | Minimal API endpoints, typed results, built-in OpenAPI, Problem Details and validation, which API-001 to API-006 also choose | It keeps controllers where a project has them, or when asked; the kit uses Minimal APIs, and controllers need an ADR (API-001). Paging (API-004), the OpenAPI document in Development only (API-003) and versioning (API-005). It allows Swashbuckle before .NET 9; the kit uses the built-in document on every version (API-003) |
| `optimizing-ef-core-queries` | `dotnet-data` | EF Core is the kit's data access; N+1, projection, tracking and paging problems are common | API-004's paging limits |
| `analyzing-dotnet-performance` | `dotnet-diag` | The Performance Efficiency pillar: finds allocation, async and LINQ problems in code review | STY-002 (`var` in samples) |
| `run-tests` | `dotnet-test` | Runs tests on Microsoft Testing Platform, the kit's runner (`global.json`), with xUnit v3 | AGENTS.md's Commands table has the exact test and coverage commands. The skill also looks for `.agents/skill-overlays/dotnet-test/run-tests.md`, which the kit doesn't have |
| `filter-syntax` | `dotnet-test` | Reference only: agents don't call it, and `run-tests` reads it to run one test or class while working through a test list (TST-002) | None known |
| `migrate-xunit-to-xunit-v3` | `dotnet-test-migration` | Moves a mature repo onto the kit's xUnit v3 (TST-005, ADR-0015) | None known |
| `migrate-vstest-to-mtp` | `dotnet-test-migration` | Moves a mature repo onto Microsoft Testing Platform, as the kit's `global.json` sets | It also covers MSTest options; the kit uses xUnit v3 (TST-005). For xUnit v2 it adds `YTest.MTP.XUnit2` with an inline version; the kit's route is `migrate-xunit-to-xunit-v3` first (TST-005), with versions in `Directory.Packages.props` (SUP-002). Its extension packages other than `Microsoft.Testing.Extensions.CodeCoverage`, which the kit already pins, are new dependencies |
| `convert-to-cpm` | `dotnet-nuget` | Moves a mature repo onto central package management (SUP-002, ADR-0015) | SUP-002 turns on transitive pinning and SUP-001 adds lock files; the skill leaves both optional |
| `author-component` | `dotnet-blazor` | Blazor Web App components, the kit's web UI (ADR-0008) | STY-002 (`var` in samples) |
| `msbuild` | `dotnet` | Build files in every repo: `Directory.Build.props`, imports, incremental builds and build failures. It bundles the `dotnet-msbuild` plugin's skills as references | None known. It refuses to delete every `bin` and `obj` folder or clear shared NuGet caches without being told to, which fits SEC-003 |

Their descriptions total 6,181 characters. With the kit's own skills that's 7,644 of the 8,000-character budget (ADR-0042). The count is on the safe side: it includes `filter-syntax`, whose description Claude Code doesn't list, and leaves out skill names and the owner's personal and plugin skills, which share the listing.

## Out

### Conflicts with a kit rule

| Skill | Upstream plugin | Why it's out |
|---|---|---|
| `writing-mstest-tests` | `dotnet-test` | MSTest; the kit tests with xUnit v3 (TST-005) |
| `migrate-mstest-v1v2-to-v3`, `migrate-mstest-v3-to-v4`, `migrate-nunit-to-mstest`, `migrate-xunit-to-mstest` | `dotnet-test-migration` | Move a repo to or within MSTest (TST-005) |
| `code-testing`, `code-testing-agent`, `code-testing-extensions` | `dotnet-test` | Generate tests for code that already exists; the kit writes each test first (TST-001, `tdd-cycle`), and they default to MSTest |
| `create-datadriven-aspnetcore` | `dotnet-data` | Generates CRUD pages and endpoints straight against the `DbContext`, past the Application layer (ARC-001), with no tests first (TST-001) |
| `create-blazor-project` | `dotnet-blazor` | Writes a second `AGENTS.md` next to the project; an app has one, from the kit's template (ADR-0032) |
| `csharp-expert` | `dotnet` | A router whose job is to send the agent to the right skill, and to give steps to install upstream's marketplace plugins when it's missing; the kit curates instead (ADR-0042), and installing is the owner's call (SEC-003) |
| `setup-local-sdk` | `dotnet` | Installs a .NET SDK (SEC-003); the kit pins the SDK in `global.json` (SUP-005) |
| `dotnet-maui-doctor` | `dotnet-maui` | Installs workloads, a JDK and the Android SDK (SEC-003) |
| `dotnet-trace-collect`, `dump-collect` | `dotnet-diag` | Install diagnostic tools on the machine (SEC-003), for production incidents, which the kit has no rules for yet |
| `troubleshoot-binlog-mcp` | `dotnet-msbuild` | Uses a binlog MCP server, a connector the kit hasn't allowlisted (SEC-004) |
| `use-igniteui-blazor` | `dotnet-blazor` | A third-party commercial component library; a commercial repo may not use it (SEC-005), and no kit app uses it |
| `migrate-dotnet10-to-dotnet11`, `process-api-net11`, `system-text-json-net11` | `dotnet-upgrade`, `dotnet11` | .NET 11 isn't an LTS release; the kit targets the current LTS, and anything else needs an ADR (ARC-004, ADR-0005) |
| `nuget-trusted-publishing` | `dotnet-advanced` | Publishes packages to nuget.org and changes repo and nuget.org settings; kit apps don't publish packages, and repo settings are the owner's (SEC-003) |

### Has scripts

The kit copies instructions only. A third-party script would run on the owner's machine, and its `.ps1` files would fail the kit's script checks (ADR-0040).

| Skill | Upstream plugin |
|---|---|
| `coverage-analysis`, `find-untested-sources` | `dotnet-test` |
| `migrate-nullable-references` | `dotnet-upgrade` (fits STY-005 otherwise) |
| `android-tombstone-symbolication`, `apple-crash-symbolication` | `dotnet-diag` |

### Duplicated by a curated skill

| Skill | Upstream plugin | Why it's out |
|---|---|---|
| `binlog-failure-analysis`, `binlog-generation`, `build-parallelism`, `build-perf-baseline`, `build-perf-diagnostics`, `check-bin-obj-clash`, `copy-to-output-directory`, `directory-build-organization`, `eliminate-redundant-restores`, `eval-performance`, `extension-points`, `find-repeated-work-within-one-build`, `including-generated-files`, `incremental-build`, `item-management`, `msbuild-antipatterns`, `msbuild-modernization`, `property-patterns`, `resolve-project-references`, `target-authoring` | `dotnet-msbuild` | The curated `msbuild` skill carries the same guidance as references; both would match the same requests |

### Not for the kit's apps

| Skill | Upstream plugin | Why it's out |
|---|---|---|
| `winforms-expert` | `dotnet-winforms` | Kit apps are web and MAUI (ADR-0008) |
| `thread-abort-migration`, `clr-activation-debugging` | `dotnet-upgrade`, `dotnet-diag` | .NET Framework only |
| `template-authoring`, `template-comparison`, `template-discovery`, `template-instantiation`, `template-smart-defaults`, `template-validation` | `dotnet-template-engine` | The kit makes apps with `Export-KitApp`, not `dotnet new` templates (ADR-0032) |
| `csharp-scripts` | `dotnet-advanced` | File-based C# programs; the kit's scripts are PowerShell (ADR-0011) |
| `exp-mock-usage-analysis`, `exp-test-maintainability` | `dotnet-experimental` | Upstream marks them experimental |
| `technology-selection` | `dotnet-ai` | Picks an AI stack; the kit has no AI rules yet, and that choice is the owner's |
| `test-tagging` | `dotnet-test` | Tags tests by category, a convention the kit doesn't use |

### Fits, waiting for room in the budget

These fit the kit's stack and rules. Each would push the listing past its budget, so one comes in when another goes out, or when the budget changes. The likeliest first: the MAUI skills when an app adds a MAUI client (ADR-0008), and the upgrade skills when a mature repo moves to the current LTS (ADR-0015).

| Skill | Upstream plugin |
|---|---|
| `maui-app-lifecycle`, `maui-collectionview`, `maui-data-binding`, `maui-dependency-injection`, `maui-safe-area`, `maui-shell-navigation`, `maui-theming` | `dotnet-maui` |
| `collect-user-input`, `configure-auth`, `coordinate-components`, `fetch-and-send-data`, `plan-ui-change`, `support-prerendering`, `use-js-interop` | `dotnet-blazor` |
| `convert-blazor-server-to-webapp` | `dotnet-aspnetcore` |
| `migrate-dotnet8-to-dotnet9`, `migrate-dotnet9-to-dotnet10`, `dotnet-aot-compat` | `dotnet-upgrade` |
| `assertion-quality`, `test-anti-patterns`, `test-smell-detection`, `test-gap-analysis`, `grade-tests`, with `test-analysis-extensions`, which they read | `dotnet-test` |
| `test-value-evidence`, `crap-score`, `detect-static-dependencies`, `testability-obstacle`, `generate-testability-wrappers`, `migrate-static-to-wrapper`, `platform-detection`, `mtp-hot-reload`, `scaffold-dotnet-test-project` | `dotnet-test` |
| `csharp-refactoring`, `dotnet-breaking-changes` | `dotnet` |
| `microbenchmarking` (adds BenchmarkDotNet, a new package) | `dotnet-diag` |
| `dotnet-pinvoke`, `vectorization` | `dotnet-advanced` |

## Move to a newer upstream commit

1. Run `./tools/Update-DotnetSkills.ps1`. It fetches upstream's `main` (or `-Commit <sha>`), copies the listed skills, removes files that are gone upstream, and rewrites `tools/dotnet-skills.json` with the new commit and today's date. It changes nothing if a listed skill is gone, holds a symbolic link or submodule, or a copy has an edit.
2. Read the diff. Upstream text becomes instructions every agent follows, so check it against the kit's rules, as the tables above did.
3. Update the commit and date in this file's "Pinned to" line and in `THIRD-PARTY-NOTICES.md`, and look upstream for new skills to add to the tables.
4. Run every check in AGENTS.md's Commands table, then open the PR.

If the script stops partway, for example on a file another program has open, some folders are new and the lock isn't, and the next run refuses. Put the folders back first: `git restore .claude/skills/` undoes changed and deleted files, and `git status --short .claude/skills/` lists the new ones (`??`), which you delete by hand. Then run it again. (`git clean` would also remove them, but it deletes for good, so it's the owner's call.)

To add a skill, add it to the `skills` list in `tools/dotnet-skills.json` with `name`, `source` and an empty `files`, run the script, and move its row in the tables above. To remove one, take it out of the list, delete its folder in `.claude/skills/`, and move its row; the script tests fail on a skill folder that is neither the kit's own nor in the list. Either way, update its folder in `THIRD-PARTY-NOTICES.md`.
