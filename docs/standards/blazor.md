---
topic: blazor
rules:
  - id: BLZ-001
    statement: "Component authors should avoid coupling a component's implementation to a specific render mode, and should typically design components to support any render mode or hosting model. In most cases, reusable component authors should not specify a render mode, even when interactivity is required."
    why: "A component that assumes where it runs breaks when an app picks a different render mode, and a library component that sets a render mode takes the choice from the app developer."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/components/class-libraries-and-static-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Component authors should avoid coupling a component's implementation to a specific render mode."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Instead, component authors should typically design components to support any render mode or hosting model."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/class-libraries-and-static-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In most cases, reusable component authors should not specify a render mode, even when interactivity is required."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that components don't assume a render mode and that library components leave @rendermode to the app"
    paths: ["**/*.razor"]

  - id: BLZ-002
    statement: "Generally, avoid creating components that write directly to their own component parameters. Component parameters should be declared as auto properties, with no custom logic in their get or set accessors. Don't use the required modifier or an init accessor on component parameter properties."
    why: "A parameter is a channel from parent to child: a value the component writes to its own parameter is overwritten when the parent rerenders."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/components/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Generally, avoid creating components that write directly to their own component parameters."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Component parameters should be declared as automatically-implemented properties (auto properties), meaning that they shouldn't contain custom logic in their get or set accessors."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't use the required modifier or init accessor on component parameter properties."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks component parameters"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-003
    statement: "For two-way data binding, the @bind:get/@bind:set modifiers are recommended. Specifying a culture with @bind:culture isn't recommended when using the date and number field types."
    why: "The modifiers run a component's own logic when a bound value changes without a hand-written property setter, and Blazor provides built-in support to render values in the current culture."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For two-way data binding, we recommend using @bind:get/@bind:set modifiers."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, specifying a culture with @bind:culture isn't recommended when using the date and number field types."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Blazor provides built-in support to render values in the current culture."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks @bind usage"
    paths: ["**/*.razor"]

  - id: BLZ-004
    statement: "Avoid thread-blocking calls in components. When a component must be updated from an external event, such as a timer or other notification, use InvokeAsync to dispatch the work to Blazor's synchronization context."
    why: "Components run on a synchronization context; blocking it stalls rendering, and updating state outside it is not safe."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid thread-blocking calls"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In the event a component must be updated based on an external event, such as a timer or other notification, use the InvokeAsync method, which dispatches code execution to Blazor's synchronization context."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks components for blocking calls and for state changes made outside the synchronization context"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-005
    statement: "Always unsubscribe event handlers from .NET events, and always dispose objects a component creates on the .NET side to avoid leaking managed memory."
    why: "A component that stays subscribed or holds undisposed objects after it is removed leaks memory."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always unsubscribe event handlers from .NET events."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "At a minimum, always dispose objects created on the .NET side to avoid leaking .NET managed memory."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks component disposal"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-006
    statement: "Prefer .razor files and let the compiler deal with sequence numbers; manual render tree builder logic is advanced and unsafe, and not recommended for general component development."
    why: "Hand-written render tree logic must be correct in ways the compiler otherwise guarantees."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/advanced-scenarios?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/advanced-scenarios?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer .razor files and allow the compiler to deal with the sequence numbers."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use of manual render tree builder logic is considered an advanced and unsafe scenario, not recommended for general component development."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks for hand-written render tree builder code"
    paths: ["**/*.cs", "**/*.razor"]

  - id: BLZ-007
    statement: "Avoid creating a single large class that represents the entire global application state; prefer granular classes cascaded separately, each with specific subscriptions, so only the components that use a portion of the state are affected when it changes."
    why: "Every change to one large cascaded object affects every component that subscribes to it."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend creating granular classes, cascading them separately with specific subscriptions to ensure that only components subscribed to a specific portion of the application state are affected by changes."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid creating a single large class representing the entire global application state."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks cascading values"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-008
    statement: "Avoid thousands of component instances. For components that render at scale, such as each item in a large list or the cells of a grid, try to avoid attribute splatting. Avoid recreating delegates for many repeated elements or components, and don't trigger events too rapidly. Most Razor components don't require aggressive optimization efforts, because most components don't repeat in the UI and don't rerender at high frequency."
    why: "Rendering cost grows with how many components render and how often they rerender."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid thousands of component instances"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For components that render at scale, such as each item in a large list or in the cells of a grid, try to avoid attribute splatting."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid recreating delegates for many repeated elements or components"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't trigger events too rapidly"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Most Razor components don't require aggressive optimization efforts because most components don't repeat in the UI and don't rerender at high frequency."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks components that render in large lists or grids"
    paths: ["**/*.razor"]

  - id: BLZ-009
    statement: "Avoiding inline event handlers in favor of assigning handlers in JavaScript with addEventListener is recommended. JS collocation combined with JS modules is recommended, and inline JavaScript isn't recommended for Blazor apps. Maintaining a reference to a JSObjectReference requires disposing of it, to avoid leaking JS memory on the client. Don't execute JS interop code for DOM cleanup tasks during component disposal or when handling location changes. Avoid excessively fine-grained JS interop calls."
    why: "Script kept in modules beside its component is easier to load and maintain than inline script, each interop call has its own overhead, and a JS call made during disposal can fail once the connection or the DOM is gone."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/location-of-javascript?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-dotnet-from-javascript?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/navigation?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/performance/javascript-interoperability?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend avoiding inline event handlers in favor of approaches that assign handlers in JavaScript with addEventListener, as the following example demonstrates:"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/location-of-javascript?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend using JS collocation combined with JS modules."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/location-of-javascript?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Inline JavaScript isn't recommended for Blazor apps."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-dotnet-from-javascript?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Maintaining a reference to a JSObjectReference requires disposing of it to avoid leaking JS memory on the client."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't execute JS interop code for DOM cleanup tasks during component disposal."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/navigation?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't attempt to execute DOM cleanup tasks via JavaScript (JS) interop when handling location changes."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/performance/javascript-interoperability?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid excessively fine-grained calls"
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks JS interop"
    paths: ["**/*.razor", "**/*.razor.cs", "**/*.js"]

  - id: BLZ-010
    statement: "When adopting server-side rendering, JS interop calls must be asynchronous, and for server-side components the asynchronous invokeMethodAsync is recommended over the synchronous invokeMethod. In server-side apps with server interactivity, JS interop may fail due to networking errors and should be treated as unreliable."
    why: "Interop calls from an interactive server component travel over the network connection."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    when: [has-server-interactivity]
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-dotnet-from-javascript?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-javascript-from-dotnet?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "When adopting server-side rendering, JS interop calls must be asynchronous because they're sent over a network connection."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-dotnet-from-javascript?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For server-side components, we recommend the asynchronous function (invokeMethodAsync) over the synchronous version (invokeMethod)."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-javascript-from-dotnet?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In server-side apps with server interactivity, JavaScript (JS) interop may fail due to networking errors and should be treated as unreliable."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks JS interop in interactive server components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-011
    statement: "In interactive server-side Blazor, the app must include appropriate checks and limits before performing potentially CPU-intensive work, and, as a general recommendation, clients shouldn't be permitted to allocate an unbounded amount of memory. Always validate data when handling events, don't trust calls from JavaScript to .NET methods, and don't make authorization decisions based on the state of the UI, only from component state."
    why: "Blazor apps don't have the request and connection time-outs that guard a regular web app, and a client controls its circuit's events and JS interop calls."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    when: [has-server-interactivity]
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In regular web apps, requests and connections time out as a safeguard, but Blazor apps don't provide the same safeguards."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Blazor apps must include appropriate checks and limits before performing potentially CPU-intensive work."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "As a general recommendation, don't permit clients to allocate an unbound amount of memory as in any other server-side app that persists client connections."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always validate data when handling events."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't trust calls from JavaScript to .NET methods."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't make authorization decisions based on the state of the UI but only from component state."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks interactive server components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-012
    statement: "Rendering raw HTML constructed from any untrusted source should always be avoided, and so should rendering HTML content directly from a database. Avoid passing user-supplied data in parameters to JavaScript calls; for example, don't write user-supplied data to the DOM by setting an element's innerHTML property. Avoid using user input as part of navigation call arguments."
    why: "Each of these lets user input reach the page as markup or a navigation target, which is cross-site scripting or open redirect."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Rendering raw HTML constructed from any untrusted source is a security risk and should always be avoided."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid passing user-supplied data in parameters to JavaScript calls."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For example, don't write user-supplied data to the DOM by setting the innerHTML property of an element."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using user input as part of the navigation call arguments."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For example, rendering HTML content directly from a database should be avoided."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks MarkupString use, JS interop arguments and NavigateTo arguments"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-013
    statement: "A Content Security Policy (CSP) is recommended for Blazor apps. Avoid setting the frame-ancestors directive value to 'null' when WebSocket compression is enabled (compression is the default), because it makes the app vulnerable to malicious script injection and clickjacking attacks."
    why: "A CSP limits what script and framing a page allows, which reduces cross-site scripting and clickjacking risk."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "CSP is recommended for Blazor apps."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid setting the frame-ancestors directive value to 'null' when WebSocket compression is enabled (compression is the default) because it makes the app vulnerable to malicious script injection and clickjacking attacks."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the app's Content-Security-Policy"
    paths: ["**/Program.cs", "**/App.razor", "**/Components/**"]

  - id: BLZ-014
    statement: "Don't implement authorization checks in client-side code if enforcement must be guaranteed; always perform authorization checks on the server within any API endpoints a client-side app accesses. Don't store app secrets, connection strings, credentials, passwords, PINs, private .NET/C# code or private keys and tokens in client-side code."
    why: "Client-side code can be modified or read by the user, so it can't enforce rules or hold secrets."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If authorization rule enforcement must be guaranteed, don't implement authorization checks in client-side code."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always perform authorization checks on the server within any API endpoints accessed by your client-side app."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't store app secrets, connection strings, credentials, passwords, personal identification numbers (PINs), private .NET/C# code, or private keys/tokens in client-side code, which is always insecure."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the .Client project and WebAssembly components"
    paths: ["**/*.Client/**", "**/*.razor"]

  - id: BLZ-015
    statement: "ASP.NET Core apps that use ASP.NET Core Identity for user management should use Razor Pages instead of Razor components for Identity-related UI, such as user registration, login, logout and other user management tasks. Building Razor components that directly handle Identity tasks isn't recommended or supported by Microsoft."
    why: "Identity is designed for HTTP request and response communication, which generally isn't how a Blazor app's client and server talk. The kit's note: the Blazor Web App template's Individual Accounts option generates its account pages as Razor components, so an app that keeps them should check them against this rule (ADR-0087)."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    when: [uses-aspnet-core-identity]
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "ASP.NET Core Identity is designed to work in the context of HTTP request and response communication, which generally isn't the Blazor app client-server communication model."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "ASP.NET Core apps that use ASP.NET Core Identity for user management should use Razor Pages instead of Razor components for Identity-related UI, such as user registration, login, logout, and other user management tasks."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Building Razor components that directly handle Identity tasks is possible for several scenarios but isn't recommended or supported by Microsoft."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks where Identity UI lives"
    paths: ["**/Components/Account/**", "**/Areas/Identity/**"]

  - id: BLZ-016
    statement: "Production web apps and web APIs should use a production distributed token cache (for example Redis, SQL Server or Azure Cosmos DB). Always replace the in-memory distributed token caches with a real token cache provider when deploying the app to a production environment."
    why: "An in-memory token cache is lost on restart and not shared across instances."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Production web apps and web APIs should use a production distributed token cache (for example: Redis, Microsoft SQL Server, Microsoft Azure Cosmos DB)."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always replace the in-memory distributed token caches with a real token cache provider when deploying the app to a production environment."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the token cache registration"
    paths: ["**/Program.cs"]

  - id: BLZ-017
    statement: "Components that use the interactive WebAssembly and Auto render modes should be designed so that they run successfully from both the client and the server. If such a component must call a server project-based API, or transform a request to an external web API, when running on the client, the recommended approach is to abstract that API call behind a service interface and implement client and server versions of the service."
    why: "A component in the Auto or WebAssembly render mode runs in either place, so it can't assume one."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "This means that components using these render modes should be designed so that they run successfully from both the client and the server."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If the component must call a server project-based API or transform a request to an external web API (one that's outside of the Blazor Web App) when running on the client, the recommended approach is to abstract that API call behind a service interface and implement client and server versions of the service:"
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks data access from client-capable components"
    paths: ["**/*.Client/**", "**/*.razor"]

  - id: BLZ-018
    statement: "Don't directly inject a scoped service into a component if you intend the service lifetime to match the lifetime of the component."
    why: "A scoped service in a component lives as long as the circuit (or the app, on the client), not as long as the component."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/fundamentals/dependency-injection?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, don't directly inject a scoped service into a component if you intend the service lifetime to match the lifetime of the component."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks service lifetimes injected into components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-019
    statement: "In production, don't render framework exception messages or stack traces in the UI. Narrowly scoping error boundaries is recommended in most scenarios."
    why: "Error detail shown to users can reveal how the app works; a narrow boundary keeps one failure from replacing the whole page."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In production, don't render framework exception messages or stack traces in the UI."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend narrowly scoping error boundaries in most scenarios."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks error UI and error boundaries"
    paths: ["**/*.razor"]

  - id: BLZ-020
    statement: "During client-side rendering (CSR, InteractiveWebAssembly), state persisted during prerendering is exposed to the browser and must not contain sensitive, private information. To improve the user experience, begin by implementing streaming rendering, to avoid waiting for an asynchronous task to complete while prerendering."
    why: "Persisted prerendered state is sent to the browser; a long-running load delays the whole prerendered response."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/state-management/prerendered-state-persistence?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/components/lifecycle?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/state-management/prerendered-state-persistence?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "During client-side rendering (CSR, InteractiveWebAssembly), the data is exposed to the browser and must not contain sensitive, private information."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/lifecycle?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To improve the user experience, begin by implementing streaming rendering to avoid waiting for the asynchronous task to complete while prerendering."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks persisted component state and slow prerendered loads"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-021
    statement: "Always use the @formname directive attribute with a unique form name. To mitigate overposting, using a separate view model or data transfer object (DTO) for the form and the database in create (insert) and update operations is recommended."
    why: "A form needs a unique name to bind to its handler, and binding straight to an entity lets a client set fields the form doesn't show."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always use the @formname directive attribute with a unique form name."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To mitigate overposting, we recommend using a separate view model/data transfer object (DTO) for the form and database with create (insert) and update operations."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks forms"
    paths: ["**/*.razor"]

  - id: BLZ-022
    statement: "Outside of processing a small file, avoid reading the incoming file stream directly into memory all at once. Don't receive files from users or other untrusted sources and then make them available for immediate download without performing security checks on them. ASP-006 covers the rest of safe upload handling, including never using a client-supplied file name for saving a file."
    why: "A whole-file read lets a large upload exhaust the server's memory, and an unchecked file offered for download can carry malware to other users."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/file-uploads?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/file-downloads?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Outside of processing a small file, avoid reading the incoming file stream directly into memory all at once."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/file-downloads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't receive files from users or other untrusted sources and then make the files available for immediate download without performing security checks on the files."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks file upload and download handling"
    paths: ["**/*.razor", "**/*.razor.cs", "**/Controllers/**"]

  - id: BLZ-023
    statement: "To avoid .NET trimming problems in scenarios that rely on reflection, such as JS interop and JSON serialization, use custom types defined in non-trimmable libraries or preserve the types through linker configuration. In most cases, don't disable integrity checking of a Blazor WebAssembly app's downloaded resources."
    why: "The trimmer removes types that only reflection reaches; disabling integrity checks hides a real delivery problem instead of fixing it."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/configure-trimmer?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/bundle-caching-and-integrity-check-failures?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/configure-trimmer?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To avoid issues with .NET trimming in scenarios that rely on reflection, such as JS interop and JSON serialization, use custom types defined in non-trimmable libraries or preserve the types via linker configuration."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/bundle-caching-and-integrity-check-failures?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In most cases, don't disable integrity checking."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks trimming configuration and WebAssembly boot settings"
    paths: ["**/*.Client/**", "**/*.csproj"]

  - id: BLZ-024
    statement: "A Blazor Web App is recommended for all new Blazor development in .NET 8 or later. For interactive server-side rendering, WebSockets is the recommended transport protocol, and selecting a proxy or gateway that supports WebSockets is recommended. Server-side Blazor Web Apps hosted in a web farm or cluster of machines must adopt session affinity to maintain Blazor circuits."
    why: "Interactive server rendering keeps a user's state in a circuit on one server, which the user's connection must keep reaching."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/tooling?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/security/blazor-web-app-with-oidc?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/tooling?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "However, we recommend a Blazor Web App for all new Blazor development in .NET 8 or later."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Although Long Polling is supported for Blazor apps, WebSockets is the recommended transport protocol."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend selecting a proxy/gateway that supports WebSockets."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/blazor-web-app-with-oidc?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Server-side Blazor Web Apps hosted in a web farm or cluster of machines must adopt session affinity to maintain Blazor circuits for users of the app."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the app's project type and hosting plan"
    paths: ["**"]

  - id: BLZ-025
    statement: "If the app should localize resources based on storing a user's culture setting, use a localization culture cookie."
    why: "A cookie lets the WebSocket connection carry the culture, which a culture kept in the URL path or query string might not."
    layer: outside
    basis: authority
    status: accepted
    strength: should
    when: [localizes-by-user-culture]
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If the app should localize resources based on storing a user's culture setting, use a localization culture cookie."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use of a cookie ensures that the WebSocket connection can correctly propagate the culture."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, the recommended approach is to use a localization culture cookie."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how the app stores a user's culture"
    paths: ["**/Program.cs", "**/Components/**"]

  - id: BLZ-026
    statement: "Never reference the MAUI library from a Razor class library (RCL). RCLs should adopt host-agnostic design and shouldn't depend on specific hosting infrastructure or platform APIs. For an RCL's abstractions, prefer interfaces over abstract classes for flexibility."
    why: "A host-agnostic library works across Blazor Server, WebAssembly, Hybrid and static server-side rendering."
    layer: outside
    basis: authority
    status: accepted
    strength: must
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "RCLs should adopt host-agnostic design, where libraries are reusable UI component packages that work across different platforms, app types, Blazor hosting models (Blazor Server, Blazor WebAssembly, Blazor Hybrid/MAUI), and static server-side rendering."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "RCLs shouldn't depend on specific hosting infrastructure or platform APIs:"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never reference the MAUI library from RCL."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer interfaces over abstract classes for flexibility."
    scope: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the references of shared Razor class libraries"
    paths: ["**/*.csproj"]

---

# Blazor

Rules from Microsoft's ASP.NET Core Blazor documentation (aspnetcore-10.0): component design, rendering, JavaScript interop, state, forms, security and hosting for Blazor Web Apps, and for Razor components in Blazor Hybrid apps. Each rule states what its cited page says, at the page's strength, and stores the sentences that say it. Accessibility is in `ui.md` (UI-); general security is in `security.md` (SEC-).

Every rule here has its page's strength (ADR-0090).
