using Microsoft.Playwright;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>
/// The running app, a headless Chromium and one page in a fresh browser context, for one test: each test starts its
/// own and disposes it, so no test sees another's cookies, storage or focus.
/// </summary>
internal sealed class AppUnderTest : IAsyncDisposable
{
    private readonly AppFactory _factory;
    private readonly IPlaywright _playwright;
    private readonly IBrowser _browser;
    private readonly IBrowserContext _context;

    private AppUnderTest(AppFactory factory, IPlaywright playwright, IBrowser browser, IBrowserContext context, IPage page)
    {
        _factory = factory;
        Address = factory.ClientOptions.BaseAddress;
        _playwright = playwright;
        _browser = browser;
        _context = context;
        Page = page;
    }

    /// <summary>Where the app listens, such as http://127.0.0.1:53124/.</summary>
    public Uri Address { get; }

    /// <summary>The page, with the app's address as its base, so tests go to "/" or "checks".</summary>
    public IPage Page { get; }

    /// <summary>
    /// Opens a page of the app and checks it loaded: axe finds nothing wrong with an error page, so a test that only
    /// ran axe would pass on a broken app.
    /// </summary>
    public async Task OpenAsync(string path)
    {
        IResponse? response = await Page.GotoAsync(path);
        response.Should().NotBeNull();
        response!.Status.Should().Be(200, "{0} should load", path);
    }

    public static async Task<AppUnderTest> StartAsync()
    {
        AppFactory factory = new();
        factory.StartServer();
        IPlaywright playwright = await Playwright.CreateAsync();
        IBrowser browser = await playwright.Chromium.LaunchAsync();
        IBrowserContext context = await browser.NewContextAsync(new BrowserNewContextOptions { BaseURL = factory.ClientOptions.BaseAddress.ToString() });
        return new AppUnderTest(factory, playwright, browser, context, await context.NewPageAsync());
    }

    public async ValueTask DisposeAsync()
    {
        await _context.DisposeAsync();
        await _browser.DisposeAsync();
        _playwright.Dispose();
        await _factory.DisposeAsync();
    }
}
