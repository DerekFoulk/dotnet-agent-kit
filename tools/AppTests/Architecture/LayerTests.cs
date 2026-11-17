using System.Reflection;

namespace Kit.AppTests.Architecture;

/// <summary>Clean Architecture: each layer depends only inward, toward the domain (ARC-001, CRF-006).</summary>
public sealed class LayerTests
{
    /// <summary>Gets each assembly with each assembly in a layer outside it, which it mustn't reference.</summary>
    public static TheoryData<string, string> OuterLayers
    {
        get
        {
            (IReadOnlyList<Assembly> Layer, Assembly[] Outside)[] rules =
            [
                (AppLayers.Domain, [.. AppLayers.Contracts, .. AppLayers.Application, .. AppLayers.Infrastructure, .. AppLayers.Presentation]),
                // Contracts are shared with clients, so they depend on no other layer either.
                (AppLayers.Contracts, [.. AppLayers.Domain, .. AppLayers.Application, .. AppLayers.Infrastructure, .. AppLayers.Presentation]),
                (AppLayers.Application, [.. AppLayers.Infrastructure, .. AppLayers.Presentation]),
                (AppLayers.Infrastructure, [.. AppLayers.Presentation]),
            ];
            return [.. rules.SelectMany(rule => rule.Layer.SelectMany(inner => rule.Outside.Select(outer => (inner.GetName().Name!, outer.GetName().Name!))))];
        }
    }

    // The compiler records a reference to another assembly only when the code uses one of its types or members, so an
    // assembly's references are the layers it depends on.
    [Theory(SkipTestWithoutData = true)]
    [MemberData(nameof(OuterLayers))]
    public void AnInnerLayerReferencesNoOuterLayer(string inner, string outer) =>
        AppLayers.ReferencedNames(inner).Should().NotContain(outer, "{0} is in a layer outside {1}'s (ARC-001)", outer, inner);
}
