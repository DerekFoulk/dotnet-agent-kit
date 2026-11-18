using System.Reflection;
using ArchUnitNET.Fluent.Syntax.Elements.Types;
using ArchUnitNET.xUnitV3;

namespace Kit.AppTests.Architecture;

/// <summary>
/// The endpoints accept and return Contracts types, so they use no domain type, even through an untyped IResult the
/// OpenAPI document can't see (SEC-013, OWASP API3).
/// </summary>
public sealed class EndpointTests
{
    /// <summary>Gets the HTTP API assemblies, whose names end in .Api, when the app has a domain for them to leak.</summary>
    public static TheoryData<string> Apis => AppLayers.Domain.Count == 0 ? [] : AppLayers.Names(AppLayers.Presentation.Where(IsApi));

    /// <summary>Gets the other presentation assemblies, such as a web UI, when the app has a domain.</summary>
    public static TheoryData<string> OtherFrontEnds =>
        AppLayers.Domain.Count == 0 ? [] : AppLayers.Names(AppLayers.Presentation.Where(assembly => !IsApi(assembly)));

    // An API has endpoints, so finding none means they've moved out of the check's sight, under another name, and it
    // fails instead of checking nothing (review 1).
    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(Apis))]
    public void AnApisEndpointsUseNoDomainType(string api) =>
        EndpointRule(api).Check(AppLayers.Architecture);

    // Another front end, such as a web UI, may have no endpoints at all.
    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(OtherFrontEnds))]
    public void AnotherFrontEndsEndpointsUseNoDomainType(string frontEnd) =>
        EndpointRule(frontEnd).WithoutRequiringPositiveResults().Check(AppLayers.Architecture);

    private static bool IsApi(Assembly assembly) => assembly.GetName().Name!.EndsWith(".Api", StringComparison.Ordinal);

    // Endpoints live in a class named for them, as the sample's BookmarkEndpoints is, or in an MVC controller.
    private static TypesShouldConjunction EndpointRule(string presentation) =>
        AppLayers.TypesIn([AppLayers.Named(presentation)]).And().HaveNameMatching("(Endpoints|Controller)$")
            .Should().NotDependOnAny(AppLayers.TypesIn(AppLayers.Domain));
}
