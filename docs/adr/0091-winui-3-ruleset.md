# ADR-0091: WinUI 3 ruleset

- **Status:** Proposed
- **Date:** 2026-11-17

## Context

A WinUI 3 app is a native Windows desktop app built on the Windows App SDK. Its `project-types.yml` entry is `winui3` (WinUI 3 (Windows App SDK)), and its docs start at <https://learn.microsoft.com/windows/apps/winui/winui3/>. The kit says "WinUI 3", never just "WinUI" (owner, 2026-11-17), because WinUI 2 is a different library, for UWP apps.

ADR-0082 makes every rule name the project types it applies to. ADR-0084 gives an app only the common ruleset plus the rulesets of its project types. This ADR records the ruleset for `winui3` (WinUI 3 (Windows App SDK)), and what Microsoft's own guidance says for it.

Microsoft's guidance pages for this type, as the 2026-11-17 inventory found them (the full list, with every page's verdict, is in `docs/inventory/windows.md`):

- <https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq>: recommends WinUI 3 for a new general-purpose Windows desktop app; several platforms start with .NET MAUI (ARC-011).
- <https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-checklist>: accessible names, keyboard, contrast (WUI-001 to WUI-006).
- <https://learn.microsoft.com/windows/apps/develop/platform/xaml/custom-dependency-properties>: DependencyObjects on the UI thread (WUI-007).
- <https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance>: keep startup fast; x:Load; image decode size (WUI-008 to WUI-010).
- <https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media>: animations and media handles (WUI-011).
- <https://learn.microsoft.com/windows/apps/develop/performance/improve-garbage-collection-performance>: do not force GC (WUI-012).
- <https://learn.microsoft.com/windows/apps/develop/performance/listview-and-gridview-data-optimization>: data virtualization (WUI-013).
- <https://learn.microsoft.com/windows/apps/develop/files/best-practices-writing-files>: serialize writes; known folders; app data (WUI-014, WUI-015).
- <https://learn.microsoft.com/windows/apps/develop/data-access/sqlite-data-access>: SQLite from WinUI 3 (WUI-016).
- <https://learn.microsoft.com/windows/apps/get-started/best-practices>: input validation, no admin, installer behavior, background tasks (WUI-017 to WUI-019, WUI-024).
- <https://learn.microsoft.com/windows/apps/package-and-deploy/choose-distribution-path>: Store and MSIX for most apps (WUI-020).
- <https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options>: sign all files; SmartScreen (WUI-021).
- <https://learn.microsoft.com/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps>: self-contained only in app projects (WUI-022).
- <https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/guides/applifecycle>: single instancing in Main (WUI-023).
- <https://learn.microsoft.com/windows/apps/design/globalizing/prepare-your-app-for-localization>: no hard-coded strings (WUI-025).
- <https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported>: no experimental APIs in production (WUI-026).

ARC-011 now follows Microsoft's recommendation of WinUI 3 for a new general-purpose Windows desktop app, with .NET MAUI for a team expecting several platforms. This supersedes ADR-0059's choice of .NET MAUI for every desktop app. ARC-014 keeps an ADR for a new WPF or Windows Forms app (ADR-0092, ADR-0093).

WUI-021 mentions Azure Artifact Signing, a paid service. ARC-012 says to list a paid option beside the free one with its price, source and date, and SEC-003 keeps spending the owner's call.

WUI-018, WUI-019 and WUI-021 also name `wpf` and `winforms`, because their pages address Windows desktop apps in general. DAT-018 (a separate EF Core migrations project) names `winui3`, and WUI-016 allows EF Core or the SQLite library Microsoft built.

## Options

### Option 1: A ruleset for WinUI 3 (Windows App SDK)

- **Trade-offs:** An app of this type gets the common rules plus the rules that name `winui3`. Nothing that belongs to another type reaches it, so an agent reads fewer rules and none that don't apply. The cost is one `projectTypes` list per rule, which `Test-RuleSources.ps1` checks.
- **Reversibility:** Easy. A rule's `projectTypes` can be widened or narrowed in one edit, and the generated files follow.
- **Risk:** Low. A rule listed for too few types is missed by the apps it should reach. Code review and the ruleset block below make that visible.

