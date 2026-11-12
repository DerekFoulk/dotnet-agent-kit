using Microsoft.Playwright;

namespace Kit.WebUi.E2E.Tests;

/// <summary>The home page, in a real browser: what axe can't check, such as where keyboard focus goes.</summary>
public sealed class HomeTests
{
    private const string LinkName = "What the kit's CI checks";

    [Fact]
    public async Task HomeLoadsWithItsHeading()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();

        await app.OpenAsync("/");

        (await app.Page.Locator("h1").AllTextContentsAsync()).Should().Equal("Web UI fixture");
    }

    // Blazor's enhanced navigation swaps the page without a reload, so nothing tells a screen reader the page changed
    // unless focus moves: FocusOnNavigate puts it on the new page's h1 (UI-001). axe can't check this.
    [Fact]
    public async Task FollowingTheLinkOpensChecksAndMovesFocusToItsHeading()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync("/");
        ILocator link = app.Page.GetByRole(AriaRole.Link, new() { Name = LinkName });
        (await link.CountAsync()).Should().Be(1);

        await link.ClickAsync();

        await Assertions.Expect(app.Page).ToHaveURLAsync(new Uri(app.Address, "checks").ToString());
        await Assertions.Expect(app.Page.Locator("h1")).ToBeFocusedAsync();
        (await app.Page.Locator("h1").TextContentAsync()).Should().Be(LinkName);
    }

    // The first Tab reaches the page's only link, and app.css's focus outline shows where focus is (UI-001: focus
    // visible, 3:1 against the page). Chromium draws a focus ring of its own, so the test asks for app.css's.
    [Fact]
    public async Task TabReachesTheLinkAndShowsTheAppsFocusOutline()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync("/");

        await app.Page.Keyboard.PressAsync("Tab");

        await Assertions.Expect(app.Page.GetByRole(AriaRole.Link, new() { Name = LinkName })).ToBeFocusedAsync();
        string outline = await app.Page.EvaluateAsync<string>(
            "() => { const style = getComputedStyle(document.activeElement); return `${style.outlineStyle} ${style.outlineWidth} ${style.outlineColor}`; }");
        outline.Should().Be("solid 3px rgb(26, 95, 180)");
    }
}
