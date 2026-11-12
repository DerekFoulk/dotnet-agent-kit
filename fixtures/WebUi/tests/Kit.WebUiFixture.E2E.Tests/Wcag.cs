using Deque.AxeCore.Commons;
using Deque.AxeCore.Playwright;
using Microsoft.Playwright;

namespace Kit.WebUiFixture.E2E.Tests;

/// <summary>The WCAG 2.2 level A and AA checks axe can make on a rendered page (UI-001, UI-002).</summary>
internal static class Wcag
{
    // axe tags each rule with the WCAG version and level it checks. WCAG 2.2 level AA is every A and AA criterion of
    // 2.0, 2.1 and 2.2. axe has no wcag22a tag: none of its rules checks a level A criterion new in 2.2 (consistent
    // help, redundant entry), so those stay with the person building the page and the reviewer.
    private static readonly List<string> Tags = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];

    /// <summary>The rules axe finds broken on the page.</summary>
    public static async Task<AxeResultItem[]> FindViolationsAsync(IPage page)
    {
        AxeResult result = await page.RunAxe(new AxeRunOptions { RunOnly = new RunOnlyOptions { Type = "tag", Values = Tags } });
        return result.Violations;
    }
}
