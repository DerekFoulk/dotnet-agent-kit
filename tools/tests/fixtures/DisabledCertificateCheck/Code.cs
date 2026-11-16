namespace DisabledCertificateCheck;

internal static class Code
{
    internal static void Use(SocketsHttpHandler handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        handler.SslOptions.RemoteCertificateValidationCallback = (_, _, _, _) => true;
    }
}
