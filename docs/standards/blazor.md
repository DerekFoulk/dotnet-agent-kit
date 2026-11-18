---
topic: blazor
rules:
  - id: BLZ-001
    statement: "Avoid coupling a component's implementation to a specific render mode: design components to support any render mode or hosting model. A reusable component should not specify a render mode, even when it needs interactivity, unless its implementation is fundamentally coupled to one mode."
    why: "A component that assumes where it runs breaks when an app picks a different render mode, and a library component that sets a render mode takes the choice from the app author."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/components/class-libraries-and-static-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/render-modes?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Component authors should avoid coupling a component's implementation to a specific render mode."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/class-libraries-and-static-server-side-rendering?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In most cases, reusable component authors should not specify a render mode, even when interactivity is required."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks that components don't assume a render mode and that library components leave @rendermode to the app"
    paths: ["**/*.razor"]

  - id: BLZ-002
    statement: "Avoid creating components that write directly to their own component parameters. Declare parameters as auto properties with no custom logic in their get or set accessors, and don't use the required modifier or an init accessor on them."
    why: "A parameter is a channel from parent to child; writing to it overwrites the parent's state when the component rerenders."
    layer: outside
    basis: authority
    status: proposed
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
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks component parameters"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-003
    statement: "For two-way data binding, use @bind:get and @bind:set rather than an event handler. Don't specify a culture with @bind:culture on date and number field types."
    why: "An event handler used for two-way binding can leave the displayed value out of step with the bound value; Blazor already formats date and number fields for the user's culture."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/data-binding?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For two-way data binding, we recommend using @bind:get/@bind:set modifiers."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, specifying a culture with @bind:culture isn't recommended when using the date and number field types."
    projectTypes: [blazor, blazor-hybrid]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid thread-blocking calls"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In the event a component must be updated based on an external event, such as a timer or other notification, use the InvokeAsync method, which dispatches code execution to Blazor's synchronization context."
    projectTypes: [blazor, blazor-hybrid]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always unsubscribe event handlers from .NET events."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "At a minimum, always dispose objects created on the .NET side to avoid leaking .NET managed memory."
    projectTypes: [blazor, blazor-hybrid]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/advanced-scenarios?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/advanced-scenarios?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer .razor files and allow the compiler to deal with the sequence numbers."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Use of manual render tree builder logic is considered an advanced and unsafe scenario, not recommended for general component development."
    projectTypes: [blazor, blazor-hybrid]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend creating granular classes, cascading them separately with specific subscriptions to ensure that only components subscribed to a specific portion of the application state are affected by changes."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid creating a single large class representing the entire global application state."
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks cascading values"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-008
    statement: "Where rendering is expensive or measured to cause UI lag, avoid thousands of component instances, avoid attribute splatting for components that render at scale, avoid recreating delegates for many repeated elements or components, and don't trigger events too rapidly. Most components don't need this optimization."
    why: "Rendering cost grows with component count and repeated work; the page itself says most components need no aggressive optimization."
    layer: outside
    basis: authority
    status: proposed
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
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks components that render in large lists or grids"
    paths: ["**/*.razor"]

  - id: BLZ-009
    statement: "Avoid inline event handlers in JavaScript that Blazor calls; assign handlers in JavaScript with addEventListener. Use JS collocation combined with JS modules, and avoid inline JavaScript. Dispose a JSObjectReference you hold to avoid leaking JS memory, and don't run JS interop for DOM cleanup tasks during component disposal or location changes. Avoid excessively fine-grained JS interop calls."
    why: "Inline script and per-item interop calls are costly and hard to unload; disposal-time JS calls can fail once the connection or DOM is gone."
    layer: outside
    basis: authority
    status: proposed
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
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks JS interop"
    paths: ["**/*.razor", "**/*.razor.cs", "**/*.js"]

  - id: BLZ-010
    statement: "In server-side components, JS interop calls must be asynchronous, and invokeMethodAsync is recommended over invokeMethod; treat JS interop as unreliable because it can fail on network errors."
    why: "Interop calls from an interactive server component travel over the network connection."
    layer: outside
    basis: authority
    status: proposed
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
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks JS interop in interactive server components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-011
    statement: "In interactive server-side Blazor, include appropriate checks and limits before potentially CPU-intensive work, and don't let clients allocate an unbounded amount of memory. Always validate data when handling events, don't trust calls from JavaScript to .NET methods, and don't make authorization decisions from the state of the UI, only from component state."
    why: "Blazor apps have no request time-out safeguards, and a client controls its circuit's events and JS interop calls."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
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
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks interactive server components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-012
    statement: "Avoid rendering raw HTML built from an untrusted source. Avoid passing user-supplied data in parameters to JavaScript calls (for example, don't write it to innerHTML), and avoid using user input as part of navigation call arguments."
    why: "Each of these lets user input reach the page as markup or a navigation target, which is cross-site scripting or open redirect."
    layer: outside
    basis: authority
    status: proposed
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
        text: "Avoid using user input as part of the navigation call arguments."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For example, rendering HTML content directly from a database should be avoided."
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks MarkupString use, JS interop arguments and NavigateTo arguments"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-013
    statement: "Use a Content Security Policy in Blazor apps. When WebSocket compression is enabled (the default), avoid setting the frame-ancestors directive to 'null'."
    why: "A CSP reduces cross-site scripting and clickjacking risk; a 'null' frame-ancestors value with compression enabled opens the app to both."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "CSP is recommended for Blazor apps."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid setting the frame-ancestors directive value to 'null' when WebSocket compression is enabled (compression is the default) because it makes the app vulnerable to malicious script injection and clickjacking attacks."
    projectTypes: [blazor]
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
    status: proposed
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
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the .Client project and WebAssembly components"
    paths: ["**/*.Client/**", "**/*.razor"]

  - id: BLZ-015
    statement: "Use Razor Pages instead of Razor components for ASP.NET Core Identity UI such as registration, login, logout and other user management; building Razor components that directly handle Identity tasks isn't recommended."
    why: "Microsoft says components that directly handle Identity tasks aren't recommended or supported by Microsoft. Note that the Blazor Web App template's own Identity UI is built from components, so a project that scaffolds it departs from this advice."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "ASP.NET Core apps that use ASP.NET Core Identity for user management should use Razor Pages instead of Razor components for Identity-related UI, such as user registration, login, logout, and other user management tasks."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Building Razor components that directly handle Identity tasks is possible for several scenarios but isn't recommended or supported by Microsoft."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks where Identity UI lives"
    paths: ["**/Components/Account/**", "**/Areas/Identity/**"]

  - id: BLZ-016
    statement: "Use a production distributed token cache (for example Redis, SQL Server or Azure Cosmos DB) in production web apps and web APIs, and always replace the in-memory distributed token caches with a real token cache provider when deploying to production."
    why: "An in-memory token cache is lost on restart and not shared across instances."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Production web apps and web APIs should use a production distributed token cache (for example: Redis, Microsoft SQL Server, Microsoft Azure Cosmos DB)."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always replace the in-memory distributed token caches with a real token cache provider when deploying the app to a production environment."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the token cache registration"
    paths: ["**/Program.cs"]

  - id: BLZ-017
    statement: "When a component must call a server project-based API (or transform a request to an external web API) and can run on the client, abstract the call behind a service interface and implement client and server versions of the service. Design components that use these render modes to run successfully from both the client and the server."
    why: "A component in the Auto or WebAssembly render mode runs in either place, so it can't assume one."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/call-web-api?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If the component must call a server project-based API or transform a request to an external web API (one that's outside of the Blazor Web App) when running on the client, the recommended approach is to abstract that API call behind a service interface and implement client and server versions of the service:"
    projectTypes: [blazor]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/fundamentals/dependency-injection?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/dependency-injection?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, don't directly inject a scoped service into a component if you intend the service lifetime to match the lifetime of the component."
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks service lifetimes injected into components"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-019
    statement: "In production, don't render framework exception messages or stack traces in the UI. Narrowly scope error boundaries in most scenarios."
    why: "Error detail shown to users can reveal how the app works; a narrow boundary keeps one failure from replacing the whole page."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In production, don't render framework exception messages or stack traces in the UI."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "We recommend narrowly scoping error boundaries in most scenarios."
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks error UI and error boundaries"
    paths: ["**/*.razor"]

  - id: BLZ-020
    statement: "State persisted during prerendering must not contain sensitive, private information when it is exposed to the browser (client-side and Auto render modes). To avoid waiting on slow asynchronous work while prerendering, begin by implementing streaming rendering."
    why: "Persisted prerendered state is sent to the browser; a long-running load delays the whole prerendered response."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/state-management/prerendered-state-persistence?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/components/lifecycle?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/state-management/prerendered-state-persistence?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "During client-side rendering (CSR, InteractiveWebAssembly), the data is exposed to the browser and must not contain sensitive, private information."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/components/lifecycle?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To improve the user experience, begin by implementing streaming rendering to avoid waiting for the asynchronous task to complete while prerendering."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks persisted component state and slow prerendered loads"
    paths: ["**/*.razor", "**/*.razor.cs"]

  - id: BLZ-021
    statement: "Always use the @formname directive attribute with a unique form name. To mitigate overposting, use a separate view model or data transfer object (DTO) for the form, apart from the database entity, for create and update operations."
    why: "A form needs a unique name to bind to its handler, and binding straight to an entity lets a client set fields the form doesn't show."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Always use the @formname directive attribute with a unique form name."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/forms/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To mitigate overposting, we recommend using a separate view model/data transfer object (DTO) for the form and database with create (insert) and update operations."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks forms"
    paths: ["**/*.razor"]

  - id: BLZ-022
    statement: "Outside of processing a small file, avoid reading an incoming file stream into memory all at once. Never use a client-supplied file name for saving a file to physical storage. Don't make an uploaded file available for immediate download without security checks."
    why: "Whole-file reads allow denial of service; a client-chosen name can overwrite files or write outside the app."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/file-uploads?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/file-downloads?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Outside of processing a small file, avoid reading the incoming file stream directly into memory all at once."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/file-uploads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never use a client-supplied file name for saving a file to physical storage."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/file-downloads?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't receive files from users or other untrusted sources and then make the files available for immediate download without performing security checks on the files."
    projectTypes: [blazor]
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
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/configure-trimmer?view=aspnetcore-10.0, retrieved 2026-11-17", "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/bundle-caching-and-integrity-check-failures?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/configure-trimmer?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "To avoid issues with .NET trimming in scenarios that rely on reflection, such as JS interop and JSON serialization, use custom types defined in non-trimmable libraries or preserve the types via linker configuration."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/bundle-caching-and-integrity-check-failures?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "In most cases, don't disable integrity checking."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks trimming configuration and WebAssembly boot settings"
    paths: ["**/*.Client/**", "**/*.csproj"]

  - id: BLZ-024
    statement: "Start new Blazor development with a Blazor Web App (.NET 8 or later). Host interactive server-side apps with WebSockets as the transport (select a proxy or gateway that supports WebSockets), and use session affinity when a web farm or cluster hosts them."
    why: "Microsoft recommends the Blazor Web App for all new development; interactive server rendering keeps its state in a circuit that a user's requests must reach."
    layer: outside
    basis: authority
    status: proposed
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
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the app's project type and hosting plan"
    paths: ["**"]

  - id: BLZ-025
    statement: "Use a localization culture cookie to localize resources by a user's stored culture setting."
    why: "Microsoft's page names the cookie as its recommended approach for a stored culture."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/globalization-localization?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Therefore, the recommended approach is to use a localization culture cookie."
    projectTypes: [blazor]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks how the app stores a user's culture"
    paths: ["**/Program.cs", "**/Components/**"]

  - id: BLZ-026
    statement: "Never reference the MAUI library from a Razor class library that holds shared components. Such a library should be host-agnostic, not depending on specific hosting infrastructure or platform APIs, and prefer interfaces over abstract classes."
    why: "A host-agnostic library works across Blazor Server, WebAssembly, Hybrid and static server-side rendering."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "RCLs shouldn't depend on specific hosting infrastructure or platform APIs:"
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Never reference the MAUI library from RCL."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Prefer interfaces over abstract classes for flexibility."
    projectTypes: [blazor, blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks the references of shared Razor class libraries"
    paths: ["**/*.csproj"]

  - id: BLZ-027
    statement: "In a Blazor Hybrid app, avoid authentication in the context of the Web View: don't implement the authentication workflow yourself, don't use the Web View control to perform authentication, and avoid passing tokens to the document context (JavaScript)."
    why: "Tokens obtained in the Web View are open to third-party scripts; native apps can obtain tokens outside the browser context."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid authentication in the context of the Web View."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid implementing the authentication workflow yourself."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid using the platform's Web View control to perform authentication."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Avoid passing the tokens to the document context (JavaScript)."
    projectTypes: [blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks sign-in in Blazor Hybrid apps"
    paths: ["**/*.razor", "**/*.cs"]

  - id: BLZ-028
    statement: "In a Blazor Hybrid app, treat code inside the Web View as untrusted and validate anything that comes from it (events, JS interop). Don't store credentials, security tokens or sensitive user data in the Web View's context, and avoid loading content from a third-party origin. Establishing a CSP is recommended."
    why: "A compromised Web View exposes whatever it holds and can attack the host system through events and interop."
    layer: outside
    basis: authority
    status: proposed
    sources: ["https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0, retrieved 2026-11-17"]
    quotes:
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Consider the code inside the Web View as untrusted in the same way that code running inside the browser for a web app isn't trusted."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "For that reason, any content coming from the Web View (events, JS interop) must be treated as untrusted and validated in the same way as for other sensitive contexts, such as in a compromised Blazor Server app that can lead to malicious attacks on the host system."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Don't store sensitive information, such as credentials, security tokens, or sensitive user data, in the context of the Web View, as it makes the information available to a cyberattacker if the Web View is compromised."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "If possible, avoid loading content from a third-party origin."
      - source: "https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations?view=aspnetcore-10.0"
        retrieved: "2026-11-17"
        text: "Establishing a CSP is recommended to reduce these security risks."
    projectTypes: [blazor-hybrid]
    enforcement:
      - kind: advisory
        in: [kit, app]
        how: "code review checks what a Blazor Hybrid app loads and stores in its Web View"
    paths: ["**/*.razor", "**/*.cs", "**/wwwroot/**"]
---

# Blazor

Rules from Microsoft's ASP.NET Core Blazor documentation (aspnetcore-10.0): component design, rendering, JavaScript interop, state, forms, security and hosting for Blazor Web Apps, and for Razor components in Blazor Hybrid apps. Each rule states what its cited page says, at the page's strength, and stores the sentences that say it. Accessibility is in `ui.md` (UI-); general security is in `security.md` (SEC-).

All rules here are `status: proposed` until the owner accepts them.
