using System.Reflection;

namespace AccessorProperty;

// Gets a property's private setter: the SetMethod property returns non-public accessors with no BindingFlags (CRF-010).
public static class Setter
{
    public static MethodInfo? HiddenSetter(PropertyInfo property)
    {
        ArgumentNullException.ThrowIfNull(property);
        return property.SetMethod;
    }
}
