// Two namespaces that call into each other: the cycle NamespaceCycleTests must catch. Nothing else uses them.
namespace Bookmarks.Architecture.Tests.CycleFixture.Left
{
    internal static class LeftEnd
    {
        public static string Tag() => "left";

        public static string Pair() => Tag() + Right.RightEnd.Tag();
    }
}

namespace Bookmarks.Architecture.Tests.CycleFixture.Right
{
    internal static class RightEnd
    {
        public static string Tag() => "right";

        public static string Pair() => Tag() + Left.LeftEnd.Tag();
    }
}
