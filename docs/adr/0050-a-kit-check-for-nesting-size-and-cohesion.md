# ADR-0050: A kit check enforces nesting, statements per member, file length and LCOM4

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

CRF-008 sets metric limits that Microsoft's analyzers enforce (CA1501, CA1502, CA1505, CA1506; ADR-0043). It also says "aim for" four more, which no tool checked, so they rested on the reviewer agent (GAP-019):
- nesting 4 levels deep at most;
- about 100 statements per method;
- about 800 lines per file;
- LCOM4 of 1, meaning classes whose members all work together.

LCOM4 (Hitz and Montazeri, 1995) counts the connected groups among a class's methods. Two methods are connected when they use the same field or one calls the other. A class whose methods form two groups that share nothing is two classes in one.

What exists:
- **Microsoft's analyzers and Microsoft.CodeAnalysis.Metrics** cover cyclomatic complexity, coupling, inheritance depth, maintainability and lines of code. They don't cover nesting depth, statement counts or LCOM4.
- **SonarAnalyzer.CSharp** (free, LGPL-3.0) has rules for nesting (S134), method length in lines (S138) and file length (S104). It counts lines, not statements, and has nothing for LCOM4. Its limits are set through a SonarLint.xml file.
- **NDepend** measures all four, LCOM4 included. It is paid, per seat (price on ndepend.com; not checked for this ADR).

What measurement showed, with the check below on the kit's own solution (13 C# projects, 58 files):
- the deepest nesting is 4;
- the longest member has 13 statements;
- the longest file has 278 lines;
- every type is at LCOM4 1.
  - Two test classes first showed 2: `BookmarksApiTests` and `EfBookmarkRepositoryTests`. Both were measurement gaps, not split classes.
  - In one, a property (`Client => _host.Client`) joins the tests to the host their `Dispose` frees.
  - In the other, the constructor builds the options from the connection.
  - The sample's services (`BookmarkService`, `EfBookmarkRepository`) keep their state in primary constructor parameters, which the check counts as state.

## Options

### Option 1: A small kit check on Roslyn, run in CI, with the four as hard limits

Roslyn is the C# compiler's own code-analysis library: it parses C# into a syntax tree and works out what each name refers to ("binding").

`tools/Test-CodeShape.ps1` lists the solution's C# projects with `dotnet sln list` (**Update, 2026-11-12:** now through `tools/KitSolution.psm1`, `.slnx` only; see Consequences). It asks MSBuild for each project's Compile items and DefineConstants (`dotnet msbuild -getItem:Compile -getProperty:DefineConstants`, an evaluation, not a build). A multi-target project is read through its first framework. It then builds and runs `tools/CodeShape`'s Kit.CodeShape console tool, which reads the files with Microsoft.CodeAnalysis.CSharp 5.9.0.

- **Trade-offs:** it checks all four, with definitions the kit states and tests.
  - Findings print in MSBuild's error format (`path(line,col): error CRF011: … [project]`), so setup-dotnet's problem matcher annotates the PR.
  - It's a small tool the kit maintains: about 560 lines, with 70 xUnit tests and 8 Pester tests.
  - It binds names only within a project's own files, with no package or project references. A call it can't resolve counts as every member it could mean, or as none when nothing in view could match.
  - The package is Microsoft's, from dotnet/roslyn, MIT and not deprecated. The owner's "add whatever we need to" (ADR-0043) covers adding it.
- **Reversibility:** easy. One CI step and one tool folder.
- **Risk:** medium.
  - A definition can be wrong for a case the tests don't cover. Each finding names the rule, and the exception comment is the escape hatch.
  - The tool is built in every app's CI, from code the app can't change. A new SDK's compiler warning, or a new NuGet advisory against Microsoft.CodeAnalysis, would fail every app's check until a kit release. So the build turns off analyzers, warnings-as-errors and NuGet's audit, as labelled safety nets (CRF-001). The kit's own CI still builds the tool with every gate on, so the kit finds such a change first.

### Option 2: SonarAnalyzer.CSharp for nesting and file length, and the reviewer for the rest

