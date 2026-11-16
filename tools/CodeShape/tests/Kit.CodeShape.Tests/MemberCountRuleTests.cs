namespace Kit.CodeShape.Tests;

public sealed class MemberCountRuleTests
{
    [Fact]
    public void ATypeWithTwentyOneMembersIsReportedOnceAtItsName() =>
        MemberCountRule.Check([new SourceFile("Wide.cs", $"class Wide {{ {Methods(21)}}}")]).Should().ContainSingle()
            .Which.Should().BeEquivalentTo(new
            {
                Path = "Wide.cs",
                Line = 1,
                Column = 7,
                Message = "Wide has 21 members; the limit is 20 (CRF-011).",
            });

    [Fact]
    public void ATypeWithTwentyMembersIsWithinTheLimit() =>
        MemberCountRule.Check([new SourceFile("AtLimit.cs", $"class AtLimit {{ {Methods(20)}}}")]).Should().BeEmpty();

    // Each field and event a declaration names is a member; so is every other kind a type declares.
    [Theory]
    [InlineData("int _a, _b;", 2)]
    [InlineData("event System.Action A, B;", 2)]
    [InlineData("event System.Action E { add { } remove { } }", 1)]
    [InlineData("int P { get; set; }", 1)]
    [InlineData("int this[int i] => i;", 1)]
    [InlineData("Kinds() { }", 1)]
    [InlineData("static Kinds() { }", 1)]
    [InlineData("~Kinds() { }", 1)]
    [InlineData("public static Kinds operator +(Kinds k, int a) => k;", 1)]
    [InlineData("public static explicit operator int(Kinds k) => 0;", 1)]
    public void EveryKindOfMemberCounts(string member, int members) =>
        MemberCountRule.Check([new SourceFile("Kinds.cs", $"class Kinds {{ {member} {Methods(21 - members)}}}")]).Should().ContainSingle()
            .Which.Message.Should().Be("Kinds has 21 members; the limit is 20 (CRF-011).");

    // A record's positional parameters are properties the compiler declares for it, unless the record declares the
    // property itself; a class's primary constructor parameters aren't members.
    [Theory]
    [InlineData("record Point(int X, int Y) { ", 19, 1)]
    [InlineData("record struct Point(int X, int Y) { ", 19, 1)]
    [InlineData("record Point(int X, int Y) { public int X { get; } = X; ", 18, 0)]
    [InlineData("class Point(int x, int y) { ", 20, 0)]
    public void ARecordsPositionalParametersAreItsProperties(string opening, int methods, int findings) =>
        MemberCountRule.Check([new SourceFile("Point.cs", $"{opening}{Methods(methods)}}}")]).Should().HaveCount(findings);

    // A nested type is a type of its own, measured on its own; it isn't a member of the type that holds it.
    [Fact]
    public void ANestedTypeIsMeasuredOnItsOwn() =>
        MemberCountRule.Check([new SourceFile("Outer.cs", $"class Outer {{ {Methods(20)}class Inner {{ {Methods(21)}}} }}")])
            .Should().ContainSingle().Which.Message.Should().Be("Inner has 21 members; the limit is 20 (CRF-011).");

    // A partial type is one type: its hand-written parts count together, a partial member declared in one and
    // implemented in another counts once, and the type is reported once, at its first part.
    [Fact]
    public void APartialTypesPartsCountTogetherAndItIsReportedOnce() =>
        MemberCountRule.Check([
            new SourceFile("Wide.B.cs", $"namespace App; partial class Wide {{ {Methods(10)}partial void Done() {{ }} }}"),
            new SourceFile("Wide.A.cs", $"namespace App; partial class Wide {{ {Methods(10, from: 10)}partial void Done(); int _a; }}"),
        ]).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Wide.A.cs",
            Line = 1,
            Column = 30,
            Message = "Wide has 22 members; the limit is 20 (CRF-011).",
        });

    // Every kind of partial member counts once, from its declaring and its implementing part; a nested partial type
    // still isn't a member.
    [Theory]
    [InlineData(15, 0)]
    [InlineData(16, 1)]
    public void EveryKindOfPartialMemberCountsOnce(int methods, int findings) =>
        MemberCountRule.Check([
            new SourceFile("Wide.A.cs", $"partial class Wide {{ partial Wide(int a); partial int P {{ get; }} partial int this[int i] {{ get; }} partial event System.Action E; partial void M(); partial class Inner {{ }} {Methods(methods)}}}"),
            new SourceFile("Wide.B.cs", "partial class Wide { partial Wide(int a) { } partial int P => 0; partial int this[int i] => i; partial event System.Action E { add { } remove { } } partial void M() { } partial class Inner { } }"),
        ]).Should().HaveCount(findings);

    // Types in different namespaces, or with a different number of type parameters, are different types.
    [Fact]
    public void TypesWithTheSameNameElsewhereAreNotParts() =>
        MemberCountRule.Check([
            new SourceFile("A.cs", $"namespace A {{ partial class Wide {{ {Methods(11)}}} }} namespace B {{ partial class Wide {{ {Methods(10)}}} }}"),
            new SourceFile("C.cs", $"namespace A {{ partial class Wide<T> {{ {Methods(10)}}} }}"),
        ]).Should().BeEmpty();

    // A file-local type is seen only in its own file, so two with the same name in two files are two types.
    [Fact]
    public void FileLocalTypesWithTheSameNameAreDifferentTypes() =>
        MemberCountRule.Check([
            new SourceFile("A.cs", $"file class Helper {{ {Methods(11)}}}"),
            new SourceFile("B.cs", $"file class Helper {{ {Methods(11)}}}"),
        ]).Should().BeEmpty();

    // What a generator writes isn't counted: a reader doesn't maintain it, as the other limits don't read it either.
    [Fact]
    public void AGeneratedPartIsNotCounted() =>
        MemberCountRule.Check([
            new SourceFile("Wide.cs", $"partial class Wide {{ {Methods(20)}}}"),
            new SourceFile("Wide.g.cs", $"partial class Wide {{ {Methods(5, from: 20)}}} class Made {{ {Methods(21)}}}") { Generated = true },
        ]).Should().BeEmpty();

    private static string Methods(int count, int from = 0) =>
        string.Concat(Enumerable.Range(from, count).Select(i => $"void M{i}() {{ }} "));
}
