using ArchUnitNET.Fluent;
using ArchUnitNET.Loader;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Bookmarks.Architecture.Tests;

/// <summary>No two namespaces depend on each other, directly or through others (CRF-007, acyclic dependencies).</summary>
public sealed class NamespaceCycleTests
{
    private const string FixtureRoot = "Bookmarks.Architecture.Tests.CycleFixture";

    [Fact]
    public void TheRuleCatchesACycleBetweenTwoNamespaces()
    {
        ArchUnitNET.Domain.Architecture fixture = new ArchLoader().LoadAssemblies(typeof(NamespaceCycleTests).Assembly).Build();

        NamespaceCycles.Rule(FixtureRoot).HasNoViolations(fixture).Should().BeFalse("Left and Right depend on each other");
    }
}

/// <summary>The rule that namespaces under a root form no cycle.</summary>
internal static class NamespaceCycles
{
    // Red: a stand-in that every architecture passes, until the real rule replaces it.
    public static IArchRule Rule(string rootNamespace) => Types().That().DoNotHaveFullName(rootNamespace).Should().Exist();
}
