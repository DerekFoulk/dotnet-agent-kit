#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Sync-KitApp brings a newer kit release into an existing app (PR D3, ADR-0042). The tests build a throwaway kit
# repo from this working tree with three release tags, export an app at v0.1.0 with Export-KitApp, edit the app the
# ways ADR-0042 covers, change the kit for v0.2.0, and sync.

BeforeAll {
    # The kit's files, listed first, with this checkout's own ignore rules, global ones included: it's the
    # person's checkout, not a test repo.
    $kitFiles = git -C (Join-Path $PSScriptRoot '..' '..') ls-files --cached --others --exclude-standard
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'Sync-KitApp' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $script = Join-Path $root 'tools' 'Sync-KitApp.ps1'

        function Set-FileText([string] $Path, [string] $Text) {
            New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
            [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
        }
        function Edit-FileText([string] $Path, [string] $Find, [string] $Replace) {
            $text = [IO.File]::ReadAllText($Path)
            $text.Contains($Find) | Should -BeTrue -Because "the fixture edits '$Find' in $Path"
            Set-FileText $Path $text.Replace($Find, $Replace)
        }
        function Get-LfHash([string] $Text) {
            $lf = $Text -replace "`r`n", "`n"
            [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($lf))).ToLowerInvariant()
        }
        function Get-Tree([string] $Path) {
            $tree = @{}
            foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -File -Force) {
                $tree[[IO.Path]::GetRelativePath($Path, $file.FullName).Replace('\', '/')] = [Convert]::ToHexString([IO.File]::ReadAllBytes($file.FullName))
            }
            $tree
        }

        # The kit: v0.0.9, then v0.1.0, which the app starts from.
        $kit = Join-Path $TestDrive 'kit'
        foreach ($file in $kitFiles) {
            $source = Join-Path $root $file
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # deleted but not yet staged
            $target = Join-Path $kit $file
            New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
            Copy-Item -LiteralPath $source -Destination $target
        }
        git -C $kit init -q -b main
        git -C $kit add -A
        git -C $kit commit -q -m 'chore: kit fixture'
        git -C $kit tag v0.0.9
        Add-Content -LiteralPath (Join-Path $kit 'README.md') -Value 'v0.1.0'
        git -C $kit commit -q -am 'chore: v0.1.0'
        git -C $kit tag v0.1.0
        $v1 = (git -C $kit rev-parse HEAD).Trim()

        $app = Join-Path $TestDrive 'app'
        & (Join-Path $kit 'tools' 'Export-KitApp.ps1') -Name 'Contoso.Orders' -Destination $app -KitRef v0.1.0 -KitRoot $kit
        $LASTEXITCODE | Should -Be 0
        $manifestBefore = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable

        # The app's own changes, one for each case ADR-0042 covers.
        Add-Content -LiteralPath (Join-Path $app '.editorconfig') -Value '# app-edit-marker'   # merges with the kit's change
        Edit-FileText (Join-Path $app '.gitignore') '# dotenv files' '# dotenv files (app)'     # conflicts with the kit's change
        Remove-Item -LiteralPath (Join-Path $app '.claude/skills/plan-checklist/SKILL.md')       # deleted; the kit changes it
        Add-Content -LiteralPath (Join-Path $app '.claude/skills/tdd-cycle/SKILL.md') -Value 'app-tdd-marker' # the kit drops it
        Set-FileText (Join-Path $app '.claude/skills/app-skill/SKILL.md') "# The app's own skill`n" # the kit adds one here
        Add-Content -LiteralPath (Join-Path $app 'AGENTS.md') -Value "`napp-notes-marker"
        Add-Content -LiteralPath (Join-Path $app 'README.md') -Value "`napp-readme-marker"
        $instructions = @($manifestBefore['files'] | Where-Object { $_['path'] -like '.github/instructions/*' })[0]['path']
        Add-Content -LiteralPath (Join-Path $app $instructions) -Value 'app-generated-edit'
        $appOwned = 'README.md', 'Contoso.Orders.slnx', 'docs/corrections-log.md', 'Directory.Packages.props', '.github/dependabot.yml'
        $appOwnedBefore = @{}
        foreach ($path in $appOwned) { $appOwnedBefore[$path] = [Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $app $path))) }

        # Copies of the app before the sync, for the tests that must change nothing.
        $untouched = Join-Path $TestDrive 'untouched'
        Copy-Item -LiteralPath $app -Destination $untouched -Recurse
        $untouchedTree = Get-Tree $untouched

        # v0.2.0: the kit's changes.
        Edit-FileText (Join-Path $kit '.editorconfig') '# Microsoft .NET code-style baseline (D9).' '# Microsoft .NET code-style baseline (D9), kit-v2-marker.'
        Edit-FileText (Join-Path $kit '.gitignore') '# dotenv files' '# dotenv files (kit v2)'
        Add-Content -LiteralPath (Join-Path $kit '.claude/skills/plan-checklist/SKILL.md') -Value 'kit-v2-plan-marker'
        Remove-Item -LiteralPath (Join-Path $kit '.claude/skills/tdd-cycle/SKILL.md'), (Join-Path $kit '.claude/skills/write-adr/SKILL.md')
        Set-FileText (Join-Path $kit '.claude/skills/fresh-skill/SKILL.md') "# A new kit skill`n"
        Set-FileText (Join-Path $kit '.claude/skills/app-skill/SKILL.md') "# The kit's skill of the same name`n"
        Edit-FileText (Join-Path $kit 'global.json') '"version": "10.0.403"' '"version": "10.0.404"'
        Edit-FileText (Join-Path $kit 'docs/standards/git.md') 'squash and rebase merges are disabled.' 'squash and rebase merges are disabled (kit-v2-rule-marker).'
        Edit-FileText (Join-Path $kit 'AGENTS.md') '## Talking to the owner' "## Talking to the owner`n`nkit-v2-agents-marker"
        $settingsPath = Join-Path $kit '.claude/settings.json'
        $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json -AsHashtable
        $settings['permissions']['allow'] += 'PowerShell(dotnet --info)'
        $settings['permissions']['ask'] += 'PowerShell(./tools/Kit-OnlyFixture.ps1*)'
        Set-FileText $settingsPath ($settings | ConvertTo-Json -Depth 100)
        git -C $kit add -A
        git -C $kit commit -q -m 'feat: v0.2.0'
        git -C $kit tag v0.2.0
        git -C $kit tag not-a-release
        $v2 = (git -C $kit rev-parse HEAD).Trim()

        if (Test-Path -LiteralPath $script) { . $script }
    }

    Context 'refusing before any change' {
        It 'refuses a kit ref that isn''t a release tag (vX.Y.Z), and changes nothing' -ForEach @(
            @{ Ref = 'main' }
            @{ Ref = 'not-a-release' }
            @{ Ref = 'v9.9.9' }
        ) {
            { Sync-KitApp -AppRoot $untouched -KitRoot $kit -KitRef $Ref } | Should -Throw "*isn't a release tag*"
            Get-Tree $untouched | ConvertTo-Json | Should -Be ($untouchedTree | ConvertTo-Json)
        }

        It 'refuses a release that doesn''t come after the app''s kit commit, so it never goes back' {
            { Sync-KitApp -AppRoot $untouched -KitRoot $kit -KitRef v0.0.9 } | Should -Throw "*doesn't come after*"
            Get-Tree $untouched | ConvertTo-Json | Should -Be ($untouchedTree | ConvertTo-Json)
        }
    }

    It 'leaves an app already at the release as it is, and says so' {
        $result = Sync-KitApp -AppRoot $untouched -KitRoot $kit -KitRef v0.1.0

        $result | Should -Not -BeNullOrEmpty -Because 'the sync reports what it did'
        $result.Changed | Should -BeFalse
        $result.ToVersion | Should -Be 'v0.1.0'
        Get-Tree $untouched | ConvertTo-Json | Should -Be ($untouchedTree | ConvertTo-Json)
    }

    Context 'from v0.1.0 to v0.2.0' {
        BeforeAll {
            # What a new app made at v0.2.0 gets: the text every unedited kit-managed file should have after the sync.
            $expected = Join-Path $TestDrive 'expected'
            & (Join-Path $kit 'tools' 'Export-KitApp.ps1') -Name 'Contoso.Orders' -Destination $expected -KitRef v0.2.0 -KitRoot $kit
            $LASTEXITCODE | Should -Be 0
            $expectedManifest = Get-Content -Raw (Join-Path $expected '.kit/manifest.json') | ConvertFrom-Json -AsHashtable
            $edited = '.editorconfig', '.gitignore', '.claude/skills/plan-checklist/SKILL.md', '.claude/skills/app-skill/SKILL.md', $instructions

            $result = Sync-KitApp -AppRoot $app -KitRoot $kit -KitRef v0.2.0
        }

        It 'gives each kit-managed file the app didn''t edit the text a new app gets at the release' {
            $result | Should -Not -BeNullOrEmpty -Because 'the sync reports what it did'
            $result.Changed | Should -BeTrue
            $whole = @($expectedManifest['files'] | Where-Object { -not $_.Contains('block') -and $_['path'] -notin $edited })
            $whole.Count | Should -BeGreaterThan 40
            foreach ($file in $whole) {
                $path = Join-Path $app $file['path']
                Test-Path -LiteralPath $path | Should -BeTrue -Because "$($file['path']) is kit-managed at v0.2.0"
                Get-LfHash ([IO.File]::ReadAllText($path)) | Should -Be $file['sha256'] -Because "$($file['path']) should be the kit's at v0.2.0"
            }

            # Among them: the SDK pin, the CI pin, and the permission rules made again with v0.2.0's tools (ADR-0032),
            # so a rule for a script apps don't get stays out.
            Get-Content -Raw (Join-Path $app 'global.json') | Should -Match '"version": "10\.0\.404"'
            Get-Content -Raw (Join-Path $app '.github/workflows/ci.yml') | Should -Match ([regex]::Escape("dotnet-ci.reusable.yml@$v2 # v0.2.0"))
            $settings = Get-Content -Raw (Join-Path $app '.claude/settings.json') | ConvertFrom-Json
            $settings.permissions.allow | Should -Contain 'PowerShell(dotnet --info)'
            $settings.permissions.ask | Should -Not -Contain 'PowerShell(./tools/Kit-OnlyFixture.ps1*)'
        }

        It 'removes a file the kit no longer has, when the app didn''t edit it' {
            Test-Path -LiteralPath (Join-Path $app '.claude/skills/write-adr/SKILL.md') | Should -BeFalse
            @($result.Files | Where-Object Path -EQ '.claude/skills/write-adr/SKILL.md').Action | Should -Be 'Removed'
        }

        It 'replaces the kit block of <Path> with the release''s, and keeps the rest of the file' -ForEach @(
            @{ Path = 'AGENTS.md'; AppText = 'app-notes-marker' }
            @{ Path = 'THIRD-PARTY-NOTICES.md'; AppText = "## This app's notices" }
        ) {
            $pattern = '(?s)<!-- kit:begin.*?<!-- kit:end -->'
            $text = [IO.File]::ReadAllText((Join-Path $app $Path))
            $block = [regex]::Match($text, $pattern).Value
            $expectedBlock = [regex]::Match([IO.File]::ReadAllText((Join-Path $expected $Path)), $pattern).Value

            ($block -replace "`r`n", "`n") | Should -Be ($expectedBlock -replace "`r`n", "`n")
            $text | Should -Match ([regex]::Escape($AppText))
            $text | Should -Match '(?m)^# '
        }

        It 'moves the app''s note of its kit version with the block' {
            $agents = Get-Content -Raw (Join-Path $app 'AGENTS.md')

            $agents | Should -Match ([regex]::Escape("dotnet-agent-kit v0.2.0 (commit ``$v2``)"))
            $agents | Should -Match 'kit-v2-agents-marker'
        }

        It 'leaves the app''s own files byte for byte as they were' {
            foreach ($path in $appOwned) {
                [Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $app $path))) | Should -Be $appOwnedBefore[$path] -Because "$path is the app's"
            }
        }
    }
}
