# Microsoft Learn inventory: .NET MAUI guidance

Batch D-maui-desktop read the MAUI part of this set. The docs-maui table of contents lists 407 pages. 20 were candidates, and the batch added four pages it found outside the extract (data access, app lifecycle, dependency injection, storage). They produced MAU-001 to MAU-016. Every verdict was checked on 2026-11-17.

The page list for this set, with every page's guidance-wording score, is in `docs/inventory/maui-pages.tsv`. Re-check with the `discover-guidance` skill.

| Page | Checked | Verdict |
|---|---|---|
| https://learn.microsoft.com/dotnet/maui/deployment/nativeaot | 2026-11-17 | new rule MAU-016 |
| https://learn.microsoft.com/dotnet/maui/deployment/performance | 2026-11-17 | new rules MAU-004, 005, 006, 007, 008, 009 (STY-011 covers the blocking and async void lines) |
| https://learn.microsoft.com/dotnet/maui/deployment/visual-studio-properties | 2026-11-17 | out of scope: IDE how-to |
| https://learn.microsoft.com/dotnet/maui/developer-tools/cli/apple-management | 2026-11-17 | out of scope: CLI tooling how-to |
| https://learn.microsoft.com/dotnet/maui/fundamentals/accessibility | 2026-11-17 | new rule MAU-003 (UI-001 cites it for WCAG) |
| https://learn.microsoft.com/dotnet/maui/fundamentals/data-binding/compiled-bindings | 2026-11-17 | new rule MAU-002 |
| https://learn.microsoft.com/dotnet/maui/fundamentals/messagingcenter | 2026-11-17 | new rule MAU-015 |
| https://learn.microsoft.com/dotnet/maui/fundamentals/shell/navigation | 2026-11-17 | new rule MAU-014 |
| https://learn.microsoft.com/dotnet/maui/migration/android-projects | 2026-11-17 | out of scope: Xamarin.Android migration how-to |
| https://learn.microsoft.com/dotnet/maui/platform-integration/appmodel/permissions | 2026-11-17 | new rule MAU-012 |
| https://learn.microsoft.com/dotnet/maui/platform-integration/communication/authentication | 2026-11-17 | new rule MAU-013 |
| https://learn.microsoft.com/dotnet/maui/user-interface/controls/hybridwebview | 2026-11-17 | out of scope: one rarely used control's API |
| https://learn.microsoft.com/dotnet/maui/user-interface/controls/scrollview | 2026-11-17 | new rule MAU-010 |
| https://learn.microsoft.com/dotnet/maui/user-interface/controls/slider | 2026-11-17 | out of scope: one control's property rules |
| https://learn.microsoft.com/dotnet/maui/user-interface/device-independent-units | 2026-11-17 | no guidance (headings only; touch-target size is UI-001) |
| https://learn.microsoft.com/dotnet/maui/user-interface/handlers/create | 2026-11-17 | out of scope: custom handler authoring, rarely used API |
| https://learn.microsoft.com/dotnet/maui/user-interface/images/splashscreen | 2026-11-17 | out of scope: resource configuration how-to |
| https://learn.microsoft.com/dotnet/maui/user-interface/layouts/ | 2026-11-17 | new rule MAU-010 |
| https://learn.microsoft.com/dotnet/maui/user-interface/pages/navigationpage | 2026-11-17 | out of scope: legacy navigation; Shell is the kit default (ADR-0008) |
| https://learn.microsoft.com/dotnet/maui/user-interface/safe-area | 2026-11-17 | out of scope: visual layout choices |
| https://learn.microsoft.com/dotnet/maui/data-cloud/database-sqlite | 2026-11-17 | new rule MAU-001 |
| https://learn.microsoft.com/dotnet/maui/fundamentals/app-lifecycle | 2026-11-17 | new rule MAU-011 |
| https://learn.microsoft.com/dotnet/maui/fundamentals/dependency-injection | 2026-11-17 | no guidance worth a rule (describes registration; "should be performed in a single method" is a convention, not a strong recommendation) |
| `/dotnet/maui/platform-integration/storage/secure-storage and preferences` | 2026-11-17 | no guidance (descriptive; one iOS Keychain note) |
