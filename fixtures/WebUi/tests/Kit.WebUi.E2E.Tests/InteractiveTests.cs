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
        await Assertions.Expect(button).ToBeEnabledAsync();

        await button.ClickAsync();

        await Assertions.Expect(app.Page.GetByRole(AriaRole.Status)).ToHaveTextAsync("Clicked 1 time");
    }
}
