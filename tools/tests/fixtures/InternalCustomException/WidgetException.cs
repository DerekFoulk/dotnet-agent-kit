namespace InternalCustomException;

// An app's own exception is internal, as CA1515 asks, with the three constructors CA1032 asks for; CA1064 (exceptions
// should be public) doesn't fire on it (C#'s creating and throwing exceptions page).
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
