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

        # A later kit commit without the "Sample app" label: exporting it fails after the copying has
        # started, which the cleanup tests need. Made before the uncommitted edit below, so it can't include it.
        git -C $kit switch -q -c no-sample-label
        $props = Join-Path $kit 'Directory.Packages.props'
        (Get-Content -Raw $props) -replace 'ItemGroup Label="Sample app"', 'ItemGroup' | Set-Content -LiteralPath $props -NoNewline
        git -C $kit -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -q -m 'chore: no label' -- Directory.Packages.props
        git -C $kit switch -q main

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

        $copied.Count | Should -BeGreaterThan 35
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
            $lf = [IO.File]::ReadAllText((Join-Path $app $path)) -replace "`r`n", "`n"
            $actual = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lf))).ToLowerInvariant()
            $listed[$path]['sha256'] | Should -Be $actual -Because "$path's hash should match the exported file"
        }

        # The app owns these from the start; the sync job never touches them.
        foreach ($path in 'README.md', 'Contoso.Orders.slnx', 'docs/corrections-log.md') {
            $listed.ContainsKey($path) | Should -BeFalse -Because "$path belongs to the app"
        }

        # AGENTS.md is the app's, except the block between kit:begin and kit:end.
        $block = [regex]::Match((Get-Content -Raw (Join-Path $app 'AGENTS.md')), '(?s)<!-- kit:begin.*?<!-- kit:end -->').Value
        $blockHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($block -replace "`r`n", "`n")))).ToLowerInvariant()
        $listed['AGENTS.md']['block'] | Should -Be 'kit'
        $listed['AGENTS.md']['sha256'] | Should -Be $blockHash
    }

    # git stores text with LF line endings, but a checkout may give CRLF (core.autocrlf, .gitattributes), so
    # the manifest hashes the text with LF line endings: the same on every machine and every checkout.
    It 'hashes each kit-managed file with LF line endings, whatever the checkout gave' {
        $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
        function Get-LfHash([string] $Text) {
            $lf = $Text -replace "`r`n", "`n"
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lf))).ToLowerInvariant()
        }
        $withCrlf = 0
        foreach ($file in $manifest['files']) {
            $text = [IO.File]::ReadAllText((Join-Path $app $file['path']))
            if ($text.Contains("`r`n")) { $withCrlf++ }
            if ($file['block']) { $text = [regex]::Match($text, '(?s)<!-- kit:begin.*?<!-- kit:end -->').Value }
            $file['sha256'] | Should -Be (Get-LfHash $text) -Because "$($file['path']) should hash the same in an LF checkout"
        }
        $withCrlf | Should -BeGreaterThan 0 -Because 'this test needs some CRLF files to mean anything (.ps1 files are eol=crlf)'
    }

    It 'names only tools and parameters the app has, in its AGENTS.md commands' {
        $agents = Get-Content -Raw (Join-Path $app 'AGENTS.md')
        $calls = [regex]::Matches($agents, '\./\.kit/tools/(?<tool>[A-Za-z-]+\.ps1)(?<args>[^`]*)')

        $calls.Count | Should -BeGreaterThan 5
        foreach ($call in $calls) {
            $tool = Join-Path $app '.kit/tools' $call.Groups['tool'].Value
            Test-Path -LiteralPath $tool | Should -BeTrue -Because "AGENTS.md runs $($call.Groups['tool'].Value)"
            $parameters = (Get-Command -Name $tool).Parameters.Keys
            foreach ($name in [regex]::Matches($call.Groups['args'].Value, '(?<=\s)-(?<name>[A-Za-z]+)') | ForEach-Object { $_.Groups['name'].Value }) {
                $parameters | Should -Contain $name -Because "AGENTS.md passes -$name to $($call.Groups['tool'].Value)"
            }
        }
        foreach ($module in [regex]::Matches($agents, '\./\.kit/tools/(?<module>[A-Za-z-]+\.psm1)')) {
            Test-Path -LiteralPath (Join-Path $app '.kit/tools' $module.Groups['module'].Value) | Should -BeTrue
        }
    }

    It 'generates the app''s agent rule files, current with its standards and AGENTS.md' {
        foreach ($path in '.claude/rules/git.md', '.github/instructions/git.instructions.md', '.github/copilot-instructions.md') {
            Test-Path -LiteralPath (Join-Path $app $path) | Should -BeTrue -Because "$path is generated during export"
        }

        & pwsh -NoProfile -File (Join-Path $app '.kit/tools/Build-AgentRules.ps1') -RepoRoot $app -Check | Out-Null
        $LASTEXITCODE | Should -Be 0 -Because 'the app''s generated files should pass its own -Check'

        # Rule files come from the kit's standards, so the kit manages them; copilot-instructions.md copies
        # the app's own AGENTS.md, so it changes whenever the app's section does and isn't in the manifest.
        $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
        $listed = @($manifest['files'] | ForEach-Object { $_['path'] })
        $generated = @(Get-ChildItem -LiteralPath (Join-Path $app '.claude/rules'), (Join-Path $app '.github/instructions') -File |
                ForEach-Object { [IO.Path]::GetRelativePath($app, $_.FullName) -replace '\\', '/' })
        $generated.Count | Should -BeGreaterThan 10
        foreach ($path in $generated) { $listed | Should -Contain $path }
        $listed | Should -Not -Contain '.github/copilot-instructions.md'
    }

    It 'passes its own ADR check, which skips the ADR template' {
        $output = & pwsh -NoProfile -File (Join-Path $app '.kit/tools/Test-AdrSections.ps1') -AdrPath (Join-Path $app 'docs/adr') 2>&1 | Out-String

        $LASTEXITCODE | Should -Be 0 -Because $output
    }

    It 'seeds central package versions with the kit''s build and test packages, without the sample app''s' {
        $path = Join-Path $app 'Directory.Packages.props'
        Test-Path -LiteralPath $path | Should -BeTrue -Because 'an app needs central package management from the start'
        $props = [xml](Get-Content -Raw $path)
        $kitProps = [xml](Get-Content -Raw (Join-Path $checkout 'Directory.Packages.props'))

        $props.SelectSingleNode('//ManagePackageVersionsCentrally').InnerText | Should -Be 'true'
        $props.SelectSingleNode('//CentralPackageTransitivePinningEnabled').InnerText | Should -Be 'true'
        $props.SelectSingleNode('//GlobalPackageReference[@Include="MinVer"]') | Should -Not -BeNullOrEmpty

        $versions = @{}
        foreach ($node in $props.SelectNodes('//PackageVersion')) { $versions[$node.Include] = $node.Version }
        foreach ($sample in $kitProps.SelectNodes('//ItemGroup[@Label="Sample app"]/PackageVersion')) {
            $versions.ContainsKey($sample.Include) | Should -BeFalse -Because "$($sample.Include) is only the kit's sample app's"
        }
        $kitTests = @($kitProps.SelectNodes('//ItemGroup[not(@Label="Sample app")]/PackageVersion'))
        $kitTests.Count | Should -BeGreaterThan 3
        foreach ($node in $kitTests) {
            $versions[$node.Include] | Should -Be $node.Version -Because "$($node.Include) is part of the kit's toolset"
        }

        # The app adds its own packages here, so the app owns the file.
        $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
        @($manifest['files'] | ForEach-Object { $_['path'] }) | Should -Not -Contain 'Directory.Packages.props'
    }

    # PowerShell's location and the process's current directory differ; .NET file calls use the latter.
    It 'writes a relative destination under PowerShell''s current location, all in one place' {
        $parent = Join-Path $TestDrive 'relative-parent'
        New-Item -ItemType Directory -Path $parent | Out-Null
        Push-Location $parent
        try {
            & $script -Name 'Contoso.Orders' -Destination 'rel-app' -KitRef $commit -KitRoot $kit 6>&1 | Out-Null
            $exit = $LASTEXITCODE
        }
        finally { Pop-Location }

        $exit | Should -Be 0
        foreach ($path in 'Directory.Packages.props', '.kit/manifest.json', 'AGENTS.md', '.claude/rules/git.md') {
            Test-Path -LiteralPath (Join-Path $parent 'rel-app' $path) | Should -BeTrue -Because "$path should be in the relative destination"
        }
    }

    It 'removes the folder it created when the export fails partway, so a rerun can start clean' {
        $target = Join-Path $TestDrive 'partial'

        $output = & $script -Name 'Contoso.Orders' -Destination $target -KitRef 'no-sample-label' -KitRoot $kit 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Sample app'
        Test-Path -LiteralPath $target | Should -BeFalse -Because 'a half-written app would block the rerun'
    }

    # An app that adopts licensed code needs somewhere to put its notice, so only the kit's notices are the
    # kit's: they sit in a kit block, like AGENTS.md's.
    It 'keeps the kit''s third-party notices in a kit block, with room for the app''s own' {
        $path = Join-Path $app 'THIRD-PARTY-NOTICES.md'
        Test-Path -LiteralPath $path | Should -BeTrue
        $text = Get-Content -Raw $path
        $block = [regex]::Match($text, '(?s)<!-- kit:begin.*?<!-- kit:end -->')
        $block.Success | Should -BeTrue -Because 'the kit''s notices sit between kit:begin and kit:end'

        $kitNotices = (Get-Content -Raw (Join-Path $checkout 'THIRD-PARTY-NOTICES.md')) -replace '(?s)^# [^\r\n]*\r?\n', ''
        $normalize = { param($t) ($t -replace "`r`n", "`n").Trim() }
        (& $normalize $block.Value) | Should -Match ([regex]::Escape((& $normalize $kitNotices)))
        $text.Substring($block.Index + $block.Length) | Should -Match '(?m)^## This app'

        $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
        $entry = @($manifest['files'] | Where-Object { $_['path'] -eq 'THIRD-PARTY-NOTICES.md' })
        $entry.Count | Should -Be 1
        $entry[0]['block'] | Should -Be 'kit'
    }

    # The kit's sync job moves the kit pin and the SDK pin with each kit release, so Dependabot proposes only
    # the app's NuGet packages; the app owns the file and adds ecosystems as it grows.
    It 'gives the app its own Dependabot config, for its NuGet packages only' {
        $text = Get-Content -Raw (Join-Path $app '.github/dependabot.yml')
        $text | Should -Match 'package-ecosystem: nuget'
        $text | Should -Not -Match 'package-ecosystem: (dotnet-sdk|github-actions)'

        $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
        @($manifest['files'] | ForEach-Object { $_['path'] }) | Should -Not -Contain '.github/dependabot.yml'
    }

    It 'empties, but keeps, an empty folder it was given when the export fails partway' {
        $target = Join-Path $TestDrive 'given-empty'
        New-Item -ItemType Directory -Path $target | Out-Null

        $output = & $script -Name 'Contoso.Orders' -Destination $target -KitRef 'no-sample-label' -KitRoot $kit 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        # The failure must come after copying started, or the cleanup isn't exercised at all.
        $output | Should -Match 'Sample app' -Because 'the export should fail partway, or the cleanup isn''t exercised'
        Test-Path -LiteralPath $target | Should -BeTrue -Because 'the folder was the caller''s before the run'
        @(Get-ChildItem -LiteralPath $target -Force) | Should -BeNullOrEmpty -Because 'nothing the failed run wrote should stay'
    }

    It 'refuses a destination that already has files, and leaves them alone' {
        $busy = Join-Path $TestDrive 'busy'
        New-Item -ItemType Directory -Path $busy | Out-Null
        Set-Content -LiteralPath (Join-Path $busy 'keep.txt') -Value 'mine'

        $output = & $script -Name 'Contoso.Orders' -Destination $busy -KitRef $commit -KitRoot $kit 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'isn''t empty'
        @(Get-ChildItem -LiteralPath $busy -Force).Name | Should -Be @('keep.txt')
    }

    It 'refuses a name that isn''t a dotted .NET name, before writing anything' {
        # Con, Nul, Com1 and the like are Windows device names: a bare Con folder fails, and older Windows and
        # some tools refuse Con.Orders.slnx too.
        foreach ($bad in 'Contoso Orders', '1Orders', 'Contoso..Orders', '../escape', '', 'Con', 'Nul.Orders', 'Contoso.Com1') {
            $target = Join-Path $TestDrive "bad-$([guid]::NewGuid().ToString('N'))"

            $output = & $script -Name $bad -Destination $target -KitRef $commit -KitRoot $kit 6>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because "'$bad' isn't a valid app name"
            $output | Should -Match 'name' -Because "the message should say the name is the problem for '$bad'"
            Test-Path -LiteralPath $target | Should -BeFalse -Because "nothing should be written for '$bad'"
        }
    }

    It 'refuses a kit ref that isn''t a commit or tag, before writing anything' {
        $target = Join-Path $TestDrive 'unknown-ref'

        $output = & $script -Name 'Contoso.Orders' -Destination $target -KitRef 'v9.9.9-nope' -KitRoot $kit 6>&1 | Out-String

        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'v9\.9\.9-nope'
        Test-Path -LiteralPath $target | Should -BeFalse
    }

    # A ref that merely looks like a release (v0.1.0~3, a branch v1.2.3-wip) must not label the app with a
    # release it isn't: ADR-0031 trusts a pin only when a release tag points to it.
    It 'labels the kit version with a release tag only when a tag points to the commit' {
        git -C $kit tag v0.0.1 $commit
        git -C $kit branch v1.2.3-wip $commit
        try {
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v0.0.1' -Commit $commit | Should -Be 'v0.0.1'

            # Two releases on one commit: the one named wins; by SHA, the highest version (0.10 above 0.9).
            git -C $kit tag v0.9.0 $commit
            git -C $kit tag v0.10.0 $commit
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v0.9.0' -Commit $commit | Should -Be 'v0.9.0'
            Get-KitVersionLabel -KitRoot $kit -KitRef $commit -Commit $commit | Should -Be 'v0.10.0'
            git -C $kit tag -d v0.9.0 v0.10.0 | Out-Null
            Get-KitVersionLabel -KitRoot $kit -KitRef $commit -Commit $commit | Should -Be 'v0.0.1'
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v1.2.3-wip' -Commit $commit | Should -Be 'v0.0.1'

            git -C $kit tag -d v0.0.1 | Out-Null
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v1.2.3-wip' -Commit $commit | Should -Be 'unreleased'
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v1.2.3-wip~0' -Commit $commit | Should -Be 'unreleased'

            # A release tag on a later commit, reached back with ~1: that names the commit, not a release of it.
            $child = (git -C $kit -c user.name=fixture -c user.email=fixture@example.invalid commit-tree "$commit^{tree}" -p $commit -m 'chore: later' | Out-String).Trim()
            git -C $kit tag v0.0.2 $child
            Get-KitVersionLabel -KitRoot $kit -KitRef 'v0.0.2~1' -Commit $commit | Should -Be 'unreleased'

            # Only a release tag (vX.Y.Z) counts, not any tag that happens to be on the commit.
            git -C $kit tag scratch-backup $commit
            Get-KitVersionLabel -KitRoot $kit -KitRef $commit -Commit $commit | Should -Be 'unreleased'
        }
        finally {
            foreach ($tag in 'v0.0.1', 'v0.0.2', 'v0.9.0', 'v0.10.0', 'scratch-backup') { git -C $kit tag -d $tag 2>&1 | Out-Null }
            git -C $kit branch -D v1.2.3-wip 2>&1 | Out-Null
        }
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
