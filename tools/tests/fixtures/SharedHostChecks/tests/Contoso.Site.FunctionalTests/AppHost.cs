using System.Buffers.Text;
using System.Net.Http.Headers;
using System.Reflection;
using System.Text;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;

namespace Kit.AppTests.Functional;

/// <summary>The fixture's one host for the kit's host checks: the site, in memory, through WebApplicationFactory.</summary>
internal static partial class AppHost
{
    public static partial IReadOnlyList<HostUnderTest> Hosts => [new Site()];

    private sealed class Site : HostUnderTest
    {
        public override string Name => "Contoso.Site";

        // The admin group's status endpoint allows anonymous callers again. The group is mapped without a leading slash.
        public override IReadOnlyCollection<string> AnonymousRoutes => ["admin/status"];

        // Signed in, the staff endpoint, which needs a signed-in user; otherwise the home page.
        public override string Route => SignsUsersIn ? "/staff" : "/";

        public override bool ServesHttpApi => true;

        // The site signs users in (Program.cs). The Pester test sets KIT_FIXTURE_SIGNS_USERS_IN to false to run the
        // same build as a host that says it signs nobody in.
        public override bool SignsUsersIn => Environment.GetEnvironmentVariable("KIT_FIXTURE_SIGNS_USERS_IN") != "false";

        public override IReadOnlyCollection<Assembly> ContractAssemblies => [];

        // The site's endpoints are public. The Pester test sets KIT_FIXTURE_SIGN_IN to run the same build as an app
        // whose endpoints mostly require sign-in.
        public override bool MostEndpointsRequireSignIn => Environment.GetEnvironmentVariable("KIT_FIXTURE_SIGN_IN") == "true";

        public override IAppUnderTest Start(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services) =>
            new SiteHost(environment, settings, services, SignsUsersIn);
    }
}

/// <summary>
/// The fixture site, in memory. When it signs users in, the signed-in client sends a token shaped like a JWT, which the
/// site doesn't check; otherwise every client is anonymous.
/// </summary>
internal sealed class SiteHost : IAppUnderTest
{
    // A header, a payload and a signature, which the token checks take apart and change.
    private static readonly string s_token = string.Join('.', Encoded("""{"alg":"HS256","typ":"JWT"}"""), Encoded("""{"sub":"fixture-user"}"""), Encoded("fixture-signature"));

    private readonly WebApplicationFactory<Program> _baseFactory = new();
    private readonly WebApplicationFactory<Program> _factory;
    private readonly bool _signsUsersIn;

    public SiteHost(string environment, IReadOnlyDictionary<string, string> settings, Action<IServiceCollection> services, bool signsUsersIn)
    {
        _signsUsersIn = signsUsersIn;
        _factory = _baseFactory.WithWebHostBuilder(host =>
        {
            host.UseDefaultServiceProvider(options =>
            {
                options.ValidateScopes = true;
                options.ValidateOnBuild = true;
            });
            host.UseEnvironment(environment);
            foreach (KeyValuePair<string, string> setting in settings)
            {
                host.UseSetting(setting.Key, setting.Value);
            }

            host.ConfigureServices(services);
        });
    }

    public IServiceProvider Services => _factory.Services;

    public HttpClient CreateClient(bool signedIn)
    {
        HttpClient client = _factory.CreateClient();
        if (signedIn && _signsUsersIn)
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", s_token);
        }

        return client;
    }

    public void Dispose()
    {
        _factory.Dispose();
        _baseFactory.Dispose();
    }

    private static string Encoded(string text) => Base64Url.EncodeToString(Encoding.UTF8.GetBytes(text));
}
