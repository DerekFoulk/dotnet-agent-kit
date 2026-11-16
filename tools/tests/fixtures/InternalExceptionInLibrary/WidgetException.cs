namespace InternalExceptionInLibrary;

// In a class library, such as an ARC-001 module's Domain or Application project, CA1064 asks an exception to be public.
internal sealed class WidgetException : Exception
{
    public WidgetException()
    {
    }

    public WidgetException(string message)
        : base(message)
    {
    }

    public WidgetException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
