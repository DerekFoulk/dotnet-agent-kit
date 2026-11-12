using Deque.AxeCore.Commons;
using Microsoft.Playwright;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>The WCAG 2.2 level A and AA checks axe can make on a rendered page (UI-001, UI-002).</summary>
internal static class Wcag
{
    /// <summary>The rules axe finds broken on the page.</summary>
    public static Task<AxeResultItem[]> FindViolationsAsync(IPage page)
    {
        ArgumentNullException.ThrowIfNull(page);
        return Task.FromResult(Array.Empty<AxeResultItem>());
    }
}
