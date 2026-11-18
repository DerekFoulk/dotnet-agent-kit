# Third-party notices

The kit itself isn't licensed for reuse (ADR-0031). These files are based on other projects' work and carry those projects' licenses. Keep this file with them wherever they're copied, including into app repos.

| File | Based on | License |
|---|---|---|
| `.editorconfig` | [dotnet/runtime `.editorconfig`](https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig) at commit `860eddb` | MIT, Copyright (c) .NET Foundation and Contributors |
| `.editorconfig` (lines marked "(docs)") | [dotnet/docs `.editorconfig`](https://github.com/dotnet/docs/blob/a9d609595f9b72ac1acd8c60170b92ae3c0644bf/.editorconfig) at commit `a9d6095` | MIT, Copyright (c) Microsoft Corporation. dotnet/docs licenses its documentation under CC-BY-4.0 (`LICENSE`) and its code under MIT (`LICENSE-CODE`); a config file is treated as code |
| `sample/src/Bookmarks.ServiceDefaults/ServiceDefaultsExtensions.cs` (the kit's sample, which apps don't get) | The `aspire-servicedefaults` template's [`Extensions.cs`](https://github.com/microsoft/aspire/blob/569ddf47bac85516bef73fa838d4558fe08f3f0c/src/Aspire.ProjectTemplates/templates/aspire-servicedefaults/Extensions.cs) in microsoft/aspire at commit `569ddf4` (2026-04-23), adapted (ADR-0037) | MIT, Copyright (c) .NET Foundation and Contributors (the text below) |
| `sample/src/Bookmarks.ServiceDefaults/ServiceDefaultsExtensions.cs` (the health endpoints' cache and timeout settings) | The example on [aspire.dev's health-check page](https://aspire.dev/fundamentals/health-checks/), from microsoft/aspire.dev, retrieved 2026-11-08 (ADR-0037) | MIT, Copyright (c) Microsoft Corporation (the dotnet/docs code text below) |
| `sample/src/Bookmarks.Api/BearerSecuritySchemeTransformer.cs` (the kit's sample, which apps don't get) | The `BearerSecuritySchemeTransformer` example on [Microsoft Learn's "Customize OpenAPI documents" page](https://learn.microsoft.com/aspnet/core/fundamentals/openapi/customize-openapi#use-document-transformers), from dotnet/AspNetCore.Docs, retrieved 2026-11-11, adapted (ADR-0048) | MIT, Copyright (c) Microsoft Corporation (the dotnet/docs code text below; dotnet/AspNetCore.Docs licenses its code under the same terms in `LICENSE-CODE`) |
| `fixtures/WebUi/src/Kit.WebUi/Components/App.razor`, `Routes.razor` and `Program.cs` (the kit's web UI fixture, which apps don't get) | The `dotnet new blazor --empty --interactivity None` template, [`src/ProjectTemplates/Web.ProjectTemplates/content/BlazorWeb-CSharp/BlazorWebCSharp.1/`](https://github.com/dotnet/aspnetcore/tree/547fc16b976e18911f9df7630f1f75758ab248f2/src/ProjectTemplates/Web.ProjectTemplates/content/BlazorWeb-CSharp/BlazorWebCSharp.1) (`Program.cs` and `Components/`) in dotnet/aspnetcore at tag `v10.0.15`, commit `547fc16` (2026-10-21), cut down (ADR-0061) | MIT, Copyright (c) .NET Foundation and Contributors (the text below) |
| `.gitignore` | The `dotnet new gitignore` template, [`template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore`](https://github.com/dotnet/sdk/blob/dc1869b/template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore) in dotnet/sdk at commit `dc1869b` (2025-03-27), plus the kit's own lines | MIT, Copyright (c) .NET Foundation and Contributors. Parts of the template come from [github/gitignore](https://github.com/github/gitignore), which is CC0 and needs no notice |
| `.claude/skills/dotnet-webapi/`, `.claude/skills/optimizing-ef-core-queries/`, `.claude/skills/analyzing-dotnet-performance/`, `.claude/skills/run-tests/`, `.claude/skills/filter-syntax/`, `.claude/skills/migrate-xunit-to-xunit-v3/`, `.claude/skills/migrate-vstest-to-mtp/`, `.claude/skills/convert-to-cpm/`, `.claude/skills/author-component/`, `.claude/skills/msbuild/` (the curated .NET skills; ADR-0042, `docs/dotnet-skills.md` in the kit) | Copied unchanged from [dotnet/skills](https://github.com/dotnet/skills/tree/96c3d68dad2855e3ab5178aa1a262789d86a1466) at commit `96c3d68` (2026-11-06), retrieved 2026-11-10 | MIT, Copyright (c) .NET Foundation and Contributors (the text below) |
| The `quotes` of each rule in `docs/standards/` (ADR-0082) | Short passages quoted word for word, unchanged, from each cited page, each with its URL and the date read | Each page's own license, as its source repo states it, checked 2026-11-17: CC-BY-4.0 for the Microsoft Learn docs from dotnet/docs, dotnet/AspNetCore.Docs, dotnet/EntityFramework.Docs, dotnet/docs-maui, MicrosoftDocs/windows-dev-docs, MicrosoftDocs/azure-docs, MicrosoftDocs/sql-docs, MicrosoftDocs/azure-aks-docs and MicrosoftDocs/SecurityBenchmarks; MIT for the NuGet docs (NuGet/docs.microsoft.com-nuget, Copyright (c) .NET Foundation) and the Microsoft Entra docs (MicrosoftDocs/entra-docs, Copyright (c) Microsoft Corporation); not verified for the Azure Well-Architected Framework and Azure Architecture Center pages, whose source repos aren't public; GitHub Docs, CC-BY-4.0; OWASP's Cheat Sheet Series, ASVS and API Security Top 10, CC-BY-SA-4.0; microsoft/vs-threading's analyzer pages and aspire.dev, MIT, Copyright (c) Microsoft Corporation; ossf/scorecard-action, Apache-2.0. The W3C pages are under the [W3C Document License](https://www.w3.org/copyright/document-license-2023/), whose notices are: [WCAG 2.2](https://www.w3.org/TR/WCAG22/), "Copyright © 2020-2024 World Wide Web Consortium. W3C® liability, trademark and document use rules apply.", W3C Recommendation 12 December 2024; [WCAG2ICT for WCAG 2.2](https://www.w3.org/TR/wcag2ict-22/), "Copyright © 2022-2025 World Wide Web Consortium. W3C® liability, trademark and document use rules apply.", W3C Group Note 11 December 2025 |

## dotnet/runtime, dotnet/sdk, dotnet/aspnetcore, dotnet/skills and microsoft/aspire

```text
The MIT License (MIT)

Copyright (c) .NET Foundation and Contributors

All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## dotnet/docs (code), dotnet/AspNetCore.Docs (code) and microsoft/aspire.dev

```text
The MIT License (MIT)
Copyright (c) Microsoft Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial
portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```
