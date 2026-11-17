using System.Net;
using System.Net.Http;
using System.Net.Sockets;

namespace PureNetworkAccess;

// A pure assembly reaches the network only through an injected abstraction, so its tests need no network (ARC-008).
internal static class Code
{
    internal static Task<string> Fetch(HttpClient client, Uri address)
    {
        ArgumentNullException.ThrowIfNull(client);
        return client.GetStringAsync(address);
    }

    internal static Socket Connect() => new(AddressFamily.InterNetwork, SocketType.Stream, ProtocolType.Tcp);

    internal static TcpClient Tcp() => new();

    internal static IPAddress[] Resolve(string host) => Dns.GetHostAddresses(host);
}
