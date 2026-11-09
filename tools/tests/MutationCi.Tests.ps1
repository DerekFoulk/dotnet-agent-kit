#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Mutation testing (GAP-003, TST-004's 85% score, ADR-0039). A shared workflow runs Stryker.NET over a solution
# and fails when the mutation score is below 85%. The kit runs it nightly; apps get the same nightly caller.

Describe 'Mutation testing in CI' {
    BeforeAll {
        Import-Module powershell-yaml
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path

        function Read-Yaml([string] $RelativePath) {
            $path = Join-Path $root $RelativePath
            $text = if (Test-Path $path) { Get-Content -Raw $path } else { '' }
            [pscustomobject]@{ Text = $text; Yaml = if ($text) { ConvertFrom-Yaml $text } else { @{} } }
        }

        function Get-Steps($Yaml) {
            if (-not $Yaml.ContainsKey('jobs')) { return @() }
            @($Yaml['jobs'].Values | ForEach-Object { @($_['steps']) })
        }

        $reusable = Read-Yaml '.github/workflows/mutation.reusable.yml'
        $kit = Read-Yaml '.github/workflows/mutation.yml'

        # The kit mutation.yml's paths-ignore entries as regexes, read as GitHub's path patterns, case-sensitively:
        # **/ is zero or more folders, ** crosses folders, * doesn't. GitHub's ?, +, [] and ! are refused, since
        # this reads only *, ** and literal paths (review 5 of PR 23 added +).
        function Get-IgnorePattern {
            $ignore = @($kit.Yaml['on']['pull_request']['paths-ignore'])
            $ignore | Should -Not -Match '[!?+\[]' -Because 'these tests read only *, ** and literal paths'
            @($ignore | ForEach-Object {
                    '^' + ([regex]::Escape($_) -creplace '\\\*\\\*/', '(?:.*/)?' -creplace '\\\*\\\*', '.*' -creplace '\\\*', '[^/]*') + '$'
                })
        }
        # {{Name}} placeholders aren't YAML; read the template with them replaced.
        $appText = if (Test-Path (Join-Path $root 'templates/app/.github/workflows/mutation.yml')) {
            Get-Content -Raw (Join-Path $root 'templates/app/.github/workflows/mutation.yml')
        } else { '' }
        $app = if ($appText) { ConvertFrom-Yaml ($appText -replace '\{\{[A-Za-z]+\}\}', 'X') } else { @{} }
    }

    Context 'an app''s mutation.yml (templates/app)' {
        It 'runs nightly and on demand, never on pull requests, calling the shared workflow pinned to the kit release' {
            $appText | Should -Not -BeNullOrEmpty -Because 'every new app gets the nightly mutation run'
            @($app['on']['schedule']).Count | Should -BeGreaterThan 0
            $app['on'].ContainsKey('workflow_dispatch') | Should -BeTrue
            $app['on'].ContainsKey('pull_request') | Should -BeFalse -Because 'it is too slow for every pull request, and so not a required check'
            $appText | Should -Match 'uses: DerekFoulk/dotnet-agent-kit/\.github/workflows/mutation\.reusable\.yml@\{\{KitCommit\}\} # \{\{KitVersion\}\}'
            $appText | Should -Match 'solution: \{\{Name\}\}\.slnx'
            $app['permissions']['contents'] | Should -Be 'read'
        }
    }

    Context 'the kit''s mutation.yml' {
        It 'runs nightly, on demand, and on every pull request except one that changes only files the run can''t read' {
            # Reviews 2, 3 and 4 of PR 23 each found files missing from a list of what the run reads. A list of
            # inputs falls behind silently; a list of what can't matter fails safe: a gap costs one extra run.
            $on = $kit.Yaml['on']

            $on | Should -Not -BeNullOrEmpty
            @($on['schedule']).Count | Should -BeGreaterThan 0
            $on.ContainsKey('workflow_dispatch') | Should -BeTrue
            $on['pull_request'].ContainsKey('paths') | Should -BeFalse -Because 'an allowlist of inputs falls behind without anyone noticing'
            @($on['pull_request']['paths-ignore']).Count | Should -BeGreaterThan 0
        }

        It 'never ignores a file the mutation run reads: the solution''s projects, the root build files, the kit files the workflow calls' {
            $read = [System.Collections.Generic.List[string]]::new()
            $read.Add('.github/workflows/mutation.yml')
            $read.Add('.github/workflows/mutation.reusable.yml')
            foreach ($match in [regex]::Matches($reusable.Text, '\$(?:env:)?KIT/(?<path>[^"''\s]+)')) { $read.Add($match.Groups['path'].Value) }
            foreach ($match in [regex]::Matches($reusable.Text, 'uses: \$/(?<path>\S+)')) { $read.Add("$($match.Groups['path'].Value)/action.yml") }
            foreach ($match in [regex]::Matches($reusable.Text, 'global-json-file: (?<path>\S+)')) { $read.Add($match.Groups['path'].Value) }
            # The solution, and every tracked file in each of its projects' folders: Stryker builds and mutates them.
            $solution = [string] @($kit.Yaml['jobs'].Values)[0]['with']['solution']
            $read.Add($solution)
            $projectFolders = foreach ($project in ([xml] (Get-Content -Raw (Join-Path $root $solution))).SelectNodes('//Project')) {
                Split-Path ($project.Path -replace '\\', '/') -Parent
            }
            foreach ($folder in $projectFolders) { git -C $root ls-files -- $folder | ForEach-Object { $read.Add($_) } }
            # What dotnet, MSBuild and the analyzers read on the way from each project up to the repo root, as MSBuild
            # looks Directory.Build.props up: every such file in every folder between (review 6 of PR 23 found
            # sample/Directory.Build.props, which the root-only list missed).
            $buildInput = '^(global\.json|nuget\.config|\.editorconfig|Directory\.[^.]+\.(props|targets|rsp))$'
            foreach ($folder in $projectFolders) {
                for ($dir = $folder; $dir; $dir = Split-Path $dir -Parent) {
                    git -C $root ls-files -- "$dir/*" | Where-Object { ((Split-Path $_ -Parent) -replace '\\', '/') -eq $dir -and (Split-Path -Leaf $_) -match $buildInput } |
                        ForEach-Object { $read.Add($_) }
                }
            }
            Get-ChildItem -LiteralPath $root -File -Force | Where-Object Name -Match $buildInput | ForEach-Object { $read.Add($_.Name) }

            $patterns = Get-IgnorePattern
            $read.Count | Should -BeGreaterThan 50 -Because 'the sample alone has more tracked files than that'
            foreach ($file in ($read | Sort-Object -Unique)) {
                @($patterns | Where-Object { $file -cmatch $_ }) | Should -BeNullOrEmpty -Because "the mutation run reads $file"
            }
        }

        It 'skips a pull request that changes only docs and the files made from them, as a standards edit does' {
            # Review 5 of PR 23: a standards edit regenerates the Copilot instruction files under .github/, and a
            # release-please PR changes only its manifest and CHANGELOG.md, so both ran the mutation test for nothing.
            $docsOnly = [System.Collections.Generic.List[string]]::new()
            # Found by the generator's marker comment, wherever front matter puts it in the file (review 6 of PR 23:
            # reading only the first lines missed 9 rule files).
            $generated = @(git -C $root ls-files | Where-Object {
                    $_ -match '\.(md|mdc)$' -and (Get-Content -Raw -LiteralPath (Join-Path $root $_) -ErrorAction SilentlyContinue) -match '<!-- Generated by Build-AgentRules\.ps1 from '
                })
            foreach ($place in '.claude/rules/*', '.github/instructions/*', '.github/copilot-instructions.md') {
                @($generated | Where-Object { $_ -like $place }).Count | Should -BeGreaterThan 0 -Because "Build-AgentRules.ps1 writes $place"
            }
            $generated | ForEach-Object { $docsOnly.Add($_) }
            foreach ($file in 'docs/standards/testing.md', 'AGENTS.md', 'CHANGELOG.md', '.release-please-manifest.json', '.github/pull_request_template.md') { $docsOnly.Add($file) }

            $patterns = Get-IgnorePattern
            foreach ($file in ($docsOnly | Sort-Object -Unique)) {
                @($patterns | Where-Object { $file -cmatch $_ }) | Should -Not -BeNullOrEmpty -Because "$file only records docs"
            }
        }

        It 'calls the shared workflow for the kit''s solution, with a read-only token' {
            $kit.Yaml.ContainsKey('jobs') | Should -BeTrue
            $job = @($kit.Yaml['jobs'].Values)[0]

            $job['uses'] | Should -Be './.github/workflows/mutation.reusable.yml'
            $job['with']['solution'] | Should -Be 'dotnet-agent-kit.slnx'
            $kit.Yaml['permissions']['contents'] | Should -Be 'read'
        }
    }

    Context 'mutation.reusable.yml' {
        It 'installs the Stryker.NET version the kit''s tool manifest pins, and runs it with the kit''s settings file' {
            # One place for each: the version in .config/dotnet-tools.json, where Dependabot keeps it current, and every
            # setting in .config/stryker-config.json, which a person running Stryker locally uses too (review of PR 23).
            $run = (Get-Steps $reusable.Yaml | ForEach-Object { "$($_['run'])" }) -join "`n"

            $run | Should -Match '\$env:KIT/\.config/dotnet-tools\.json'
            $run | Should -Match 'dotnet tool install dotnet-stryker --version \$version '
            $run | Should -Match '--config-file "\$KIT/\.config/stryker-config\.json"'
            $run | Should -Match '--solution "\$SOLUTION"'
            $run | Should -Not -Match '--version \d|--test-runner|--break-at|--threshold|--reporter|"stryker-config"' -Because 'the settings live in the kit''s files, not in the workflow'
        }
    }

    Context 'the kit''s Stryker files' {
        It 'pins Stryker.NET in the tool manifest' {
            $path = Join-Path $root '.config/dotnet-tools.json'
            Test-Path $path | Should -BeTrue
            $manifest = Get-Content -Raw $path | ConvertFrom-Json -AsHashtable

            $manifest['tools']['dotnet-stryker']['version'] | Should -Match '^\d+\.\d+\.\d+$'
            @($manifest['tools']['dotnet-stryker']['commands']) | Should -Contain 'dotnet-stryker'
        }

        It 'keeps every setting in stryker-config.json: the MTP runner, failing below 85%, per-test coverage, ConfigureAwait skipped' {
            # Per-test coverage stays (the default): with the API tests fixed it captures coverage, and the report
            # check needs it. ConfigureAwait(true) can't change behaviour without a synchronization context.
            $path = Join-Path $root '.config/stryker-config.json'
            Test-Path $path | Should -BeTrue
            $config = (Get-Content -Raw $path | ConvertFrom-Json -AsHashtable)['stryker-config']

            $config['test-runner'] | Should -Be 'mtp'
            $config['configuration'] | Should -Be 'Release'
            $config['thresholds']['break'] | Should -Be 85
            $config['thresholds']['low'] | Should -Be 85
            @($config['reporters']) | Should -Contain 'html'
            @($config['reporters']) | Should -Contain 'json'
            @($config['ignore-methods']) | Should -Contain 'ConfigureAwait'
            $config.ContainsKey('coverage-analysis') | Should -BeFalse
        }

        It 'keeps a local run''s StrykerOutput folder out of commits, here and in every app (which copies .gitignore)' {
            # Re-review of PR 23: the documented local run writes StrykerOutput/<date>/ at the repo root.
            # Only the repo's own .gitignore counts, not this machine's global excludes.
            $noGlobal = Join-Path $TestDrive 'no-global-excludes'
            git -C $root -c "core.excludesFile=$noGlobal" check-ignore --no-index -q 'StrykerOutput/2026-11-08.06-17-00/reports/mutation-report.json'
            $LASTEXITCODE | Should -Be 0 -Because 'StrykerOutput/ must be in .gitignore'
        }

        It 'skips Stryker while the solution has no projects, as a new app''s does' {
            $steps = @(Get-Steps $reusable.Yaml)
            $count = @($steps | Where-Object { $_['id'] -eq 'projects' })
            $stryker = @($steps | Where-Object { "$($_['run'])" -match 'dotnet-stryker' })

            $count.Count | Should -Be 1
            $stryker.Count | Should -BeGreaterThan 0
            $stryker | ForEach-Object { $_['if'] | Should -Be "steps.projects.outputs.count != '0'" }
        }

        It 'refuses a score that one test inflated, with the kit''s Test-MutationReport.ps1 at its own version' {
            $steps = @(Get-Steps $reusable.Yaml)
            $kitTools = @($steps | Where-Object { "$($_['uses'])" -eq '$/.github/actions/kit-tools' })
            $check = @($steps | Where-Object { "$($_['run'])" -match 'Test-MutationReport\.ps1' })

            $kitTools.Count | Should -Be 1
            $kitTools[0]['id'] | Should -Be 'kit'
            $check.Count | Should -Be 1
            "$($check[0]['run'])" | Should -Match '\$env:KIT/tools/Test-MutationReport\.ps1'
            "$($check[0]['run'])" | Should -Match 'stryker-output/reports/mutation-report\.json'
            $check[0]['if'] | Should -Match 'always\(\)'
            $check[0]['if'] | Should -Match "steps\.projects\.outputs\.count != '0'"
        }

        It 'uploads the HTML and JSON report, even when the score fails, so the surviving mutants can be read' {
            # The YAML parser drops the "# vX" comment, so the version is read from the text.
            $upload = @(Get-Steps $reusable.Yaml | Where-Object { "$($_['uses'])" -match '^actions/upload-artifact@[0-9a-f]{40}$' })

            $upload.Count | Should -Be 1
            $reusable.Text | Should -Match 'actions/upload-artifact@[0-9a-f]{40} # v\d'
            $upload[0]['if'] | Should -Match 'always\(\)'
            "$($upload[0]['with']['path'])" | Should -Match 'stryker-output/reports'
        }
    }
}
