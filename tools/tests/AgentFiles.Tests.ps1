#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The skills, the reviewer, the PR template, the VS Code settings and the generated rule files are copied
# unchanged into every app repo (Export-KitApp, ADR-0032). An app
# keeps the kit's scripts in .kit/tools/, not tools/, so these files must not send an agent to a kit-only
# path: they point to the Commands table in AGENTS.md, which each repo writes for its own layout.

Describe 'agent files shared with app repos' {
    BeforeDiscovery {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        # The generated rule files are checked too: they carry a header naming how to regenerate them.
        $shared = @(Get-ChildItem -LiteralPath (Join-Path $root '.claude' 'skills') -Recurse -File -Filter '*.md') +
            @(Get-Item -LiteralPath (Join-Path $root '.claude' 'agents' 'reviewer.md'),
                (Join-Path $root '.github' 'pull_request_template.md'), (Join-Path $root '.vscode' 'settings.json')) +
            @(Get-ChildItem -LiteralPath (Join-Path $root '.claude' 'rules'), (Join-Path $root '.github' 'instructions') -File -Filter '*.md')
        $files = @($shared | ForEach-Object {
                @{ Path = $_.FullName; Name = [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' }
            })
    }

    It '<Name> names no path under the kit''s own tools/ folder' -ForEach $files {
        # tools/ at the start of a path, not .kit/tools/.
        $hits = Select-String -LiteralPath $Path -Pattern '(?<![\w.\-/])(\./)?tools/' |
            ForEach-Object { "line $($_.LineNumber): $($_.Line.Trim())" }

        @($hits) | Should -BeNullOrEmpty -Because 'app repos have the scripts in .kit/tools; point to AGENTS.md''s Commands table instead'
    }
}
