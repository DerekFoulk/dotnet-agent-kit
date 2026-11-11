# Third-party notices

The kit itself isn't licensed for reuse (ADR-0031). These files are based on other projects' work and carry those projects' licenses. Keep this file with them wherever they're copied, including into app repos.

| File | Based on | License |
|---|---|---|
| `.editorconfig` | [dotnet/runtime `.editorconfig`](https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig) at commit `860eddb` | MIT, Copyright (c) .NET Foundation and Contributors |
| `.editorconfig` (lines marked "(docs)") | [dotnet/docs `.editorconfig`](https://github.com/dotnet/docs/blob/a9d609595f9b72ac1acd8c60170b92ae3c0644bf/.editorconfig) at commit `a9d6095` | MIT, Copyright (c) Microsoft Corporation. dotnet/docs licenses its documentation under CC-BY-4.0 (`LICENSE`) and its code under MIT (`LICENSE-CODE`); a config file is treated as code |
| `sample/src/Bookmarks.ServiceDefaults/ServiceDefaultsExtensions.cs` (the kit's sample, which apps don't get) | The `aspire-servicedefaults` template's [`Extensions.cs`](https://github.com/microsoft/aspire/blob/569ddf47bac85516bef73fa838d4558fe08f3f0c/src/Aspire.ProjectTemplates/templates/aspire-servicedefaults/Extensions.cs) in microsoft/aspire at commit `569ddf4` (2026-04-23), adapted (ADR-0037) | MIT, Copyright (c) .NET Foundation and Contributors (the text below) |
| `sample/src/Bookmarks.ServiceDefaults/ServiceDefaultsExtensions.cs` (the health endpoints' cache and timeout settings) | The example on [aspire.dev's health-check page](https://aspire.dev/fundamentals/health-checks/), from microsoft/aspire.dev, retrieved 2026-11-08 (ADR-0037) | MIT, Copyright (c) Microsoft Corporation (the dotnet/docs code text below) |
| `.gitignore` | The `dotnet new gitignore` template, [`template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore`](https://github.com/dotnet/sdk/blob/dc1869b/template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore) in dotnet/sdk at commit `dc1869b` (2025-03-27), plus the kit's own lines | MIT, Copyright (c) .NET Foundation and Contributors. Parts of the template come from [github/gitignore](https://github.com/github/gitignore), which is CC0 and needs no notice |
| `.claude/skills/dotnet-webapi/`, `.claude/skills/optimizing-ef-core-queries/`, `.claude/skills/analyzing-dotnet-performance/`, `.claude/skills/run-tests/`, `.claude/skills/filter-syntax/`, `.claude/skills/migrate-xunit-to-xunit-v3/`, `.claude/skills/migrate-vstest-to-mtp/`, `.claude/skills/convert-to-cpm/`, `.claude/skills/author-component/`, `.claude/skills/msbuild/` (the curated .NET skills; ADR-0042, `docs/dotnet-skills.md` in the kit) | Copied unchanged from [dotnet/skills](https://github.com/dotnet/skills/tree/96c3d68dad2855e3ab5178aa1a262789d86a1466) at commit `96c3d68` (2026-11-06), retrieved 2026-11-10 | MIT, Copyright (c) .NET Foundation and Contributors (the text below) |

## dotnet/runtime, dotnet/sdk, dotnet/skills and microsoft/aspire

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

## dotnet/docs (code) and microsoft/aspire.dev

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
