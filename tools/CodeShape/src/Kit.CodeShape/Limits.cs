namespace Kit.CodeShape;

/// <summary>The limits CRF-011 sets beyond Microsoft's metric rules (ADR-0050; the owner's numbers of 2026-11-12,
/// ADR-0071). CRF-011 states the same numbers, and tools/tests/Test-CodeShape.Tests.ps1 fails if the two
/// disagree.</summary>
internal static class Limits
{
    /// <summary>The most control-flow statements a statement may sit inside, within one member.</summary>
    public const int NestingDepth = 3;

    /// <summary>The most statements one member may hold, nested ones included.</summary>
    public const int StatementsPerMember = 30;

    /// <summary>The most lines one source file may have.</summary>
    public const int LinesPerFile = 400;

    /// <summary>The most groups a type's methods may form that share no state (LCOM4).</summary>
    public const int Lcom4 = 1;

    /// <summary>The most members one type may declare, counting every part of a partial type.</summary>
    public const int MembersPerType = 20;

    /// <summary>The most public top-level types one source file may declare.</summary>
    public const int PublicTypesPerFile = 1;
}
