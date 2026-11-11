using System.Collections;
using System.Runtime.CompilerServices;

namespace UnsafeAccessorUse;

// Reaches ArrayList's private array through UnsafeAccessor: another route into internals (CRF-010).
public static class Peeker
{
    [UnsafeAccessor(UnsafeAccessorKind.Field, Name = "_items")]
    public static extern ref object?[] Items(ArrayList list);
}
