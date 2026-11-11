---
topic: ui
rules:
  - id: UI-001
    statement: "Every UI an app ships meets WCAG 2.2 level AA: web UI (Blazor, Razor) as written, native UI (MAUI, desktop) as W3C's WCAG2ICT note applies it. Building UI, an agent checks at least that: everything works by keyboard alone, in a logical order, with no trap; every control and meaningful image has an accessible name and every input a visible label; text contrasts at least 4.5:1 (3:1 for large text, and for what identifies a control or its state, such as a focus indicator); keyboard focus is visible and never fully hidden; pointer targets are at least 24 by 24 CSS pixels (dp, pt or epx natively) or spaced to match; and content reflows at 320 CSS pixels wide and text scales to 200% without loss. Each check keeps WCAG's own exceptions, such as a link inside a sentence or a data table that needs two dimensions."
    why: "WCAG is the global accessibility standard and legal benchmark for web and mobile, and Microsoft's MAUI guidance points apps at it; level AA means every level A and AA criterion. 2.2 is W3C's current Recommendation and adds focus not obscured and target size to 2.1 (GAP-018)."
    layer: outside
    status: proposed
    sources: ["ADR-0046", "https://www.w3.org/TR/WCAG22/, retrieved 2026-11-11", "https://www.w3.org/TR/wcag2ict-22/, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/dotnet/maui/fundamentals/accessibility, retrieved 2026-11-11", "https://learn.microsoft.com/en-us/aspnet/core/blazor/fundamentals/routing#focus-an-element-on-navigation, retrieved 2026-11-11"]
    enforcement: "advisory: until GAP-004 adds Playwright with axe to web UI tests, no tool checks it; the plan-checklist skill's Accessibility heading points here (a Pester test keeps it pointing), and the reviewer agent reviews UI changes against it. Native UI stays a manual check with each platform's tools"
    scope: core
    paths: ["**/*.razor", "**/*.razor.cs", "**/*.cshtml", "**/*.css", "**/*.html", "**/*.xaml", "**/*.xaml.cs"]
---

# UI and accessibility

Every UI an app ships meets WCAG 2.2 level AA (UI-001, ADR-0046). WCAG, the Web Content Accessibility Guidelines, is W3C's standard for making UI usable by people with disabilities: for example, someone who uses a screen reader, or moves through a page with the Tab key because they can't use a mouse. Level AA means every level A and level AA success criterion.

WCAG is written for web content. For a MAUI or desktop app, W3C's WCAG2ICT note says how each level A and AA criterion applies to software that isn't web: for example, read "CSS pixels" as the platform's density-independent unit (dp on Android, pt on iOS and macOS, epx on Windows; MAUI's own units are already device-independent).

## The checks to apply while building UI

The rule names six. They're the criteria a UI most often fails, not the whole standard; the full list is on the WCAG 2.2 page. Each criterion has exceptions, listed with it there, and they still apply: the table names the common ones.

| Check | WCAG 2.2 criteria | In practice |
|---|---|---|
| Keyboard | 2.1.1, 2.1.2, 2.4.3 | Every action works with Tab, Shift+Tab, Enter, Space and the arrow keys, in reading order; nothing traps focus. Prefer native controls (`<button>`, `<a href>`, MAUI's `Button`) to clickable `<div>`s. |
| Names and labels | 1.1.1, 1.3.1, 3.3.2, 4.1.2 | Every input has a visible label tied to it; every icon button and meaningful image has a text name; decorative images have none. |
| Contrast | 1.4.3, 1.4.11 | Text at least 4.5:1 against its background, large text 3:1. Whatever a user needs to see to identify a control and its state (an input's border, an icon button's icon, a focus indicator) 3:1 against what's next to it. Check both light and dark themes. |
| Focus | 2.4.7, 2.4.11 | Keyboard focus is always visible, and a sticky header, banner or dialog never hides the focused item completely. Don't remove the browser's focus outline without a replacement. |
| Target size | 2.5.8 | Pointer targets are at least 24 by 24, or spaced so a 24-wide circle on each doesn't touch another. A link inside a sentence is exempt, as are a few other cases WCAG lists. |
| Reflow and text size | 1.4.4, 1.4.10 | At 320 CSS pixels wide (a phone, or 400% zoom) content fits without scrolling sideways; text scales to 200% without being cut off. Don't hard-code heights for text. Content that needs two dimensions, such as a data table, map or diagram, may scroll both ways. |

Don't rely on color alone to carry meaning (1.4.1): an error is red *and* says so.

## Blazor and Razor

- **Labels:** give each input component a `<label for="...">` that matches its `id`, or wrap the input in its `<label>`. Show validation messages as text next to the field, not only as a red border.
- **Navigation:** keep `<FocusOnNavigate RouteData="routeData" Selector="h1" />` in the router, so a screen reader announces each new page; give every page one `<h1>`.
- **Icon buttons:** add `aria-label` when there's no visible text. Use ARIA only where no native element does the job.

## MAUI and desktop

- **Names:** set `SemanticProperties.Description` on images, `ImageButton`s and other controls without text, and `SemanticProperties.HeadingLevel` on headings. Use `SemanticProperties.Hint` for extra context. Microsoft's warnings apply: don't set `Description` on a `Label`, on an `Entry` or `Editor` on Android, or on a container on iOS.
- **Order:** the accessibility order is the order controls appear in XAML and the layout, so lay out the visual tree in reading order.
- **Text size and contrast:** don't hard-code control sizes; let layouts grow with large fonts, and test high-contrast mode.
- `AutomationProperties.Name`, `HelpText` and `LabeledBy` are deprecated since .NET 8; use the semantic properties instead.
- UI built in C# rather than XAML (C# markup, a page class) falls under the rule too, though the rule file loads automatically only for XAML and its code-behind.

## How it's checked

- **Web UI:** automated checks come with GAP-004, which adds Playwright browser tests with axe, a library that finds WCAG failures in a rendered page. Until then the rule is advisory. Axe finds only part of WCAG's failures, so keyboard and screen-reader checks stay manual even then.
- **Native UI:** there's no CI check. Test with each platform's tools (Accessibility Insights for Windows and Android, Accessibility Inspector for iOS and macOS) and its screen reader (Narrator, TalkBack, VoiceOver). Microsoft's MAUI guide says manual testing on devices is the most reliable check.
- **Plans:** the plan-checklist skill's Accessibility heading points here.

## Pending ratification

UI-001 was added in auto mode (ADR-0035), so it stays `proposed` until you accept it. A proposed rule isn't in force, and `Build-AgentRules.ps1` writes no rule file for it; once accepted, the file it generates loads only for UI files.
