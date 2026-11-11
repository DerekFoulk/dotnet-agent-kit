using System.Runtime.Intrinsics;
using System.Runtime.Intrinsics.X86;

namespace PlatformIntrinsics;

// An x86-only intrinsic where a cross-platform one exists: CA1516.
public static class Adder
{
    public static Vector128<int> Add(Vector128<int> left, Vector128<int> right) =>
        Sse2.IsSupported ? Sse2.Add(left, right) : left + right;
}
