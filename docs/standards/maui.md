---
topic: maui
rules:
  - id: MAU-001
    statement: "Use the sqlite-net-pcl NuGet package for a local SQLite database in a .NET MAUI project. Microsoft.Data.Sqlite, a lightweight ADO.NET provider for SQLite, is the alternative the same page names."
    why: "Microsoft's .NET MAUI local database page builds its example on sqlite-net-pcl, not EF Core, and tells readers to use that package in MAUI projects despite its name; it calls Microsoft.Data.Sqlite an alternative."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite"
        retrieved: "2026-11-17"
        text: "Despite the package name, use the sqlite-net-pcl NuGet package in .NET MAUI projects."
      - source: "https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite"
        retrieved: "2026-11-17"
        text: "This article uses the sqlite-net-pcl NuGet package to provide SQLite database access to a table to store todo items."
      - source: "https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite"
        retrieved: "2026-11-17"
        text: "An alternative is to use the Microsoft.Data.Sqlite NuGet package, which is a lightweight ADO.NET provider for SQLite."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks which package a MAUI app's local SQLite access uses"
    paths: ["**/*.cs", "**/*.csproj", "**/Directory.Packages.props"]
  - id: MAU-002
    statement: "Use compiled bindings in XAML: it's recommended to set x:DataType at the same level in the view hierarchy as the BindingContext is set, and best practice to add it to all elements where the binding context changes. Consider changing the XC0022 and XC0023 warnings to build errors with $(WarningsAsErrors); they stay suppressed unless $(MauiStrictXamlCompilation) is true."
    why: "A binding that isn't compiled costs runtime performance, and XC0022 and XC0023, which report one, are always suppressed unless the strict XAML compilation property is set."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings"
        retrieved: "2026-11-17"
        text: "It's recommended to set the x:DataType attribute at the same level in the view hierarchy as the BindingContext is set."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings"
        retrieved: "2026-11-17"
        text: "It's best practice to add x:DataType to all elements where the binding context changes."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings"
        retrieved: "2026-11-17"
        text: "To ensure these warnings aren't ignored, consider changing specific warnings to build errors with the $(WarningsAsErrors) build property:"
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings"
        retrieved: "2026-11-17"
        text: "XC0022 and XC0023 warnings will always be suppressed unless the $(MauiStrictXamlCompilation) build property is set to true."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for x:DataType where the binding context changes; no gate turns XC0022 and XC0023 into errors yet"
    paths: ["**/*.xaml", "**/*.csproj", "**/Directory.Build.props"]
  - id: MAU-003
    statement: "Use semantic properties for accessibility values in a MAUI app: they are the recommended approach. Avoid setting SemanticProperties.Description on a Label, on an Entry or Editor on Android, or on any control with children on iOS. Prefer layouts that resize to larger font sizes over hardcoded control sizes, and don't rely on audio or color cues alone. Testing manually on physical devices with screen readers is the best way to test accessibility."
    why: "Each warning names a case where a Description makes a screen reader skip the visible text, break TalkBack actions or be unable to reach child controls. MAUI's accessibility page is where UI-001 points for native UI."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "Semantic properties are the .NET MAUI approach to providing accessibility values in apps, and are the recommended approach."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "Avoid setting the Description attached property on a Label."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "Avoid setting the Description attached property on an Entry or Editor on Android."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "On iOS, if you set the Description property on any control that has children the screen reader will be unable to reach the children."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "Avoid hardcoding control dimensions, and instead prefer layouts that resize to accommodate larger font sizes."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "Don't rely on audio or color cues alone."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility"
        retrieved: "2026-11-17"
        text: "However, none of these tools can perfectly emulate the screen reader user experience, and the best way to test and troubleshoot your apps for accessibility will always be manually on physical devices with screen readers."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML against this rule, with UI-001 (native UI has no automated accessibility test yet, GAP-032)"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: MAU-004
    statement: "When profiling a MAUI app, avoid profiling in a simulator, which may distort performance. Ideally profile on a variety of devices, and at a minimum on a device with the lowest anticipated specification."
    why: "A simulator can distort the numbers, and one device's measurements won't show the performance of another."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Avoid profiling an app in a simulator, as the simulator may distort the app performance."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Ideally, profiling should be performed on a variety of devices, as taking performance measurements on one device won't always show the performance characteristics of other devices."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "However, at a minimum, profiling should be performed on a device that has the lowest anticipated specification."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the plan's performance pillar and code review check where a MAUI change claims a performance result"
    paths: ["**"]
  - id: MAU-005
    statement: "Before a MAUI app displays its initial UI, it should provide a splash screen, and its activation logic should only perform the work needed to let the user start using the app."
    why: "A splash screen tells the user the app is starting, and work that isn't needed to start delays the first screen."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Before an app displays its initial UI, it should provide a splash screen to indicate to the user that the app is starting."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "In addition, the app's activation logic should only perform work that's required to let the user start using the app."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks startup code (MauiProgram, App, the first page) for work the first screen doesn't need"
    paths: ["**/MauiProgram.cs", "**/App.xaml", "**/App.xaml.cs", "**/AppShell.xaml", "**/AppShell.xaml.cs"]
  - id: MAU-006
    statement: "Keep resources used throughout a MAUI app in the app's resource dictionary to avoid duplication. XAML specific to a page shouldn't go in the app's resource dictionary, because it is then parsed at app startup; put a resource used by a page other than the startup page in that page's resource dictionary."
    why: "Page-specific resources in the app dictionary are parsed at startup instead of when a page needs them."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Any resources that are used throughout the app should be stored in the app's resource dictionary to avoid duplication."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "However, XAML that's specific to a page shouldn't be included in the app's resource dictionary, as the resources will then be parsed at app startup instead of when required by a page."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "If a resource is used by a page that's not the startup page, it should be placed in the resource dictionary for that page, therefore helping to reduce the XAML that's parsed when the app starts."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks App.xaml's resource dictionaries for resources only one page uses"
    paths: ["**/*.xaml"]
  - id: MAU-007
    statement: "In a MAUI app, update UI elements with data from asynchronous operations on the UI thread, to avoid exceptions. Avoid asynchronous constructors, and use the lazy task pattern to avoid waiting for asynchronous operations to complete during app startup. Blocking on a task and async void are STY-011's."
    why: "Updating a UI element off the UI thread throws, and waiting on asynchronous work at startup delays the first screen."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Update UI elements with data from asynchronous operations on the UI thread, to avoid exceptions being thrown."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Avoid trying to create asynchronous constructors."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Use the lazy task pattern to avoid waiting for asynchronous operations to complete during app startup."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks asynchronous code that touches UI elements, and constructors that start asynchronous work"
    paths: ["**/*.cs"]
  - id: MAU-008
    statement: "In a MAUI app, unsubscribe from events before the subscriber object is disposed of, to prevent memory leaks. On iOS and Mac Catalyst, avoid strong circular references."
    why: "An event subscription keeps its subscriber reachable, and on iOS and Mac Catalyst a strong reference cycle through a native container is never collected."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "To prevent memory leaks, events should be unsubscribed from before the subscriber object is disposed of."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Avoid strong circular references on iOS and Mac Catalyst"
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks event subscriptions in pages, view models and handlers against where they are removed"
    paths: ["**/*.cs"]
  - id: MAU-009
    statement: "In MAUI XAML, don't use bindings for content that can easily be set statically, and don't reproduce a layout's appearance with combinations of other layouts. Create images only when required, and release them as soon as the app no longer needs them."
    why: "Bindings aren't cost efficient, extra layouts cause unnecessary layout calculations, and images held longer than needed use memory."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "Don't use bindings for content that can easily be set statically."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "In addition, don't attempt to reproduce the appearance of a specific layout by using combinations of other layouts, as this results in unnecessary layout calculations being performed."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance"
        retrieved: "2026-11-17"
        text: "In addition, images should only be created when required and should be released as soon as the app no longer requires them."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for bindings to constant values and for layouts nested only to imitate another layout"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: MAU-010
    statement: "In a MAUI layout, don't nest ScrollView objects, or nest one with another control that scrolls, such as a CollectionView or ListView. Avoid AbsoluteLayout.AutoSize whenever possible. Use a bindable layout only when the collection is small and scrolling and selection aren't required."
    why: "Nested scrolling and AutoSize add layout work, and a bindable layout has no scrolling or selection of its own."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview"
        retrieved: "2026-11-17"
        text: "ScrollView objects should not be nested."
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/"
        retrieved: "2026-11-17"
        text: "Avoid using the AbsoluteLayout.AutoSize property whenever possible, as it will cause the layout engine to perform additional layout calculations."
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/"
        retrieved: "2026-11-17"
        text: "Bindable layouts should only be used when the collection of items to be displayed is small, and scrolling and selection isn't required."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for nested ScrollViews, AutoSize and bindable layouts over large collections"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: MAU-011
    statement: "Handle a MAUI window's lifecycle events as the page says. On Stopped, disconnect from long running processes and cancel pending requests that might consume device resources: the app may be terminated by the operating system and might not resume. On Resumed, subscribe to any required events and refresh the visible page's content. On Destroying, remove event subscriptions attached to the native window. On iOS and Mac Catalyst, persist string state to the Backgrounding event's State property. When overriding an Android activity lifecycle method the page lists, always call the super class's implementation."
    why: "The lifecycle page gives an action for each of these events; skipping them keeps work running in the background, leaves subscriptions behind or loses state the system would have kept."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "There's no guarantee that an app will resume from this state, because it may be terminated by the operating system."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "Disconnect from any long running processes, or cancel any pending requests that might consume device resources."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "Subscribe to any required events, and refresh any content that's on the visible page."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "Remove any event subscriptions that you've attached to the native window."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "A BackgroundingEventArgs object accompanies this event, and any string state should be persisted to the State property of the BackgroundingEventArgs object, which the OS will preserve until it's time to resume the window."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle"
        retrieved: "2026-11-17"
        text: "Always call the super class's implementation."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks Window lifecycle handlers and platform lifecycle overrides against this rule"
    paths: ["**/App.xaml.cs", "**/MauiProgram.cs", "**/Platforms/**", "**/*Window*.cs"]
  - id: MAU-012
    statement: "In a MAUI app, don't request permissions from the MauiProgram or App class; request them only once the app's first page has appeared. Explain to the user why the app needs a permission (best practice). A permission must have its matching attributes in the Android Manifest and its matching string in Info.plist."
    why: "A permission prompt before the first page appears has no screen to explain it, and a permission without its manifest or plist entry can't be granted."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions"
        retrieved: "2026-11-17"
        text: "Permissions shouldn't be requested from your MauiProgram or App class, and should only be requested once the first page of the app has appeared."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions"
        retrieved: "2026-11-17"
        text: "It's best practice to explain to your user why your application needs a specific permission."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions"
        retrieved: "2026-11-17"
        text: "Permissions must have the matching attributes set in the Android Manifest file."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions"
        retrieved: "2026-11-17"
        text: "Permissions must have a matching string in the Info.plist file."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks where permission requests are made and that each has its manifest and plist entry"
    paths: ["**/*.cs", "**/Platforms/**"]
  - id: MAU-013
    statement: "Authenticate a MAUI app through a web backend as a middle layer between the app and the authentication provider (the best practice). Older mobile-only authentication libraries and patterns that don't use a web backend are strongly recommended against, because they can't store client secrets securely. On Apple platforms, an app that uses any social login service must also offer Sign in with Apple, according to Apple's review guidelines as the page relays them."
    why: "A client secret shipped inside a mobile app can be extracted; a web backend keeps it server-side."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication"
        retrieved: "2026-11-17"
        text: "The best practice here's to use a web backend as a middle layer between your mobile app and the authentication provider."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication"
        retrieved: "2026-11-17"
        text: "We strongly recommend against using older mobile-only authentication libraries and patterns which do not leverage a web backend in the authentication flow, due to their inherent lack of security for storing client secrets."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication"
        retrieved: "2026-11-17"
        text: "According to Apple's review guidelines, if your Apple app uses any social login service to authenticate, it must also offer Apple Sign In as an option."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the plan's security section and code review check a MAUI app's sign-in design against this rule"
    paths: ["**/*.cs"]
  - id: MAU-014
    statement: "In a MAUI Shell app, always await Shell.GoToAsync. Receiving navigation data with QueryPropertyAttribute isn't trim safe and shouldn't be used with full trimming or NativeAOT; implement IQueryAttributable on the types that accept query parameters instead. Set an explicit AccessibilityLabel whenever IconOverride is set or TextOverride is hidden."
    why: "A navigation call that isn't awaited races the code after it; QueryPropertyAttribute breaks under trimming; and screen readers announce a generic value or none when the text is hidden."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation"
        retrieved: "2026-11-17"
        text: "Always await the GoToAsync method."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation"
        retrieved: "2026-11-17"
        text: "Receiving navigation data using the QueryPropertyAttribute isn't trim safe and shouldn't be used with full trimming or NativeAOT."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation"
        retrieved: "2026-11-17"
        text: "Instead, you should implement the IQueryAttributable interface on types that need to accept query parameters."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation"
        retrieved: "2026-11-17"
        text: "Setting an explicit AccessibilityLabel is recommended whenever IconOverride is set or TextOverride is hidden, because screen readers would otherwise announce a generic value or no value at all."
    projectTypes: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks navigation calls are awaited and how pages receive query parameters"
    paths: ["**/*.cs", "**/*.xaml"]
  - id: MAU-015
    statement: "Don't build new messaging on MessagingCenter, which is deprecated: replace it with WeakReferenceMessenger from the CommunityToolkit.Mvvm package, or use events with weak references for simple scenarios."
    why: "The MAUI page marks MessagingCenter deprecated and names its replacement."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter"
        retrieved: "2026-11-17"
        text: "MessagingCenter has been deprecated and we recommend that you replace it with WeakReferenceMessenger in the CommunityToolkit.Mvvm NuGet package."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter"
        retrieved: "2026-11-17"
        text: "We recommend migrating to WeakReferenceMessenger from the CommunityToolkit.Mvvm package, or using events with weak references for simple scenarios."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks for MessagingCenter in MAUI code"
    paths: ["**/*.cs"]
  - id: MAU-016
    statement: "When a MAUI app is deployed with Native AOT on iOS or Mac Catalyst, review and correct all trimming and AOT warnings; all binding expressions must use compiled bindings; the $(PublishAot) build property shouldn't be conditioned by build configuration. Develop, debug and test as usual and publish with Native AOT as one of the last steps."
    why: "A trimming or AOT warning means the app might not work correctly under Native AOT; conditioning PublishAot makes the feature switches differ between configurations, so code behaves differently."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/nativeaot, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot"
        retrieved: "2026-11-17"
        text: "Therefore, when building an app for Native AOT deployment you should review and correct all trimming and AOT warnings."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot"
        retrieved: "2026-11-17"
        text: "All binding expressions must use compiled bindings, rather than a binding path that's set to a string."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot"
        retrieved: "2026-11-17"
        text: "The $(PublishAot) build property shouldn't be conditioned by build configuration."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot"
        retrieved: "2026-11-17"
        text: "You should develop, debug, and test your application as usual and publish your final app with Native AOT as one of the last steps."
    projectTypes: [maui, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks a MAUI project that sets PublishAot"
    paths: ["**/*.csproj", "**/Directory.Build.props"]
---

# .NET MAUI

Rules for apps built on .NET MAUI, from Microsoft's .NET MAUI documentation on Microsoft Learn. Each rule states what its page says, at the page's strength, and stores the sentence. They apply to the `maui` project type, and to `blazor-hybrid` where a rule is about the MAUI host (a Blazor Hybrid app is a MAUI app); rules about XAML apply to `maui` only.

MAUI's own local database page builds its example on sqlite-net-pcl, not EF Core (MAU-001). DAT-002's EF Core rule is a separate rule about the kit's default, not something that page says.

Blocking on a task and `async void` have their own rule, STY-011, which the performance page's guidance agrees with. WCAG 2.2 for native UI is UI-001.

These rules are `proposed` until the owner accepts them, and a proposed rule isn't in force.
