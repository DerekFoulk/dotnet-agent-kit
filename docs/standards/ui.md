---
topic: ui
rules:
  - id: UI-001
    statement: "Every UI an app ships meets WCAG 2.2 level AA: web UI (Blazor, Razor) as written, native UI (MAUI, desktop) as W3C's WCAG2ICT note applies it. Building UI, an agent checks at least the success criteria UI-003 lists, keeping each one's own exceptions, such as a link inside a sentence or a data table that needs two dimensions."
    why: "The owner chose level AA of WCAG 2.2, W3C's current Recommendation, for every UI (ADR-0046, GAP-018). WCAG defines level AA as satisfying all the level A and AA criteria, WCAG2ICT says how to apply them to software that isn't web content, and Microsoft's MAUI checklist tells apps to follow WCAG. 2.2 adds six level A and AA criteria to 2.1, among them focus not obscured, target size and accessible authentication."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0046", "https://www.w3.org/TR/WCAG22/, retrieved 2026-11-17", "https://www.w3.org/TR/wcag2ict-22/, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "For Level AA conformance, the web page satisfies all the Level A and Level AA success criteria, or a Level AA conforming alternate version is provided."
      - source: "https://www.w3.org/TR/wcag2ict-22/"
        retrieved: "2026-11-17"
        text: "This document is intended to help clarify how to use WCAG 2 to make non-web documents and software more accessible to people with disabilities."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Ensure your app is perceivable, operable, understandable, and robust for all by following the Web Content Accessibility Guidelines (WCAG)."
    scope: [blazor, maui]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review reviews UI changes against this rule and UI-003 once it's accepted, and the plan-checklist skill's Accessibility heading points here (a Pester test keeps it pointing)"
    paths: ["**/*.razor", "**/*.razor.cs", "**/*.cshtml", "**/*.css", "**/*.html", "**/*.xaml", "**/*.xaml.cs"]
  - id: UI-002
    statement: "Every page of a web UI (Blazor, Razor) has a Playwright test in the app's E2E.Tests project that opens it, checks it loaded, and runs axe's WCAG 2.2 level A and AA rules (the tags wcag2a, wcag2aa, wcag21a, wcag21aa and wcag22aa), failing on any violation; what a person does that axe can't see, such as where focus goes after a link or the first Tab, gets its own Playwright test."
    why: "axe finds, in a real browser, on every pull request and for free, the WCAG failures a tool can find in a rendered page: missing names and labels, text contrast, the page's language and title, autocomplete values, target size. A test must check the page loaded first, because axe passes an error page. Keyboard order, focus movement and whether names make sense need a test written for them or a person (ADR-0061, GAP-004)."
    layer: owner
    basis: preference
    status: proposed
    sources: ["ADR-0061", "https://www.w3.org/TR/WCAG22/, retrieved 2026-11-17", "https://github.com/dequelabs/axe-core/blob/develop/doc/API.md, retrieved 2026-11-17", "https://github.com/dequelabs/axe-core-nuget/blob/develop/packages/playwright/README.md, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/test?view=aspnetcore-10.0, retrieved 2026-11-12"]
    scope: [blazor]
    enforcement:
      - kind: gate
        in: [kit, app]
        how: "ci: the shared .NET CI runs every E2E test an app writes, inside Microsoft's Playwright image pinned by tag and digest in the repo's .config/playwright/Dockerfile (dotnet-ci.reusable.yml, tools/Invoke-WithPlaywrightImage.ps1, ADR-0061), and the kit's web UI fixture proves the pattern in the kit's own CI, where tools/tests/WebUiFixture.Tests.ps1 holds its axe call to the tags named here"
      - kind: advisory
        in: [kit, app]
        how: "no check finds a page without its test, so code review checks that, once the rule is accepted"
    paths: ["**/*.razor", "**/*.cshtml", "**/*E2E.Tests/**"]
  - id: UI-003
    statement: "For WCAG 2.2 level AA conformance, a UI satisfies all the level A and level AA success criteria (or a level AA conforming alternate version is provided); among them, each with the exceptions and conditions WCAG lists: non-text content has a text alternative, and non-text content that is a control or accepts user input has a name that describes its purpose (1.1.1); information, structure and relationships conveyed through presentation can be programmatically determined or are available in text (1.3.1); color isn't the only visual means of conveying information (1.4.1); text has a contrast ratio of at least 4.5:1, and large-scale text at least 3:1 (1.4.3); text, except captions and images of text, can be resized without assistive technology up to 200 percent without loss of content or functionality (1.4.4); vertically scrolling content can be presented at a width equivalent to 320 CSS pixels without loss of information or functionality and without scrolling in two dimensions (1.4.10); the visual information required to identify user interface components and states has a contrast ratio of at least 3:1 against adjacent colors (1.4.11); all functionality is operable through a keyboard interface (2.1.1), and focus moved to a component with the keyboard can be moved away with the keyboard (2.1.2); where navigation sequences affect meaning or operation, components receive focus in an order that preserves meaning and operability (2.4.3); keyboard operable UI has a mode where the focus indicator is visible (2.4.7), and a component receiving focus isn't entirely hidden by author-created content (2.4.11); pointer targets are at least 24 by 24 CSS pixels (2.5.8); labels or instructions are provided when content requires user input (3.3.2); no step in authentication requires a cognitive function test unless that step provides an alternative or a mechanism WCAG lists (3.3.8); and every user interface component's name and role can be programmatically determined (4.1.2). W3C's WCAG2ICT note helps clarify how to use WCAG 2 for non-web software."
    why: "Microsoft's MAUI page calls WCAG the global accessibility standard and legal benchmark for web and mobile; these are the criteria a UI most often fails, not the whole standard, and each keeps the exceptions its page lists (GAP-018)."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://www.w3.org/TR/WCAG22/, retrieved 2026-11-17", "https://www.w3.org/TR/wcag2ict-22/, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "For Level AA conformance, the web page satisfies all the Level A and Level AA success criteria, or a Level AA conforming alternate version is provided."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "WCAG is the global accessibility standard and legal benchmark for web and mobile."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "All non-text content that is presented to the user has a text alternative that serves the equivalent purpose, except for the situations listed below."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "If non-text content is a control or accepts user input, then it has a name that describes its purpose."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Information, structure, and relationships conveyed through presentation can be programmatically determined or are available in text."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Color is not used as the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a visual element."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "The visual presentation of text and images of text has a contrast ratio of at least 4.5:1, except for the following:"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Large-scale text and images of large-scale text have a contrast ratio of at least 3:1;"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Except for captions and images of text, text can be resized without assistive technology up to 200 percent without loss of content or functionality."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Content can be presented without loss of information or functionality, and without requiring scrolling in two dimensions for:"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Vertical scrolling content at a width equivalent to 320 CSS pixels;"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "The visual presentation of the following have a contrast ratio of at least 3:1 against adjacent color(s):"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Visual information required to identify user interface components and states, except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author;"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement and not just the endpoints."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "If keyboard focus can be moved to a component of the page using a keyboard interface, then focus can be moved away from that component using only a keyboard interface, and, if it requires more than unmodified arrow or tab keys or other standard exit methods, the user is advised of the method for moving focus away."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "If a web page can be navigated sequentially and the navigation sequences affect meaning or operation, focusable components receive focus in an order that preserves meaning and operability."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Any keyboard operable user interface has a mode of operation where the keyboard focus indicator is visible."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "When a user interface component receives keyboard focus, the component is not entirely hidden due to author-created content."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "The size of the target for pointer inputs is at least 24 by 24 CSS pixels, except when:"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "Labels or instructions are provided when content requires user input."
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "A cognitive function test (such as remembering a password or solving a puzzle) is not required for any step in an authentication process unless that step provides at least one of the following:"
      - source: "https://www.w3.org/TR/WCAG22/"
        retrieved: "2026-11-17"
        text: "For all user interface components (including but not limited to: form elements, links and components generated by scripts), the name and role can be programmatically determined; states, properties, and values that can be set by the user can be programmatically set; and notification of changes to these items is available to user agents, including assistive technologies."
      - source: "https://www.w3.org/TR/wcag2ict-22/"
        retrieved: "2026-11-17"
        text: "This document is intended to help clarify how to use WCAG 2 to make non-web documents and software more accessible to people with disabilities."
    scope: [blazor, maui]
    enforcement:
      - kind: gate
        in: [kit]
        how: "ci: the web UI fixture's axe tests run in the kit's CI (ADR-0061) and catch the part of WCAG axe can test"
      - kind: advisory
        in: [app]
        how: "an app's axe tests run in the shared .NET CI only once the app writes them (UI-002)"
      - kind: advisory
        in: [kit, app]
        how: "the rest stays with the person building and code review, which reviews UI changes against this rule once it's accepted; native UI stays a manual check with each platform's tools (GAP-032)"
    paths: ["**/*.razor", "**/*.razor.cs", "**/*.cshtml", "**/*.css", "**/*.html", "**/*.xaml", "**/*.xaml.cs"]
  - id: UI-004
    statement: "In a .NET MAUI app, semantic properties are the recommended approach to providing accessibility values; automation properties, the Xamarin.Forms approach, have been superseded by them, and AutomationProperties.Name and HelpText have been deprecated since .NET 8. Description should be set on elements that have a meaning that's important for understanding the content or interacting with the user interface; avoid setting it on a Label, or on an Entry or Editor on Android. Ensure images and icons have alternate text descriptions; support large fonts and high contrast (avoid hardcoding control dimensions and prefer layouts that resize to accommodate larger font sizes, and test color schemes in high-contrast mode); design the visual tree with navigation in mind; don't rely on audio or color cues alone; and test the accessibility features of the app on each platform it targets."
    why: "Microsoft's MAUI accessibility page warns that a Description on a Label stops its Text being spoken by the screen reader, and that one on an Entry or Editor on Android stops TalkBack actions functioning."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Semantic properties are the .NET MAUI approach to providing accessibility values in apps, and are the recommended approach."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Automation properties are the Xamarin.Forms approach to providing accessibility values in apps, and have been superseded by semantic properties."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid setting the Description attached property on a Label. This will stop the Text property being spoken by the screen reader."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid setting the Description attached property on an Entry or Editor on Android. Doing so will stop Talkback actions functioning."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "This property should be set for elements that have a meaning that's important for understanding the content or interacting with the user interface."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "The Name attached property has been deprecated in .NET 8."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "The HelpText attached property has been deprecated in .NET 8."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Ensure that images and icons have alternate text descriptions."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Support large fonts and high contrast."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid hardcoding control dimensions, and instead prefer layouts that resize to accommodate larger font sizes."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Test color schemes in high-contrast mode to ensure they are readable."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Design the visual tree with navigation in mind."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Don't rely on audio or color cues alone."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Test the accessibility features of your app on each platform it targets."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks MAUI UI changes against this rule; native UI stays a manual check on each platform with its tools and screen reader (GAP-032)"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
