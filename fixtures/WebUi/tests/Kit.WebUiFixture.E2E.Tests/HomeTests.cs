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

    [Fact]
    public async Task HomeHasNoWcagFailureAxeCanFind()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync("/");

        Deque.AxeCore.Commons.AxeResultItem[] violations = await Wcag.FindViolationsAsync(app.Page);

        violations.Should().BeEmpty(Wcag.Describe(violations));
    }
}
