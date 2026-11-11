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
        Edit-FileText (Join-Path $kit 'templates/app/.github/workflows/mutation.yml') 'name: Mutation testing' "# kit-v2-workflow-marker`nname: Mutation testing"
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

        # Dependabot's PR: the kit pin, with its version comment, moved in every workflow (ADR-0042).
        foreach ($workflow in Get-ChildItem -LiteralPath (Join-Path $app '.github/workflows') -File) {
            Edit-FileText $workflow.FullName "@$v1 # v0.1.0" "@$v2 # v0.2.0"
        }

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

        It 'refuses an app whose manifest <Case>, and changes nothing' -ForEach @(
            @{ Case = 'is missing'; Change = { param($m) $null }; Message = '*has no .kit/manifest.json*' }
            @{ Case = 'has no app name (made before ADR-0042)'; Change = { param($m) $m.Remove('appName'); $m }; Message = '*no "appName"*' }
            @{ Case = 'has no full kit commit'; Change = { param($m) $m['kitCommit'] = 'v0.1.0'; $m }; Message = '*full kit commit*' }
        ) {
            $copy = Join-Path $TestDrive "manifest-$(New-Guid)"
            Copy-Item -LiteralPath $untouched -Destination $copy -Recurse
            $manifestPath = Join-Path $copy '.kit/manifest.json'
            $changed = & $Change (Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable)
            if ($null -eq $changed) { Remove-Item -LiteralPath $manifestPath } else { Set-FileText $manifestPath ($changed | ConvertTo-Json -Depth 4) }
            $before = Get-Tree $copy

            { Sync-KitApp -AppRoot $copy -KitRoot $kit -KitRef v0.2.0 } | Should -Throw $Message
            Get-Tree $copy | ConvertTo-Json | Should -Be ($before | ConvertTo-Json)
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

    It 'keeps an edited file instead of merging it when the kit''s earlier text can''t be rebuilt exactly' {
        # A manifest hash no export reproduces: the merge would have no trustworthy base.
        $copy = Join-Path $TestDrive 'unknown-base'
        Copy-Item -LiteralPath $untouched -Destination $copy -Recurse
        $manifestPath = Join-Path $copy '.kit/manifest.json'
        $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json -AsHashtable
        ($manifest['files'] | Where-Object { $_['path'] -eq '.editorconfig' })['sha256'] = '0' * 64
        Set-FileText $manifestPath ($manifest | ConvertTo-Json -Depth 4)

        $sync = Sync-KitApp -AppRoot $copy -KitRoot $kit -KitRef v0.2.0

        @($sync.Files | Where-Object Path -EQ '.editorconfig' | ForEach-Object Action) | Should -Be @('Conflict')
        Get-Content -Raw (Join-Path $copy '.editorconfig') | Should -Not -Match 'kit-v2-marker'
    }

    Context 'deciding each file' {
        It 'gives <Expected> for <Case>' -ForEach @(
            # Review of the decision table: the kit dropping a kit block must never delete the app's whole file.
            @{ Case = 'a kit block the kit no longer has'; Old = @{ path = 'AGENTS.md'; block = 'kit'; sha256 = 'a' * 64 }; Theirs = $null; Ours = 'a' * 64; Generated = $false; Expected = 'NowAppOwned' }
            @{ Case = 'an app file that already is the kit''s new file'; Old = $null; Theirs = @{ path = 'x'; sha256 = 'b' * 64 }; Ours = 'b' * 64; Generated = $false; Expected = 'None' }
            @{ Case = 'an edited generated file the kit no longer makes'; Old = @{ path = '.claude/rules/x.md'; sha256 = 'a' * 64 }; Theirs = $null; Ours = 'c' * 64; Generated = $true; Expected = 'Removed' }
        ) {
            Get-KitSyncAction -Old $Old -Theirs $Theirs -OursHash $Ours -Generated $Generated | Should -Be $Expected
        }
    }

    Context 'run as a script' {
        BeforeAll {
            $cli = Join-Path $TestDrive 'cli'
            Copy-Item -LiteralPath $untouched -Destination $cli -Recurse
            $report = Join-Path $TestDrive 'report.md'
            & pwsh -NoProfile -File $script -AppRoot $cli -KitRoot $kit -KitRef v0.2.0 -ReportPath $report *> $null
            $cliExit = $LASTEXITCODE
            $text = if (Test-Path -LiteralPath $report) { Get-Content -Raw -LiteralPath $report } else { '' }
        }

        It 'exits 0 and writes the pull request''s description' {
            $cliExit | Should -Be 0
            $text | Should -Match ([regex]::Escape("dotnet-agent-kit v0.2.0 (commit ``$v2``)"))
            $text | Should -Match ([regex]::Escape("from v0.1.0 (commit ``$v1``)"))
        }

        It 'lists every file that needs a look, with what happened and what to do' {
            foreach ($path in '.editorconfig', '.gitignore', '.claude/skills/plan-checklist/SKILL.md', '.claude/skills/tdd-cycle/SKILL.md',
                '.claude/skills/app-skill/SKILL.md', $instructions) {
                $text | Should -Match "(?m)^\| ``$([regex]::Escape($path))`` \| [^|]+ \| [^|]+ \|$" -Because "$path needs a look"
            }
            $text | Should -Not -Match '(?m)^\| `global\.json` \|' -Because 'an unedited file needs no look'
        }

        It 'lists the files it updated, added and removed' {
            $text | Should -Match '`global\.json`'
            $text | Should -Match '`\.claude/skills/fresh-skill/SKILL\.md`'
            $text | Should -Match '`\.claude/skills/write-adr/SKILL\.md`'
        }

        It 'tells the reviewer how to check the new kit pin against the release tag (ADR-0031)' {
            $text | Should -Match ([regex]::Escape('gh api repos/DerekFoulk/dotnet-agent-kit/commits/v0.2.0 --jq .sha'))
        }

        It 'writes no description, and exits 0, when the app is already at the release' {
            $again = Join-Path $TestDrive 'report-again.md'
            & pwsh -NoProfile -File $script -AppRoot $cli -KitRoot $kit -KitRef v0.2.0 -ReportPath $again *> $null

            $LASTEXITCODE | Should -Be 0
            Test-Path -LiteralPath $again | Should -BeFalse
        }
    }

    Context 'from v0.1.0 to v0.2.0' {
        BeforeAll {
            # What a new app made at v0.2.0 gets: the text every unedited kit-managed file should have after the sync.
            $expected = Join-Path $TestDrive 'expected'
            & (Join-Path $kit 'tools' 'Export-KitApp.ps1') -Name 'Contoso.Orders' -Destination $expected -KitRef v0.2.0 -KitRoot $kit
            $LASTEXITCODE | Should -Be 0
            $expectedManifest = Get-Content -Raw (Join-Path $expected '.kit/manifest.json') | ConvertFrom-Json -AsHashtable

            # What the sync reported for one file, or '(none)'.
            function Get-SyncAction([string] $Path) {
                $file = @($result.Files | Where-Object Path -EQ $Path)
                if ($file) { $file[0].Action } else { '(none)' }
            }
            $edited = '.editorconfig', '.gitignore', '.claude/skills/plan-checklist/SKILL.md', '.claude/skills/app-skill/SKILL.md', $instructions,
            '.github/workflows/mutation.yml'

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

            # Among them: the SDK pin, and the permission rules made again with v0.2.0's tools (ADR-0032), so a rule
            # for a script apps don't get stays out.
            Get-Content -Raw (Join-Path $app 'global.json') | Should -Match '"version": "10\.0\.404"'
            $settings = Get-Content -Raw (Join-Path $app '.claude/settings.json') | ConvertFrom-Json
            $settings.permissions.allow | Should -Contain 'PowerShell(dotnet --info)'
            $settings.permissions.ask | Should -Not -Contain 'PowerShell(./tools/Kit-OnlyFixture.ps1*)'
        }

        # A workflow's own token can't push a change to .github/workflows. Dependabot moves the pin there; anything
        # else the kit changed in a workflow is listed for a person to apply.
        It 'never writes a workflow file, and lists a kit change to one that Dependabot didn''t make' {
            $mutation = Get-Content -Raw (Join-Path $app '.github/workflows/mutation.yml')
            $mutation | Should -Not -Match 'kit-v2-workflow-marker'
            $mutation | Should -Match ([regex]::Escape("@$v2 # v0.2.0"))
            Get-SyncAction '.github/workflows/mutation.yml' | Should -Be 'WorkflowByHand'
            Get-SyncAction '.github/workflows/ci.yml' | Should -Be '(none)' -Because "Dependabot's pin is all the kit changed there"
        }

        It 'removes a file the kit no longer has, when the app didn''t edit it' {
            Test-Path -LiteralPath (Join-Path $app '.claude/skills/write-adr/SKILL.md') | Should -BeFalse
            Get-SyncAction '.claude/skills/write-adr/SKILL.md' | Should -Be 'Removed'
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

        It 'merges the kit''s change into a file the app edited, when the two don''t overlap, and reports it' {
            $text = Get-Content -Raw (Join-Path $app '.editorconfig')

            $text | Should -Match 'kit-v2-marker'
            $text | Should -Match 'app-edit-marker'
            Get-SyncAction '.editorconfig' | Should -Be 'Merged'
        }

        It 'keeps the app''s text, and reports it, when the app''s edit and the kit''s change overlap' {
            $text = Get-Content -Raw (Join-Path $app '.gitignore')

            $text | Should -Match '# dotenv files \(app\)'
            $text | Should -Not -Match 'kit v2'
            $text | Should -Not -Match '<<<<<<<|>>>>>>>'
            Get-SyncAction '.gitignore' | Should -Be 'Conflict'
        }

        It 'keeps the app''s choice for <Case>, and reports it as <Action>' -ForEach @(
            @{ Case = 'a kit file the app deleted, which the kit changed'; Path = '.claude/skills/plan-checklist/SKILL.md'; Action = 'KeptDeleted'; Text = $null }
            @{ Case = 'a kit file the app edited, which the kit dropped'; Path = '.claude/skills/tdd-cycle/SKILL.md'; Action = 'NowAppOwned'; Text = 'app-tdd-marker' }
            @{ Case = 'the app''s own file where the kit adds one'; Path = '.claude/skills/app-skill/SKILL.md'; Action = 'AppFileKept'; Text = "The app's own skill" }
        ) {
            $file = Join-Path $app $Path
            if ($null -eq $Text) { Test-Path -LiteralPath $file | Should -BeFalse }
            else { Get-Content -Raw $file | Should -Match ([regex]::Escape($Text)) }
            Get-SyncAction $Path | Should -Be $Action
        }

        It 'rebuilds the generated agent files from the release''s standards and the app''s AGENTS.md, and reports a lost edit' {
            $file = $expectedManifest['files'] | Where-Object { $_['path'] -eq $instructions }
            Get-LfHash ([IO.File]::ReadAllText((Join-Path $app $instructions))) | Should -Be $file['sha256']
            Get-SyncAction $instructions | Should -Be 'Regenerated'
            Get-Content -Raw (Join-Path $app '.claude/rules/git.md') | Should -Match 'kit-v2-rule-marker'

            # copilot-instructions.md copies the app's AGENTS.md, so it isn't kit-managed but must be current.
            $copilot = Get-Content -Raw (Join-Path $app '.github/copilot-instructions.md')
            $copilot | Should -Match 'kit-v2-agents-marker'
            $copilot | Should -Match 'app-notes-marker'
        }

        It 'leaves the app''s own files byte for byte as they were' {
            foreach ($path in $appOwned) {
                [Convert]::ToHexString([IO.File]::ReadAllBytes((Join-Path $app $path))) | Should -Be $appOwnedBefore[$path] -Because "$path is the app's"
            }
        }

        It 'writes the release''s manifest, so a kept edit still shows as an edit next time' {
            $manifest = Get-Content -Raw (Join-Path $app '.kit/manifest.json') | ConvertFrom-Json -AsHashtable

            $manifest['kitVersion'] | Should -Be 'v0.2.0'
            $manifest['kitCommit'] | Should -Be $v2
            $manifest['appName'] | Should -Be 'Contoso.Orders'
            ($manifest['files'] | ConvertTo-Json -Depth 4) | Should -Be ($expectedManifest['files'] | ConvertTo-Json -Depth 4)
            $gitignore = $manifest['files'] | Where-Object { $_['path'] -eq '.gitignore' }
            Get-LfHash ([IO.File]::ReadAllText((Join-Path $app '.gitignore'))) | Should -Not -Be $gitignore['sha256']
        }

        # Last: it runs the sync again on the synced app.
        It 'changes nothing when run again for the same release' {
            $before = Get-Tree $app

            (Sync-KitApp -AppRoot $app -KitRoot $kit -KitRef v0.2.0).Changed | Should -BeFalse
            Get-Tree $app | ConvertTo-Json | Should -Be ($before | ConvertTo-Json)
        }
    }
}
