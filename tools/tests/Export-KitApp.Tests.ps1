#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Export-KitApp writes a new app repo's files from the kit at one version (PR D2a, ADR-0032). The tests
# build a throwaway kit repo from this working tree (tracked and new files), commit it, and export from
# that commit, so they run before the kit's own changes are committed.

Describe 'Export-KitApp' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $script = Join-Path $root 'tools' 'Export-KitApp.ps1'

        $kit = Join-Path $TestDrive 'kit'
        $files = git -C $root ls-files --cached --others --exclude-standard
        foreach ($file in $files) {
            $source = Join-Path $root $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted but not yet staged
            $target = Join-Path $kit $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
        git -C $kit init -q -b main
        git -C $kit -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false add -A
        git -C $kit -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -q -m 'chore: kit fixture'
        $commit = (git -C $kit rev-parse HEAD).Trim()

        # An edit nobody committed must not reach an app.
        Add-Content -LiteralPath (Join-Path $kit '.editorconfig') -Value '# uncommitted-edit-marker'

        $app = Join-Path $TestDrive 'app'
        & $script -Name 'Contoso.Orders' -Destination $app -KitRef $commit -KitRoot $kit
        $exportExit = $LASTEXITCODE

        . $script
        $map = @(Get-KitAppFileMap -KitRoot $kit -Commit $commit -Name 'Contoso.Orders')

        # The expected bytes: a clean checkout of the commit, line endings as .gitattributes gives them.
        $checkout = Join-Path $TestDrive 'checkout'
        git -C $kit worktree add -q --detach $checkout $commit
    }

    AfterAll {
        git -C $kit worktree remove --force $checkout
    }

    It 'exits 0' {
        $exportExit | Should -Be 0
    }

    It 'copies every kit-managed file unchanged, as it is at the chosen commit' {
        $copied = @($map | Where-Object { $_.Kind -eq 'Copy' })

        $copied.Count | Should -BeGreaterThan 40
        foreach ($entry in $copied) {
            $expected = [IO.File]::ReadAllBytes((Join-Path $checkout $entry.Source))
            $actualPath = Join-Path $app $entry.Target
            Test-Path -LiteralPath $actualPath | Should -BeTrue -Because "$($entry.Target) should be exported"
            [Convert]::ToHexString([IO.File]::ReadAllBytes($actualPath)) |
                Should -Be ([Convert]::ToHexString($expected)) -Because "$($entry.Target) should match the kit's $($entry.Source)"
        }
    }

    It 'ignores an edit in the kit that isn''t committed' {
        Get-Content -Raw (Join-Path $app '.editorconfig') | Should -Not -Match 'uncommitted-edit-marker'
    }

    It 'renders the app''s own files from the templates, with no placeholder left' {
        foreach ($path in 'AGENTS.md', 'README.md', 'Contoso.Orders.slnx', 'docs/corrections-log.md',
            '.github/workflows/ci.yml', '.github/workflows/app-checks.yml', '.github/dependabot.yml') {
            Test-Path -LiteralPath (Join-Path $app $path) | Should -BeTrue -Because "$path comes from templates/app"
        }
        Get-Content -Raw (Join-Path $app 'README.md') | Should -Match '# Contoso\.Orders'

        # ${{ github.ref }} in a workflow is GitHub's syntax, not a template placeholder.
        $leftovers = Get-ChildItem -LiteralPath $app -Recurse -File | Select-String -Pattern '\{\{[A-Za-z]+\}\}'
        @($leftovers | ForEach-Object { "$($_.Path):$($_.LineNumber)" }) | Should -BeNullOrEmpty
    }

    It 'pins both caller workflows to the kit commit, with the version in a comment, and names the solution' {
        foreach ($path in '.github/workflows/ci.yml', '.github/workflows/app-checks.yml') {
            Test-Path -LiteralPath (Join-Path $app $path) | Should -BeTrue -Because "$path should be exported"
        }
        $ci = Get-Content -Raw (Join-Path $app '.github/workflows/ci.yml')
        $checks = Get-Content -Raw (Join-Path $app '.github/workflows/app-checks.yml')

        $ci | Should -Match ([regex]::Escape("uses: DerekFoulk/dotnet-agent-kit/.github/workflows/dotnet-ci.reusable.yml@$commit # unreleased"))
        $ci | Should -Match 'solution: Contoso\.Orders\.slnx'
        $checks | Should -Match ([regex]::Escape("uses: DerekFoulk/dotnet-agent-kit/.github/workflows/app-checks.reusable.yml@$commit # unreleased"))
    }

    It 'starts with a solution that has no projects' {
        Test-Path -LiteralPath (Join-Path $app 'Contoso.Orders.slnx') | Should -BeTrue -Because 'the solution should be exported'
        $solution = [xml](Get-Content -Raw (Join-Path $app 'Contoso.Orders.slnx'))

        $solution.DocumentElement.Name | Should -Be 'Solution'
        $solution.SelectNodes('//Project').Count | Should -Be 0
    }

    It 'copies the kit''s shared AGENTS.md sections word for word into the app''s kit block' {
        function Get-Section([string] $Text, [string] $Title) {
            $match = [regex]::Match($Text, "(?ms)^## $([regex]::Escape($Title))\r?\n.*?(?=^## |^<!-- kit:end|\z)")
            $match.Success | Should -BeTrue -Because "'## $Title' should be there"
            $match.Value.TrimEnd()
        }
        Test-Path -LiteralPath (Join-Path $app 'AGENTS.md') | Should -BeTrue -Because 'AGENTS.md should be exported'
        $kitAgents = Get-Content -Raw (Join-Path $checkout 'AGENTS.md')
        $appAgents = Get-Content -Raw (Join-Path $app 'AGENTS.md')

        foreach ($title in 'Whose rules win', 'How to work', 'Talking to the owner', 'Git', 'Ask before') {
            Get-Section $appAgents $title | Should -Be (Get-Section $kitAgents $title)
        }
        $appAgents | Should -Match '<!-- kit:begin'
        $appAgents | Should -Match '<!-- kit:end -->'
    }

    It 'writes a manifest of the kit version and every kit-managed file, with its SHA-256' {
        $manifestPath = Join-Path $app '.kit/manifest.json'
        Test-Path -LiteralPath $manifestPath | Should -BeTrue -Because 'the sync job reads .kit/manifest.json'
        $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable

        $manifest['kitRepository'] | Should -Be 'DerekFoulk/dotnet-agent-kit'
        $manifest['kitCommit'] | Should -Be $commit
        $manifest['kitVersion'] | Should -Be 'unreleased'

        $listed = @{}
        foreach ($file in $manifest['files']) { $listed[$file['path']] = $file }
        $kitOwned = @($map | Where-Object { $_.Owner -eq 'Kit' } | ForEach-Object { $_.Target })
        $kitOwned | Should -Contain '.github/workflows/ci.yml'
        foreach ($path in $kitOwned) {
            $listed.ContainsKey($path) | Should -BeTrue -Because "$path is kit-managed"
            $actual = (Get-FileHash -LiteralPath (Join-Path $app $path) -Algorithm SHA256).Hash.ToLowerInvariant()
            $listed[$path]['sha256'] | Should -Be $actual -Because "$path's hash should match the exported file"
        }

        # The app owns these from the start; the sync job never touches them.
        foreach ($path in 'README.md', 'Contoso.Orders.slnx', 'docs/corrections-log.md') {
            $listed.ContainsKey($path) | Should -BeFalse -Because "$path belongs to the app"
        }

        # AGENTS.md is the app's, except the block between kit:begin and kit:end.
        $block = [regex]::Match((Get-Content -Raw (Join-Path $app 'AGENTS.md')), '(?s)<!-- kit:begin.*?<!-- kit:end -->').Value
        $blockHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($block))).ToLowerInvariant()
        $listed['AGENTS.md']['block'] | Should -Be 'kit'
        $listed['AGENTS.md']['sha256'] | Should -Be $blockHash
    }

    It 'includes the build files, agent files, rules, notices and tools an app needs' {
        $targets = @($map | ForEach-Object { $_.Target })

        foreach ($path in '.editorconfig', 'global.json', 'nuget.config', 'Directory.Build.props', 'tests/Directory.Build.props',
            'THIRD-PARTY-NOTICES.md', 'CLAUDE.md', '.mcp.json', '.claude/settings.json', '.claude/agents/reviewer.md',
            '.claude/skills/tdd-cycle/SKILL.md', 'docs/standards/git.md', '.githooks/commit-msg', '.githooks/commit-msg.ps1',
            '.github/pull_request_template.md', 'docs/adr/0000-template.md', '.kit/tools/Test-ConventionalTitle.ps1') {
            $targets | Should -Contain $path
        }
    }
}
