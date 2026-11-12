using Deque.AxeCore.Commons;
using Deque.AxeCore.Playwright;
using Microsoft.Playwright;

namespace Kit.WebUi.E2E.Tests;

/// <summary>The WCAG 2.2 level A and AA checks axe can make on a rendered page (UI-001, UI-002).</summary>
internal static class Wcag
{
    /// <summary>The rules axe finds broken on the page.</summary>
    public static async Task<AxeResultItem[]> FindViolationsAsync(IPage page)
    {
        // axe tags each rule with the WCAG version and level it checks. WCAG 2.2 level AA is every A and AA criterion
        // of 2.0, 2.1 and 2.2. axe has no wcag22a tag: none of its rules checks a level A criterion new in 2.2
        // (consistent help, redundant entry), so those stay with the person building the page and the reviewer.
        AxeRunOptions options = new()
        {
            RunOnly = new RunOnlyOptions { Type = "tag", Values = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"] },
        };
        AxeResult result = await page.RunAxe(options);
        return result.Violations;
    }

    /// <summary>One line per broken rule: what it is, how bad, where to read about it, and which elements break it.</summary>
    public static string Describe(IEnumerable<AxeResultItem> violations) =>
        string.Join(Environment.NewLine, violations.Select(violation =>
            $"{violation.Id} ({violation.Impact}): {violation.Help} {violation.HelpUrl} at {string.Join(", ", violation.Nodes.Select(node => node.Target.ToString()))}"));
}
