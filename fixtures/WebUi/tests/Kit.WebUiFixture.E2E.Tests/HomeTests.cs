using Microsoft.Playwright;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>The home page, in a real browser.</summary>
public sealed class HomeTests
{
    [Fact]
    public async Task HomeLoadsWithItsHeading()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();

        IResponse? response = await app.Page.GotoAsync("/");

        response.Should().NotBeNull();
        response!.Status.Should().Be(200);
        (await app.Page.Locator("h1").AllTextContentsAsync()).Should().Equal("Web UI fixture");
    }


    // Blazor's enhanced navigation swaps the page without a reload, so nothing tells a screen reader the page changed
    // unless focus moves: FocusOnNavigate puts it on the new page's h1 (UI-001). axe can't check this.
    [Fact]
    public async Task FollowingTheLinkOpensChecksAndMovesFocusToItsHeading()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync("/");

        ILocator link = app.Page.GetByRole(AriaRole.Link, new() { Name = "What the kit's CI checks" });
        (await link.CountAsync()).Should().Be(1);

        await link.ClickAsync();

        await Assertions.Expect(app.Page).ToHaveURLAsync(new Uri(app.Address, "checks").ToString());
        await Assertions.Expect(app.Page.Locator("h1")).ToBeFocusedAsync();
        (await app.Page.Locator("h1").TextContentAsync()).Should().Be("What the kit's CI checks");
    }
}
