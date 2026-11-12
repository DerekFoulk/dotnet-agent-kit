using Microsoft.CodeAnalysis;

namespace Kit.CodeShape;

/// <summary>Symbols joined into groups: each join merges the two symbols' groups (a union-find).</summary>
internal sealed class DisjointSets
{
    private readonly Dictionary<ISymbol, ISymbol> _parent = new(SymbolEqualityComparer.Default);

    /// <summary>Puts two symbols, and everything already joined to either, in one group.</summary>
    public void Join(ISymbol first, ISymbol second) => _parent[Root(first)] = Root(second);

    /// <summary>The symbol that stands for the group this one is in.</summary>
    public ISymbol Root(ISymbol symbol)
    {
        ISymbol current = symbol;
        while (_parent.TryGetValue(current, out ISymbol? parent) && !SymbolEqualityComparer.Default.Equals(parent, current))
        {
            current = parent;
        }

        return current;
    }
}