---

# UI and accessibility

The quotes from WCAG 2.2 and WCAG2ICT in this file are W3C documents' text: their copyright notices and status are in the "Quoted passages" section of `THIRD-PARTY-NOTICES.md`, at the root of this repo.

Every UI an app ships meets WCAG 2.2 level AA (UI-001, ADR-0046). WCAG, the Web Content Accessibility Guidelines, is W3C's standard for making UI usable by people with disabilities: for example, someone who uses a screen reader, or moves through a page with the Tab key because they can't use a mouse. Level AA means every level A and level AA success criterion.

WCAG is written for web content. For a MAUI or desktop app, W3C's WCAG2ICT note says how each level A and AA criterion applies to software that isn't web: for example, read "CSS pixels" as the platform's density-independent unit (dp on Android, pt on iOS and macOS, epx on Windows; MAUI's own units are already device-independent).

## The checks to apply while building UI

UI-003 names the criteria below. They're the criteria a UI most often fails, not the whole standard; the full list is on the WCAG 2.2 page. Each criterion has exceptions, listed with it there, and they still apply: the table names the common ones.

| Check | WCAG 2.2 criteria | In practice |
|---|---|---|
| Keyboard | 2.1.1, 2.1.2, 2.4.3 | Every action works with Tab, Shift+Tab, Enter, Space and the arrow keys, in reading order; nothing traps focus. Prefer native controls (`<button>`, `<a href>`, MAUI's `Button`) to clickable `<div>`s. |
| Names and labels | 1.1.1, 1.3.1, 3.3.2, 4.1.2 | Every input has a visible label tied to it; every icon button and meaningful image has a text name; decorative images have none. |
| Contrast | 1.4.3, 1.4.11 | Text at least 4.5:1 against its background, large text 3:1. Whatever a user needs to see to identify a control and its state (an input's border, an icon button's icon, a focus indicator) 3:1 against what's next to it. Check both light and dark themes. |
| Focus | 2.4.7, 2.4.11 | Keyboard focus is always visible, and a sticky header, banner or dialog never hides the focused item completely. Don't remove the browser's focus outline without a replacement. |
| Target size | 2.5.8 | Pointer targets are at least 24 by 24, or spaced so a 24-wide circle on each doesn't touch another. A link inside a sentence is exempt, as are a few other cases WCAG lists. |
| Reflow and text size | 1.4.4, 1.4.10 | At 320 CSS pixels wide (a phone, or 400% zoom) content fits without scrolling sideways; text scales to 200% without being cut off. Don't hard-code heights for text. Content that needs two dimensions, such as a data table, map or diagram, may scroll both ways. |

Don't rely on color alone to carry meaning (1.4.1): an error is red *and* says so. Don't make sign-in depend on remembering or retyping something (3.3.8): allow paste and password managers.

## Blazor and Razor

- **Labels:** give each input component a `<label for="...">` that matches its `id`, or wrap the input in its `<label>`. Show validation messages as text next to the field, not only as a red border.
- **Navigation:** keep `<FocusOnNavigate RouteData="routeData" Selector="h1" />` in the router, so a screen reader announces each new page; give every page one `<h1>`. This is the kit's advice (UI-001): Microsoft's routing page calls it a common strategy for ensuring a page navigation is announced, not a requirement.
- **Icon buttons:** add `aria-label` when there's no visible text. Use ARIA only where no native element does the job.

## MAUI and desktop

- **Names:** set `SemanticProperties.Description` on images, `ImageButton`s and other controls without text, and `SemanticProperties.HeadingLevel` on headings. Use `SemanticProperties.Hint` for extra context. Microsoft's warnings apply: avoid setting `Description` on a `Label`, or on an `Entry` or `Editor` on Android, and on iOS a `Description` on a control with children leaves the screen reader unable to reach the children.
- **Order:** the accessibility order is the order controls appear in XAML and the layout, so lay out the visual tree in reading order.
- **Text size and contrast:** don't hard-code control sizes; let layouts grow with large fonts, and test high-contrast mode.
- `AutomationProperties.Name` and `HelpText` are deprecated since .NET 8, and Microsoft's MAUI page says automation properties have been superseded by semantic properties; use the semantic properties instead (UI-004).
- UI built in C# rather than XAML (C# markup, a page class) falls under the rule too, though the rule file loads automatically only for XAML and its code-behind.

## How it's checked

- **Web UI:** every page gets a browser test that runs axe (UI-002, ADR-0061). axe is Deque's library that finds WCAG failures in a page a real browser has rendered; Playwright drives the browser. The test opens the page, checks it loaded (axe finds nothing wrong with an error page), then runs axe's rules for WCAG 2.2 level A and AA, the tags UI-002 names. The kit's web UI fixture, [`fixtures/WebUi`](https://github.com/DerekFoulk/dotnet-agent-kit/tree/main/fixtures/WebUi), shows the pattern: [`Wcag.cs`](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/Wcag.cs) runs axe and lists each broken rule with its impact, help link and elements; [`PageTests.cs`](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/PageTests.cs) runs it on every page; [`WcagTests.cs`](https://github.com/DerekFoulk/dotnet-agent-kit/blob/main/fixtures/WebUi/tests/Kit.WebUi.E2E.Tests/WcagTests.cs) checks that axe really finds a failure for each version and level it runs, so a passing page means something. `docs/standards/testing.md` says how the tests are set up and run.
- **What axe checks, and what it doesn't.** With those tags, axe checks what it can read from the rendered page: names and labels on controls and images, text contrast, the page's language and title, valid `autocomplete` values, ARIA used correctly, and target size. Its rules for landmarks and heading order are tagged `best-practice`, not WCAG, so they don't run, and it has no rule for the contrast of controls and focus indicators. It can't tell whether a name makes sense, follow a keyboard path, or judge focus order. So a person and code review still check:
  - keyboard: every action works by keyboard, in a logical order, with no trap (write a Playwright test for each key path, as the fixture does for the first Tab);
  - focus: it's visible, never fully hidden, and moves to the new page's `h1` after navigation (the fixture's link test checks that);
  - headings and landmarks: one `h1`, headings in order, and a `main` landmark (1.3.1);
  - the contrast of control borders, icons and focus indicators, at least 3:1 (1.4.11);
  - reflow at 320 CSS pixels and text at 200%;
  - target size where axe can't measure, such as targets that move;
  - consistent help and redundant entry (WCAG 2.2's new level A criteria), and accessible authentication;
  - what a screen reader says;
  - anything behind an interaction a test didn't make, such as a menu that's never opened.
- **Interactive Blazor:** on a page with an interactive render mode, a click made before the component is interactive is lost. Render each such control disabled until `RendererInfo.IsInteractive`, and have its test wait for it to be enabled before clicking (`docs/standards/testing.md`, "Browser and accessibility tests"; the fixture's `/interactive` page).
- **Native UI:** there's no CI check, and no automated UI test yet (GAP-032). Test with each platform's tools (Accessibility Insights for Windows and Android, Accessibility Inspector for iOS and macOS) and its screen reader (Narrator, TalkBack, VoiceOver). Microsoft's MAUI guide says manual testing on devices is the most reliable check.
- **Plans:** the plan-checklist skill's Accessibility heading points here.

## Pending ratification

UI-001 to UI-004 are `proposed` until you accept them: UI-001 and UI-002 were added in auto mode (ADR-0035), and UI-003 and UI-004 hold what the WCAG, WCAG2ICT and Microsoft MAUI pages say, split out of UI-001 on 2026-11-17 so that UI-001 and UI-002 are the owner's decisions (level AA for every UI; the axe test on every page) and the others are the pages' words. A proposed rule isn't in force, and `Build-AgentRules.ps1` writes no rule file for it; once accepted, the file it generates loads only for UI files.
