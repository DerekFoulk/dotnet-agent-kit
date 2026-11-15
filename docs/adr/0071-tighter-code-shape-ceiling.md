# ADR-0071: The code shape check takes the owner's tighter ceiling, with members per type and public types per file

- **Status:** Proposed
- **Date:** 2026-11-15

## Context

ADR-0050 built the code shape check (`tools/Test-CodeShape.ps1`, the Kit.CodeShape tool) with the four numbers CRF-008 then gave as aims: nesting 4 levels deep, 100 statements per member, 800 lines per file and LCOM4 of 1. CRF-011 (`status: proposed`) states them as limits.

In the rule-of-ten discussion (owner, 2026-11-12, the rules audit's CRF-011 row), the owner set two levels:
- **An aim, CRF-012 (accepted):** at most ten subfolders per folder, files per folder, types per file, members per type and lines per method. More is a reason to look for a split, and code review reports it as a Consider. No tool enforces it.
- **A hard ceiling, CRF-011:** nesting 3, 30 statements per member, 400 lines per file, 20 members per type, one public type per file, LCOM4 of 1. He asked for the numbers to be confirmed in the cleanup PR.

Three of the six numbers are tighter versions of ADR-0050's. Members per type and public types per file are new: no analyzer the kit runs checks them, and Kit.CodeShape didn't count them.

What measurement showed, with the new numbers on the kit's own solution (16 projects; 81 files before the fixes below, 85 after):
- one member nested 4 deep: `ContractTests.TheDocumentDescribesEveryErrorAsProblemDetails`, in the sample's functional tests;
- two files with three public types each: the sample's `BookmarkService.cs` (the service and its two result records) and `BookmarkContracts.cs` (the three API contracts);
- no member over 30 statements, no file over 400 lines (the longest has 285), and no type over 20 members.

## Options

### Option 1: The owner's six numbers as hard limits now, with two new counts in Kit.CodeShape

`Limits.cs` takes the three tighter numbers and two new ones, `MembersPerType = 20` and `PublicTypesPerFile = 1`. Two new rules count them:
- **Members per type** (`MemberCountRule`): the methods, constructors, finalizers, properties, indexers, events, fields and operators a type declares. A field or event declaration counts once for each name it lists. A record's positional parameters count as the properties the compiler makes of them, unless the record declares that property itself; a class's or struct's primary constructor parameters aren't members. A nested type isn't a member of the type that holds it: it's measured on its own. A partial type is measured whole, across its project's hand-written files, with a partial member declared in one part and implemented in another counted once, and it's reported once, at its first part. Interfaces count too. Enums aren't measured: their values are data.
- **Public types per file** (`PublicTypeRule`): the classes, structs, interfaces, records, enums and delegates declared `public` outside any other type, through every namespace in the file. A partial type's parts in one file are one type. The finding points at the first type over the limit and lists them all.
- **Both read syntax only,** with no compilation: two declarations are parts of one type when they share a namespace, the types they're nested in, a name and a number of type parameters (`TypeIdentity`, the one place that says so). What a generator writes isn't counted, as no limit reads it.
- **Exceptions:** a type's `// CRF-011 exception: <reason>` comment now covers its member count as well as its cohesion, and on any part of a partial type it covers the whole type. A file's comment now covers its public types as well as its length and top-level statements.

- **Trade-offs:** the gate matches what the owner asked for, and the kit's own code meets it after three small refactors. The tighter numbers will fail some app code that passed before, and test classes are the likeliest: xUnit needs them public, so a test file with two test classes now fails. In an executable project, where CA1515 makes types internal (craft.md), the public type check finds few. Members per type counts by syntax, so an unusual case, such as a member that a source generator declares in a hand-written part, can count differently from the compiler's own view.
- **Reversibility:** easy. Each number is one constant in `Limits.cs` and one phrase in CRF-011's statement, which a Pester test keeps in step; each rule is one class and one line in `ProjectCheck`.
- **Risk:** medium. An app updating the kit may get findings it has to fix or mark as exceptions before its CI passes again. The exception comment keeps a real case possible without hiding it.

### Option 2: Keep ADR-0050's numbers in the gate, and leave the new ceiling to code review until the owner ratifies CRF-011

- **Trade-offs:** no new findings in apps until he decides. But the ceiling he set would rest on the reviewer, which is what CRF-008's reason argues against ("a few limits a tool enforces beat many that people ignore"), and the two new counts would have no check at all.
- **Reversibility:** n/a; option 1 can follow at any time.
- **Risk:** the code drifts past the ceiling in the meantime, and option 1 later has more to fix.

## Recommendation

Option 1. It's what the owner asked for, it costs the kit three small refactors, and CRF-011 stays proposed, so he can still change any number.

## Decision

The owner's numbers from 2026-11-12, applied in auto mode (ADR-0035) overnight for his review. CRF-011 keeps `status: proposed`: he hasn't ratified the rule itself, and this PR is where he confirms the numbers.

## Consequences

- `tools/CodeShape/src/Kit.CodeShape/Limits.cs`: nesting 3, 30 statements per member, 400 lines per file, 20 members per type, one public type per file, LCOM4 of 1. CRF-011's statement in `docs/standards/craft.md` states all six, and `tools/tests/Test-CodeShape.Tests.ps1` now checks the two new ones too.
- New in Kit.CodeShape: `MemberCountRule`, `PublicTypeRule` and `TypeIdentity`, with xUnit tests, and `ProjectCheck` runs both rules. `LimitExemption`'s comments and craft.md's "Exceptions" say what a type's and a file's comment now cover.
- The kit's own code, fixed without exceptions:
  - the sample's contract tests read every operation through one `Operations` helper, which keeps both tests that walk them at 3 levels deep and states the walk once (CRF-003);
  - each Contracts type has its own file (`CreateBookmarkRequest.cs`, `BookmarkResponse.cs`, `BookmarkPage.cs`); the OpenAPI snapshot test passes unchanged;
  - `AddBookmarkResult` and `BookmarkListResult` moved out of `BookmarkService.cs` into files of their own.
- Every app's CI runs the tighter check from its next kit update. Its findings name the rule and the limit, and the exception comment is the escape hatch for a real case.
- craft.md's "What the checks miss" adds the two new counts' gaps: syntax only, and few public types in executable projects.

## Pillars affected

- **Operational excellence:** smaller members, types and files are easier to read, review and change, and a tool keeps them from drifting.
- **Reliability:** defects collect in large, deeply nested code (CRF-008's reason); the ceiling keeps units small enough to test in isolation (CRF-009).
- **Performance efficiency:** the two new counts read syntax only, with no compilation, so the check takes about as long as before.
- **Cost optimization:** none; the check stays the kit's own free tool.
- **Security:** none directly.

## Sources

- owner, 2026-11-12 (the rules audit's CRF-011 row, from the rule-of-ten discussion)
- ADR-0050, the code shape check and how its limits are measured
- CRF-012, the rule of ten (`docs/standards/craft.md`)
