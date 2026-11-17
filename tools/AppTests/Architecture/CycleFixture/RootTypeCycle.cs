// A type in the root namespace and one in a namespace under it that call into each other: the cycle
// NamespaceCycleTests must catch even though one end sits in the root itself. Nothing else uses them.
namespace Kit.AppTests.Architecture.RootTypeCycle
{
    internal static class RootEnd
    {
        public static string Tag() => "root";

        public static string Pair() => Tag() + Child.ChildEnd.Tag();
    }
}

namespace Kit.AppTests.Architecture.RootTypeCycle.Child
{
    internal static class ChildEnd
    {
        public static string Tag() => "child";

        public static string Pair() => Tag() + RootTypeCycle.RootEnd.Tag();
    }
}
