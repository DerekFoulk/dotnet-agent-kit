namespace TypeInitializerUse;

// Reads a type's static constructor, which is always private: C# allows no access modifier on one (CS0515) (CRF-010).
public static class Peeker
{
    public static bool HasStaticConstructor(Type type)
    {
        ArgumentNullException.ThrowIfNull(type);
        return type.TypeInitializer is not null;
    }
}
