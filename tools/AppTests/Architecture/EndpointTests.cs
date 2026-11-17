using ArchUnitNET.xUnitV3;

namespace Kit.AppTests.Architecture;

/// <summary>
/// The endpoints accept and return Contracts types, so they use no domain type, even through an untyped IResult the
/// OpenAPI document can't see (SEC-013, OWASP API3).
/// </summary>
public sealed class EndpointTests
{
    /// <summary>Gets the presentation assemblies, when the app has a domain for them to leak.</summary>
    public static TheoryData<string> Presentation => AppLayers.Domain.Count == 0 ? [] : AppLayers.Names(AppLayers.Presentation);

    // An endpoint class is named for its endpoints, as the sample's BookmarkEndpoints is. A front end with none, such as a
    // web UI, has nothing to check.
    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(Presentation))]
    public void TheEndpointsUseNoDomainType(string presentation) =>
        AppLayers.TypesIn([AppLayers.Named(presentation)]).And().HaveNameEndingWith("Endpoints")
            .Should().NotDependOnAny(AppLayers.TypesIn(AppLayers.Domain)).WithoutRequiringPositiveResults()
            .Check(AppLayers.Architecture);
}
