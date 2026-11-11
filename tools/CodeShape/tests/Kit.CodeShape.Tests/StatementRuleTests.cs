namespace Kit.CodeShape.Tests;

public sealed class StatementRuleTests
{
    [Fact]
    public void AMemberWithOneHundredAndOneStatementsIsReportedAtItsName()
    {
        SourceFile file = Method("Long.cs", Statements(101));

        StatementRule.Check(file).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Long.cs",
            Line = 3,
            Column = 10,
            Message = "Run has 101 statements; the limit is 100 (CRF-008).",
        });
    }

    [Fact]
    public void AMemberWithOneHundredStatementsIsWithinTheLimit() =>
        StatementRule.Check(Method("AtLimit.cs", Statements(100))).Should().BeEmpty();

    [Fact]
    public void BlocksAreNotStatementsButWhatTheyHoldIs() =>
        StatementRule.Check(Method("Blocks.cs", $"{{ {{ {Statements(100)} }} }}")).Should().BeEmpty();

    [Fact]
    public void StatementsInLambdasAndLocalFunctionsCountForTheirMember()
    {
        string body = $"System.Action f = () => {{ {Statements(49)} }}; void Local() {{ {Statements(49)} }} Local();";

        // 49 + 49, plus the declaration of f, the local function itself and its call: 101.
        StatementRule.Check(Method("Nested.cs", body)).Should().ContainSingle()
            .Which.Message.Should().Be("Run has 101 statements; the limit is 100 (CRF-008).");
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
