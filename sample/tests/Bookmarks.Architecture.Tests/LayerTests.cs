using System.Reflection;
using ArchUnitNET.Fluent.Syntax.Elements.Types;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnitV3;
using Bookmarks.Application.Features.Bookmarks;
using Bookmarks.Contracts;
using Bookmarks.Domain;
using Bookmarks.Infrastructure;
using static ArchUnitNET.Fluent.ArchRuleDefinition;

namespace Bookmarks.Architecture.Tests;

/// <summary>Clean Architecture: each layer depends only inward (ARC-001, ARC-003).</summary>
public sealed class LayerTests
{
    private static readonly Assembly s_domain = typeof(Bookmark).Assembly;
    private static readonly Assembly s_contracts = typeof(BookmarkResponse).Assembly;
    private static readonly Assembly s_application = typeof(BookmarkService).Assembly;
    private static readonly Assembly s_infrastructure = typeof(BookmarksDbContext).Assembly;
    private static readonly Assembly s_api = Assembly.Load("Bookmarks.Api");

    private static readonly ArchUnitNET.Domain.Architecture s_architecture =
        new ArchLoader().LoadAssemblies(s_domain, s_contracts, s_application, s_infrastructure, s_api).Build();

    [Fact]
    public void DomainDependsOnNoOtherLayer() =>
        Layer(s_domain).Should().NotDependOnAny(Layer(s_contracts, s_application, s_infrastructure, s_api)).Check(s_architecture);

    [Fact]
    public void ContractsDependOnNoOtherLayer() =>
        Layer(s_contracts).Should().NotDependOnAny(Layer(s_domain, s_application, s_infrastructure, s_api)).Check(s_architecture);

    [Fact]
    public void ApplicationDependsOnlyOnDomainAndContracts() =>
        Layer(s_application).Should().NotDependOnAny(Layer(s_infrastructure, s_api)).Check(s_architecture);

    [Fact]
    public void InfrastructureDoesNotDependOnTheApi() =>
        Layer(s_infrastructure).Should().NotDependOnAny(Layer(s_api)).Check(s_architecture);

    private static GivenTypesConjunction Layer(params Assembly[] assemblies) =>
        Types().That().ResideInAssembly(assemblies[0], assemblies[1..]);
}
