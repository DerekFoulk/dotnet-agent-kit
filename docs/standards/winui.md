---
topic: winui
rules:
  - id: WUI-001
    statement: "In a WinUI 3 app, set the accessible name explicitly for images and other controls that don't get one from their own text, and use labels for form elements so the label text can be a LabeledBy target."
    why: "Screen readers announce a control by its accessible name; Microsoft's accessibility checklist for Windows apps says you should set it where there is no implicit one."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-checklist, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-checklist"
        retrieved: "2026-11-17"
        text: "You should set the accessible name explicitly for images or other controls that do not promote inner text content as an implicit accessible name."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-checklist"
        retrieved: "2026-11-17"
        text: "You should use labels for form elements so that the label text can be used as a LabeledBy target in the Microsoft UI Automation model for correlating labels and inputs."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks images and unlabeled controls in XAML for an accessible name"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-002
    statement: "In a WinUI 3 app, treat keyboard accessibility as a primary interaction model: every control reachable by focus traversal, anything a pointer can activate also invokable by keyboard, a clear visual focus indicator on every focusable custom control, and F6 region navigation implemented explicitly where the app has regions."
    why: "Microsoft's keyboard accessibility guidance says the keyboard is a primary model, and that F6 navigation is not provided automatically."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility"
        retrieved: "2026-11-17"
        text: "Keyboard accessibility should be treated as a primary interaction model, not a secondary fallback."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility"
        retrieved: "2026-11-17"
        text: "Any UI that can be activated by pointer should also be invokable by keyboard."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility"
        retrieved: "2026-11-17"
        text: "Any focusable custom control should expose a clear visual focus indicator."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/keyboard-accessibility"
        retrieved: "2026-11-17"
        text: "You must implement F6 navigation explicitly in your app; it is not provided automatically."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks keyboard operation and focus visibility of new XAML"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-003
    statement: "In a WinUI 3 app, visible text must have a minimum luminance contrast ratio of 4.5:1 against its background. Don't treat high-contrast mode as the primary fix for low readability, avoid disabling text scaling broadly, and avoid embedding text in graphics when possible."
    why: "Microsoft's accessible text requirements set the 4.5:1 ratio and warn against these shortcuts."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/accessible-text-requirements, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessible-text-requirements"
        retrieved: "2026-11-17"
        text: "To meet this requirement, visible text must have a minimum luminance contrast ratio of 4.5:1 against its background."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessible-text-requirements"
        retrieved: "2026-11-17"
        text: "Do not treat high-contrast mode as the primary mitigation for low readability."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessible-text-requirements"
        retrieved: "2026-11-17"
        text: "Avoid disabling text scaling broadly."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessible-text-requirements"
        retrieved: "2026-11-17"
        text: "Avoid embedding text in graphics when possible."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks text colors and text scaling in new XAML"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-004
    statement: "In a WinUI 3 app, don't hard-code colors in contrast themes, and don't mix incompatible foreground and background SystemColor pairs."
    why: "Users modify contrast theme colors; hard-coded or mismatched colors become unreadable."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/high-contrast-themes, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/high-contrast-themes"
        retrieved: "2026-11-17"
        text: "Do not hard-code colors in HighContrast."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/high-contrast-themes"
        retrieved: "2026-11-17"
        text: "Do not mix incompatible foreground/background pairs."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the HighContrast theme dictionary uses SystemColor resources"
    paths: ["**/*.xaml"]
  - id: WUI-005
    statement: "A WinUI 3 custom control that supports automation must override OnCreateAutomationPeer and return a class derived from AutomationPeer, with that override doing nothing more than creating the peer. The peer must report accessibility-relevant state changes by calling RaiseAutomationEvent. Return a specific AutomationControlType rather than Custom when one fits."
    why: "Microsoft's custom automation peers page says a custom control takes part in the UI Automation provider model, so accessibility and test clients can use it."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/custom-automation-peers, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/custom-automation-peers"
        retrieved: "2026-11-17"
        text: "A custom control that supports automation must override OnCreateAutomationPeer and return an instance of a class that derives from AutomationPeer."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/custom-automation-peers"
        retrieved: "2026-11-17"
        text: "Do not attempt additional logic in this method."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/custom-automation-peers"
        retrieved: "2026-11-17"
        text: "In the automation peer model, peers for custom controls must report changes to control state that are relevant to accessibility by calling the RaiseAutomationEvent method."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/custom-automation-peers"
        retrieved: "2026-11-17"
        text: "Although you can return AutomationControlType.Custom, you should return one of the more specific control types if it accurately describes your control's main scenarios."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks custom controls for an automation peer"
    paths: ["**/*.cs"]
  - id: WUI-006
    statement: "Test a WinUI 3 app's accessibility with Accessibility Insights for Windows, which Microsoft strongly recommends over the older Windows SDK tools, and consider AccScope for Narrator scenarios."
    why: "Microsoft's accessibility testing page names the tool it recommends."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-testing, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-testing"
        retrieved: "2026-11-17"
        text: "The tools described here are still available in the Windows SDK, but we strongly recommend transitioning to Accessibility Insights."
      - source: "https://learn.microsoft.com/windows/apps/design/accessibility/accessibility-testing"
        retrieved: "2026-11-17"
        text: "You should also consider using the AccScope tool to test Narrator accessibility scenarios with your app."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review asks how the UI's accessibility was tested"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-007
    statement: "In a WinUI 3 app, create every DependencyObject on the UI thread associated with the window; other threads reach the object through its dispatcher."
    why: "The Windows App SDK documentation states that DependencyObject instances are tied to the UI thread."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/platform/xaml/custom-dependency-properties, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/platform/xaml/custom-dependency-properties"
        retrieved: "2026-11-17"
        text: "All DependencyObject instances must be created on the UI thread which is associated with the current Window that is shown by a WinUI app."
      - source: "https://learn.microsoft.com/windows/apps/develop/platform/xaml/custom-dependency-properties"
        retrieved: "2026-11-17"
        text: "Although each DependencyObject must be created on the main UI thread, the objects can be accessed using a dispatcher reference from other threads, by calling Dispatcher."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that UI objects are created and touched on the UI thread"
    paths: ["**/*.cs"]
  - id: WUI-008
    statement: "Keep a WinUI 3 app's startup fast: delay or lower the priority of startup work that isn't needed to bring up the UI, and download only the minimum needed to show an interactive UI with placeholders before loading data progressively. Keep navigation parameters small and the back stack limited, and use page caching as appropriate."
    why: "Microsoft's startup guidance says users consider the app loaded when content is on screen."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance"
        retrieved: "2026-11-17"
        text: "Applications commonly need to do multiple things during startup, and not all of that work is required to bring up the UI, so those pieces should be delayed or prioritized lower than the UI."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance"
        retrieved: "2026-11-17"
        text: "We recommend that an app download the minimal amount of data needed to show an interactive UI with placeholder elements in phase 2 and then progressively load data, which replaces the placeholder elements, in phase 3."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance"
        retrieved: "2026-11-17"
        text: "Therefore it's recommended to keep the navigation parameters small and to limit the size of the BackStack."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/app-startup-performance"
        retrieved: "2026-11-17"
        text: "Therefore it's recommended to use page caching as appropriate for your application."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the App.OnLaunched and first-page path for work not needed for the first frame"
    paths: ["**/App.xaml.cs", "**/*Page.xaml.cs"]
  - id: WUI-009
    statement: "In a WinUI 3 app, x:Load is the recommended way to defer XAML content that isn't needed immediately (typically elements not viewable in the first frame); use profiling tools to check that deferring helps. Put a resource used by only one page in that page's local resources rather than App.xaml, unless that page is the initial page."
    why: "Microsoft's guidance on XAML loading says App.xaml is parsed at startup, and that x:Load is the recommended deferred-loading pattern."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/optimize-xaml-loading, retrieved 2026-11-17", "https://learn.microsoft.com/windows/apps/develop/platform/xaml/x-load-attribute, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-xaml-loading"
        retrieved: "2026-11-17"
        text: "In Windows App SDK, x:Load is the recommended deferred-loading pattern for XAML content that is not needed immediately."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-xaml-loading"
        retrieved: "2026-11-17"
        text: "You should use profiling tools on your app to determine whether deferred loading will help."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-xaml-loading"
        retrieved: "2026-11-17"
        text: "But App.xaml is parsed at app startup, so any resource that is used in only one page, unless that page is the initial page, should be put into the page's local resources."
      - source: "https://learn.microsoft.com/windows/apps/develop/platform/xaml/x-load-attribute"
        retrieved: "2026-11-17"
        text: "Typically, we recommend that you defer elements that are not viewable in the first frame."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks App.xaml resources and hidden elements in new XAML"
    paths: ["**/*.xaml"]
  - id: WUI-010
    statement: "In a WinUI 3 app, set an explicit decode size on images when you know their display size ahead of time, with DecodePixelType Logical if that size is relative to other XAML element sizes. Use SetSourceAsync, not SetSource, to set a stream source, and always attach a BitmapImage to the live tree before setting its source."
    why: "Microsoft's animations, media and images guidance ties these to memory use and UI responsiveness."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "You should set an explicit decode size if you know the size of the image content ahead of time."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "You should also in conjunction set DecodePixelType to Logical if the supplied decode size is relative to other XAML element sizes."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "You should always attach a BitmapImage to the live tree before setting the source."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "You should always avoid using SetSource and instead use SetSourceAsync when setting a stream source."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks image loading code"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-011
    statement: "In a WinUI 3 app, minimize infinite animations, release media handles as soon as the app is finished with them, and call DisplayRequest.RequestRelease as soon as the display request is no longer required."
    why: "Microsoft's guidance says infinite animations keep the CPU from idling, and held media and display requests cost memory and battery."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "We recommend minimizing the use of infinite animations because they continually consume CPU resources and can prevent the CPU from going into a low power or idle state, causing it to run out of power more quickly."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "Because media file resources can greatly increase the size of your app's memory footprint, you must remember to release the handle to media as soon as the app is finished using it."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/optimize-animations-and-media"
        retrieved: "2026-11-17"
        text: "To conserve power and battery life, you should call DisplayRequest.RequestRelease to release the display request as soon as it is no longer required."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks animations and media use in new code"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-012
    statement: "In a WinUI 3 app, don't force a garbage collection; to avoid inducing too many, consider GCCollectionMode.Optimized. A buffer pool that reuses objects is one common technique against large temporary allocations."
    why: "Microsoft's guidance says the collector's heuristics pick the best time, so a forced collection is usually wasted CPU."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/improve-garbage-collection-performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/improve-garbage-collection-performance"
        retrieved: "2026-11-17"
        text: "We recommend that you don't force a garbage collection in your app because the garbage collector uses many heuristics to determine the best time to perform a collection, and forcing a collection is in many cases an unnecessary use of the CPU."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/improve-garbage-collection-performance"
        retrieved: "2026-11-17"
        text: "To avoid inadvertently inducing too many garbage collections, you can set the GCCollectionMode to Optimized."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for GC.Collect calls"
    paths: ["**/*.cs"]
  - id: WUI-013
    statement: "In a WinUI 3 app, make asynchronous requests for the data a virtualized ListView or GridView needs and don't block the UI thread. If you turn off ShowsScrollingPlaceholders, render item templates progressively with x:Phase."
    why: "Microsoft's data virtualization guidance for large sets that can't all be held in memory."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/performance/listview-and-gridview-data-optimization, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/listview-and-gridview-data-optimization"
        retrieved: "2026-11-17"
        text: "Make asynchronous requests for data; don't block the UI thread."
      - source: "https://learn.microsoft.com/windows/apps/develop/performance/listview-and-gridview-data-optimization"
        retrieved: "2026-11-17"
        text: "You can turn the feature off by setting ListViewBase.ShowsScrollingPlaceholders to false, but if you do so then we recommend that you use the x:Phase attribute to progressively render the elements in your item template."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks large list data sources"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WUI-014
    statement: "When a WinUI 3 app writes files, it is recommended to serialize write operations to the same file; don't assume anything about a file's data while a write is in progress, and avoid writes that take hundreds of milliseconds or more."
    why: "Microsoft's best practices for writing files say concurrent writes and long suspension work cause corruption and lost data."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/files/best-practices-writing-files, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/files/best-practices-writing-files"
        retrieved: "2026-11-17"
        text: "To mitigate this, we recommend that your app serializes Write operations to the file."
      - source: "https://learn.microsoft.com/windows/apps/develop/files/best-practices-writing-files"
        retrieved: "2026-11-17"
        text: "Your app should not make any assumption about data in the file while a write operation is in progress."
      - source: "https://learn.microsoft.com/windows/apps/develop/files/best-practices-writing-files"
        retrieved: "2026-11-17"
        text: "Avoid writing files that require hundreds of milliseconds or more to write."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks file writes"
    paths: ["**/*.cs"]
  - id: WUI-015
    statement: "A WinUI 3 app should write user-generated content to the Windows known folders (Documents, Pictures, Music, Videos), keep machine-specific data in the LocalAppData folder, treat local state as only a temporary optimization, and store its critical app state in the cloud."
    why: "Microsoft's Windows app restore guidance describes where each kind of data goes so users keep it across uninstalls and new devices."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/windows-app-restore, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/windows-app-restore"
        retrieved: "2026-11-17"
        text: "Your app should write user-generated content to the Windows known folders (see the KnownFolders class)."
      - source: "https://learn.microsoft.com/windows/apps/develop/windows-app-restore"
        retrieved: "2026-11-17"
        text: "You should store data that's specific to the machine on which the app is currently running in the FOLDERID_LocalAppData folder; normally in a sub-folder."
      - source: "https://learn.microsoft.com/windows/apps/develop/windows-app-restore"
        retrieved: "2026-11-17"
        text: "Your app should store its critical app state in the cloud."
      - source: "https://learn.microsoft.com/windows/apps/develop/windows-app-restore"
        retrieved: "2026-11-17"
        text: "Local state should be thought of as only a temporary optimization."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks where the app stores user content and state"
    paths: ["**/*.cs"]
  - id: WUI-016
    statement: "In a WinUI 3 app that uses SQLite, use Entity Framework Core or the open-source SQLite library built by Microsoft, and never concatenate user input into a SQL query string."
    why: "Microsoft's SQLite tutorial for Windows apps names its recommended libraries and the injection risk."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/data-access/sqlite-data-access, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/data-access/sqlite-data-access"
        retrieved: "2026-11-17"
        text: "We recommend that you use either Entity Framework Core or the open-source SQLite library built by Microsoft."
      - source: "https://learn.microsoft.com/windows/apps/develop/data-access/sqlite-data-access"
        retrieved: "2026-11-17"
        text: "Never concatenate user input into a SQL query string."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks SQL built from user input"
    paths: ["**/*.cs"]
  - id: WUI-017
    statement: "In a WinUI 3 app, always validate the lengths, types and ranges of user input before acting on it, and never pass raw TextBox.Text values to shell commands, file paths or database queries. Never hardcode API keys, passwords or connection strings. Its security checklist also lists minimum necessary capabilities in the manifest and sensitive data in PasswordVault rather than ApplicationData.LocalSettings."
    why: "Microsoft's security checklist for Windows development lists these as what to review before shipping."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai"
        retrieved: "2026-11-17"
        text: "Always validate lengths, types, and ranges before acting on user input."
      - source: "https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai"
        retrieved: "2026-11-17"
        text: "Never pass raw TextBox.Text values to shell commands, file paths, or database queries."
      - source: "https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai"
        retrieved: "2026-11-17"
        text: "Never hardcode API keys, passwords, or connection strings."
      - source: "https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai"
        retrieved: "2026-11-17"
        text: "Minimum necessary capabilities declared in the manifest"
      - source: "https://learn.microsoft.com/windows/apps/develop/ai-assisted/security-and-responsible-ai"
        retrieved: "2026-11-17"
        text: "Sensitive data stored in PasswordVault, not ApplicationData.LocalSettings"
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks input handling, manifest capabilities and where sensitive data is stored"
    paths: ["**/*.cs", "**/Package.appxmanifest"]
  - id: WUI-018
    statement: "A Windows desktop app must not require administrative privileges to install or run; where a feature needs them, consider a separate process for it. Use your language or framework's standard libraries for cryptography, never your own, and always use secured connections such as TLS when transmitting data. Always get the user's consent before collecting and storing personal data."
    why: "Microsoft's Windows development best practices list these as the security and privacy practices that limit risk."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/get-started/best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Don't require administrative privileges to install your app."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Don't require administrative privileges to run your app."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "If certain features need administrative privileges, consider separating them into their own processes to reduce the attack surface."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Always use your chosen language or framework's standard libraries for cryptography and other security-sensitive code."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "If you must transmit data over the network, always use secured connections, such as connections over TLS."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Always get the user's consent before collecting and storing personal data."
    projectTypes: [winui3, wpf, winforms]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks elevation requirements, cryptography and personal-data collection"
    paths: ["**"]
  - id: WUI-019
    statement: "An installer for a Windows desktop app shouldn't leave temporary files behind, and should avoid requiring elevated permissions or operating system reboots where possible. Consider MSIX for a seamless install, update and uninstall, and consider letting users preserve their data when they uninstall."
    why: "Microsoft's Windows development best practices describe the install experience users expect."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/get-started/best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Your application's installation shouldn't leave any temporary files behind."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Avoid requiring elevated permissions to install and requiring operating system reboots when possible."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Consider using MSIX to ensure that users experience a seamless installation, update, and uninstallation experience."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Consider giving your users the option to preserve their data when they uninstall your application."
    projectTypes: [winui3, wpf, winforms]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the installer or package definition"
    paths: ["**"]
  - id: WUI-020
    statement: "For most WinUI 3 apps, the Microsoft Store is the recommended distribution path, and MSIX is the recommended package format; WinUI 3 apps are packaged by default. For an internal line-of-business app on managed devices, MSIX sideloading is the recommended path."
    why: "Microsoft's guidance on choosing a distribution path names these as recommended."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/package-and-deploy/choose-distribution-path, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/choose-distribution-path"
        retrieved: "2026-11-17"
        text: "For most developers, the Microsoft Store is the recommended path."
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/choose-distribution-path"
        retrieved: "2026-11-17"
        text: "Requirements: MSIX is the recommended package format — WinUI 3 apps are packaged by default."
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/choose-distribution-path"
        retrieved: "2026-11-17"
        text: "For internal line-of-business apps that will be deployed to managed devices via Microsoft Intune or Configuration Manager, MSIX sideloading is the recommended path."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the distribution path an app plan names"
    paths: ["**"]
  - id: WUI-021
    statement: "Sign all the files of a Windows app distributed outside the Microsoft Store with a valid certificate; unsigned files build SmartScreen reputation anew with every update. Azure Artifact Signing is Microsoft's recommended code signing service for that case."
    why: "Microsoft's SmartScreen and code signing guidance ties signing to avoiding download warnings."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation, retrieved 2026-11-17", "https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation"
        retrieved: "2026-11-17"
        text: "To reduce the likelihood of interruption, you should sign all of your files with a valid certificate."
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation"
        retrieved: "2026-11-17"
        text: "Unsigned files must build reputation anew with every update."
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options"
        retrieved: "2026-11-17"
        text: "Azure Artifact Signing (formerly Trusted Signing) is Microsoft's recommended code signing service for developers who distribute apps outside the Store."
    projectTypes: [winui3, wpf, winforms]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that a release outside the Store is signed; a paid signing option is listed with its price (ARC-012)"
    paths: ["**"]
  - id: WUI-022
    statement: "Configure self-contained Windows App SDK deployment only in app projects (and, where applicable, a Windows Application Packaging Project), never in library projects."
    why: "Microsoft's self-contained deployment guide for the Windows App SDK says so."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/package-and-deploy/self-contained-deploy/deploy-self-contained-apps"
        retrieved: "2026-11-17"
        text: "Self-contained deployment should only be configured in app projects (and, where applicable, in a Windows Application Packaging Project)."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks project files for WindowsAppSDKSelfContained in a library"
    paths: ["**/*.csproj"]
  - id: WUI-023
    statement: "In a WinUI 3 app that supports single instancing, perform it in the app's Main function, not in Application.OnLaunched; and don't use the LaunchActivatedEventArgs passed to OnLaunched to determine the activation kind, because it reports Launch unconditionally."
    why: "Microsoft's app lifecycle migration guide says OnLaunched can be too late, and the args don't carry the activation kind."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/guides/applifecycle, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/guides/applifecycle"
        retrieved: "2026-11-17"
        text: "For that reason, we recommend that you perform your single-instancing logic in your app's Main (or wWinMain for C++/WinRT) function."
      - source: "https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/guides/applifecycle"
        retrieved: "2026-11-17"
        text: "Don't use the Microsoft.UI.Xaml.LaunchActivatedEventArgs object passed to App::OnLaunched to determine the activation kind, because it reports \"Launch\" unconditionally."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks single-instance and activation handling"
    paths: ["**/App.xaml.cs", "**/Program.cs"]
  - id: WUI-024
    statement: "In a WinUI 3 app, don't register a background task multiple times, and avoid long-running background tasks, which the system may terminate and doesn't recommend. Minimize background work so the app doesn't wake the CPU or use system resources while in the background, and use push notifications to wake the app rather than always keeping it running."
    why: "Microsoft's background task and Windows best practices pages tie these to reliability and battery life."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/windows-app-sdk/applifecycle/background-tasks, retrieved 2026-11-17", "https://learn.microsoft.com/windows/apps/get-started/best-practices, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/windows-app-sdk/applifecycle/background-tasks"
        retrieved: "2026-11-17"
        text: "Don't register a background task multiple times."
      - source: "https://learn.microsoft.com/windows/apps/windows-app-sdk/applifecycle/background-tasks"
        retrieved: "2026-11-17"
        text: "Long-running tasks may be terminated by the system and are not recommended."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Improve power consumption and battery life by minimizing background work: Don't wake the CPU or use system resources while in the background."
      - source: "https://learn.microsoft.com/windows/apps/get-started/best-practices"
        retrieved: "2026-11-17"
        text: "Use push notifications to wake up the app or client rather than always keeping it running to optimize performance on the user's device."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks background task registration and background work"
    paths: ["**/*.cs", "**/Package.appxmanifest"]
  - id: WUI-025
    statement: "In a WinUI 3 app, don't hard-code string literals in code, XAML markup or the package manifest. Don't put text in images, to minimize localization costs, and if color conveys meaning, also convey it by another means such as size, shape or a label."
    why: "Microsoft's localization guidance says this keeps strings translatable and keeps localization costs down."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/design/globalizing/prepare-your-app-for-localization, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/design/globalizing/prepare-your-app-for-localization"
        retrieved: "2026-11-17"
        text: "Don't hard-code string literals in your imperative code, XAML markup, nor in your app package manifest."
      - source: "https://learn.microsoft.com/windows/apps/design/globalizing/prepare-your-app-for-localization"
        retrieved: "2026-11-17"
        text: "To minimize localization costs, don't put text nor culturally-sensitive material into images to begin with."
      - source: "https://learn.microsoft.com/windows/apps/design/globalizing/prepare-your-app-for-localization"
        retrieved: "2026-11-17"
        text: "If you use color to convey meaning then you should also convey that same information by some other means, such as size, shape, or a label."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks new user-visible strings"
    paths: ["**/*.xaml", "**/*.xaml.cs", "**/Package.appxmanifest"]
  - id: WUI-026
    statement: "Don't use experimental Windows App SDK APIs in production applications."
    why: "Microsoft's migration support page says so."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/windows/apps/windows-app-sdk/migrate-to-windows-app-sdk/what-is-supported"
        retrieved: "2026-11-17"
        text: "Do not use experimental APIs in production applications."
    projectTypes: [winui3]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the Windows App SDK package is a stable release"
    paths: ["**/*.csproj", "Directory.Packages.props"]
---

# WinUI 3 and the Windows App SDK

Rules for a C# app built directly on WinUI 3 and the Windows App SDK (`winui3`): accessibility, the UI thread,
performance, files and data, security, packaging and signing, app lifecycle, and localization. A few (WUI-018,
WUI-019, WUI-021) also fit WPF and Windows Forms apps, because their pages speak of Windows desktop apps in general.
They are all `status: proposed` and take effect when the owner accepts them. Each states only what its cited
Microsoft Learn page says, at the page's strength. Per-control design advice and C++/WinRT- or UWP-only advice are
left out.
