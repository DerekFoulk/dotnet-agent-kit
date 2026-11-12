using Deque.AxeCore.Commons;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>The accessibility check itself: it must find what it's meant to find, or a passing page proves nothing.</summary>
public sealed class WcagTests
{
    // An input with no label breaks a WCAG 2.0 level A rule; two 10-pixel buttons side by side break WCAG 2.2's
    // level AA target size. Markup this broken lives only here, never in the fixture app.
    private const string BrokenPage = """
        <!DOCTYPE html>
        <html lang="en">
        <head><title>Broken on purpose</title></head>
        <body><main>
            <h1>Broken on purpose</h1>
            <input type="text">
            <div style="display:flex">
                <button style="width:10px;height:10px;padding:0;border:0;margin:0" aria-label="Previous"></button>
                <button style="width:10px;height:10px;padding:0;border:0;margin:0" aria-label="Next"></button>
            </div>
        </main></body>
        </html>
        """;

    [Fact]
    public async Task FindsAWcag20LevelAFailureAndAWcag22LevelAAFailure()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.Page.SetContentAsync(BrokenPage);

        AxeResultItem[] violations = await Wcag.FindViolationsAsync(app.Page);

        violations.Select(violation => violation.Id).Should().Contain(["label", "target-size"]);
    }
}
