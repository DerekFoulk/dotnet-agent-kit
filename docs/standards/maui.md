---
topic: maui
rules:
  - id: MAU-001
    statement: "When a .NET MAUI app uses SQLite-net for a local SQLite database, use the sqlite-net-pcl NuGet package, despite the package name."
    why: "Several NuGet packages have similar names, and the page's example is built on sqlite-net-pcl."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Despite the package name, use the sqlite-net-pcl NuGet package in .NET MAUI projects."
      - source: "https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "This article uses the sqlite-net-pcl NuGet package to provide SQLite database access to a table to store todo items."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks which package a MAUI app's local SQLite access uses"
    paths: ["**/*.cs", "**/*.csproj", "**/Directory.Packages.props"]
  - id: MAU-002
    statement: "In .NET MAUI XAML, setting the x:DataType attribute at the same level in the view hierarchy as the BindingContext is set is recommended, and adding x:DataType to all elements where the binding context changes is best practice. Consider changing the compiled-binding warnings, such as XC0022 and XC0023, to build errors with the $(WarningsAsErrors) build property; XC0022 and XC0023 are always suppressed unless $(MauiStrictXamlCompilation) is true."
    why: "A binding without x:DataType isn't compiled and costs runtime performance, and the warnings that report one stay silent unless strict XAML compilation is on."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "It's recommended to set the x:DataType attribute at the same level in the view hierarchy as the BindingContext is set."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "It's best practice to add x:DataType to all elements where the binding context changes."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "To ensure these warnings aren't ignored, consider changing specific warnings to build errors with the $(WarningsAsErrors) build property:"
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "XC0022 and XC0023 warnings will always be suppressed unless the $(MauiStrictXamlCompilation) build property is set to true."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for x:DataType where the binding context changes; no gate turns XC0022 and XC0023 into errors yet"
    paths: ["**/*.xaml", "**/*.csproj", "**/Directory.Build.props"]
  - id: MAU-004
    statement: "Avoid profiling a MAUI app in a simulator, as the simulator may distort the app's performance. Ideally, profiling should be performed on a variety of devices, and at a minimum on a device that has the lowest anticipated specification."
    why: "A simulator can distort the numbers, and one device's measurements won't show the performance of another."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid profiling an app in a simulator, as the simulator may distort the app performance."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Ideally, profiling should be performed on a variety of devices, as taking performance measurements on one device won't always show the performance characteristics of other devices."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "However, at a minimum, profiling should be performed on a device that has the lowest anticipated specification."
    scope: [maui]
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
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Before an app displays its initial UI, it should provide a splash screen to indicate to the user that the app is starting."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "In addition, the app's activation logic should only perform work that's required to let the user start using the app."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks startup code (MauiProgram, App, the first page) for work the first screen doesn't need"
    paths: ["**/MauiProgram.cs", "**/App.xaml", "**/App.xaml.cs", "**/AppShell.xaml", "**/AppShell.xaml.cs"]
  - id: MAU-006
    statement: "Resources used throughout a MAUI app should be stored in the app's resource dictionary to avoid duplication. XAML that's specific to a page shouldn't be included in the app's resource dictionary, because it is then parsed at app startup instead of when a page needs it; a resource used by a page that isn't the startup page should be placed in that page's resource dictionary."
    why: "Page-specific resources in the app dictionary are parsed at startup instead of when a page needs them."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    unconditional: "'when the app starts' describes startup, not which apps the rule holds for"
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Any resources that are used throughout the app should be stored in the app's resource dictionary to avoid duplication."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "However, XAML that's specific to a page shouldn't be included in the app's resource dictionary, as the resources will then be parsed at app startup instead of when required by a page."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "If a resource is used by a page that's not the startup page, it should be placed in the resource dictionary for that page, therefore helping to reduce the XAML that's parsed when the app starts."
    scope: [maui]
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
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Update UI elements with data from asynchronous operations on the UI thread, to avoid exceptions being thrown."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid trying to create asynchronous constructors."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Use the lazy task pattern to avoid waiting for asynchronous operations to complete during app startup."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks asynchronous code that touches UI elements, and constructors that start asynchronous work"
    paths: ["**/*.cs"]
  - id: MAU-008
    statement: "In a MAUI app, events should be unsubscribed from before the subscriber object is disposed of, to prevent memory leaks. Avoid strong circular references on iOS and Mac Catalyst."
    why: "An event subscription keeps its subscriber reachable, and on iOS and Mac Catalyst a strong reference cycle can keep objects from ever being collected."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "To prevent memory leaks, events should be unsubscribed from before the subscriber object is disposed of."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid strong circular references on iOS and Mac Catalyst"
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks event subscriptions in pages, view models and handlers against where they are removed"
    paths: ["**/*.cs"]
  - id: MAU-009
    statement: "In MAUI XAML, don't use bindings for content that can easily be set statically, and don't reproduce a layout's appearance with combinations of other layouts. Images should only be created when required and should be released as soon as the app no longer requires them."
    why: "Bindings aren't cost efficient, extra layouts cause unnecessary layout calculations, and images held longer than needed use memory."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Don't use bindings for content that can easily be set statically."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "In addition, don't attempt to reproduce the appearance of a specific layout by using combinations of other layouts, as this results in unnecessary layout calculations being performed."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/performance?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "In addition, images should only be created when required and should be released as soon as the app no longer requires them."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for bindings to constant values and for layouts nested only to imitate another layout"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: MAU-010
    statement: "In a MAUI layout, ScrollView objects should not be nested, and should not be nested with other controls that provide scrolling, such as CollectionView, ListView and WebView. Avoid using the AbsoluteLayout.AutoSize property whenever possible, as it makes the layout engine perform additional layout calculations. Bindable layouts should only be used when the collection of items to be displayed is small, and scrolling and selection aren't required."
    why: "Nested scrolling controls compete for the same scroll gestures, and a bindable layout has no scrolling, selection or virtualization of its own."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview?view=net-maui-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "ScrollView objects should not be nested."
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "In addition, ScrollView objects should not be nested with other controls that provide scrolling, such as CollectionView, ListView, and WebView."
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using the AbsoluteLayout.AutoSize property whenever possible, as it will cause the layout engine to perform additional layout calculations."
      - source: "https://learn.microsoft.com/dotnet/maui/user-interface/layouts/?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Bindable layouts should only be used when the collection of items to be displayed is small, and scrolling and selection isn't required."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for nested ScrollViews, AutoSize and bindable layouts over large collections"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: MAU-011
    statement: "In a MAUI window's lifecycle events: on Stopped, disconnect from any long running processes, or cancel any pending requests that might consume device resources, because there's no guarantee the app will resume (the operating system may terminate it). On Resumed, subscribe to any required events and refresh any content that's on the visible page. On Destroying, remove any event subscriptions attached to the native window. On iOS and Mac Catalyst, any string state should be persisted to the State property of the Backgrounding event's BackgroundingEventArgs. In the Android activity lifecycle overrides that need it, such as OnPause and OnDestroy, always call the super class's implementation."
    why: "The lifecycle page gives an action for each of these events, and its table of Android methods marks the ones whose override must call the base implementation; skipping them keeps work running in the background, leaves subscriptions behind or loses state the system would have kept."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "There's no guarantee that an app will resume from this state, because it may be terminated by the operating system."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Disconnect from any long running processes, or cancel any pending requests that might consume device resources."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Subscribe to any required events, and refresh any content that's on the visible page."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Remove any event subscriptions that you've attached to the native window."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "In addition, the Window class also defines a Backgrounding event that's raised on iOS and Mac Catalyst when the Window is closed or enters a background state."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "A BackgroundingEventArgs object accompanies this event, and any string state should be persisted to the State property of the BackgroundingEventArgs object, which the OS will preserve until it's time to resume the window."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Always call the super class's implementation."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks Window lifecycle handlers and platform lifecycle overrides against this rule"
    paths: ["**/App.xaml.cs", "**/MauiProgram.cs", "**/Platforms/**", "**/*Window*.cs"]
  - id: MAU-012
    statement: "In a MAUI app, permissions shouldn't be requested from the MauiProgram or App class, and should only be requested once the first page of the app has appeared. It's best practice to explain to the user why the app needs a specific permission. On Android, permissions must have the matching attributes set in the Android Manifest file; on iOS and Mac Catalyst, permissions must have a matching string in the Info.plist file."
    why: "A permission prompt before the first page appears has no screen to explain it, and a permission without its manifest or plist entry can't be granted."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Permissions shouldn't be requested from your MauiProgram or App class, and should only be requested once the first page of the app has appeared."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "It's best practice to explain to your user why your application needs a specific permission."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Permissions must have the matching attributes set in the Android Manifest file."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Permissions must have a matching string in the Info.plist file."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks where permission requests are made and that each has its manifest and plist entry"
    paths: ["**/*.cs", "**/Platforms/**"]
  - id: MAU-013
    statement: "Using a web backend as a middle layer between a MAUI app and the authentication provider is the best practice. Older mobile-only authentication libraries and patterns that don't use a web backend in the authentication flow are strongly recommended against, due to their inherent lack of security for storing client secrets. An Apple app that uses any social login service to authenticate must also offer Sign in with Apple as an option (Apple's review guidelines)."
    why: "A client secret shipped inside a mobile app can be extracted; a web backend keeps it server-side."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    when: [has-sign-in]
    sources: ["https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "The best practice here's to use a web backend as a middle layer between your mobile app and the authentication provider."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "We strongly recommend against using older mobile-only authentication libraries and patterns which do not leverage a web backend in the authentication flow, due to their inherent lack of security for storing client secrets."
      - source: "https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "According to Apple's review guidelines, if your Apple app uses any social login service to authenticate, it must also offer Apple Sign In as an option."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "the plan's security section and code review check a MAUI app's sign-in design against this rule"
    paths: ["**/*.cs"]
  - id: MAU-014
    statement: "In a MAUI Shell app, always await the GoToAsync method. Receiving navigation data using the QueryPropertyAttribute isn't trim safe and shouldn't be used with full trimming or NativeAOT; instead, types that need to accept query parameters should implement the IQueryAttributable interface. Setting an explicit AccessibilityLabel is recommended whenever IconOverride is set or TextOverride is hidden."
    why: "A navigation call that isn't awaited races the code after it; QueryPropertyAttribute breaks under trimming; and screen readers announce a generic value or none when the text is hidden."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Always await the GoToAsync method."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Receiving navigation data using the QueryPropertyAttribute isn't trim safe and shouldn't be used with full trimming or NativeAOT."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Instead, you should implement the IQueryAttributable interface on types that need to accept query parameters."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Setting an explicit AccessibilityLabel is recommended whenever IconOverride is set or TextOverride is hidden, because screen readers would otherwise announce a generic value or no value at all."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks navigation calls are awaited and how pages receive query parameters"
    paths: ["**/*.cs", "**/*.xaml"]
  - id: MAU-015
    statement: "MessagingCenter has been deprecated in .NET MAUI: replacing it with WeakReferenceMessenger from the CommunityToolkit.Mvvm NuGet package is recommended, or using events with weak references for simple scenarios."
    why: "The MAUI page marks MessagingCenter deprecated and names its replacement."
    layer: outside
    basis: authority
    status: proposed
    strength: should
    sources: ["https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "MessagingCenter has been deprecated and we recommend that you replace it with WeakReferenceMessenger in the CommunityToolkit.Mvvm NuGet package."
      - source: "https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "We recommend migrating to WeakReferenceMessenger from the CommunityToolkit.Mvvm package, or using events with weak references for simple scenarios."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks for MessagingCenter in MAUI code"
    paths: ["**/*.cs"]
  - id: MAU-016
    statement: "When building a MAUI app for Native AOT deployment on iOS or Mac Catalyst, you should review and correct all trimming and AOT warnings; all binding expressions must use compiled bindings, rather than a binding path that's set to a string; and the $(PublishAot) build property shouldn't be conditioned by build configuration. You should develop, debug and test the app as usual, and publish the final app with Native AOT as one of the last steps."
    why: "A trimming or AOT warning means the app might not work correctly under Native AOT; conditioning PublishAot makes the feature switches differ between configurations, so code behaves differently."
    layer: outside
    basis: authority
    status: proposed
    strength: must
    when: [publishes-native-aot]
    sources: ["https://learn.microsoft.com/dotnet/maui/deployment/nativeaot?view=net-maui-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, when building an app for Native AOT deployment you should review and correct all trimming and AOT warnings."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "All binding expressions must use compiled bindings, rather than a binding path that's set to a string."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "The $(PublishAot) build property shouldn't be conditioned by build configuration."
      - source: "https://learn.microsoft.com/dotnet/maui/deployment/nativeaot?view=net-maui-10.0"
        retrieved: "2026-11-17"
        text: "You should develop, debug, and test your application as usual and publish your final app with Native AOT as one of the last steps."
    scope: [maui]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks a MAUI project that sets PublishAot"
    paths: ["**/*.csproj", "**/Directory.Build.props"]
---

# .NET MAUI

Rules for apps built on .NET MAUI, from Microsoft's .NET MAUI documentation on Microsoft Learn. Each rule states what its page says, at the page's strength, and stores the sentence. They apply to the `maui` app type.

MAU-001 only says which package to use when an app takes the local database page's approach, SQLite-net. The kit's note: that page's example doesn't use EF Core, and DAT-002's EF Core rule is the kit's own default, not something that page says.

Blocking on a task and `async void` have their own rule, STY-011, which the performance page's guidance agrees with. WCAG 2.2 for native UI is UI-001, and the MAUI accessibility page's advice (semantic properties, where not to set a Description, large fonts, color cues) is UI-004.

These rules are `proposed` until the owner accepts them, and a proposed rule isn't in force.
