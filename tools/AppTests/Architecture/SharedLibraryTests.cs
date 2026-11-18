namespace Kit.AppTests.Architecture;

/// <summary>
/// Shared libraries reference no UI, web or platform package, so any front end can use them (ARC-003), and the domain
/// knows nothing of how it's stored (CRF-014).
/// </summary>
public sealed class SharedLibraryTests
{
    private static readonly string[] s_uiOrPlatform =
    [
        "Microsoft.AspNetCore",
        "Microsoft.EntityFrameworkCore",
        "Microsoft.Maui",
        "PresentationFramework",
        "System.Windows",
    ];

    // EF Core and ADO.NET: the domain's own references are what it's compiled against, so a persistence library it
    // uses shows here.
    private static readonly string[] s_persistence = ["Microsoft.EntityFrameworkCore", "Microsoft.Data.", "System.Data"];

    /// <summary>Gets the shared libraries: the domain, contracts and application assemblies.</summary>
    public static TheoryData<string> SharedLibraries => AppLayers.Names([.. AppLayers.Domain, .. AppLayers.Contracts, .. AppLayers.Application]);

    /// <summary>Gets the domain assemblies.</summary>
    public static TheoryData<string> DomainLibraries => AppLayers.Names(AppLayers.Domain);

    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(SharedLibraries))]
    public void ASharedLibraryReferencesNoUiOrPlatformPackage(string library) =>
        AppLayers.ReferencedNames(library).Should().NotContain(name => s_uiOrPlatform.Any(prefix => name.StartsWith(prefix, StringComparison.Ordinal)));

    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(DomainLibraries))]
    public void TheDomainKnowsNothingOfPersistence(string domain) =>
        AppLayers.ReferencedNames(domain).Should().NotContain(name => s_persistence.Any(prefix => name.StartsWith(prefix, StringComparison.Ordinal)));
}
