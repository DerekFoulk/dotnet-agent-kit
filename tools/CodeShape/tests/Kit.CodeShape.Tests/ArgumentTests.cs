using Microsoft.CodeAnalysis;

namespace Kit.CodeShape.Tests;

// Every entry point says which argument it was missing, rather than failing later with a NullReferenceException.
public sealed class ArgumentTests
{
    public static TheoryData<string, Action> EntryPoints => new()
    {
        { "Cli.Run args", () => Cli.Run(null!, TextWriter.Null) },
        { "Cli.Run output", () => Cli.Run([], null!) },
        { "CohesionRule.Check", () => _ = CohesionRule.Check(null!).ToList() },
        { "FileLengthRule.Check", () => _ = FileLengthRule.Check(null!).ToList() },
        { "Finding.At", () => Finding.At("A.cs", null!, "message") },
        { "GeneratedCode.Is", () => GeneratedCode.Is(null!) },
        { "LimitException.Covers", () => LimitException.Covers(null!) },
        { "LimitException.CoversFile", () => LimitException.CoversFile(null!) },
        { "Member.Of", () => _ = Member.Of(null!).ToList() },
        { "NestingRule.Check", () => _ = NestingRule.Check(null!).ToList() },
        { "ProjectCheck.Check", () => _ = ProjectCheck.Check(null!).ToList() },
        { "StatementRule.Check", () => _ = StatementRule.Check(null!).ToList() },
    };

    [Theory]
    [MemberData(nameof(EntryPoints))]
    public void EachEntryPointRejectsAMissingArgument(string entryPoint, Action call)
    {
        _ = entryPoint;
        call.Should().Throw<ArgumentNullException>();
    }

    [Fact]
    public void AFindingTakesItsPlaceFromALocation() =>
        Finding.At("A.cs", Location.None, "message").Should().BeEquivalentTo(new { Path = "A.cs", Line = 1, Column = 1 });
}
