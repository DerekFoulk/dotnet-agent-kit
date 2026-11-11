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

    // On Linux, CI's coverage collector rewrites each assembly and injects tracker types
    // (Microsoft.CodeCoverage.Instrumentation.*); they aren't part of any layer.
    private static GivenTypesConjunction Layer(params Assembly[] assemblies) =>
        Types().That().ResideInAssembly(assemblies[0], assemblies[1..])
            .And().DoNotResideInNamespaceMatching(@"^Microsoft\.CodeCoverage(\.|$)");
}
