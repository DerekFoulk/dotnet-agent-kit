namespace Kit.CodeShape.Tests;

// The nullable migration page's end state: nullable is on in the project and no file changes it (STY-005).
public sealed class NullableDirectiveRuleTests
{
    [Theory]
    [InlineData("#nullable disable")]
    [InlineData("#nullable enable")]
    [InlineData("#nullable restore warnings")]
    public void ADirectiveIsReportedAtItsLine(string directive) =>
        NullableDirectiveRule.Check(new SourceFile("Legacy.cs", $"class Legacy {{ }}\n{directive}\nclass Other {{ }}\n"))
            .Should().ContainSingle().Which.Should().BeEquivalentTo(new
            {
                Path = "Legacy.cs",
                Line = 2,
                Column = 1,
                Message = "#nullable changes the nullable context the project sets; nullable stays on in every file (STY-005).",
            });

    // Review 1: EF Core writes #nullable disable into every migration it generates, marking only the designer
    // file and the snapshot as generated (CSharpMigrationsGenerator), so the migration itself must be allowed it.
    [Fact]
    public void AnEfCoreMigrationMayDisableNullable() =>
        NullableDirectiveRule.Check(new SourceFile(
            Path.Join("src", "App", "Migrations", "20261116000000_Initial.cs"),
            "using Microsoft.EntityFrameworkCore.Migrations;\n\n#nullable disable\n\nnamespace App.Migrations\n{\n    public partial class Initial : Migration\n    {\n    }\n}\n"))
            .Should().BeEmpty();

    [Fact]
    public void AHandWrittenFileInMigrationsMayNotDisableNullable() =>
        NullableDirectiveRule.Check(new SourceFile(Path.Join("src", "App", "Migrations", "Seeding.cs"), "#nullable disable\nclass Seeding { }\n"))
            .Should().ContainSingle();

    [Fact]
    public void AFileWithNoDirectiveHasNoFinding() =>
        NullableDirectiveRule.Check(new SourceFile("Tidy.cs", "// #nullable disable, in a comment\nclass Tidy { }\n")).Should().BeEmpty();
}
