# Microsoft Learn inventory

The kit's rules with `basis: authority` say only what a Microsoft Learn page says (ADR-0082). On 2026-11-17 helpers listed the guidance pages of six Learn docs sets and wrote rules from them. This folder keeps what they read, so a later pass can see what was checked and what wasn't.

The method: each docs repo's `toc.yml` files were read from a shallow sparse clone, and every linked page was scored for guidance wording (we recommend, best practice, DO, DON'T, AVOID, CONSIDER, should, avoid, prefer, guidelines). Tutorials, quickstarts, reference, what's-new, breaking-changes, compatibility, samples and API pages were skipped. A page that scored 3 or more, or whose `ms.topic` is best-practice, was a candidate, and a helper read its guidance sentences. The dotnet set's design-guidelines pages (Framework Design Guidelines) were skipped, because the owner's earlier 94-page audit covered them.

Each set has two files. `<set>-pages.tsv` lists every page in the table of contents, with its score and whether it was a candidate, all "checked 2026-11-17". `<set>.md` gives each candidate page's verdict: the rule ids it became, "covered by" an existing rule, "no guidance", or "out of scope" with the reason. Re-check pages with the `discover-guidance` skill.

The kit's rules cover only its supported app types, the ones the new-app intake offers: `web-api`, `blazor` and `maui` (`docs/standards/app-types.yml`, ADR-0084). WPF, Windows Forms, WinUI 3, Blazor Hybrid, Razor Pages and MVC, and workers and console apps aren't supported types yet, so their pages were inventoried but their rules aren't in the kit. A verdict below that names a rule for one of them (WPF, WFM and WUI rules, and some ASP and BLZ rules) records what a batch wrote on 2026-11-17, ready for when that type is supported.

| Set | Docs repo | TOC pages | Candidates | Batches |
|---|---|---|---|---|
| [aspnetcore](aspnetcore.md) | dotnet/AspNetCore.Docs | 872 | 167 | D-aspnetcore, D-blazor, R3 (host-and-deploy) |
| [dotnet](dotnet.md) | dotnet/docs | 4,771 | 408 | D-csharp, D-dotnet, R7 (hosting), R4 (testing), R3 (deploy) |
| [efcore](efcore.md) | dotnet/EntityFramework.Docs | 180 | 28 | R5 |
| [maui](maui.md) | dotnet/docs-maui | 407 | 20 | D-maui-desktop |
| [desktop](desktop.md) | dotnet/docs-desktop | 1,602 | 39 | D-maui-desktop |
| [windows](windows.md) | MicrosoftDocs/windows-dev-docs | 882 | 172 | D-windows |
