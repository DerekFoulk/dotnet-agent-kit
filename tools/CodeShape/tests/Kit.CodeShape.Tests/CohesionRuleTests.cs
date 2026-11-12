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

    // A property's accessor is a method too: methods that use the property share the state it reads.
    [Fact]
    public void APropertyJoinsTheMethodsThatUseItToTheStateItReads() => CohesionRule.Check([new SourceFile("Api.cs", """
        class Api
        {
            private readonly Host _host = new();

            private Client Client => _host.Client;

            void Get() => Client.Send();
            void Dispose() => _host.Dispose();
        }
        """)]).Should().BeEmpty();

    // A field the constructor builds from another depends on it, so methods using either share state.
    [Fact]
    public void AFieldTheConstructorBuildsFromAnotherJoinsThem() => CohesionRule.Check([new SourceFile("Tests.cs", """
        class Tests
        {
            private readonly Connection _connection = new();
            private readonly Options _options;

            Tests()
            {
                _options = new Options(_connection);
            }

            void Find() => Use(_options);
            void Dispose() => _connection.Dispose();
            static void Use(Options options) { }
        }
        """)]).Should().BeEmpty();

    // Fields a constructor only fills from its parameters stay apart: the constructor touches every field, so
    // counting it as a method would make every class look cohesive.
    [Fact]
    public void FieldsTheConstructorFillsFromParametersStayApart() => CohesionRule.Check([new SourceFile("Service.cs", """
        class Service
        {
            private readonly int _a;
            private readonly int _b;

            Service(int a, int b)
            {
                _a = a;
                _b = b;
            }

            int A() => _a;
            int B() => _b;
        }
        """)]).Should().ContainSingle().Which.Message.Should().Contain("[A], [B]");

    // Review 1 of GAP-019: a local function belongs to its method, not to the type's state.
    [Fact]
    public void AMethodThatCallsOnlyItsOwnLocalFunctionUsesNoState() => CohesionRule.Check([new SourceFile("L.cs", """
        class L
        {
            private int _x;

            void B() => _x++;
            int C() => _x;
            int A(int n)
            {
                int Twice() => n * 2;
                return Twice();
            }
        }
        """)]).Should().BeEmpty();

    // A primary constructor's parameters are the type's state, as the compiler keeps them for its methods.
    [Fact]
    public void PrimaryConstructorParametersAreState() => CohesionRule.Check([new SourceFile("Svc.cs", """
        class Svc(Repo repo, Log log)
        {
            void Get() => repo.Get();
            void Write() => log.Write();
        }
        """)]).Should().ContainSingle().Which.Message.Should().Contain("[Get], [Write]");

    [Fact]
    public void MethodsSharingAPrimaryConstructorParameterFormOneGroup() => CohesionRule.Check([new SourceFile("Svc.cs", """
        class Svc(Repo repo)
        {
            private int _a;
            private int _b;

            void A() { repo.Get(); _a++; }
            void B() { repo.Save(); _b++; }
        }
        """)]).Should().BeEmpty();

    [Fact]
    public void AFieldInitializedFromAPrimaryConstructorParameterSharesItsState() => CohesionRule.Check([new SourceFile("Svc.cs", """
        class Svc(Connection connection)
        {
            private readonly Options _options = new(connection);

            void Find() => Use(_options);
            void Dispose() => connection.Dispose();
            static void Use(Options options) { }
        }
        """)]).Should().BeEmpty();

    // A property's accessors are methods, as LCOM4 counts them.
    [Fact]
    public void APropertyThatReadsStateIsAMethodOfItsOwn() => CohesionRule.Check([new SourceFile("Prop.cs", """
        class Prop
        {
            private int _a;
            private int _b;

            int A => _a;
            void M() => _b++;
        }
        """)]).Should().ContainSingle().Which.Message.Should().Contain("[A], [M]");

    // A generated half of a partial type declares state the hand-written half uses; it's read, though never reported.
    [Fact]
    public void AGeneratedHalfIsReadForItsStateButNeverReported() => CohesionRule.Check([
        new SourceFile("Form.cs", "partial class Form { private int _a; private int _b; void A() { _a++; _shared++; } void B() { _b++; _shared++; } }"),
        new SourceFile("Form.g.cs", "partial class Form { private int _shared; }") { Generated = true },
        new SourceFile("Other.g.cs", "class Other { int _a; int _b; void A() => _a++; void B() => _b++; }") { Generated = true },
    ]).Should().BeEmpty();

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
