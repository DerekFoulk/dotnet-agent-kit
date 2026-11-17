namespace Kit.WebUi.Components.Pages;

/// <summary>
/// The interactive page's click count. It lives in a plain class, not the page's @code block, so the code shape and
/// duplicate code checks and Stryker read it (docs/standards/testing.md, "Components").
/// </summary>
internal sealed class ClickCount
{
    private int _clicks;

    /// <summary>What the page's status line says, such as "Clicked 1 time".</summary>
    public string Status => _clicks == 1 ? "Clicked 1 time" : $"Clicked {_clicks} times";

    /// <summary>Counts one more click.</summary>
    public void Add() => _clicks++;
}
