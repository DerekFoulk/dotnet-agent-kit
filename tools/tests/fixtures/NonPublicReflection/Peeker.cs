using System.Reflection;

namespace NonPublicReflection;

// Reads a private field by reflection: code that depends on another library's internals (CRF-010).
public static class Peeker
{
    public static object? ReadHidden(object target, string name)
    {
        ArgumentNullException.ThrowIfNull(target);
        return target.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(target);
    }
}
