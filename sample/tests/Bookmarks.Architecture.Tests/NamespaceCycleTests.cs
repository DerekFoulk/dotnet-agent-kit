using ArchUnitNET.Fluent;
using ArchUnitNET.Fluent.Slices;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnitV3;

namespace Bookmarks.Architecture.Tests;

/// <summary>No two namespaces depend on each other, directly or through others (CRF-007, acyclic dependencies).</summary>
public sealed class NamespaceCycleTests
{
    private const string FixtureRoot = "Bookmarks.Architecture.Tests.CycleFixture";

    [Fact]
    public void TheSamplesNamespacesFormNoCycle() =>
        NamespaceCycles.Rule("Bookmarks").Check(SampleArchitecture.Value);

    [Fact]
    public void TheRuleCatchesACycleBetweenTwoNamespaces()
    {
        ArchUnitNET.Domain.Architecture fixture = new ArchLoader().LoadAssemblies(typeof(NamespaceCycleTests).Assembly).Build();

        NamespaceCycles.Rule(FixtureRoot).HasNoViolations(fixture).Should().BeFalse("Left and Right depend on each other");
    }

    [Fact]
    public void TheRuleFailsWhenNoNamespaceSitsUnderTheRoot()
    {
        // A mistyped root would otherwise check nothing and pass.
        NamespaceCycles.Rule("Bookmarks.NoSuchNamespace").HasNoViolations(SampleArchitecture.Value)
            .Should().BeFalse("no slice means nothing was checked");
    }
}

/// <summary>The rule that namespaces under a root form no cycle.</summary>
internal static class NamespaceCycles
{
    // Each namespace under the root is a slice ((**) takes the rest of the name), so a cycle between any two fails.
    public static IArchRule Rule(string rootNamespace) =>
        SliceRuleDefinition.Slices().Matching(rootNamespace + ".(**)").Should().BeFreeOfCycles();
}
