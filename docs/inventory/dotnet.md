# Microsoft Learn inventory: .NET guidance (C#, libraries, hosting, testing, deployment)

Batches D-csharp, D-dotnet, R7 (hosting), R4 (testing) and R3 (deploy) read this set. The dotnet/docs table of contents lists 4,771 pages. 408 were candidates. The rows below give the verdicts the batches reported, 187 rows, some grouping several pages of one family (the code analysis rules). They produced CS-001 to CS-039, NET-001 to NET-003, HST-001 to HST-005, TST-012 and OPS-015. The excluded folders (install, porting, tools, compatibility, design-guidelines) hold candidates that no batch read: install, porting, tools and compatibility are how-to and migration pages, not guidance for code, and design-guidelines (Framework Design Guidelines) was covered by the owner's earlier 94-page audit. Paths in backticks are relative to https://learn.microsoft.com/dotnet/. Every verdict was checked on 2026-11-17.

The page list for this set, with every page's guidance-wording score, is in `docs/inventory/dotnet-pages.tsv`. Re-check with the `discover-guidance` skill.

| Page | Checked | Verdict |
|---|---|---|
| https://learn.microsoft.com/dotnet/csharp/advanced-topics/interface-implementation/mixins-with-default-interface-methods | 2026-11-17 | new rule CS-018 |
| https://learn.microsoft.com/dotnet/csharp/advanced-topics/performance/ | 2026-11-17 | new rule CS-010 (other sentences describe struct/class trade-offs) |
| https://learn.microsoft.com/dotnet/csharp/advanced-topics/performance/ref-tutorial | 2026-11-17 | no guidance (tutorial walk-through; its advice repeats the performance page, CS-010) |
| https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/async-scenarios | 2026-11-17 | covered by STY-011 and STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/csharp/asynchronous-programming/task-asynchronous-programming-model | 2026-11-17 | covered by STY-007 (the "Async" suffix convention) |
| https://learn.microsoft.com/dotnet/csharp/delegates-patterns | 2026-11-17 | no guidance (design walk-through; "often a good practice" is not a recommendation) |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions | 2026-11-17 | covered by STY-007 |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/identifier-names | 2026-11-17 | covered by STY-007 |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/exceptions/creating-and-throwing-exceptions | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/patterns/discards | 2026-11-17 | new rules CS-001, CS-002 |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/strings/common-tasks/compare | 2026-11-17 | covered by STY-012 (best-practices-strings says the same: pass an explicit comparison) |
| https://learn.microsoft.com/dotnet/csharp/fundamentals/types/built-in-types | 2026-11-17 | new rules CS-003, CS-004 (its `var` advice is STY-002) |
| https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/general | 2026-11-17 | new rules CS-005, CS-006 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/attributes/nullable-analysis | 2026-11-17 | new rule CS-019 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/enum | 2026-11-17 | new rule CS-007 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/record | 2026-11-17 | new rule CS-008 (records page already feeds STY-012) |
| https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/struct | 2026-11-17 | new rule CS-009 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/keywords/private-protected | 2026-11-17 | no guidance (accessibility table) |
| https://learn.microsoft.com/dotnet/csharp/language-reference/operators/operator-overloading | 2026-11-17 | no guidance (compiler requirements, not recommendations) |
| https://learn.microsoft.com/dotnet/csharp/language-reference/operators/stackalloc | 2026-11-17 | new rule CS-011 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock | 2026-11-17 | new rule CS-012 |
| https://learn.microsoft.com/dotnet/csharp/language-reference/unsafe-code | 2026-11-17 | out of scope (the requires-unsafe memberwise safety model is new unsafe-evolution material; the page defers to unsafe-code best practices, which STY-012 covers) |
| https://learn.microsoft.com/dotnet/csharp/linq/get-started/type-relationships-in-linq-query-operations | 2026-11-17 | covered by STY-002 (its only recommendation is about var) |
| https://learn.microsoft.com/dotnet/csharp/linq/get-started/write-linq-queries | 2026-11-17 | new rule CS-015 |
| https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/access-modifiers | 2026-11-17 | no guidance (compiler rules) |
| https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/extension-methods | 2026-11-17 | new rule CS-016 |
| https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/static-constructors | 2026-11-17 | new rule CS-013 |
| https://learn.microsoft.com/dotnet/csharp/programming-guide/classes-and-structs/versioning-with-the-override-and-new-keywords | 2026-11-17 | new rule CS-017 |
| https://learn.microsoft.com/dotnet/csharp/programming-guide/events/how-to-subscribe-to-and-unsubscribe-from-events | 2026-11-17 | new rule CS-014 |
| https://learn.microsoft.com/dotnet/standard/analyzers/platform-compat-analyzer | 2026-11-17 | new rule CS-020 |
| https://learn.microsoft.com/dotnet/standard/assembly/resolve-loads | 2026-11-17 | out of scope (advice about one rarely used API, AssemblyResolve) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/async-wrappers-for-synchronous-methods | 2026-11-17 | new rule CS-021 |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/best-practices-for-implementing-the-event-based-asynchronous-pattern | 2026-11-17 | out of scope (legacy EAP, superseded by TAP) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/complete-your-tasks | 2026-11-17 | new rule CS-022 |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/deciding-when-to-implement-the-event-based-asynchronous-pattern | 2026-11-17 | out of scope (legacy EAP) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/event-based-asynchronous-pattern-eap | 2026-11-17 | out of scope (legacy EAP; an index page) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/implementing-the-event-based-asynchronous-pattern | 2026-11-17 | out of scope (legacy EAP) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/implementing-the-task-based-asynchronous-pattern | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/keep-async-methods-alive | 2026-11-17 | new rule CS-022 |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/synchronous-wrappers-for-asynchronous-methods | 2026-11-17 | new rule CS-021 |
| https://learn.microsoft.com/dotnet/standard/asynchronous-programming-patterns/task-based-asynchronous-pattern-tap | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/base-types/backtracking-in-regular-expressions | 2026-11-17 | covered by STY-012 (best-practices-regex: time-out; CS-023 for the generator) |
| https://learn.microsoft.com/dotnet/standard/base-types/best-practices-display-data | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/base-types/best-practices-regex | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/base-types/best-practices-strings | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/base-types/character-classes-in-regular-expressions | 2026-11-17 | no guidance (syntax reference) |
| https://learn.microsoft.com/dotnet/standard/base-types/character-encoding | 2026-11-17 | new rule CS-025 |
| https://learn.microsoft.com/dotnet/standard/base-types/choosing-between-anonymous-and-tuple | 2026-11-17 | no guidance (trade-off table) |
| https://learn.microsoft.com/dotnet/standard/base-types/comparing | 2026-11-17 | covered by STY-012 (best-practices-strings) |
| https://learn.microsoft.com/dotnet/standard/base-types/creating-new | 2026-11-17 | no guidance (performance micro-choices between two APIs) |
| https://learn.microsoft.com/dotnet/standard/base-types/grouping-constructs-in-regular-expressions | 2026-11-17 | no guidance (syntax reference) |
| https://learn.microsoft.com/dotnet/standard/base-types/how-to-verify-that-strings-are-in-valid-email-format | 2026-11-17 | new rule CS-024 |
| https://learn.microsoft.com/dotnet/standard/base-types/regular-expression-source-generators | 2026-11-17 | new rule CS-023 |
| https://learn.microsoft.com/dotnet/standard/commandline/design-guidance | 2026-11-17 | new rule CS-037 |
| https://learn.microsoft.com/dotnet/standard/commandline/migration-guide-2.0.0-beta5 | 2026-11-17 | out of scope (beta migration guide) |
| https://learn.microsoft.com/dotnet/standard/data/xml/extending-the-dom | 2026-11-17 | out of scope (rarely used API, XmlNode derivation) |
| https://learn.microsoft.com/dotnet/standard/datetime/converting-between-time-zones | 2026-11-17 | covered by STY-012 (choosing-between-datetime: UTC) |
| https://learn.microsoft.com/dotnet/standard/datetime/working-with-calendars | 2026-11-17 | no guidance (descriptive) |
| https://learn.microsoft.com/dotnet/standard/events/observer-design-pattern-best-practices | 2026-11-17 | new rule CS-026 |
| https://learn.microsoft.com/dotnet/standard/exceptions/best-practices-for-exceptions | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals | 2026-11-17 | new rule CS-029 (the Dispose advice is covered by STY-012's implementing-dispose) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-dispose | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/implementing-disposeasync | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/large-object-heap | 2026-11-17 | new rule CS-029 |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/latency | 2026-11-17 | out of scope (LowLatency mode, one rarely used setting) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/performance | 2026-11-17 | no guidance (investigation procedure) |
| https://learn.microsoft.com/dotnet/standard/garbage-collection/weak-references | 2026-11-17 | new rule CS-029 |
| https://learn.microsoft.com/dotnet/standard/io/isolated-storage | 2026-11-17 | out of scope (advice about one rarely used API) |
| https://learn.microsoft.com/dotnet/standard/io/pipelines | 2026-11-17 | new rule CS-038 |
| https://learn.microsoft.com/dotnet/standard/io/zip-tar-best-practices | 2026-11-17 | new rule CS-030 |
| https://learn.microsoft.com/dotnet/standard/language-independence | 2026-11-17 | out of scope (CLS compliance only matters to components that choose it; no app-wide recommendation) |
| `standard/library-guidance/ (index)` | 2026-11-17 | no guidance (index; the sub-pages are below) |
| https://learn.microsoft.com/dotnet/standard/library-guidance/breaking-changes | 2026-11-17 | audited (library-and-csharp-audit.md); the rules it carries sit in CS-035's neighbourhood but the page itself is not quoted here: not re-read, not verified |
| https://learn.microsoft.com/dotnet/standard/library-guidance/cross-platform-targeting | 2026-11-17 | audited; see breaking-changes line, not re-read |
| https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies | 2026-11-17 | audited; CS-034 covers the sibling dependencies-net page |
| https://learn.microsoft.com/dotnet/standard/library-guidance/dependencies-net | 2026-11-17 | new rule CS-034 |
| https://learn.microsoft.com/dotnet/standard/library-guidance/get-started | 2026-11-17 | no guidance (index) |
| https://learn.microsoft.com/dotnet/standard/library-guidance/nuget | 2026-11-17 | audited; not re-read |
| https://learn.microsoft.com/dotnet/standard/library-guidance/nuget-package-compatibility-rules | 2026-11-17 | new rule CS-035 |
| https://learn.microsoft.com/dotnet/standard/library-guidance/publish-nuget-package | 2026-11-17 | audited; not re-read |
| https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink | 2026-11-17 | audited; not re-read |
| https://learn.microsoft.com/dotnet/standard/library-guidance/strong-naming | 2026-11-17 | audited; not re-read |
| https://learn.microsoft.com/dotnet/standard/library-guidance/versioning | 2026-11-17 | audited; not re-read |
| https://learn.microsoft.com/dotnet/standard/linq/linq-xml-security | 2026-11-17 | new rule CS-031 |
| https://learn.microsoft.com/dotnet/standard/linq/mixed-declarative-imperative-code-bugs | 2026-11-17 | new rule CS-015 |
| https://learn.microsoft.com/dotnet/standard/memory-and-spans/ | 2026-11-17 | no guidance (index; points to memory-t-usage-guidelines) |
| https://learn.microsoft.com/dotnet/standard/memory-and-spans/memory-t-usage-guidelines | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/native-interop/best-practices | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/native-interop/com-callable-wrapper | 2026-11-17 | out of scope (COM interop, rarely used) |
| https://learn.microsoft.com/dotnet/standard/native-interop/copying-and-pinning | 2026-11-17 | no guidance (marshalling behavior) |
| https://learn.microsoft.com/dotnet/standard/native-interop/customize-struct-marshalling | 2026-11-17 | new rule CS-039 |
| https://learn.microsoft.com/dotnet/standard/native-interop/qualify-net-types-for-interoperation | 2026-11-17 | out of scope (COM interop, rarely used) |
| https://learn.microsoft.com/dotnet/standard/native-interop/tutorial-comwrappers | 2026-11-17 | out of scope (COM interop tutorial) |
| https://learn.microsoft.com/dotnet/standard/net-standard | 2026-11-17 | new rule CS-036 |
| https://learn.microsoft.com/dotnet/standard/parallel-programming/exception-handling-task-parallel-library | 2026-11-17 | new rule CS-028 |
| https://learn.microsoft.com/dotnet/standard/parallel-programming/how-to-cancel-a-plinq-query | 2026-11-17 | out of scope (advice about one rarely used API; cancellation is CS-027) |
| https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-in-data-and-task-parallelism | 2026-11-17 | new rule CS-028 |
| https://learn.microsoft.com/dotnet/standard/parallel-programming/potential-pitfalls-with-plinq | 2026-11-17 | new rule CS-028 |
| `standard/security/ (index)` | 2026-11-17 | no guidance (index) |
| https://learn.microsoft.com/dotnet/standard/security/cryptographic-services | 2026-11-17 | new rule CS-032 |
| https://learn.microsoft.com/dotnet/standard/security/secure-coding-guidelines | 2026-11-17 | covered by SEC-014 / STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/security/security-and-on-the-fly-code-generation | 2026-11-17 | covered by SEC-014 area (audited, secure-coding-audit.md) |
| https://learn.microsoft.com/dotnet/standard/security/security-and-race-conditions | 2026-11-17 | covered by SEC-014 area (audited, secure-coding-audit.md) |
| https://learn.microsoft.com/dotnet/standard/serialization/binaryformatter-migration-guide/ | 2026-11-17 | covered by SEC-014 (BinaryFormatter SYSLIB obsoletion is banned) |
| https://learn.microsoft.com/dotnet/standard/serialization/binaryformatter-migration-guide/choose-a-serializer | 2026-11-17 | no guidance (comparison table) |
| https://learn.microsoft.com/dotnet/standard/serialization/binaryformatter-migration-guide/read-nrbf-payloads | 2026-11-17 | out of scope (advice about one rarely used API, NrbfDecoder) |
| https://learn.microsoft.com/dotnet/standard/serialization/binaryformatter-security-guide | 2026-11-17 | covered by SEC-014 (already a source) |
| https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/migrate-from-newtonsoft | 2026-11-17 | no guidance (feature mapping) |
| https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/reflection-vs-source-generation | 2026-11-17 | new rule CS-033 |
| https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/source-generation-modes | 2026-11-17 | no guidance (support table) |
| https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/use-utf8jsonreader | 2026-11-17 | out of scope (advice about one rarely used API) |
| https://learn.microsoft.com/dotnet/standard/simd | 2026-11-17 | out of scope (hardware intrinsics; rarely used API) |
| https://learn.microsoft.com/dotnet/standard/threading/cancellation-in-managed-threads | 2026-11-17 | new rule CS-027 |
| https://learn.microsoft.com/dotnet/standard/threading/managed-threading-best-practices | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/standard/threading/spinlock | 2026-11-17 | out of scope (one rarely used API; its recommendation is "use SpinLock only when profiling shows it helps") |
| https://learn.microsoft.com/dotnet/standard/unsafe-code/best-practices | 2026-11-17 | covered by STY-012 (already a source) |
| https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient-guidelines | 2026-11-17 | NET-001, NET-003 (OPS-003 cites it) |
| https://learn.microsoft.com/dotnet/core/resilience/http-resilience | 2026-11-17 | NET-002 (OPS-003 cites it) |
| https://learn.microsoft.com/dotnet/fundamentals/networking/http/httpclient | 2026-11-17 | covered by NET-001/OPS-003 (reuse); rest descriptive or one-API advice |
| https://learn.microsoft.com/dotnet/fundamentals/networking/http/http-overview | 2026-11-17 | no guidance |
| https://learn.microsoft.com/dotnet/fundamentals/networking/ipv6-overview | 2026-11-17 | no guidance |
| `fundamentals/networking/telemetry/events, tracing` | 2026-11-17 | out of scope (event-listener API advice; tracing covered by OPS-001) |
| https://learn.microsoft.com/dotnet/core/diagnostics/diagnostic-resource-monitoring | 2026-11-17 | out of scope (Kubernetes/package-specific) |
| https://learn.microsoft.com/dotnet/core/diagnostics/diagnostics-in-containers | 2026-11-17 | out of scope (tooling how-to) |
| `core/diagnostics/diagnosticsource-diagnosticlistener, eventsource-activity-ids, eventsource-getting-started, eventsource-instrumentation` | 2026-11-17 | out of scope (rarely used APIs; OPS-001 uses OpenTelemetry) |
| https://learn.microsoft.com/dotnet/core/diagnostics/metrics-strongly-typed | 2026-11-17 | out of scope (one source-generator API) |
| `core/dependency-loading/loading-managed, understanding-assemblyloadcontext` | 2026-11-17 | out of scope (rarely used APIs) |
| https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector | 2026-11-17 | no guidance (configuration reference) |
| https://learn.microsoft.com/dotnet/core/distribution-packaging | 2026-11-17 | out of scope (for distro maintainers) |
| https://learn.microsoft.com/dotnet/core/sdk/file-based-apps | 2026-11-17 | out of scope (tooling how-to; no project type uses it) |
| https://learn.microsoft.com/dotnet/core/versions/selection | 2026-11-17 | covered by supply-chain.md global.json pin rule (Dependabot "consider" is the kit's ecosystem setup) |
| `core/unmanaged-api/debugging/, unmanaged-api/metadata/interfaces/imetadataemit-definemethod-method` | 2026-11-17 | out of scope (native debugging/metadata API reference) |
| `fundamentals/syslib-diagnostics/obsoletions-overview, syslib0046` | 2026-11-17 | covered by SEC-014 |
| `fundamentals/code-analysis/overview, quality-rules/ (overview), style-rules/ (overview), language-rules` | 2026-11-17 | covered by STY-001, STY-003, STY-004 |
| `quality-rules/design-warnings, naming-warnings, usage-warnings, performance-warnings, reliability-warnings, maintainability-warnings, interoperability-warnings` | 2026-11-17 | covered by STY-003, STY-009 |
| `quality-rules/security-warnings; ca2300, ca2305, ca2310, ca2315, ca2326, ca2327, ca5350, ca5351, ca5358, ca5364, ca5373, ca5374, ca5375, ca5384, ca5386, ca5387, ca5393, ca5394, ca5397, ca5398, ca5401` | 2026-11-17 | covered by SEC-014 / SEC-015 |
| `quality-rules ca1005, ca1012, ca1018, ca1021, ca1034, ca1040, ca1044, ca1053, ca1054, ca1055, ca1056, ca1058, ca1065, ca1069, ca1070, ca1200, ca1401, ca1417` | 2026-11-17 | covered by STY-009 (Design/Interop analyzers) |
| `quality-rules ca1501, ca1502, ca1505, ca1506, ca1508, ca1509` | 2026-11-17 | covered by CRF-008 |
| `quality-rules ca1707, ca1711, ca1713, ca1716, ca1720, ca1721, ca1724` | 2026-11-17 | covered by STY-007, STY-009 (Naming) |
| `quality-rules ca1801, ca1812, ca1813, ca1814, ca1819, ca1823, ca1825, ca1827, ca1828, ca1830, ca1831, ca1832, ca1833, ca1835, ca1836, ca1838, ca1841, ca1842, ca1843, ca1846, ca1850, ca1854, ca1860, ca1861, ca1864` | 2026-11-17 | covered by STY-003, STY-009 |
| `quality-rules ca2008, ca2013, ca2014, ca2019, ca2022, ca2026, ca2211, ca2234, ca2253, ca2255, ca2261` | 2026-11-17 | covered by STY-003, STY-009 (CA2255 libraries-only ModuleInitializer, CA2008 explicit TaskScheduler included) |
| `style-rules ide0003 through ide2002 (all IDE pages in the extract)` | 2026-11-17 | covered by STY-001 (.editorconfig baseline), STY-002 (var) |
| https://learn.microsoft.com/dotnet/core/extensions/async-state | 2026-11-17 | out of scope: advice on one rarely used API (AsyncLocal-style state clean-up) |
| https://learn.microsoft.com/dotnet/core/extensions/best-practices-for-developing-world-ready-apps | 2026-11-17 | covered by ARC rule in architecture.md (line ~103/107, TimeProvider); other items are globalization (other batch/ out of this topic) |
| https://learn.microsoft.com/dotnet/core/extensions/caching | 2026-11-17 | new rule HST-004; rest descriptive/consider-only (HybridCache "consider" not made a rule) |
| https://learn.microsoft.com/dotnet/core/extensions/create-resource-files | 2026-11-17 | out of scope: resource-file tooling how-to (Resgen/.resx); localization topic |
| https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/auto-activation | 2026-11-17 | new rule HST-001 |
| https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/guidelines | 2026-11-17 | covered by CRF-013 (and CRF-005/CRF-009) |
| https://learn.microsoft.com/dotnet/core/extensions/dependency-injection/overview | 2026-11-17 | no guidance beyond what CRF-005/CRF-013 cover; mostly descriptive |
| https://learn.microsoft.com/dotnet/core/extensions/globalization | 2026-11-17 | already audited/cited (architecture.md, code-style.md); not duplicated here |
| https://learn.microsoft.com/dotnet/core/extensions/globalization-icu | 2026-11-17 | no guidance: descriptive of ICU behavior changes |
| https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory | 2026-11-17 | covered by OPS-003 (factory use, cookies, resilience) and HST-002 (typed clients in singletons) |
| https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-keyed-di | 2026-11-17 | out of scope: advice about one rarely used API (keyed HttpClient); transient-lifetime caution folded under HST-002's spirit, not quoted |
| https://learn.microsoft.com/dotnet/core/extensions/httpclient-factory-troubleshooting | 2026-11-17 | new rule HST-002 (cookie DO NOT covered by OPS-003) |
| https://learn.microsoft.com/dotnet/core/extensions/httpclient-logging | 2026-11-17 | out of scope: enhanced HTTP client logging, one rarely used API (LogBody warning) |
| https://learn.microsoft.com/dotnet/core/extensions/logging/high-performance-logging | 2026-11-17 | covered by OPS-007 (generated logger) |
| https://learn.microsoft.com/dotnet/core/extensions/logging/library-guidance | 2026-11-17 | covered by OPS-007 and HST-003 (templates, no interpolation) |
| https://learn.microsoft.com/dotnet/core/extensions/logging/overview | 2026-11-17 | new rule HST-003; Trace/Debug-in-production sentences left as descriptive/consider |
| https://learn.microsoft.com/dotnet/core/extensions/options-library-authors | 2026-11-17 | new rule HST-005 (core: every app holds libraries) |
| https://learn.microsoft.com/dotnet/core/extensions/performing-culture-insensitive-case-changes | 2026-11-17 | covered by existing strings/culture rules (CA1305/CA1311 fixtures in code-style.md); not duplicated |
| https://learn.microsoft.com/dotnet/core/extensions/performing-culture-insensitive-string-operations | 2026-11-17 | same as above |
| https://learn.microsoft.com/dotnet/core/extensions/sslstream-best-practices | 2026-11-17 | out of scope: TLS; touches SEC topic, owned by another batch if at all |
| https://learn.microsoft.com/dotnet/core/extensions/timeprovider-testing | 2026-11-17 | already audited/cited (architecture.md TimeProvider rule) |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-best-practices | 2026-11-17 | covered by TST-010 (quotes added) and TST-004 (quote added) |
| https://learn.microsoft.com/dotnet/core/testing/order-unit-tests | 2026-11-17 | new rule TST-012 |
| https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-architecture-extensions | 2026-11-17 | out of scope: how to write MTP extensions, not app guidance |
| https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-architecture-test-framework | 2026-11-17 | out of scope: how to write a test framework for MTP |
| https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-troubleshooting | 2026-11-17 | out of scope: troubleshooting how-to (exit codes, .NET Framework AnyCPU) |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-with-dotnet-test | 2026-11-17 | out of scope: VSTest-mode caveats and CLI migration; the kit runs MTP natively (`dotnet test --coverage` via global.json) |
| https://learn.microsoft.com/dotnet/core/testing/mstest-analyzers/design-rules | 2026-11-17 | out of scope: MSTest only |
| `mstest-analyzers/mstest0006, 0015, 0019, 0020, 0021, 0022, 0026, 0036, 0038, 0042, 0044, 0048, 0052, 0053, 0058, 0059, 0060, 0062, 0064, 0065, 0067, 0071, 0073, 0075, 0076, 0077, 0085, 0087 (28 pages)` | 2026-11-17 | out of scope: MSTest analyzers; the kit uses xUnit v3 |
| https://learn.microsoft.com/dotnet/core/testing/mstest-analyzers/overview | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/mstest-analyzers/usage-rules | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-migration-from-tmi | 2026-11-17 | out of scope: MSTest migration |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-migration-from-v1-to-v3 | 2026-11-17 | out of scope: MSTest migration |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-assertions | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-controlling-execution | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-data-driven | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-deployment-items | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-lifecycle | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/testing/unit-testing-mstest-writing-tests-organizing | 2026-11-17 | out of scope: MSTest only |
| https://learn.microsoft.com/dotnet/core/deploying/native-aot/diagnostics | 2026-11-17 | new rule OPS-015 (one recommendation); rest descriptive |
| https://learn.microsoft.com/dotnet/core/deploying/runtime-patch-selection | 2026-11-17 | no guidance (two alternatives, each "prefer" only for a stated case) |
| https://learn.microsoft.com/dotnet/core/deploying/single-file/overview | 2026-11-17 | out of scope: advice about one rarely used feature (self-extraction directory) |
| https://learn.microsoft.com/dotnet/core/deploying/single-file/warnings/overview | 2026-11-17 | out of scope: analyzer list for single-file |
| https://learn.microsoft.com/dotnet/core/deploying/trimming/fixing-warnings | 2026-11-17 | new rule OPS-015 |
| https://learn.microsoft.com/dotnet/core/deploying/trimming/prepare-libraries-for-trimming | 2026-11-17 | already audited elsewhere, not in my files; nothing added |
