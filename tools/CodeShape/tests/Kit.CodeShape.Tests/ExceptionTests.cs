namespace Kit.CodeShape.Tests;

// A "// CRF-011 exception: <reason>" comment right before a member, a type or a file's first line exempts it from
// the limits, as [SuppressMessage] with a Justification does for an analyzer rule (craft.md, "Exceptions").
public sealed class ExceptionTests
{
    private const string FiveIfs =
        "if (a > 0) { if (a > 1) { if (a > 2) { if (a > 3) { if (a > 4) { a++; } } } } }";

    [Fact]
    public void AMemberWithAReasonedExceptionMayNestDeeper() => NestingRule.Check(new SourceFile("Deep.cs", $$"""
        class Deep
        {
            // CRF-011 exception: a parser's state machine reads better in one place.
            void Run(int a) { {{FiveIfs}} }
        }
        """)).Should().BeEmpty();

    [Fact]
    public void AnExceptionWithoutAReasonExemptsNothing() => NestingRule.Check(new SourceFile("Deep.cs", $$"""
        class Deep
        {
            // CRF-011 exception:
            void Run(int a) { {{FiveIfs}} }
        }
        """)).Should().ContainSingle();

    [Fact]
    public void AnExceptionBeforeAnAttributedMemberStillCounts() => StatementRule.Check(new SourceFile("Long.cs", $$"""
        class Long
        {
            // CRF-011 exception: a generated-style table kept by hand.
            [System.Obsolete]
            void Run(int a) { {{string.Concat(Enumerable.Repeat("a++; ", 101))}} }
        }
        """)).Should().BeEmpty();

    [Fact]
    public void AnExceptionAtTheTopOfAFileExemptsItsLength() => FileLengthRule.Check(new SourceFile(
        "Long.cs",
        "// CRF-011 exception: one table of every country code.\n\n" + string.Join('\n', Enumerable.Repeat("// a line", 800))))
        .Should().BeEmpty();

    // Review 1 of GAP-019: what each placement covers. A file's marker stands apart, a blank line below it; a
    // member's or type's sits right before it; a property's covers its accessors.
    [Fact]
    public void ATypesExceptionAtTheTopOfAFileDoesNotExemptTheFile() => FileLengthRule.Check(new SourceFile(
        "Long.cs",
        "// CRF-011 exception: a facade over two stores.\nclass Ledger { }\n" + string.Join('\n', Enumerable.Repeat("// a line", 800))))
        .Should().ContainSingle();

    [Fact]
    public void AnExceptionSetApartByABlankLineExemptsNothing() => NestingRule.Check(new SourceFile("Deep.cs", $$"""
        class Deep
        {
            // CRF-011 exception: left behind when the member it was for moved.

            void Run(int a) { {{FiveIfs}} }
        }
        """)).Should().ContainSingle();

    [Fact]
    public void AnExceptionBeforeAPropertyCoversItsAccessors() => NestingRule.Check(new SourceFile("Deep.cs", $$"""
        class Deep
        {
            // CRF-011 exception: a parser's state machine reads better in one place.
            int P { get { int a = 0; {{FiveIfs}} return a; } }
        }
        """)).Should().BeEmpty();

    [Fact]
    public void AnExceptionBeforeATypeExemptsItsCohesion() => CohesionRule.Check([new SourceFile("Ledger.cs", """
        // CRF-011 exception: a facade over two stores that callers use together.
        class Ledger
        {
            private int _total;
            private string _title = "";

            void Add(int amount) => _total += amount;
            void Rename(string title) => _title = title;
        }
        """)]).Should().BeEmpty();
}
