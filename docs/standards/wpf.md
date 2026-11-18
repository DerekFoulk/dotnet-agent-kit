---
topic: wpf
rules:
  - id: WPF-001
    statement: "Reduce a WPF app's startup time: in general, minimize the use of external resources such as network, web services or disk, and consider postponing initialization code until after the main application window is rendered."
    why: "Microsoft's startup page lists these among the ways to shorten a slow startup."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/advanced/application-startup-time, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/application-startup-time"
        retrieved: "2026-11-17"
        text: "In general, you should minimize the use of external resources, such as network, Web services, or disk."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/application-startup-time"
        retrieved: "2026-11-17"
        text: "Consider postponing initialization code until after the main application window is rendered."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks startup code (App.xaml.cs, the main window's constructor and Loaded handler) for work the first window doesn't need"
    paths: ["**/App.xaml.cs", "**/MainWindow.xaml.cs"]
  - id: WPF-002
    statement: "Freeze a Freezable, such as a brush, when its conditions allow and you don't intend to modify it, to gain the performance benefits. Check CanFreeze before freezing, and IsFrozen to see whether it already is."
    why: "An unfrozen Freezable makes the system monitor it for changes, even if you never modify it."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/advanced/freezable-objects-overview, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/freezable-objects-overview"
        retrieved: "2026-11-17"
        text: "If these conditions are false, and you don't intend to modify the Freezable, then you should freeze it to gain the performance benefits described earlier."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/freezable-objects-overview"
        retrieved: "2026-11-17"
        text: "Even if you don't actually modify a graphics system object, the system must still spend some of its resources monitoring the object, in case you do change it."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks brushes, pens and geometries created in code or shared in resources"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WPF-003
    statement: "In WPF, whenever possible avoid the Auto value for HorizontalScrollBarVisibility and VerticalScrollBarVisibility. Use automatic hyphenation and the optimal paragraph feature only when needed: it is recommended that you don't use either unless you need it."
    why: "Microsoft's WPF performance pages name Auto scrollbar visibility, and the text services hyphenation and optimal paragraph, as costs to take only when needed."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-other-recommendations, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-text, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-other-recommendations"
        retrieved: "2026-11-17"
        text: "Whenever possible, avoid using the ScrollBarVisibility.Auto value for the HorizontalScrollBarVisibility and VerticalScrollBarVisibility properties."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-text"
        retrieved: "2026-11-17"
        text: "It is recommended that you do not use automatic hyphenation unless you need it."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/optimizing-performance-text"
        retrieved: "2026-11-17"
        text: "It is recommended that you do not use the optimal paragraph feature unless you need it."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for ScrollBarVisibility=Auto, IsHyphenationEnabled and IsOptimalParagraphEnabled"
    paths: ["**/*.xaml"]
  - id: WPF-004
    statement: "Design a WPF UI for localization. Write it in XAML and avoid creating UI in code. Avoid absolute positions and fixed sizes, and use relative or automatic sizing instead: use SizeToContent and keep widths and heights set to Auto, and use Grid and its size-sharing feature. Avoid using Canvas to lay out UIs. Avoid fixed dimensions for panels and controls, to prevent clipping localized text that may be longer than the source text."
    why: "Localized text is often longer than the source text, and XAML UI is what WPF's localization APIs read."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/use-automatic-layout-overview, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview"
        retrieved: "2026-11-17"
        text: "Write your UI in XAML; avoid creating UI in code."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview"
        retrieved: "2026-11-17"
        text: "Avoid using absolute positions and fixed sizes to lay out content; instead, use relative or automatic sizing."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview"
        retrieved: "2026-11-17"
        text: "Avoid using Canvas to lay out UIs."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/wpf-globalization-and-localization-overview"
        retrieved: "2026-11-17"
        text: "Avoid using fixed dimensions to prevent clipping localized text that may be longer than the source text."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/advanced/use-automatic-layout-overview"
        retrieved: "2026-11-17"
        text: "Do not use Canvas because it positions elements absolutely."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks XAML for Canvas, absolute positions and fixed sizes, and UI built in code"
    paths: ["**/*.xaml", "**/*.xaml.cs"]
  - id: WPF-005
    statement: "In a WPF custom control, implement a property as a dependency property when it should support WPF's property features, and keep the CLR wrapper to GetValue and SetValue code except in rare cases, because WPF and XAML bypass the wrapper. Avoid setting a dependency property value in the constructor of a class that might be used as a base class; consider setting a default value in property metadata instead."
    why: "WPF's XAML processor calls GetValue and SetValue directly, so wrapper logic is skipped, and a constructor that sets a dependency property in an inheritable class can cause runtime initialization problems."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/properties/custom-dependency-properties, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/wpf/properties/safe-constructor-patterns-for-dependencyobjects, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/wpf/controls/control-authoring-overview, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/controls/control-authoring-overview"
        retrieved: "2026-11-17"
        text: "If you want a property of your control to support any of this functionality, you should implement it as a dependency property."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/properties/custom-dependency-properties"
        retrieved: "2026-11-17"
        text: "Except in rare cases, your wrapper implementation should only contain GetValue and SetValue code."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/properties/safe-constructor-patterns-for-dependencyobjects"
        retrieved: "2026-11-17"
        text: "Avoid setting a dependency property value in a constructor of your custom dependency property class if your class might be used as a base class."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/properties/safe-constructor-patterns-for-dependencyobjects"
        retrieved: "2026-11-17"
        text: "If you need to initialize a dependency property value, consider setting the required value as the default value in property metadata during dependency property registration or when overriding metadata."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks custom dependency properties and the constructors of controls that other classes derive from"
    paths: ["**/*.cs"]
  - id: WPF-006
    statement: "Make a WPF custom control resilient to its template: don't strictly enforce template contracts, and don't throw an exception when any aspect of a template contract isn't followed. Provide a control contract that says which parts and states the ControlTemplate should define, and define the control's visual structure and behavior in the template instead of in code."
    why: "A template author may omit parts, on purpose or by mistake; the parts and states model expects the control to keep working."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/wpf/controls/guidelines-for-designing-stylable-controls, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/wpf/controls/creating-a-control-that-has-a-customizable-appearance, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/controls/guidelines-for-designing-stylable-controls"
        retrieved: "2026-11-17"
        text: "Do not strictly enforce template contracts."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/controls/guidelines-for-designing-stylable-controls"
        retrieved: "2026-11-17"
        text: "Do not throw exceptions when any aspect of a template contract is not followed."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/controls/creating-a-control-that-has-a-customizable-appearance"
        retrieved: "2026-11-17"
        text: "You must provide a control contract that tells application authors which FrameworkElement objects and states should be defined in the ControlTemplate."
      - source: "https://learn.microsoft.com/dotnet/desktop/wpf/controls/creating-a-control-that-has-a-customizable-appearance"
        retrieved: "2026-11-17"
        text: "Instead of defining the control's visual structure and visual behavior in its code, you should define it in the ControlTemplate."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks a custom control's handling of missing template parts"
    paths: ["**/*.cs", "**/Themes/**"]
  - id: WPF-007
    statement: "Treat untrusted XAML generally the same as untrusted code, and use sandboxing or other metaphors to keep it from accessing trusted code. Don't share XAML reader instances, a nondefault XAML schema context, or settings for XAML reader and writer classes between trusted and untrusted code."
    why: "XAML can create objects and call into code, so XAML from a source you don't trust is code from that source."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/xaml-services/security-considerations, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/xaml-services/security-considerations"
        retrieved: "2026-11-17"
        text: "For untrusted XAML, you should treat it generally the same as if it were untrusted code."
      - source: "https://learn.microsoft.com/dotnet/desktop/xaml-services/security-considerations"
        retrieved: "2026-11-17"
        text: "Use sandboxing or other metaphors to prevent possibly untrusted XAML from accessing your trusted code."
      - source: "https://learn.microsoft.com/dotnet/desktop/xaml-services/security-considerations"
        retrieved: "2026-11-17"
        text: "Don't share XAML reader instances, nondefault XAML schema context, or settings for XAML reader/writer classes between trusted and untrusted code."
    projectTypes: [wpf]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks code that loads XAML from a file, user or network source (XamlReader, XamlServices)"
    paths: ["**/*.cs"]
---

# WPF

Rules for WPF apps on modern .NET, from Microsoft's .NET Desktop Guide on Microsoft Learn. Each rule states what its page says, at the page's strength, and stores the sentence. They apply to the `wpf` project type.

The kit's own choices about desktop apps are elsewhere: ARC-011 asks for an ADR before an app uses WPF, and ARC-010 keeps logic out of the UI project. WCAG 2.2 for native UI is UI-001.

These rules are `proposed` until the owner accepts them, and a proposed rule isn't in force.
