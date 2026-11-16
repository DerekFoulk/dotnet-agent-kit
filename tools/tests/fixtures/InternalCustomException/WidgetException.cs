namespace InternalCustomException;

// An Exe's own exception is internal, as CA1515 asks of an Exe's types, with the three constructors CA1032 asks for.
// CA1064 (exceptions should be public) doesn't fire on it here, though its page names no exception for an Exe: this
// pins what the analyzer does. In a class library CA1064 does fire (the InternalExceptionInLibrary fixture), so a
// library's exception is public.
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
