namespace Kit.CodeShape;

/// <summary>The limits CRF-008 sets beyond Microsoft's metric rules (ADR-0050). CRF-008 states the same numbers, and
/// tools/tests/Test-CodeShape.Tests.ps1 fails if the two disagree.</summary>
internal static class Limits
{
    /// <summary>The most control-flow statements a statement may sit inside, within one member.</summary>
    public const int NestingDepth = 4;

    /// <summary>The most statements one member may hold, nested ones included.</summary>
    public const int StatementsPerMember = 100;

    /// <summary>The most lines one source file may have.</summary>
    public const int LinesPerFile = 800;

    /// <summary>The most groups a type's methods may form that share no state (LCOM4).</summary>
    public const int Lcom4 = 1;
}
