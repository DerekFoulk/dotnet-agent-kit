namespace Kit.CodeShape.Tests;

public sealed class StatementRuleTests
{
    [Fact]
    public void AMemberWithThirtyOneStatementsIsReportedAtItsName()
    {
        SourceFile file = Method("Long.cs", Statements(31));

        StatementRule.Check(file).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Long.cs",
            Line = 3,
            Column = 10,
            Message = "Run has 31 statements; the limit is 30 (CRF-011).",
        });
    }

    [Fact]
    public void TopLevelStatementsAreCountedAsOneMember() =>
        StatementRule.Check(new SourceFile("Program.cs", "int a = 0; " + Statements(30))).Should().ContainSingle()
            .Which.Message.Should().Be("top-level statements has 31 statements; the limit is 30 (CRF-011).");

    [Fact]
    public void AMemberWithThirtyStatementsIsWithinTheLimit() =>
        StatementRule.Check(Method("AtLimit.cs", Statements(30))).Should().BeEmpty();

    [Fact]
    public void BlocksAreNotStatementsButWhatTheyHoldIs() =>
        StatementRule.Check(Method("Blocks.cs", $"{{ {{ {Statements(30)} }} }}")).Should().BeEmpty();

    [Fact]
    public void StatementsInLambdasAndLocalFunctionsCountForTheirMember()
    {
        string body = $"System.Action f = () => {{ {Statements(14)} }}; void Local() {{ {Statements(14)} }} Local();";

        // 14 + 14, plus the declaration of f, the local function itself and its call: 31.
        StatementRule.Check(Method("Nested.cs", body)).Should().ContainSingle()
            .Which.Message.Should().Be("Run has 31 statements; the limit is 30 (CRF-011).");
    }

    private static string Statements(int count) => string.Concat(Enumerable.Repeat("a++; ", count));

    private static SourceFile Method(string path, string body) => new(path, $$"""
        class Long
        {
            void Run(int a)
            {
                {{body}}
            }
        }
        """);
}
