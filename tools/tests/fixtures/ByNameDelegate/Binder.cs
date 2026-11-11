namespace ByNameDelegate;

// Binds a delegate to a method by its name, which finds private methods too, with no BindingFlags (CRF-010).
public static class Binder
{
    public static Func<string> Bind(object target, string methodName) =>
        (Func<string>)Delegate.CreateDelegate(typeof(Func<string>), target, methodName);
}
