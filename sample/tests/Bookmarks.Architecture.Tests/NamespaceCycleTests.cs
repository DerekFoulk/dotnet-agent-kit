using System.Text.RegularExpressions;
using ArchUnitNET.Fluent;
using ArchUnitNET.Fluent.Slices;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnitV3;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Bookmarks.Architecture.Tests;

/// <summary>No two namespaces depend on each other, directly or through others (CRF-007, acyclic dependencies).</summary>
public sealed class NamespaceCycleTests
{
    private static readonly ArchUnitNET.Domain.Architecture s_fixtures =
        new ArchLoader().LoadAssemblies(typeof(NamespaceCycleTests).Assembly).Build();

    [Fact]
    public void TheSamplesNamespacesFormNoCycle() =>
        NamespaceCycles.Rule("Bookmarks").Check(SampleArchitecture.Value);

    [Fact]
    public void TheRuleCatchesACycleBetweenTwoNamespaces() =>
        NamespaceCycles.CycleRule("Bookmarks.Architecture.Tests.CycleFixture").HasNoViolations(s_fixtures)
            .Should().BeFalse("Left and Right depend on each other");

    [Fact]
    public void TheRuleCatchesACycleThroughATypeInTheRootNamespace() =>
        NamespaceCycles.CycleRule("Bookmarks.Architecture.Tests.RootTypeCycle").HasNoViolations(s_fixtures)
            .Should().BeFalse("RootEnd, in the root namespace itself, and ChildEnd depend on each other");

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
    /// <summary>The cycle rule, guarded so that a root with nothing under it fails instead of checking nothing.</summary>
    public static IArchRule Rule(string rootNamespace) =>
        CycleRule(rootNamespace)
            .And(Types().That().ResideInNamespaceMatching($@"^{Regex.Escape(rootNamespace)}\.").Should().Exist());

    /// <summary>
    /// Each namespace under the root is a slice ((**) takes the rest of the name), so a cycle between any two fails.
    /// ArchUnitNET passes a slice rule that matches nothing, which is why <see cref="Rule"/> adds a guard.
    /// </summary>
    public static IArchRule CycleRule(string rootNamespace) =>
        SliceRuleDefinition.Slices().Matching(rootNamespace + ".(**)").Should().BeFreeOfCycles();
}
