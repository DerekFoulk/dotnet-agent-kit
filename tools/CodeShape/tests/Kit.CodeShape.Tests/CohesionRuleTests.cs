namespace Kit.CodeShape.Tests;

public sealed class CohesionRuleTests
{
    [Fact]
    public void ATypeWhoseMethodsFormTwoGroupsThatShareNoStateIsReportedAtItsName()
    {
        SourceFile file = new("Ledger.cs", """
            class Ledger
            {
                private int _total;
                private string _title = "";

                void Add(int amount) => _total += amount;
                int Total() => _total;
                void Rename(string title) => _title = title;
            }
            """);

        CohesionRule.Check([file]).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Ledger.cs",
            Line = 1,
            Column = 7,
            Message = "Ledger's methods form 2 groups that share no state (LCOM4 2; the limit is 1): [Add, Total], [Rename] (CRF-008).",
        });
    }

    [Fact]
    public void MethodsThatShareAFieldFormOneGroup() => CohesionRule.Check([new SourceFile("Counter.cs", """
        class Counter
        {
            private int _count;

            void Increment() => _count++;
            int Count() => _count;
        }
        """)]).Should().BeEmpty();
}
