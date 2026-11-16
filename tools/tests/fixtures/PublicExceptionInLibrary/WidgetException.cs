namespace PublicExceptionInLibrary;

/// <summary>A class library's own exception: public, as CA1064 asks, which CA1515 allows outside an Exe.</summary>
public sealed class WidgetException : Exception
{
    /// <summary>Creates the exception with no message.</summary>
    public WidgetException()
    {
    }

    /// <summary>Creates the exception with a message.</summary>
    /// <param name="message">What went wrong.</param>
    public WidgetException(string message)
        : base(message)
    {
    }

    /// <summary>Creates the exception with a message and the exception that caused it.</summary>
    /// <param name="message">What went wrong.</param>
    /// <param name="innerException">The exception that caused this one.</param>
    public WidgetException(string message, Exception innerException)
        : base(message, innerException)
    {
    }
}
