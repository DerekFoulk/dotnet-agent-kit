using Microsoft.CodeAnalysis;

namespace Kit.CodeShape.Tests;

// Every entry point says which argument it was missing, rather than failing later with a NullReferenceException.
// Each entry passes null where the type says it can't be, on purpose, so each null! carries its CRF-001 label (STY-005).
public sealed class ArgumentTests
{
    public static TheoryData<string, Action> EntryPoints => new()
    {
        { "Cli.Run args", () => Cli.Run(null!, TextWriter.Null) }, // CRF-001 safety net: null on purpose, to test the guard.
        { "Cli.Run output", () => Cli.Run([], null!) }, // CRF-001 safety net: null on purpose, to test the guard.
        { "CohesionRule.Check", () => _ = CohesionRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "FileLengthRule.Check", () => _ = FileLengthRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "Finding.At", () => Finding.At("A.cs", null!, "message") }, // CRF-001 safety net: null on purpose, to test the guard.
        { "GeneratedCode.Is", () => GeneratedCode.Is(null!) }, // CRF-001 safety net: null on purpose, to test the guard.
        { "LimitExemption.Covers", () => LimitExemption.Covers(null!) }, // CRF-001 safety net: null on purpose, to test the guard.
        { "LimitExemption.CoversFile", () => LimitExemption.CoversFile(null!) }, // CRF-001 safety net: null on purpose, to test the guard.
        { "Member.Of", () => _ = Member.Of(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "NestingRule.Check", () => _ = NestingRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "ProjectCheck.Check", () => _ = ProjectCheck.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "ProjectCheck.HandWritten", () => _ = ProjectCheck.HandWritten(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "StatementRule.Check", () => _ = StatementRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "NullableDirectiveRule.Check", () => _ = NullableDirectiveRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "NullForgivingRule.Check", () => _ = NullForgivingRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
        { "GeneratedMarkerRule.Check", () => _ = GeneratedMarkerRule.Check(null!).ToList() }, // CRF-001 safety net: null on purpose, to test the guard.
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
