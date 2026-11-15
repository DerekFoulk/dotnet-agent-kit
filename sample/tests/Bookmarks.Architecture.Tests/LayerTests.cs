using System.Reflection;
using ArchUnitNET.Fluent.Syntax.Elements.Types;
using ArchUnitNET.xUnitV3;
using static ArchUnitNET.Fluent.ArchRuleDefinition;
using Sample = Bookmarks.Architecture.Tests.SampleArchitecture;

namespace Bookmarks.Architecture.Tests;

/// <summary>Clean Architecture: each layer depends only inward (ARC-001, ARC-003).</summary>
public sealed class LayerTests
{
    [Fact]
    public void DomainDependsOnNoOtherLayer() =>
        Layer(Sample.Domain).Should().NotDependOnAny(Layer(Sample.Contracts, Sample.Application, Sample.Infrastructure, Sample.Api)).Check(Sample.Value);

    [Fact]
    public void ContractsDependOnNoOtherLayer() =>
        Layer(Sample.Contracts).Should().NotDependOnAny(Layer(Sample.Domain, Sample.Application, Sample.Infrastructure, Sample.Api)).Check(Sample.Value);

    [Fact]
    public void ApplicationDependsOnlyOnDomainAndContracts() =>
        Layer(Sample.Application).Should().NotDependOnAny(Layer(Sample.Infrastructure, Sample.Api)).Check(Sample.Value);

    [Fact]
    public void InfrastructureDoesNotDependOnTheApi() =>
        Layer(Sample.Infrastructure).Should().NotDependOnAny(Layer(Sample.Api)).Check(Sample.Value);

    // Persistence ignorance (CRF-014): the domain knows nothing of how it's stored, so it references no EF Core or
    // ADO.NET assembly. The architecture holds only the sample's assemblies, so a rule on EF Core's types would match
    // nothing; the domain's own references are what it's compiled against.
    [Fact]
    public void TheDomainKnowsNothingOfPersistence() =>
        PersistenceReferences(Sample.Domain).Should().BeEmpty();

    private static IEnumerable<string> PersistenceReferences(Assembly assembly) =>
        assembly.GetReferencedAssemblies().Select(reference => reference.Name ?? string.Empty)
            .Where(name => name.StartsWith("Microsoft.EntityFrameworkCore", StringComparison.Ordinal)
                || name.StartsWith("Microsoft.Data.", StringComparison.Ordinal)
                || name.StartsWith("System.Data", StringComparison.Ordinal));

    // On Linux, CI's coverage collector rewrites each assembly and injects tracker types
    // (Microsoft.CodeCoverage.Instrumentation.*); they aren't part of any layer.
    private static GivenTypesConjunction Layer(params Assembly[] assemblies) =>
        Types().That().ResideInAssembly(assemblies[0], assemblies[1..])
            .And().DoNotResideInNamespaceMatching(@"^Microsoft\.CodeCoverage(\.|$)");
}
