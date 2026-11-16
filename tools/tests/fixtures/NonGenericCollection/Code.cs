using System.Collections;

namespace NonGenericCollection;

// The non-generic collections box their items and check no types; use the generic ones (STY-009).
internal static class Code
{
    internal static int List() => new ArrayList().Count;

    internal static int Table() => new Hashtable().Count;

    internal static int Queue() => new Queue().Count;

    internal static int Stack() => new Stack().Count;
}