### Option 2: Every app gets every rule

This is how the kit worked before 2026-11-17.

- **Trade-offs:** One list, nothing to maintain per type. But web assumptions leak into other types (health endpoints, Problem Details, Kestrel checks in a desktop app), and an agent reads rules that don't apply and has to decide which to ignore.
- **Reversibility:** Easy.
- **Risk:** Medium. Rules that don't apply get ignored, and then the ones that do get ignored with them.

## Recommendation

Option 1: it gives a `winui3` app the rules written for it and keeps the rest out of its way.

## Decision

Option 1, proposed on 2026-11-17 as part of the project-type rulesets (ADR-0084). The owner accepts it with the rules it lists.

## The ruleset

Generated by Build-AgentRules.ps1 from docs/standards; proposed rules are marked, and aren't in force until the owner accepts them.

<!-- ruleset: winui3 -->
- [ARC-010](../standards/architecture.md) (proposed): In MAUI and desktop apps, view models and all other logic live in UI-independent libraries (ARC-003); a UI project, one that sets UseMaui, UseWPF, UseWindowsForms or UseWinUI, holds only views, platform code and startup wiring, no other project references it, and the coverage gate exempts it.
- [ARC-011](../standards/architecture.md) (proposed): A new general-purpose Windows desktop app is recommended to use WinUI 3, the native UI framework delivered with the Windows App SDK; a team expecting to target several platforms should start with .NET MAUI (Microsoft names React Native for Desktop beside it), which uses WinUI 3 when running on Windows.
- [ARC-014](../standards/architecture.md) (proposed): A new desktop app uses the framework ARC-011 names for its platforms (WinUI 3 for a Windows desktop app, .NET MAUI for several platforms); a new WPF or Windows Forms app needs an ADR that says why.
- [DAT-018](../standards/data.md) (proposed): In a platform-specific app that uses EF Core migrations (.NET MAUI or WinUI 3), store the migrations in a separate project, and don't use the platform-specific application project as the startup project for EF tools; prefer an AnyCPU migrations project.
- [UI-001](../standards/ui.md) (proposed): Every UI an app ships meets WCAG 2.2 level AA: web UI (Blazor, Razor) as written, native UI (MAUI, desktop) as W3C's WCAG2ICT note applies it. Building UI, an agent checks at least the success criteria UI-003 lists, keeping each one's own exceptions, such as a link inside a sentence or a data table that needs two dimensions.
- [UI-003](../standards/ui.md) (proposed): To meet WCAG 2.2 level AA, a UI must meet, among all the other level A and AA success criteria: a text alternative for non-text content, and a name for every control (1.1.1); structure and relationships that can be programmatically determined (1.3.1); color not as the only visual means of conveying information (1.4.1); a contrast ratio of at least 4.5:1 for text, 3:1 for large text (1.4.3); text resizable to 200 percent without loss of content or functionality (1.4.4); content that reflows at a width equivalent to 320 CSS pixels (1.4.10); a contrast ratio of at least 3:1 for the visual information that identifies user interface components and states (1.4.11); all functionality operable through a keyboard interface (2.1.1) with no keyboard trap (2.1.2); a focus order that preserves meaning and operability (2.4.3); a visible keyboard focus indicator (2.4.7) that isn't entirely hidden by author-created content (2.4.11); pointer targets at least 24 by 24 CSS pixels unless an exception applies (2.5.8); labels or instructions where content requires input (3.3.2); no cognitive function test in authentication unless an alternative or a mechanism is offered (3.3.8); and a programmatically determinable name and role for every user interface component (4.1.2). For native UI, W3C's WCAG2ICT note says how each criterion applies.
- [WUI-001](../standards/winui.md) (proposed): In a WinUI 3 app, set the accessible name explicitly for images and other controls that don't get one from their own text, and use labels for form elements so the label text can be a LabeledBy target.
- [WUI-002](../standards/winui.md) (proposed): In a WinUI 3 app, treat keyboard accessibility as a primary interaction model: every control reachable by focus traversal, anything a pointer can activate also invokable by keyboard, a clear visual focus indicator on every focusable custom control, and F6 region navigation implemented explicitly where the app has regions.
- [WUI-003](../standards/winui.md) (proposed): In a WinUI 3 app, visible text must have a minimum luminance contrast ratio of 4.5:1 against its background. Don't treat high-contrast mode as the primary fix for low readability, avoid disabling text scaling broadly, and avoid embedding text in graphics when possible.
- [WUI-004](../standards/winui.md) (proposed): In a WinUI 3 app, don't hard-code colors in contrast themes, and don't mix incompatible foreground and background SystemColor pairs.
- [WUI-005](../standards/winui.md) (proposed): A WinUI 3 custom control that supports automation must override OnCreateAutomationPeer and return a class derived from AutomationPeer, with that override doing nothing more than creating the peer. The peer must report accessibility-relevant state changes by calling RaiseAutomationEvent. Return a specific AutomationControlType rather than Custom when one fits.
- [WUI-006](../standards/winui.md) (proposed): Test a WinUI 3 app's accessibility with Accessibility Insights for Windows, which Microsoft strongly recommends over the older Windows SDK tools, and consider AccScope for Narrator scenarios.
- [WUI-007](../standards/winui.md) (proposed): In a WinUI 3 app, create every DependencyObject on the UI thread associated with the window; other threads reach the object through its dispatcher.
- [WUI-008](../standards/winui.md) (proposed): Keep a WinUI 3 app's startup fast: delay or lower the priority of startup work that isn't needed to bring up the UI, and download only the minimum needed to show an interactive UI with placeholders before loading data progressively. Keep navigation parameters small and the back stack limited, and use page caching as appropriate.
- [WUI-009](../standards/winui.md) (proposed): In a WinUI 3 app, x:Load is the recommended way to defer XAML content that isn't needed immediately (typically elements not viewable in the first frame); use profiling tools to check that deferring helps. Put a resource used by only one page in that page's local resources rather than App.xaml, unless that page is the initial page.
- [WUI-010](../standards/winui.md) (proposed): In a WinUI 3 app, set an explicit decode size on images when you know their display size ahead of time, with DecodePixelType Logical if that size is relative to other XAML element sizes. Use SetSourceAsync, not SetSource, to set a stream source, and always attach a BitmapImage to the live tree before setting its source.
- [WUI-011](../standards/winui.md) (proposed): In a WinUI 3 app, minimize infinite animations, release media handles as soon as the app is finished with them, and call DisplayRequest.RequestRelease as soon as the display request is no longer required.
- [WUI-012](../standards/winui.md) (proposed): In a WinUI 3 app, don't force a garbage collection; to avoid inducing too many, consider GCCollectionMode.Optimized. A buffer pool that reuses objects is one common technique against large temporary allocations.
- [WUI-013](../standards/winui.md) (proposed): In a WinUI 3 app, make asynchronous requests for the data a virtualized ListView or GridView needs and don't block the UI thread. If you turn off ShowsScrollingPlaceholders, render item templates progressively with x:Phase.
- [WUI-014](../standards/winui.md) (proposed): When a WinUI 3 app writes files, it is recommended to serialize write operations to the same file; don't assume anything about a file's data while a write is in progress, and avoid writes that take hundreds of milliseconds or more.
- [WUI-015](../standards/winui.md) (proposed): A WinUI 3 app should write user-generated content to the Windows known folders (Documents, Pictures, Music, Videos), keep machine-specific data in the LocalAppData folder, treat local state as only a temporary optimization, and store its critical app state in the cloud.
- [WUI-016](../standards/winui.md) (proposed): In a WinUI 3 app that uses SQLite, use Entity Framework Core or the open-source SQLite library built by Microsoft, and never concatenate user input into a SQL query string.
- [WUI-017](../standards/winui.md) (proposed): In a WinUI 3 app, always validate the lengths, types and ranges of user input before acting on it, and never pass raw TextBox.Text values to shell commands, file paths or database queries. Never hardcode API keys, passwords or connection strings. Its security checklist also lists minimum necessary capabilities in the manifest and sensitive data in PasswordVault rather than ApplicationData.LocalSettings.
- [WUI-018](../standards/winui.md) (proposed): A Windows desktop app must not require administrative privileges to install or run; where a feature needs them, consider a separate process for it. Use your language or framework's standard libraries for cryptography, never your own, and always use secured connections such as TLS when transmitting data. Always get the user's consent before collecting and storing personal data.
- [WUI-019](../standards/winui.md) (proposed): An installer for a Windows desktop app shouldn't leave temporary files behind, and should avoid requiring elevated permissions or operating system reboots where possible. Consider MSIX for a seamless install, update and uninstall, and consider letting users preserve their data when they uninstall.
- [WUI-020](../standards/winui.md) (proposed): For most WinUI 3 apps, the Microsoft Store is the recommended distribution path, and MSIX is the recommended package format; WinUI 3 apps are packaged by default. For an internal line-of-business app on managed devices, MSIX sideloading is the recommended path.
- [WUI-021](../standards/winui.md) (proposed): Sign all the files of a Windows app distributed outside the Microsoft Store with a valid certificate; unsigned files build SmartScreen reputation anew with every update. Azure Artifact Signing is Microsoft's recommended code signing service for that case.
- [WUI-022](../standards/winui.md) (proposed): Configure self-contained Windows App SDK deployment only in app projects (and, where applicable, a Windows Application Packaging Project), never in library projects.
- [WUI-023](../standards/winui.md) (proposed): In a WinUI 3 app that supports single instancing, perform it in the app's Main function, not in Application.OnLaunched; and don't use the LaunchActivatedEventArgs passed to OnLaunched to determine the activation kind, because it reports Launch unconditionally.
- [WUI-024](../standards/winui.md) (proposed): In a WinUI 3 app, don't register a background task multiple times, and avoid long-running background tasks, which the system may terminate and doesn't recommend. Minimize background work so the app doesn't wake the CPU or use system resources while in the background, and use push notifications to wake the app rather than always keeping it running.
- [WUI-025](../standards/winui.md) (proposed): In a WinUI 3 app, don't hard-code string literals in code, XAML markup or the package manifest. Don't put text in images, to minimize localization costs, and if color conveys meaning, also convey it by another means such as size, shape or a label.
- [WUI-026](../standards/winui.md) (proposed): Don't use experimental Windows App SDK APIs in production applications.
<!-- end ruleset -->

