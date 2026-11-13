#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The skills, the code-review instructions, the PR and ADR templates, the VS Code settings and the generated rule files
# are copied unchanged into every app repo (Export-KitApp, ADR-0032). An app keeps the kit's scripts in .kit/tools/,
# not tools/, so these files must not send an agent to a kit-only path: they point to the Commands table
# in AGENTS.md, which each repo writes for its own layout.

Describe 'agent files shared with app repos' {
    BeforeDiscovery {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        # The generated rule files are checked too: they carry a header naming how to regenerate them.
        $shared = @(Get-ChildItem -LiteralPath (Join-Path $root '.claude' 'skills') -Recurse -File -Filter '*.md') +
            @(Get-Item -LiteralPath (Join-Path $root '.github' 'pull_request_template.md'), (Join-Path $root '.vscode' 'settings.json'),
                (Join-Path $root 'docs' 'adr' '0000-template.md')) +
            @(Get-ChildItem -LiteralPath (Join-Path $root '.claude' 'rules'), (Join-Path $root '.github' 'instructions') -File -Filter '*.md')
        # A kit-only skill, such as new-app, never reaches an app, so it may name the kit's own scripts. Export-KitApp
        # says which those are.
        . (Join-Path $root 'tools' 'Export-KitApp.ps1')
        $files = @($shared | ForEach-Object {
                @{ Path = $_.FullName; Name = [IO.Path]::GetRelativePath($root, $_.FullName) -replace '\\', '/' }
            } | Where-Object { -not (Test-KitOnlyPath -Path $_.Name) })
    }

    It '<Name> names no path under the kit''s own tools/ folder' -ForEach $files {
        # tools/ at the start of a path, not .kit/tools/. YAML front matter is skipped: a rule scoped to
        # paths: 'tools/**' just never loads in an app, and sends nobody anywhere.
        $lines = @(Get-Content -LiteralPath $Path)
        $start = 0
        if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
            $end = [Array]::IndexOf($lines, '---', 1)
            if ($end -gt 0) { $start = $end + 1 }
        }
        $hits = for ($i = $start; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?<![\w.\-/])(\./)?tools/') { "line $($i + 1): $($lines[$i].Trim())" }
        }

        @($hits) | Should -BeNullOrEmpty -Because 'app repos have the scripts in .kit/tools; point to AGENTS.md''s Commands table instead'
    }
}
