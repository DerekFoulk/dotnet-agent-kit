# Microsoft Learn inventory: ASP.NET Core and Blazor guidance

Batches D-aspnetcore and D-blazor read this set, and batch R3 read its host-and-deploy pages. The AspNetCore.Docs table of contents lists 872 pages. 167 were candidates. They produced ASP-001 to ASP-024, BLZ-001 to BLZ-028 and OPS-013, OPS-014 and OPS-016. Pages are under https://learn.microsoft.com/aspnet/core/. Pages with no verdict row here were candidates that a batch folded into a neighbouring page's row. Every verdict was checked on 2026-11-17.

The page list for this set, with every page's guidance-wording score, is in `docs/inventory/aspnetcore-pages.tsv`. Re-check with the `discover-guidance` skill.

| Page | Checked | Verdict |
|---|---|---|
| https://learn.microsoft.com/aspnet/core/client-side/dotnet-interop | 2026-11-17 | out of scope: Blazor WebAssembly JS interop (Blazor batch) |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/complex-data-model | 2026-11-17 | no guidance (tutorial) |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/concurrency | 2026-11-17 | covered by DAT-008 |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/crud | 2026-11-17 | covered by ASP-011 (overposting); paging by DAT-009 |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/intro | 2026-11-17 | covered by DAT-009 (paging, context not thread safe is tutorial text) |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/migrations | 2026-11-17 | covered by DAT-004 |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/sort-filter-page | 2026-11-17 | no guidance (tutorial) |
| https://learn.microsoft.com/aspnet/core/data/ef-rp/update-related-data | 2026-11-17 | no guidance (tutorial) |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0003 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0004 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0006 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0008 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0009 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0010 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/asp0038 | 2026-11-17 | no guidance (title only) |
| https://learn.microsoft.com/aspnet/core/diagnostics/bl0005 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/bl0006 | 2026-11-17 | new rule ASP-016 |
| https://learn.microsoft.com/aspnet/core/diagnostics/code-analysis | 2026-11-17 | no guidance (table of IDs) |
| https://learn.microsoft.com/aspnet/core/fundamentals/ | 2026-11-17 | out of scope: overview; Generic Host and Key Vault advice is hosting or Azure-specific (hosting batch) |
| https://learn.microsoft.com/aspnet/core/fundamentals/apis | 2026-11-17 | covered by API-001 |
| https://learn.microsoft.com/aspnet/core/fundamentals/app-state | 2026-11-17 | new rules ASP-004, ASP-008 |
| https://learn.microsoft.com/aspnet/core/fundamentals/best-practices | 2026-11-17 | covered by OPS-007 |
| https://learn.microsoft.com/aspnet/core/fundamentals/configuration/ | 2026-11-17 | new rule ASP-002 |
| https://learn.microsoft.com/aspnet/core/fundamentals/configuration/options | 2026-11-17 | covered by OPS-006 |
| https://learn.microsoft.com/aspnet/core/fundamentals/dependency-injection | 2026-11-17 | new rule ASP-001 |
| https://learn.microsoft.com/aspnet/core/fundamentals/error-handling | 2026-11-17 | covered by API-002 |
| https://learn.microsoft.com/aspnet/core/fundamentals/http-requests | 2026-11-17 | covered by OPS-003; new rule ASP-024 (handler lifetime) |
| https://learn.microsoft.com/aspnet/core/fundamentals/localization/provide-resources | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/fundamentals/logging/ | 2026-11-17 | new rule ASP-003 |
| https://learn.microsoft.com/aspnet/core/fundamentals/metapackage | 2026-11-17 | out of scope: ASP.NET Core 2.0 metapackage |
| https://learn.microsoft.com/aspnet/core/fundamentals/native-aot | 2026-11-17 | out of scope: opt-in feature |
| https://learn.microsoft.com/aspnet/core/fundamentals/routing | 2026-11-17 | new rule ASP-015 |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/httpsys | 2026-11-17 | out of scope: Windows-only alternative server, rarely used |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/endpoints | 2026-11-17 | covered by SEC-011 |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/kestrel/security-considerations | 2026-11-17 | covered by SEC-011 |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/yarp/extensibility-transforms | 2026-11-17 | out of scope: YARP is a separate product |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/yarp/header-guidelines | 2026-11-17 | out of scope: YARP |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/yarp/http-client-config | 2026-11-17 | out of scope: YARP |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/yarp/middleware | 2026-11-17 | out of scope: YARP |
| https://learn.microsoft.com/aspnet/core/fundamentals/servers/yarp/session-affinity | 2026-11-17 | out of scope: YARP |
| https://learn.microsoft.com/aspnet/core/fundamentals/static-files | 2026-11-17 | new rule ASP-007 |
| https://learn.microsoft.com/aspnet/core/fundamentals/troubleshoot-aspnet-core-localization | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/fundamentals/url-rewriting | 2026-11-17 | covered by SEC-011 (HTTPS redirection) |
| https://learn.microsoft.com/aspnet/core/grpc/client | 2026-11-17 | new rule ASP-017 |
| https://learn.microsoft.com/aspnet/core/grpc/performance | 2026-11-17 | new rule ASP-017 |
| https://learn.microsoft.com/aspnet/core/grpc/security | 2026-11-17 | new rule ASP-018 |
| https://learn.microsoft.com/aspnet/core/grpc/supported-platforms | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/mvc/advanced/app-parts | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/mvc/advanced/custom-model-binding | 2026-11-17 | new rule ASP-011 |
| https://learn.microsoft.com/aspnet/core/mvc/controllers/filters | 2026-11-17 | new rule ASP-010 |
| https://learn.microsoft.com/aspnet/core/mvc/models/file-uploads | 2026-11-17 | new rule ASP-006 |
| https://learn.microsoft.com/aspnet/core/mvc/models/model-binding | 2026-11-17 | new rule ASP-011 |
| https://learn.microsoft.com/aspnet/core/mvc/views/overview | 2026-11-17 | new rule ASP-013 |
| https://learn.microsoft.com/aspnet/core/mvc/views/partial | 2026-11-17 | new rule ASP-013 |
| https://learn.microsoft.com/aspnet/core/mvc/views/razor | 2026-11-17 | new rule ASP-013 (Raw); `@code` advice is Blazor batch |
| https://learn.microsoft.com/aspnet/core/mvc/views/tag-helpers/authoring | 2026-11-17 | no guidance (naming conventions) |
| https://learn.microsoft.com/aspnet/core/mvc/views/view-components | 2026-11-17 | no guidance (naming and layout conventions) |
| https://learn.microsoft.com/aspnet/core/performance/caching/hybrid | 2026-11-17 | new rule ASP-008 |
| https://learn.microsoft.com/aspnet/core/performance/caching/memory | 2026-11-17 | new rule ASP-008 |
| https://learn.microsoft.com/aspnet/core/performance/caching/middleware | 2026-11-17 | new rule ASP-009 |
| https://learn.microsoft.com/aspnet/core/performance/caching/response | 2026-11-17 | new rule ASP-009 |
| https://learn.microsoft.com/aspnet/core/performance/overview | 2026-11-17 | no guidance (link list) |
| https://learn.microsoft.com/aspnet/core/performance/response-compression | 2026-11-17 | no guidance (tuning detail; compression thresholds) |
| https://learn.microsoft.com/aspnet/core/razor-pages/ | 2026-11-17 | new rules ASP-011, ASP-014 |
| https://learn.microsoft.com/aspnet/core/razor-pages/razor-pages-conventions | 2026-11-17 | new rule ASP-014 |
| https://learn.microsoft.com/aspnet/core/security/ | 2026-11-17 | new rule ASP-002 (connection string); secrets also SEC-001 |
| https://learn.microsoft.com/aspnet/core/security/anti-request-forgery | 2026-11-17 | new rules ASP-005, ASP-023 |
| https://learn.microsoft.com/aspnet/core/security/app-secrets | 2026-11-17 | new rule ASP-002 |
| https://learn.microsoft.com/aspnet/core/security/authentication/ | 2026-11-17 | no guidance (multi-tenant recommends third-party frameworks only) |
| https://learn.microsoft.com/aspnet/core/security/authentication/accconfirm | 2026-11-17 | out of scope: email-service tutorial |
| https://learn.microsoft.com/aspnet/core/security/authentication/certauth | 2026-11-17 | no guidance (niche; client certificate auth) |
| https://learn.microsoft.com/aspnet/core/security/authentication/configure-jwt-bearer-authentication | 2026-11-17 | covered by SEC-008 |
| https://learn.microsoft.com/aspnet/core/security/authentication/configure-oidc-web-authentication | 2026-11-17 | new rule ASP-021 |
| https://learn.microsoft.com/aspnet/core/security/authentication/passkeys/ | 2026-11-17 | out of scope: optional feature; registration limits advice is niche |
| https://learn.microsoft.com/aspnet/core/security/authentication/scaffold-identity | 2026-11-17 | new rule ASP-022 |
| https://learn.microsoft.com/aspnet/core/security/authorization/custom-authorization-policy-providers | 2026-11-17 | no guidance (niche API) |
| https://learn.microsoft.com/aspnet/core/security/data-protection/configuration/overview | 2026-11-17 | new rule ASP-023 |
| https://learn.microsoft.com/aspnet/core/security/data-protection/consumer-apis/purpose-strings | 2026-11-17 | new rule ASP-023 |
| https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-management | 2026-11-17 | no guidance (advanced key APIs) |
| https://learn.microsoft.com/aspnet/core/security/data-protection/implementation/key-storage-providers | 2026-11-17 | new rule ASP-023 |
| https://learn.microsoft.com/aspnet/core/security/enforcing-ssl | 2026-11-17 | covered by SEC-011 |
| https://learn.microsoft.com/aspnet/core/security/samesite | 2026-11-17 | no guidance (cookie compatibility detail) |
| https://learn.microsoft.com/aspnet/core/signalr/client-features | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/signalr/hubs | 2026-11-17 | new rule ASP-019 |
| https://learn.microsoft.com/aspnet/core/signalr/javascript-client | 2026-11-17 | out of scope: JavaScript client detail |
| https://learn.microsoft.com/aspnet/core/signalr/messagepackhubprotocol | 2026-11-17 | out of scope: optional protocol, old CVE |
| https://learn.microsoft.com/aspnet/core/signalr/scale | 2026-11-17 | new rule ASP-020 |
| https://learn.microsoft.com/aspnet/core/signalr/security | 2026-11-17 | new rule ASP-020 |
| https://learn.microsoft.com/aspnet/core/web-api/ | 2026-11-17 | new rule ASP-012 |
| https://learn.microsoft.com/aspnet/core/web-api/http-repl/ | 2026-11-17 | out of scope: tooling how-to |
| https://learn.microsoft.com/aspnet/core/blazor/advanced-scenarios | 2026-11-17 | BLZ-006 |
| https://learn.microsoft.com/aspnet/core/blazor/call-web-api | 2026-11-17 | BLZ-016, BLZ-017 (other sentences mangled in extract or descriptive) |
| https://learn.microsoft.com/aspnet/core/blazor/components/ | 2026-11-17 | BLZ-002, BLZ-012 |
| https://learn.microsoft.com/aspnet/core/blazor/components/cascading-values-and-parameters | 2026-11-17 | BLZ-007 |
| https://learn.microsoft.com/aspnet/core/blazor/components/class-libraries-and-static-server-side-rendering | 2026-11-17 | BLZ-001 |
| https://learn.microsoft.com/aspnet/core/blazor/components/component-disposal | 2026-11-17 | BLZ-005 |
| https://learn.microsoft.com/aspnet/core/blazor/components/css-isolation | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/blazor/components/data-binding | 2026-11-17 | BLZ-002, BLZ-003 |
| https://learn.microsoft.com/aspnet/core/blazor/components/event-handling | 2026-11-17 | covered by BLZ-008 (loop-variable lambda sentence; other sentences mangled); no separate rule |
| https://learn.microsoft.com/aspnet/core/blazor/components/integration | 2026-11-17 | covered by BLZ-020 (prerender state) |
| https://learn.microsoft.com/aspnet/core/blazor/components/integration-hosted-webassembly | 2026-11-17 | out of scope (hosted WASM, deprecated model); prerender point covered by BLZ-020 |
| https://learn.microsoft.com/aspnet/core/blazor/components/js-spa-frameworks | 2026-11-17 | out of scope (JS SPA integration) |
| https://learn.microsoft.com/aspnet/core/blazor/components/layouts | 2026-11-17 | no rule written (one DO NOT: root @layout loop; trivia) |
| https://learn.microsoft.com/aspnet/core/blazor/components/lifecycle | 2026-11-17 | BLZ-020 (streaming sentence); rest mangled in extract (API names stripped), no rule; not verified against the local file |
| https://learn.microsoft.com/aspnet/core/blazor/components/overwriting-parameters | 2026-11-17 | covered by BLZ-002 |
| https://learn.microsoft.com/aspnet/core/blazor/components/quickgrid | 2026-11-17 | out of scope (one control) |
| https://learn.microsoft.com/aspnet/core/blazor/components/render-modes | 2026-11-17 | BLZ-001 |
| https://learn.microsoft.com/aspnet/core/blazor/components/rendering | 2026-11-17 | no rule (sentences mangled or descriptive); perf covered by BLZ-008 |
| https://learn.microsoft.com/aspnet/core/blazor/components/synchronization-context | 2026-11-17 | BLZ-004 |
| https://learn.microsoft.com/aspnet/core/blazor/components/virtualization | 2026-11-17 | no guidance (layout caveats for one control) |
| https://learn.microsoft.com/aspnet/core/blazor/file-downloads | 2026-11-17 | BLZ-022 |
| https://learn.microsoft.com/aspnet/core/blazor/file-uploads | 2026-11-17 | BLZ-022 |
| https://learn.microsoft.com/aspnet/core/blazor/forms/ | 2026-11-17 | BLZ-021 |
| https://learn.microsoft.com/aspnet/core/blazor/forms/binding | 2026-11-17 | no rule (guidance sentences mangled); overposting covered by BLZ-021 |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/ | 2026-11-17 | no guidance |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/dependency-injection | 2026-11-17 | BLZ-018 |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/handle-errors | 2026-11-17 | BLZ-006, BLZ-019 |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/navigation | 2026-11-17 | BLZ-009 |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/routing | 2026-11-17 | no guidance worth a rule (niche) |
| https://learn.microsoft.com/aspnet/core/blazor/fundamentals/static-files | 2026-11-17 | out of scope (niche API) |
| https://learn.microsoft.com/aspnet/core/blazor/globalization-localization | 2026-11-17 | BLZ-003, BLZ-025 |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/app-base-path | 2026-11-17 | out of scope (sub-app hosting detail) |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/configure-trimmer | 2026-11-17 | BLZ-023 |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/ | 2026-11-17 | out of scope (hosting how-to, Azure Static Web Apps) |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/bundle-caching-and-integrity-check-failures | 2026-11-17 | BLZ-023 |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/deployment-layout | 2026-11-17 | out of scope (workaround for blocked DLLs) |
| https://learn.microsoft.com/aspnet/core/blazor/host-and-deploy/webassembly/http-caching-issues | 2026-11-17 | out of scope (upgrade troubleshooting) |
| https://learn.microsoft.com/aspnet/core/blazor/hosting-models | 2026-11-17 | no guidance (choice table); Azure SignalR advice out of scope |
| https://learn.microsoft.com/aspnet/core/blazor/hybrid/class-libraries-best-practices | 2026-11-17 | BLZ-026 |
| https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/ | 2026-11-17 | BLZ-027 |
| https://learn.microsoft.com/aspnet/core/blazor/hybrid/security/security-considerations | 2026-11-17 | BLZ-028, BLZ-012 |
| https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/ | 2026-11-17 | BLZ-009, BLZ-010 |
| https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-dotnet-from-javascript | 2026-11-17 | BLZ-009, BLZ-010 |
| https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/call-javascript-from-dotnet | 2026-11-17 | BLZ-010 |
| https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/location-of-javascript | 2026-11-17 | BLZ-009 |
| https://learn.microsoft.com/aspnet/core/blazor/javascript-interoperability/static-server-rendering | 2026-11-17 | out of scope (one rarely used pattern) |
| https://learn.microsoft.com/aspnet/core/blazor/performance/app-download-size | 2026-11-17 | out of scope (WASM size settings; sentences mangled) |
| https://learn.microsoft.com/aspnet/core/blazor/performance/javascript-interoperability | 2026-11-17 | BLZ-009 |
| https://learn.microsoft.com/aspnet/core/blazor/performance/rendering | 2026-11-17 | BLZ-008 |
| https://learn.microsoft.com/aspnet/core/blazor/progressive-web-app/push-notifications | 2026-11-17 | out of scope (PWA push) |
| https://learn.microsoft.com/aspnet/core/blazor/security/ | 2026-11-17 | BLZ-014, BLZ-015 |
| https://learn.microsoft.com/aspnet/core/blazor/security/account-confirmation-and-password-recovery | 2026-11-17 | out of scope (email service/Azure); secrets advice not kit-wide here |
| https://learn.microsoft.com/aspnet/core/blazor/security/blazor-web-app-with-entra | 2026-11-17 | BLZ-016, BLZ-024 (session affinity); rest Entra-specific, out of scope |
| https://learn.microsoft.com/aspnet/core/blazor/security/blazor-web-app-with-oidc | 2026-11-17 | BLZ-024 (session affinity); rest IdP-specific, out of scope |
| https://learn.microsoft.com/aspnet/core/blazor/security/content-security-policy | 2026-11-17 | BLZ-013 |
| https://learn.microsoft.com/aspnet/core/blazor/security/interactive-server-side-rendering | 2026-11-17 | BLZ-011, BLZ-012, BLZ-024 |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/ | 2026-11-17 | BLZ-014 |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/additional-scenarios | 2026-11-17 | out of scope (token-handling API detail) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/graph-api | 2026-11-17 | out of scope (Microsoft Graph specific) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/hosted-with-identity-server | 2026-11-17 | out of scope (deprecated, hosted WASM) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/hosted-with-microsoft-entra-id | 2026-11-17 | out of scope (Entra specific, hosted WASM) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/microsoft-entra-id-groups-and-roles | 2026-11-17 | out of scope (Entra specific) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/microsoft-entra-id-groups-and-roles-net-5-to-7 | 2026-11-17 | out of scope (.NET 5 to 7) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/standalone-with-identity/ | 2026-11-17 | out of scope (standalone WASM Identity how-to) |
| https://learn.microsoft.com/aspnet/core/blazor/security/webassembly/standalone-with-identity/account-confirmation-and-password-recovery | 2026-11-17 | out of scope |
| https://learn.microsoft.com/aspnet/core/blazor/state-management/prerendered-state-persistence | 2026-11-17 | BLZ-020 |
| https://learn.microsoft.com/aspnet/core/blazor/state-management/protected-browser-storage | 2026-11-17 | no rule (state-provider pattern only) |
| https://learn.microsoft.com/aspnet/core/blazor/tooling | 2026-11-17 | BLZ-024 |
| https://learn.microsoft.com/aspnet/core/blazor/webassembly-lazy-load-assemblies | 2026-11-17 | out of scope (one rarely used feature) |
| https://learn.microsoft.com/aspnet/core/host-and-deploy/aspnet-core-module | 2026-11-17 | out of scope: IIS module configuration how-to |
| https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/ | 2026-11-17 | new rules OPS-013 (data protection key store) and OPS-014 (background-only app: Windows Service, not IIS); rest out of scope (IIS-specific configuration); web.config, app pools, bindings omitted |
| https://learn.microsoft.com/aspnet/core/host-and-deploy/iis/advanced | 2026-11-17 | covered by OPS-013 and OPS-014; rest IIS-specific, out of scope |
| https://learn.microsoft.com/aspnet/core/host-and-deploy/linux-nginx | 2026-11-17 | new rules OPS-013, OPS-016 (KillSignal); forwarded headers, HTTPS redirection and HSTS are covered by security.md rules (not my file, not quoted); nginx config how-to out of scope |