## Consequences

- A WinUI 3 app gets the common ruleset, WUI-001 to WUI-026, ARC-010, ARC-011, ARC-014 and the UI accessibility rules (UI-001, UI-003).
- WUI-001 to WUI-026 are proposed.
- The kit's CI builds Windows apps on Windows runners (ADR-0059). That doesn't change.
- **Gap:** Threading is thin. The inventory has no DispatcherQueue page, so WUI-007 covers the one page that states the UI-thread rule. A fuller threading rule needs a page the inventory didn't find. Most of the windows page is out of scope: UX design, per-control advice and Store submission aren't code rules.

## Pillars affected

- **Security:** input validation, no admin rights, code signing (WUI-017, WUI-018, WUI-021).
- **Reliability:** file writes, background tasks, single instancing (WUI-014, WUI-023, WUI-024).
- **Performance Efficiency:** startup, virtualization, GC and media rules (WUI-008 to WUI-013).
- **Cost Optimization:** signing options can cost money. ARC-012 and SEC-003 apply.

## Sources

- ADR-0082, ADR-0084
- owner, 2026-11-17
- https://learn.microsoft.com/windows/apps/get-started/windows-developer-faq, retrieved 2026-11-17
- https://learn.microsoft.com/windows/apps/get-started/best-practices, retrieved 2026-11-17
- https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options, retrieved 2026-11-17
