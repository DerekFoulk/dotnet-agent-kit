namespace Kit.CodeShape.Tests;

public sealed class NestingRuleTests
{
    [Fact]
    public void AMemberNestedFiveLevelsDeepIsReportedAtItsDeepestStatement()
    {
        SourceFile file = new("Deep.cs", """
            class Deep
            {
                void Run(int a)
                {
                    if (a > 0)
                    {
                        if (a > 1)
                        {
                            if (a > 2)
                            {
                                if (a > 3)
                                {
                                    if (a > 4)
                                    {
                                        a++;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            """);

        IEnumerable<Finding> findings = NestingRule.Check(file);

        findings.Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Deep.cs",
            Line = 15,
            Column = 29,
            Message = "Run nests 5 levels deep; the limit is 4 (CRF-011).",
        });
    }

    [Fact]
    public void AMemberNestedFourLevelsDeepIsWithinTheLimit()
    {
        SourceFile file = new("AtLimit.cs", """
            class AtLimit
            {
                void Run(int a)
                {
                    if (a > 0)
                    {
                        if (a > 1)
                        {
                            if (a > 2)
                            {
                                if (a > 3)
                                {
                                    a++;
                                }
                            }
                        }
                    }
                }
            }
            """);

        NestingRule.Check(file).Should().BeEmpty();
    }

    // Four ifs deep around a statement; whatever wraps it decides whether it's over the limit.
    private const string FourIfs = "if (a > 1) { if (a > 2) { if (a > 3) { if (a > 4) { a++; } } } }";

    [Theory]
    [InlineData("switch (a) { case 0: ", " break; }")]
    [InlineData("for (;;) { ", " }")]
    [InlineData("foreach (int x in new int[0]) { ", " }")]
    [InlineData("foreach (var (x, y) in new (int, int)[0]) { ", " }")]
    [InlineData("while (a > 0) { ", " }")]
    [InlineData("do { ", " } while (a > 0);")]
    [InlineData("try { ", " } finally { }")]
    [InlineData("try { } catch { ", " }")]
    [InlineData("if (a > 0) { } else { ", " }")]
    [InlineData("if (a > 0) { System.Action f = () => { ", " }; }")]
    [InlineData("if (a > 0) { void Local() { ", " } Local(); }")]
    public void EachControlFlowStatementAddsALevelAndLambdasKeepCounting(string before, string after)
    {
        NestingRule.Check(FourIfsIn(before, after)).Should().ContainSingle()
            .Which.Message.Should().Be("Run nests 5 levels deep; the limit is 4 (CRF-011).");
    }

    [Theory]
    [InlineData("{ ", " }")]
    [InlineData("using (System.IDisposable d = null!) { ", " }")]
    [InlineData("lock (this) { ", " }")]
    [InlineData("checked { ", " }")]
    [InlineData("System.Action f = () => { ", " };")]
    public void BlocksUsingLockCheckedAndLambdasAddNoLevel(string before, string after) =>
        NestingRule.Check(FourIfsIn(before, after)).Should().BeEmpty();

    [Fact]
    public void AnElseIfContinuesItsChainWithoutALevel()
    {
        SourceFile file = new("Chain.cs", """
            class Chain
            {
                void Run(int a)
                {
                    if (a > 9) { } else if (a > 8) { } else if (a > 7) { if (a > 2) { if (a > 3) { if (a > 4) { a++; } } } }
                }
            }
            """);

        NestingRule.Check(file).Should().BeEmpty();
    }

    [Theory]
    [InlineData("Kinds(int a) { FIVE }", "Kinds")]
    [InlineData("~Kinds() { int a = 0; FIVE }", "~Kinds")]
    [InlineData("public static Kinds operator +(Kinds k, int a) { FIVE return k; }", "operator +")]
    [InlineData("public static explicit operator int(Kinds k) { int a = 0; FIVE return a; }", "explicit operator int")]
    [InlineData("int P { get { int a = 0; FIVE return a; } }", "P.get")]
    [InlineData("int this[int a] { set { FIVE } }", "this[].set")]
    [InlineData("event System.Action E { add { int a = 0; FIVE } remove { } }", "E.add")]
    [InlineData("System.Action P => () => { int a = 0; FIVE };", "P")]
    [InlineData("System.Action this[int a] => () => { FIVE };", "this[]")]
    public void EveryMemberWithABodyIsMeasuredAndNamed(string member, string name)
    {
        SourceFile file = new("Kinds.cs", $$"""
            class Kinds
            {
                {{member}}
            }
            """.Replace("FIVE", $"if (a > 0) {{ {FourIfs} }}", StringComparison.Ordinal));

        NestingRule.Check(file).Should().ContainSingle()
            .Which.Message.Should().Be($"{name} nests 5 levels deep; the limit is 4 (CRF-011).");
    }

    [Fact]
    public void TopLevelStatementsAreMeasuredAsOneMember()
    {
        SourceFile file = new("Program.cs", $"int a = 0; if (a > 0) {{ {FourIfs} }}");

        NestingRule.Check(file).Should().ContainSingle()
            .Which.Message.Should().Be("top-level statements nests 5 levels deep; the limit is 4 (CRF-011).");
    }

    // A method whose body is four nested ifs, with the given text before and after them.
    private static SourceFile FourIfsIn(string before, string after) => new("Wrapped.cs", $$"""
        class Wrapped
        {
            void Run(int a)
            {
                {{before}}{{FourIfs}}{{after}}
            }
        }
        """);
}
