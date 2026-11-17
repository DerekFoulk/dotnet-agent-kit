# ADR-0078: A project marks itself pure with an MSBuild property that adds a second banned-symbols file

- **Status:** Accepted
- **Date:** 2026-11-16

## Context

ARC-008 says assemblies marked pure (core business logic) use no randomness, file or network access except through injected abstractions, so their tests are deterministic, and that this is opt-in per project. Nothing said how an assembly is marked pure, and no check held the APIs it may not call (GAP-039). The clock part was done: `BannedSymbols.txt` bans reading it in every project.

Some facts limit the choice:

- **The analyzer takes several files.** The kit's banned-API check is `Microsoft.CodeAnalysis.BannedApiAnalyzers` (CRF-010, ADR-0043). Its help page names the file it reads as `BannedSymbols.txt` or `BannedSymbols.*.txt`, given as `AdditionalFiles`. It doesn't say how several combine. A fixture showed it: a project given both files fails on entries from each (`tools/tests/BuildConfig.Tests.ps1`, the `PureRandomness` rows).
- **Items see every property.** `Directory.Build.props` is imported before a `.csproj`'s own properties. But MSBuild evaluates every property, in every file, before any item. So an item's condition in `Directory.Build.props` sees a property the `.csproj` sets later. This is in Microsoft's "How MSBuild builds projects" page: "items can access any property if defined outside any targets, regardless of whether the property definition appears later".
- **The sample's domain made a random id.** `Bookmark.Create` made its id with `Guid.CreateVersion7(createdAt)`, whose bits after the time are random.

## Options

### Option 1: An MSBuild property in the project, which adds `BannedSymbols.Pure.txt`

A project sets `<PureAssembly>true</PureAssembly>` in its `.csproj`. `Directory.Build.props` adds `BannedSymbols.Pure.txt` as one more `AdditionalFiles` item, on that condition.

- **Trade-offs:** The mark sits in the project it applies to, where a reader looks, and is opt-in per project, as ARC-008 says. The ban list is one file beside `BannedSymbols.txt`, in the same format and checked the same way, and a project that doesn't set the property is unchanged. But a typo in the property name marks nothing, and nothing warns: the sample's test, which reads the evaluated items of every `*.Domain` project, covers the sample, and code review covers an app.
- **Reversibility:** Easy. Remove the property, or the item group and the file.
- **Risk:** Low.

### Option 2: Mark by name, as the coverage gate does

`Directory.Build.props` adds the file to every project whose name ends in `.Domain`, the pattern `Test-CoverageGate.ps1` holds to 100% line coverage (TST-004).

- **Trade-offs:** Nothing to set, and one idea of "the pure assemblies" across both checks. But ARC-008 says opt-in per project, pure logic needn't sit in a project named `Domain` (a console tool's one project, ARC-009, may hold some), and a name that changes moves the ban silently.
- **Reversibility:** Easy.
- **Risk:** Medium: a `Domain` project that must, for now, touch something the list bans has to rename itself, or the rule needs an exception.

### Option 3: Each pure project adds the file itself

The `.csproj` adds `<AdditionalFiles Include="../../BannedSymbols.Pure.txt" />` with a relative path.

- **Trade-offs:** No new property, but every project repeats a path into the repo root that breaks when the project moves, and the kit can't test the mechanism once for every app.
- **Reversibility:** Easy.
- **Risk:** Medium: a wrong relative path adds a file that isn't there, and the analyzer ignores it without a sound.

## Recommendation

Option 1: the mark is opt-in and lives in the project, as ARC-008 asks, and `Directory.Build.props` keeps the path in one place.

## Decision

