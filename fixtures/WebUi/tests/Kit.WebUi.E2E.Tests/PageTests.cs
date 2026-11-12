using Deque.AxeCore.Commons;

namespace Kit.WebUi.E2E.Tests;

/// <summary>Every page of the app, checked by axe once it has loaded (UI-002).</summary>
public sealed class PageTests
{
    [Theory]
    [InlineData("/")]
    [InlineData("checks")]
    public async Task PageHasNoWcagFailureAxeCanFind(string path)
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.OpenAsync(path);

        AxeResultItem[] violations = await Wcag.FindViolationsAsync(app.Page);

        violations.Should().BeEmpty(Wcag.Describe(violations));
    }
}
