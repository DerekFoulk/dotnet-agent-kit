using System.Reflection;

namespace DeclaredMembersReflection;

// Lists a type's private fields with no BindingFlags at all: DeclaredFields returns non-public members too (CRF-010).
public static class Peeker
{
    public static IEnumerable<string> HiddenFieldNames(Type type)
    {
        ArgumentNullException.ThrowIfNull(type);
        return type.GetTypeInfo().DeclaredFields.Where(field => !field.IsPublic).Select(field => field.Name);
    }
}
