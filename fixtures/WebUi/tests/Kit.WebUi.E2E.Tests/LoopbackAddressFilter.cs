using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.Http.Features;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// Points the app's server at 127.0.0.1 and port 0, so the operating system picks a free port: Kestrel's default, 5000,
/// would clash when two factories run at once (two test classes, two test projects, Stryker's runners). The address
/// wins over any endpoint the app configures for itself (PreferHostingUrls), so no test binds a fixed port.
/// </summary>
/// <remarks>
/// A startup filter runs while the app builds its pipeline, on the app's own thread, before Kestrel binds. The factory's
/// UseKestrel(0) set the same address after the app had built its host instead, racing the app's Program, which starts
/// Kestrel on a thread of its own, and it threw whenever Kestrel bound first (dotnet/aspnetcore#67340). ASP.NET Core
/// moved UseKestrel(port) to a startup filter like this one after .NET 10 (dotnet/aspnetcore#70520).
/// </remarks>
internal sealed class LoopbackAddressFilter(IServer server) : IStartupFilter
{
    private const string LoopbackOnAnyPort = "http://127.0.0.1:0";

    public Action<IApplicationBuilder> Configure(Action<IApplicationBuilder> next)
    {
        IServerAddressesFeature addresses = server.Features.GetRequiredFeature<IServerAddressesFeature>();
        addresses.Addresses.Clear();
        addresses.Addresses.Add(LoopbackOnAnyPort);
        addresses.PreferHostingUrls = true;
        return next;
    }
}
