using System.Security.Authentication;

namespace DeprecatedTls;

internal static class Code
{
    internal static void Use(HttpClientHandler handler)
    {
        ArgumentNullException.ThrowIfNull(handler);
        handler.SslProtocols = SslProtocols.Tls11;
    }
}
