using Deque.AxeCore.Commons;

namespace Kit.WebUi.E2E.Tests;

/// <summary>The accessibility check itself: it must find what it's meant to find, or a passing page proves nothing.</summary>
public sealed class WcagTests
{
    // One failure for each tag the check runs, so dropping any of them fails this test: an input with no label (WCAG
    // 2.0 level A, axe's wcag2a), faint grey text (2.0 level AA, wcag2aa), a button whose name doesn't contain its
    // visible text (2.1 level A, wcag21a), an autocomplete value that doesn't exist (2.1 level AA, wcag21aa) and two
    // 10-pixel buttons side by side (2.2 level AA, wcag22aa). Markup this broken lives only here, never in the app.
    private const string BrokenPage = """
        <!DOCTYPE html>
        <html lang="en">
        <head><title>Broken on purpose</title></head>
        <body><main>
            <h1>Broken on purpose</h1>
            <input type="text">
            <p style="color:#bbb;background:#fff">Faint text</p>
            <button aria-label="Close">Open</button>
            <label for="name">Name</label><input id="name" type="text" autocomplete="nonsense">
            <div style="display:flex">
                <button style="width:10px;height:10px;padding:0;border:0;margin:0" aria-label="Previous"></button>
                <button style="width:10px;height:10px;padding:0;border:0;margin:0" aria-label="Next"></button>
            </div>
        </main></body>
        </html>
        """;

    [Fact]
    public async Task FindsAFailureOfEachWcagVersionAndLevelItChecks()
    {
        await using AppUnderTest app = await AppUnderTest.StartAsync();
        await app.Page.SetContentAsync(BrokenPage);

        AxeResultItem[] violations = await Wcag.FindViolationsAsync(app.Page);

        violations.Select(violation => violation.Id).Should().Contain(["label", "color-contrast", "label-content-name-mismatch", "autocomplete-valid", "target-size"]);
    }
}
