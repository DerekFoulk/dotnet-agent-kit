// A root namespace with a type directly in it and nothing under it: the guard must accept it, since the cycle rule
// gives the root's own types a slice (NamespaceCycleTests). Nothing else uses it.
namespace Bookmarks.Architecture.Tests.RootOnly;

internal static class Lone
{
    public static string Tag() => "lone";
}
