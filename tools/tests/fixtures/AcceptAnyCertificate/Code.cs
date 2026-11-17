namespace AcceptAnyCertificate;

// An accept-all certificate validator, which CA5359 doesn't check on HttpClientHandler (SEC-014).
internal static class Code
{
    internal static void Use(HttpClientHandler handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        handler.ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator;
    }
}
