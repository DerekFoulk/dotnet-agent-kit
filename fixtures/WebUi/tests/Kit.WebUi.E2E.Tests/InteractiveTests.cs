using Microsoft.Playwright;

namespace Kit.WebUi.E2E.Tests;

/// <summary>
/// A page with an interactive render mode (Interactive Server), in a real browser. The server prerenders it, so the
/// browser shows the button before Blazor's circuit is up, and a click made then is lost: nothing handles it yet.
/// </summary>
public sealed class InteractiveTests
{
    private const string Path = "interactive";
    private const string ButtonName = "Add one";

    // The page keeps its button disabled until the component is interactive (RendererInfo.IsInteractive), the way
    // Microsoft's render modes page shows. Playwright waits for a button to be enabled before it clicks; the test says
    // so first, so a page that stopped disabling it fails here rather than now and then.
    [Fact]
    public async Task AClickMadeOnceThePageIsInteractiveIsCounted()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync(Path);
        ILocator button = app.Page.GetByRole(AriaRole.Button, new() { Name = ButtonName });
        ILocator status = app.Page.GetByRole(AriaRole.Status);
        await Assertions.Expect(button).ToBeEnabledAsync();
        await Assertions.Expect(status).ToHaveTextAsync("Clicked 0 times");

        await button.ClickAsync();

        await Assertions.Expect(status).ToHaveTextAsync("Clicked 1 time");
    }

    // What the wait above rests on: the prerendered page, before any script runs, already has the button disabled.
    // Without it, Playwright would click the prerendered button at once and the click would be lost.
    [Fact]
    public async Task ThePrerenderedPageSendsTheButtonDisabled()
    {
        await using AppFactory factory = new();
        factory.StartServer();
        using HttpClient client = factory.CreateClient();

        string html = await client.GetStringAsync(new Uri(Path, UriKind.Relative), TestContext.Current.CancellationToken);

        html.Should().MatchRegex($"<button[^>]*\\sdisabled(?:[\\s=][^>]*)?>{ButtonName}</button>");
    }
}
