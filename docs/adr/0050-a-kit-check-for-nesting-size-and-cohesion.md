# ADR-0050: A kit check enforces nesting, statements per member, file length and LCOM4

- **Status:** Proposed
- **Date:** 2026-11-11

## Context

CRF-008 sets metric limits that Microsoft's analyzers enforce (CA1501, CA1502, CA1505, CA1506; ADR-0043). It also said "aim for" four more, which no tool checked, so they rested on the reviewer agent (GAP-019):
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
- two test classes first showed LCOM4 2: `BookmarksApiTests` and `EfBookmarkRepositoryTests`. Both were measurement gaps, not split classes. In one, a property (`Client => _host.Client`) joins the tests to the host their `Dispose` frees. In the other, the constructor builds the options from the connection. Once the check joins through both, every type is at 1.

## Options

### Option 1: A small kit check on Roslyn, run in CI, with the four as hard limits

`tools/Test-CodeShape.ps1` lists the solution's C# projects with `dotnet sln list`. It asks MSBuild for each project's Compile items and DefineConstants (`dotnet msbuild -getItem:Compile -getProperty:DefineConstants`, an evaluation, not a build). It then runs `tools/CodeShape`'s Kit.CodeShape console tool, which parses with Microsoft.CodeAnalysis.CSharp 5.9.0.

- **Trade-offs:** it checks all four, with definitions the kit states and tests.
  - Findings print in MSBuild's error format (`path(line,col): error CRF008: … [project]`), so setup-dotnet's problem matcher annotates the PR.
  - It's a small tool the kit maintains: about 400 lines, with 58 xUnit tests and 6 Pester tests.
  - It sees a project's own files only, with no package or project references, so binding is partial: a name it can't resolve counts as every member it could mean.
  - The package is Microsoft's, from dotnet/roslyn, MIT and not deprecated. The owner's "add whatever we need to" (ADR-0043) covers adding it.
- **Reversibility:** easy. One CI step and one tool folder.
- **Risk:** low to medium. A definition can be wrong for a case the tests don't cover. Each finding names the rule, and the exception comment is the escape hatch.

### Option 2: SonarAnalyzer.CSharp for nesting and file length, and the reviewer for the rest

- **Trade-offs:** an analyzer in the build, with IDE squiggles. But S138 counts lines, not statements, and nothing covers LCOM4, so GAP-019 stays half open. S134's default limit is 3, so the kit would have to configure it. It is also a large third-party analyzer set whose other rules overlap Microsoft's.
- **Reversibility:** easy.
- **Risk:** medium. Its other rules would need turning off or reconciling with STY-003's "every rule on".

### Option 3: Keep the four as advisory, for the reviewer

- **Trade-offs:** no new code. But GAP-019 stays open and the numbers stay ones nobody enforces, which CRF-008's own reason ("a few limits a tool enforces beat many that people ignore") argues against.
- **Reversibility:** n/a.
- **Risk:** the limits drift.

NDepend is the paid alternative to option 1. It measures all four, with an IDE view, but costs per seat and adds a licence every app needs. The kit uses only free tools unless the owner chooses otherwise.

## Recommendation

Option 1. It's the only free way to check all four, and the definitions are short enough to keep and test.

## Decision

Option 1, built in auto mode (ADR-0035) on 2026-11-11, at the owner's request to close the open scorecard gaps. **Proposed:** CRF-008 now states the four as limits, with an exception comment, until the owner accepts. If he'd rather keep them advisory, the CI step reports without failing instead.

How each limit is measured (the kit's own choices, each with tests in `tools/CodeShape/tests`):

- **Members:**
  - What counts: methods, constructors, destructors, operators, conversion operators, and property, indexer and event accessors. A file's top-level statements count as one member.
  - Local functions and lambdas count as part of the member that holds them.
- **Nesting:** these add a level: `if` (but not an `else if`, which continues its chain), `switch` statement, `for`, `foreach`, `while`, `do` and `try`. A block, `using`, `lock`, `checked` or a lambda adds none. The finding points at the deepest statement.
- **Statements:** every statement in the member, nested ones included; a block `{ }` isn't one.
- **File length:** the file's lines; a final newline ends the last line without starting another.
- **LCOM4:**
  - Each non-static method that uses the type's instance state joins every instance member it names, and the methods are then grouped by what they share.
  - A property's accessors are methods, so a property joins the state it reads.
  - A constructor isn't a method, since it touches every field. But a field or property it assigns from other state is joined to that state.
  - A partial type is measured whole and reported once.
  - Static methods, and methods that use no instance state, aren't counted.
- **Skipped:** generated code, by the compiler's own test. That's a name starting `TemporaryGeneratedFile_` or ending `.designer.cs`, `.generated.cs`, `.g.cs` or `.g.i.cs`, or an `<auto-generated>` comment before the file's first token. The compiler's fourth way, `generated_code = true` in .editorconfig, isn't read; such a file takes the exception comment instead. Each file is parsed with its project's preprocessor symbols.
- **Exceptions:** a single-line comment `// CRF-008 exception: <reason>` right before a member or type, or at the top of a file, exempts it. This is the kit's counterpart of `[SuppressMessage]` with a `Justification`, which a non-analyzer check can't use. A marker without a reason exempts nothing, and the reviewer checks the reason holds (CRF-001).

## Consequences

- `dotnet-ci.reusable.yml` runs the check after the tests, in the kit and in every app, from the repo root so the repo's own global.json picks the SDK. It builds the tool from the kit's download with analyzers off, so an app's newer SDK analyzers can't fail the kit's code.
- `Directory.Packages.props` adds Microsoft.CodeAnalysis.CSharp 5.9.0 and pins Microsoft.CodeAnalysis.Analyzers 5.9.0. The C# package asks for a preview of the analyzers, and the pin takes the stable release. Both are in the "Kit tools" group, which apps don't get (ADR-0032).
- **An app can't yet run the check on its own machine:** the tool's source isn't in `.kit/tools`. It runs only in the app's CI (GAP-022). This waits for the kit's move to a .NET tool (v0.2.0), so it isn't solved twice.
- **EF Core migrations:** EF Core marks the model snapshot and `.Designer.cs` files as generated, so they're skipped. A migration file itself may not be. A very large one may need the exception comment. Not measured: the sample has no migrations.
- GAP-019 is closed. CRF-008's enforcement names the check. `tools/tests/Test-CodeShape.Tests.ps1` fails if CRF-008's four numbers and `Limits.cs` disagree.

## Pillars affected

- **Operational excellence:** four more limits checked in CI, annotated on the PR.
- **Reliability:** smaller, more cohesive members and types are where fewer defects collect (CRF-008's reason).
- **Cost:** about 10 to 20 seconds of CI per run to build and run the tool; no licence.
- **Security, performance:** none.

## Sources

- owner, 2026-11-11 (close the open scorecard gaps; hard limits, proposed until he accepts)
- ADR-0043
- Hitz, M. and Montazeri, B., "Measuring Coupling and Cohesion in Object-Oriented Systems", 1995 (LCOM4)
- https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/compiler-options/language#nullable, retrieved 2026-11-11 (how the compiler recognizes generated code)
- https://learn.microsoft.com/en-us/visualstudio/msbuild/evaluate-items-and-properties, retrieved 2026-11-11 (`-getItem`, `-getProperty`)
- https://learn.microsoft.com/en-us/dotnet/fundamentals/code-analysis/configuration-options#general-options, retrieved 2026-11-11 (`generated_code` in .editorconfig)