Accepted as recommended, in auto mode (owner's task brief for GAP-039, 2026-11-16: an MSBuild property that `Directory.Build.props` turns into a second banned-symbols file).

## Consequences

- **The ban list.** `BannedSymbols.Pure.txt` bans four families.
  - **Randomness:** `Random`, `RandomNumberGenerator`, `Guid.NewGuid` and both `Guid.CreateVersion7` overloads.
  - **File access:** `File`, `Directory`, the `FileSystemInfo` types, `FileStream` and the other file types, and `Path`'s members that touch the disk or read the current or temporary folder. Also the `StreamReader` and `StreamWriter` constructors that open a path, zip and tar files (`ZipFile`, `ZipFileExtensions`, `TarFile`), folder listings (`FileSystemEnumerable`), and the app's and an assembly's own location.
  - **Network access:** `HttpClient` and its handlers, even when passed in, plus `Socket`, `TcpClient`, `Dns` and the other network types. A pure assembly takes an interface of its own, which the infrastructure implements over `HttpClient`.
  - **The environment and other processes:** environment variables, the command line and current directory, the machine's and user's names and folders, `Environment`'s tick counts, `Stopwatch` (clocks), the local time zone (`TimeProvider.LocalTimeZone` replaces it), `Console`, `Process`, named and anonymous pipes, and ending the process.

  ARC-008's statement now names the fourth family. Its reason, deterministic tests, covers it as it covers the other three.
- **What stays open.** `tools/tests/BuildConfig.Tests.ps1` shows the first three build in a marked project:
  - `Path`'s string work.
  - Streams, readers and writers the caller passes in.
  - What only describes the platform, such as `Environment.NewLine` and `ProcessorCount`.
  - `CultureInfo.CurrentCulture`: CA1305 and the other culture rules, which every project has, already keep the current culture out of formatting and comparison.
  - `HashCode` and `string.GetHashCode`, whose per-process seed changes no result a test should assert.
- **What the list can't reach.** Some APIs take a path or a URL through a general-purpose overload, such as `XDocument.Load(string)` or `XmlReader.Create(string)`. Code review checks these (ARC-008's advisory part).
- **Tests.** `tools/tests/BuildConfig.Tests.ps1` has:
  - a failing fixture for each family, with one row per banned symbol it proves, including one that shows a marked project keeps `BannedSymbols.txt`'s bans;
  - rows that show a marked project keeps what the list leaves open, so a ban widened to a whole type shows;
  - a clean fixture that shows an unmarked project may use them;
  - checks that every ID in the new file resolves and repeats none of `BannedSymbols.txt`'s, and that every path constructor of the stream reader and writer is listed;
  - a test that every `*.Domain` project in the sample gets the file.
- **The sample.** `Bookmarks.Domain` is marked pure. `Bookmark.Create` now takes its id from the application, which makes it with `Guid.CreateVersion7(createdAt)`, and checks that the id is a UUID version 7 of `createdAt`, so ordering by id is still creation order. The banned-API analyzer reads XML documentation `cref`s too, so a pure assembly's comments name a banned member as `<c>` text.
- **Apps.** `Export-KitApp` copies `BannedSymbols.Pure.txt` with the other root build files, and the sync job carries it. The app template has no projects, so nothing in it is marked. An app's domain project sets the property when it's created (ARC-008's statement says how).
- **The two ideas of pure.** TST-004's 100% coverage still keys on the `*.Domain` name. A domain project that isn't marked, or a marked project not named `Domain`, gets one check without the other. Making the coverage gate read the property would unify them, but it waits for a project that needs it.

## Pillars affected

Reliability: pure logic's tests can't depend on the machine, the clock, the disk or the network, so they don't flake. Operational Excellence: the mark is one line in the project, checked by the build. Performance Efficiency: unchanged; the analyzer reads one more small file in marked projects.

## Sources

- owner, 2026-11-16
- https://github.com/dotnet/roslyn/blob/main/src/RoslynAnalyzers/Microsoft.CodeAnalysis.BannedApiAnalyzers/BannedApiAnalyzers.Help.md, retrieved 2026-11-16
- https://learn.microsoft.com/visualstudio/msbuild/build-process-overview#evaluation-phase, retrieved 2026-11-16