- **Trade-offs:** an analyzer in the build, with IDE squiggles. But:
  - S138 counts lines, not statements, and nothing covers LCOM4, so GAP-019 stays half open.
  - S134's default limit is 3, so the kit would have to configure it.
  - It's a large third-party analyzer set whose other rules overlap Microsoft's.
- **Reversibility:** easy.
- **Risk:** medium. Its other rules would need turning off or reconciling with STY-003's "every rule on".

### Option 3: Keep the four as advisory, for the reviewer

- **Trade-offs:** no new code. But GAP-019 stays open, and the numbers stay ones nobody enforces, which CRF-008's own reason argues against: "a few limits a tool enforces beat many that people ignore".
- **Reversibility:** n/a.
- **Risk:** the limits drift.

NDepend is the paid alternative to option 1. It measures all four, with an IDE view, but it costs per seat and adds a licence every app needs. The kit uses only free tools unless the owner chooses otherwise.

## Recommendation

Option 1. It's the only free way to check all four, and the definitions are short enough to keep and test.

## Decision

Option 1, built in auto mode (ADR-0035) on 2026-11-11, at the owner's request to close the open scorecard gaps.

**Proposed:** a new rule, CRF-011 (`status: proposed`), states the four as limits with an exception comment, until the owner accepts it.
- CRF-008 keeps its accepted wording, "aim for", in the meantime.
- If he accepts, CRF-008's "aim for" sentence goes, so the numbers are stated once.
- If he'd rather keep them advisory, the CI step reports without failing instead.

How each limit is measured (the kit's own choices, each with tests in `tools/CodeShape/tests`):

- **Members:**
  - What counts: methods, constructors, destructors, operators, conversion operators, property, indexer and event accessors, and expression-bodied properties and indexers. A file's top-level statements count as one member.
  - Local functions and lambdas count as part of the member that holds them. A lambda in a field initializer isn't measured.
- **Nesting:** these add a level: `if` (but not an `else if`, which continues its chain), `switch` statement, `for`, `foreach` (a deconstructing one too), `while`, `do` and `try`. A block, `using`, `lock`, `checked` or a lambda adds none. The finding points at the deepest statement.
- **Statements:** every statement in the member, nested ones included; a block `{ }` isn't one.
- **File length:** the file's lines; a final newline ends the last line without starting another.
- **LCOM4:**
  - What counts as a method: each non-static method that uses the type's instance state. Each joins every piece of state and every method it names. A call to a generic method (`Helper<int>`) joins the method declared (`Helper<T>`).
  - What counts as state: the type's fields, properties and events, and its primary constructor's parameters, which the compiler keeps for the type's members. A local function belongs to its method, not the type.
  - Properties: a property or indexer links the state it reads, so a method that uses it shares that state. It isn't a method of its own. Counting it as one, as some LCOM4 tools do, failed every options class and record with two computed properties over different state (review 2), which aren't two classes in one.
  - Grouping: methods are grouped by what they share, and the type is reported when it has more groups than the limit.
  - Constructors: a constructor isn't a method, since it touches every field. But a field or property it assigns from other state, or one initialized from other state (a primary constructor's parameter, say), is joined to that state. Only the type's own instance state is joined this way: a static field or a local built from two fields doesn't join them.
  - Other instances: a member a method reads through another instance of the type (`other._b`, or `other._b` on another construction of the same generic type) counts as the type's own. A field of another construction that a constructor assigns isn't joined; nor is a tuple deconstruction in a constructor (`(_c, _b) = (_a, 1)`). Both are rare, err toward a report, and are left for a later PR.
  - Partial types: a partial type is measured whole and reported once. Its generated halves are read for what they declare, never reported on.
  - Static methods, and methods that use no instance state, aren't counted.
- **Skipped:**
  - Generated code, by the compiler's own test: a name starting `TemporaryGeneratedFile_` or ending `.designer.cs`, `.generated.cs`, `.g.cs` or `.g.i.cs`, or an `<auto-generated>` comment before the file's first token.
  - The compiler's fourth way, `generated_code = true` in .editorconfig, isn't read; such a file takes the exception comment instead.
  - Each file is parsed with its project's DefineConstants. The SDK's implicit symbols, such as `NET10_0_OR_GREATER`, are added by a build target, not the evaluation, so code under an `#if` on one of them is read as if the symbol weren't defined.
