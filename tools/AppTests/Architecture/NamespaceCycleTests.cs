using System.Text.RegularExpressions;
using ArchUnitNET.Fluent;
using ArchUnitNET.Fluent.Slices;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnitV3;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Kit.AppTests.Architecture;

/// <summary>No two namespaces depend on each other, directly or through others (CRF-007, acyclic dependencies).</summary>
public sealed class NamespaceCycleTests
{
    private static readonly ArchUnitNET.Domain.Architecture s_fixtures =
        new ArchLoader().LoadAssemblies(typeof(NamespaceCycleTests).Assembly).Build();

    /// <summary>
    /// Gets each root namespace the app's assemblies share, taken from their names without the layer: Contoso.Orders
    /// for Contoso.Orders.Domain. Each project's root namespace is its name unless it sets another.
    /// </summary>
    public static TheoryData<string> Roots =>
        [.. AppLayers.All.Select(assembly => assembly.GetName().Name!)
            .Select(name => name.Contains('.', StringComparison.Ordinal) ? name[..name.LastIndexOf('.')] : name)
            .Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal)];

    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(Roots))]
    public void TheAppsNamespacesFormNoCycle(string root) =>
        NamespaceCycles.Rule(root).Check(AppLayers.Architecture);

    [Fact]
    public void TheRuleCatchesACycleBetweenTwoNamespaces() =>
        NamespaceCycles.CycleRule("Kit.AppTests.Architecture.CycleFixture").HasNoViolations(s_fixtures)
            .Should().BeFalse("Left and Right depend on each other");

    [Fact]
    public void TheRuleCatchesACycleThroughATypeInTheRootNamespace() =>
        NamespaceCycles.CycleRule("Kit.AppTests.Architecture.RootTypeCycle").HasNoViolations(s_fixtures)
            .Should().BeFalse("RootEnd, in the root namespace itself, and ChildEnd depend on each other");

    [Fact]
    public void TheRuleAcceptsARootWhoseOnlyTypesSitInTheRootItself() =>
        NamespaceCycles.Rule("Kit.AppTests.Architecture.RootOnly").HasNoViolations(s_fixtures)
            .Should().BeTrue("the root's own types are checked, so the guard counts them");

    // A mistyped root would otherwise check nothing and pass.
    [Fact]
    public void TheRuleFailsWhenNoNamespaceSitsUnderTheRoot() =>
        NamespaceCycles.Rule("Kit.AppTests.NoSuchNamespace").HasNoViolations(s_fixtures)
            .Should().BeFalse("no slice means nothing was checked");
}

/// <summary>The rule that namespaces under a root form no cycle.</summary>
internal static class NamespaceCycles
{
    /// <summary>The cycle rule, guarded so that a root with nothing under it fails instead of checking nothing.</summary>
    public static IArchRule Rule(string rootNamespace) =>
        CycleRule(rootNamespace)
            .And(Types().That().ResideInNamespaceMatching($@"^{Regex.Escape(rootNamespace)}(\.|$)").Should().Exist());

    /// <summary>
    /// The root namespace and every namespace under it are slices, so a cycle between any two fails. The pattern has
    /// no dot before (**), so the root's own types form a slice too; it also takes in namespaces whose names merely
    /// start with the root's (RootX beside Root), and any cycle it finds there is still a real one. ArchUnitNET passes
    /// a slice rule that matches nothing, which is why <see cref="Rule"/> adds a guard.
    /// </summary>
    public static IArchRule CycleRule(string rootNamespace) =>
        SliceRuleDefinition.Slices().Matching(rootNamespace + "(**)").Should().BeFreeOfCycles();
}
