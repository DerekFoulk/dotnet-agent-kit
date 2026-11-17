using System.Diagnostics;
using System.Net;
using System.Security.Cryptography;

namespace UnmarkedProjectAccess;

// A project that doesn't set PureAssembly may use what a pure one may not (ARC-008): only BannedSymbols.txt applies.
internal static class Code
{
    internal static Guid NewId() => Guid.NewGuid();

    internal static int Secure() => RandomNumberGenerator.GetInt32(10);

    internal static string Read(string path) => File.ReadAllText(path);

    internal static Task<string> Fetch(HttpClient client, Uri address)
    {
        ArgumentNullException.ThrowIfNull(client);
        return client.GetStringAsync(address);
    }

    internal static IPAddress[] Resolve(string host) => Dns.GetHostAddresses(host);

    internal static string? Setting(string name) => Environment.GetEnvironmentVariable(name);

    internal static string? Line() => Console.ReadLine();

    internal static long Elapsed() => Stopwatch.GetTimestamp();
}
