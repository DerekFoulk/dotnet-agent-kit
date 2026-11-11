namespace ModuleTypes;

// Lists a module's types, which include its internal ones, with no BindingFlags (CRF-010).
public static class Scanner
{
    public static int CountTypes(Type anchor)
    {
        ArgumentNullException.ThrowIfNull(anchor);
        return anchor.Module.GetTypes().Length;
    }
}
