namespace Kit.CodeShape.Tests;

public sealed class PublicTypeRuleTests
{
    // Every kind of type counts: class, struct, interface, record, enum and delegate.
    [Fact]
    public void ASecondPublicTypeIsReportedAtItsName() =>
        PublicTypeRule.Check(new SourceFile("Many.cs", """
            namespace App;

            public class First { }

            public record Second(int A);

            public struct Third { }
            public interface IFourth { }
            public enum Fifth { A }
            public delegate void Sixth();
            """)).Should().ContainSingle().Which.Should().BeEquivalentTo(new
        {
            Path = "Many.cs",
            Line = 5,
            Column = 15,
            Message = "The file declares 6 public types (First, Second, Third, IFourth, Fifth, Sixth); the limit is 1 (CRF-011).",
        });

    // Only a public top-level type counts: a nested one belongs to the type that holds it.
    [Fact]
    public void OnePublicTypeBesideNestedAndNonPublicOnesIsWithinTheLimit() =>
        PublicTypeRule.Check(new SourceFile("One.cs", """
            namespace App;

            public class Only { public class Nested { } public enum Kind { A } }
            internal class Helper { }
            file class Local { }
            delegate void Handler();
            """)).Should().BeEmpty();

    // Two parts of one partial type are one type; the same name in another namespace, or with type parameters, isn't.
    [Theory]
    [InlineData("public partial class A { } public partial class A { }", 0)]
    [InlineData("namespace N { public partial class A { } } namespace N { public partial class A { } }", 0)]
    [InlineData("namespace N { public class A { } } namespace M { public class A { } }", 1)]
    [InlineData("public class Box { } public class Box<T> { }", 1)]
    public void APartialTypesPartsInOneFileAreOneType(string text, int findings) =>
        PublicTypeRule.Check(new SourceFile("Parts.cs", text)).Should().HaveCount(findings);

    // A file's top-level statements aren't types.
    [Fact]
    public void TopLevelStatementsBesideOnePublicTypeAreWithinTheLimit() =>
        PublicTypeRule.Check(new SourceFile("Program.cs", "System.Console.WriteLine(); public class Only { }")).Should().BeEmpty();
}
