# Third-party notices

The kit itself isn't licensed for reuse (ADR-0031). These files are based on other projects' work and carry those projects' licenses. Keep this file with them wherever they're copied, including into app repos.

| File | Based on | License |
|---|---|---|
| `.editorconfig` | [dotnet/runtime `.editorconfig`](https://github.com/dotnet/runtime/blob/860eddba936f4a7e8a04cb12ee3bc54385216cab/.editorconfig) at commit `860eddb` | MIT, Copyright (c) .NET Foundation and Contributors |
| `.editorconfig` (lines marked "(docs)") | [dotnet/docs `.editorconfig`](https://github.com/dotnet/docs/blob/a9d609595f9b72ac1acd8c60170b92ae3c0644bf/.editorconfig) at commit `a9d6095` | MIT, Copyright (c) Microsoft Corporation. dotnet/docs licenses its documentation under CC-BY-4.0 (`LICENSE`) and its code under MIT (`LICENSE-CODE`); a config file is treated as code |
| `.gitignore` | The `dotnet new gitignore` template, [`template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore`](https://github.com/dotnet/sdk/blob/dc1869b/template_feed/Microsoft.DotNet.Common.ItemTemplates/content/Gitignore/.gitignore) in dotnet/sdk at commit `dc1869b` (2025-03-27), plus the kit's own lines | MIT, Copyright (c) .NET Foundation and Contributors. Parts of the template come from [github/gitignore](https://github.com/github/gitignore), which is CC0 and needs no notice |

## dotnet/runtime and dotnet/sdk

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

## dotnet/docs (code)

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
