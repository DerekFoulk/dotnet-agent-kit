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
    public void APartialTypeIsMeasuredWholeAndReportedOnce() => CohesionRule.Check([
        new SourceFile("Ledger.cs", "partial class Ledger { private int _total; void Add(int amount) => _total += amount; }"),
        new SourceFile("Ledger.Title.cs", "partial class Ledger { private string _title = \"\"; void Rename(string t) => _title = t; }"),
    ]).Should().ContainSingle().Which.Message.Should().Contain("[Add], [Rename]");

    [Fact]
    public void ACallTheCompilerCantResolveStillJoinsTheMethodsItCouldMean() => CohesionRule.Check([new SourceFile("Store.cs", """
        class Store
        {
            private int _count;
            private int _imported;

            void Save(Order order) => _count++;
            void Save(Invoice invoice) => _count++;
            void Import(Unknown item)
            {
                _imported++;
                Save(item);
            }
        }
        """)]).Should().BeEmpty();

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
