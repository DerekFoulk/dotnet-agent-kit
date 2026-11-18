---
topic: winforms
rules:
  - id: WFM-001
    statement: "Use the type-safe TryGetData<T> method, not the obsolete GetData, for custom clipboard data in Windows Forms on .NET 10, and prefer the JSON-based SetDataAsJson<T> and TryGetData<T> for custom formats. BinaryFormatter clipboard support isn't recommended: use it only as a temporary migration bridge, and if you do, you must implement type resolvers that restrict deserialization to explicitly approved types."
    why: "The JSON-based methods give better type safety and avoid BinaryFormatter dependencies, which carry significant security risks."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/winforms/advanced/how-to-retrieve-data-from-the-clipboard, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/winforms/migration/clipboard-dataobject-net10, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/how-to-retrieve-data-from-the-clipboard"
        retrieved: "2026-11-17"
        text: "For custom data formats, it's recommended to use the JSON-based methods (SetDataAsJson<T>() and TryGetData<T>()) for better type safety and to avoid BinaryFormatter dependencies."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/migration/clipboard-dataobject-net10"
        retrieved: "2026-11-17"
        text: "You should migrate to the new type-safe TryGetData<T>() methods for better error handling and type safety."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/migration/clipboard-dataobject-net10"
        retrieved: "2026-11-17"
        text: "BinaryFormatter support is not recommended. Use it only as a temporary migration bridge for legacy applications that can't immediately migrate to the new type-safe APIs."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/migration/clipboard-dataobject-net10"
        retrieved: "2026-11-17"
        text: "Even with BinaryFormatter enabled, you must implement type resolvers to restrict deserialization to explicitly approved types."
    projectTypes: [winforms]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks clipboard code for GetData and for BinaryFormatter configuration"
    paths: ["**/*.cs", "**/*.csproj", "**/*.runtimeconfig.json"]
  - id: WFM-002
    statement: "In Windows Forms async event handlers, always wrap awaited operations in try-catch blocks. Never use blocking calls such as .Wait(), .Result or .GetAwaiter().GetResult() in event handlers or any UI code."
    why: "An async void event handler is one of the rare acceptable uses of async void, and its exceptions can't be caught by a caller; a blocking call on the UI thread can deadlock. The page's ban on blocking in UI code is stricter than STY-011, which allows GetAwaiter().GetResult() where await can't reach."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/winforms/forms/events, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/forms/events"
        retrieved: "2026-11-17"
        text: "Always wrap awaited operations in try-catch blocks to handle exceptions properly, as shown in the previous example."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/forms/events"
        retrieved: "2026-11-17"
        text: "Never use blocking calls like .Wait(), .Result, or .GetAwaiter().GetResult() in event handlers or any UI code."
    projectTypes: [winforms]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks Windows Forms event handlers; STY-011's analyzers already report async void and blocking calls generally"
    paths: ["**/*.cs"]
  - id: WFM-003
    statement: "Support Windows accessibility in a Windows Forms app. When SystemInformation.HighContrast is true, display all UI elements with the system color scheme, convey by visual cues or sound any information conveyed through color, and omit images or patterns behind text; check the setting at startup, respond to the UserPreferenceChanged system event, and release that event when the app closes. Avoid conveying important information by sound alone. Create access keys with the & character, put a text box's label immediately before it in the tab order, and set a font size of 10 points or larger if it isn't adjustable. Test the accessibility features before deploying."
    why: "The accessibility pages give these as the way to support high-contrast mode, keyboard access and users who can't hear sound; an event on SystemEvents that isn't released keeps running after the program closes."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/properties-on-windows-forms-controls-that-support-accessibility-guidelines, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "If SystemInformation.HighContrast is true, the application should:"
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "Display all user interface elements using the system color scheme"
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "Convey by visual cues or sound any information that is conveyed through color."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "Omit any images or patterns behind text"
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "The application should check the setting of HighContrast when the application starts and respond to the system event UserPreferenceChanged."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "If you do not release the event, the code that you hook up to the event will run even after the program is closed."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "Avoid conveying important information by sound alone."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/walkthrough-creating-an-accessible-windows-based-application"
        retrieved: "2026-11-17"
        text: "Before deploying the application, you should test the accessibility features that you have implemented."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/properties-on-windows-forms-controls-that-support-accessibility-guidelines"
        retrieved: "2026-11-17"
        text: "Use the \"&\" character to create access keys."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/properties-on-windows-forms-controls-that-support-accessibility-guidelines"
        retrieved: "2026-11-17"
        text: "It is important for controls without intrinsic labels, such as text boxes, to have their associated label immediately precede them in the tab order."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/advanced/properties-on-windows-forms-controls-that-support-accessibility-guidelines"
        retrieved: "2026-11-17"
        text: "If the font size is not adjustable, then it should be set to 10 points or larger."
    projectTypes: [winforms]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks Windows Forms UI against this rule, with UI-001; native UI has no automated accessibility test yet (GAP-032)"
    paths: ["**/*.cs", "**/*.Designer.cs"]
  - id: WFM-004
    statement: "When a Windows Forms DataGridView displays large amounts of data, follow the page's scaling guidelines to avoid consuming large amounts of memory or degrading UI responsiveness. Avoid setting cell style properties on individual cells or rows, avoid creating shortcut menus for individual cells and rows, and avoid automatic sizing on a large set of rows; if you do use automatic sizing, only resize based on the displayed rows."
    why: "Each per-cell style or shortcut menu is an object the grid must keep, and automatic sizing must examine every cell it covers."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control, retrieved 2026-11-17", "https://learn.microsoft.com/dotnet/desktop/winforms/controls/sizing-options-in-the-windows-forms-datagridview-control, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control"
        retrieved: "2026-11-17"
        text: "If you need to display large amounts of data, you should follow the guidelines described in this topic to avoid consuming large amounts of memory or degrading the responsiveness of the user interface (UI)."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control"
        retrieved: "2026-11-17"
        text: "Avoid setting cell style properties for individual DataGridViewCell or DataGridViewRow objects."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control"
        retrieved: "2026-11-17"
        text: "Avoid creating shortcut menus for individual cells and rows."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/controls/best-practices-for-scaling-the-windows-forms-datagridview-control"
        retrieved: "2026-11-17"
        text: "Avoid using automatic sizing on a DataGridView control with a large set of rows. If you do use automatic sizing, only resize based on the displayed rows."
      - source: "https://learn.microsoft.com/dotnet/desktop/winforms/controls/sizing-options-in-the-windows-forms-datagridview-control"
        retrieved: "2026-11-17"
        text: "To avoid performance penalties, use the automatic sizing modes that calculate sizes based only on the displayed rows rather than analyzing every row in the control."
    projectTypes: [winforms]
    enforcement:
      - kind: advisory
        in: [app]
        how: "code review checks DataGridView use where a grid can show many rows"
    paths: ["**/*.cs", "**/*.Designer.cs"]
---

# Windows Forms

Rules for Windows Forms apps on modern .NET, from Microsoft's .NET Desktop Guide on Microsoft Learn. Each rule states what its page says, at the page's strength, and stores the sentence. They apply to the `winforms` project type.

The kit's own choices about desktop apps are elsewhere: ARC-011 asks for an ADR before an app uses Windows Forms, and ARC-010 keeps logic out of the UI project. WCAG 2.2 for native UI is UI-001.

These rules are `proposed` until the owner accepts them, and a proposed rule isn't in force.