- **Exceptions:** the single-line comment `// CRF-011 exception: <reason>`, the kit's counterpart of `[SuppressMessage]` with a `Justification`, which a non-analyzer check can't use. Where it sits says what it covers:
  - **Right before a member,** as the last comment before it (before its attributes) with no blank line between: that member. Before a property, its accessors too.
  - **Right before a type,** in the same way: the type's cohesion, not its members.
  - **The file's first comment, with a blank line below it:** the file's length and its top-level statements. A file that must start with a license header can't use it; the kit's `.editorconfig` sets no header, and an app that adds one would need this rule widened.
  - A marker without a reason covers nothing, and the reviewer checks the reason holds (CRF-001).

## Consequences

- `dotnet-ci.reusable.yml` runs the check after the tests, in the kit and in every app.
  - It runs from the repo root, so the repo's own global.json picks the SDK.
  - It builds the tool from the kit's download with the safety nets above. MinVer is skipped too, since the download isn't a git checkout.
  - A tool that doesn't build stops the check with its errors, so it never reads as a finding in the app's code.
- `Directory.Packages.props` adds Microsoft.CodeAnalysis.CSharp 5.9.0 and pins Microsoft.CodeAnalysis.Analyzers 5.9.0. The C# package asks for a preview of the analyzers, and the pin takes the stable release.
  - Both are in the "Kit tools" group, which `Export-KitApp` now leaves out of an app, as it does the sample app's.
  - An app never needs them: CI builds the tool with the kit's own props. Transitive pinning would otherwise force them on an app's own Roslyn packages.
- **An app can't yet run the check on its own machine:** the tool's source isn't in `.kit/tools`. It runs only in the app's CI (GAP-022). This waits for the kit's move to a .NET tool (v0.2.0), so it isn't solved twice.
- **EF Core migrations:** EF Core marks the model snapshot and `.Designer.cs` files as generated, so they're skipped. A migration file itself may not be, and a very large one may need the exception comment. Not measured: the sample has no migrations.
- GAP-019 is closed. CRF-008's enforcement points to CRF-011. `tools/CodeShape/src/Kit.CodeShape/Limits.cs` is the one source of the numbers, and `tools/tests/Test-CodeShape.Tests.ps1` fails if CRF-011's statement and `Limits.cs` disagree.
- **Update (2026-11-12):** Test-CodeShape no longer lists projects with `dotnet sln list`. It reads the solution, and picks a multi-target project's first framework, through `tools/KitSolution.psm1`, as every kit script and shared workflow does (CRF-003). That reads `.slnx` only, so the check now refuses a `.sln` and names `dotnet sln migrate`, which converts one. It read a `.sln` before only because `dotnet sln list` does; nothing in the kit passes one, and CI runs Get-UiProject, which needs a `.slnx`, on the same solution first.

## Pillars affected

- **Operational excellence:** four more limits checked in CI, annotated on the PR.
- **Reliability:** smaller, more cohesive members and types are where fewer defects collect (CRF-008's reason).
- **Security:** the tool runs only in CI and reads code. NuGet's audit of its packages runs in the kit's CI, not in an app's.
- **Cost:** a few seconds of CI per run to build and run the tool (not measured on a runner yet); no licence.
- **Performance:** none.

## Sources

- owner, 2026-11-11 (close the open scorecard gaps; hard limits, proposed until he accepts)
- ADR-0043
- Hitz, M. and Montazeri, B., "Measuring Coupling and Cohesion in Object-Oriented Systems", 1995 (LCOM4)
- https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/language#nullable, retrieved 2026-11-11 (how the compiler recognizes generated code)
- https://learn.microsoft.com/en-us/visualstudio/msbuild/evaluate-items-and-properties, retrieved 2026-11-11 (`-getItem`, `-getProperty`)
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-options#general-options, retrieved 2026-11-11 (`generated_code` in .editorconfig)
