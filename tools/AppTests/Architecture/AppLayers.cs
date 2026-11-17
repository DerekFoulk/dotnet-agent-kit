using System.Reflection;
using ArchUnitNET.Fluent.Syntax.Elements.Types;
using ArchUnitNET.Loader;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Kit.AppTests.Architecture;

/// <summary>
/// The app's assemblies, layer by layer (ARC-001), which the kit's architecture tests check. This part is the kit's
/// (tools/AppTests in the kit, .kit/tools/AppTests in an app). The app's Architecture.Tests project declares its
/// assemblies in its own part, each property listing that layer's assemblies, or none, so the project doesn't build
/// until it says what its layers are.
/// </summary>
internal static partial class AppLayers
{
    /// <summary>Gets the domain assemblies: business rules, which know nothing of the other layers.</summary>
    public static partial IReadOnlyList<Assembly> Domain { get; }

    /// <summary>Gets the contracts assemblies: the types an API accepts and returns, shared with its clients.</summary>
    public static partial IReadOnlyList<Assembly> Contracts { get; }

    /// <summary>Gets the application assemblies: the use cases, grouped by feature.</summary>
    public static partial IReadOnlyList<Assembly> Application { get; }

    /// <summary>Gets the infrastructure assemblies: persistence and other outside services.</summary>
    public static partial IReadOnlyList<Assembly> Infrastructure { get; }

    /// <summary>Gets the presentation assemblies: an HTTP API, a web UI or another front end.</summary>
    public static partial IReadOnlyList<Assembly> Presentation { get; }

    /// <summary>Gets every assembly the app declares, in any layer.</summary>
    public static IReadOnlyList<Assembly> All => [.. Domain, .. Contracts, .. Application, .. Infrastructure, .. Presentation];

    /// <summary>Gets the declared assemblies, loaded once for the rules that read types.</summary>
    public static ArchUnitNET.Domain.Architecture Architecture => s_architecture.Value;

    private static readonly Lazy<ArchUnitNET.Domain.Architecture> s_architecture =
        new(() => new ArchLoader().LoadAssemblies([.. All]).Build());

    /// <summary>The declared assembly with this name.</summary>
    public static Assembly Named(string name) => All.Single(assembly => assembly.GetName().Name == name);

    /// <summary>The names of the assemblies one assembly references.</summary>
    public static IEnumerable<string> ReferencedNames(string name) =>
        Named(name).GetReferencedAssemblies().Select(reference => reference.Name ?? string.Empty);

    /// <summary>The names of the assemblies in a layer.</summary>
    public static TheoryData<string> Names(IEnumerable<Assembly> layer) => [.. layer.Select(assembly => assembly.GetName().Name!)];

    /// <summary>
    /// The types in a layer's assemblies. On Linux, CI's coverage collector rewrites each assembly and injects tracker
    /// types (Microsoft.CodeCoverage.Instrumentation.*); they aren't part of any layer.
    /// </summary>
    public static GivenTypesConjunction TypesIn(IReadOnlyList<Assembly> layer)
    {
        ArgumentNullException.ThrowIfNull(layer);
        return Types().That().ResideInAssembly(layer[0], [.. layer.Skip(1)])
            .And().DoNotResideInNamespaceMatching(@"^Microsoft\.CodeCoverage(\.|$)");
    }
}
