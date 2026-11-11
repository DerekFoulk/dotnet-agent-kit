using System.Reflection;

namespace PrivateAccessor;

// Gets a property's private setter: GetSetMethod(true) returns non-public accessors with no BindingFlags (CRF-010).
public static class Setter
{
    public static MethodInfo? HiddenSetter(PropertyInfo property)
    {
        ArgumentNullException.ThrowIfNull(property);
        return property.GetSetMethod(nonPublic: true);
    }
}
