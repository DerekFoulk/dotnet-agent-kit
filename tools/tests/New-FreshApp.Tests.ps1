#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-FreshApp writes a fresh app of one app type, with a probe project of that type, for the kit's CI to check
# (GAP-049, ADR-0095). Like Export-KitApp's tests, these build a throwaway kit repo from this working tree (tracked and
# new files), commit it, and export from that commit, so they run before the kit's own changes are committed.

BeforeAll {
    # The kit's files, listed before the test git settings, with this checkout's own ignore rules.
    $kitFiles = git -C (Join-Path $PSScriptRoot '..' '..') ls-files --cached --others --exclude-standard
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'New-FreshApp' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        . (Join-Path $root 'tools' 'New-FreshApp.ps1')
    }

    # MAUI's leg waits for GAP-028 (the Windows and macOS jobs proven), and the owner put MAUI after the practice run.
    It 'refuses an app type it has no probe for, naming the gap that waits for it' {
        { New-FreshApp -Type maui -Destination (Join-Path $TestDrive 'maui') -KitRef HEAD -KitRoot $root } |
            Should -Throw -ExpectedMessage '*maui*GAP-028*'
    }

    Context 'a fresh <Type> app' -ForEach @(
        @{ Type = 'web-api'; Name = 'Fresh.WebApi' }
        @{ Type = 'blazor'; Name = 'Fresh.Blazor' }
    ) {
        BeforeAll {
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
            $commit = (git -C $kit rev-parse HEAD).Trim()

            # A developer's preferences must not reach the app: a run here and CI's give the same app.
            Mock Read-KitPreference { throw 'New-FreshApp read a preferences file.' }

            $app = Join-Path $TestDrive 'app'
            New-FreshApp -Type $Type -Destination $app -KitRef $commit -KitRoot $kit
            $profilePath = Join-Path $app 'docs' 'app-profile.md'
            $intake = Get-Content -Raw -LiteralPath (Join-Path $kit 'templates' 'app-intake.json') | ConvertFrom-Json -AsHashtable
        }

        It 'gets the core ruleset and its own type''s, from a profile of the intake''s defaults' {
            $profilePath | Should -Exist
            $text = Get-Content -Raw -LiteralPath $profilePath
            @([regex]::Matches($text, '(?m)^App types: .*$').Value) | Should -Be @("App types: $Type")
            $label = @($intake['cards'] | Where-Object { $_['id'] -eq 'appType' })[0]['options'] |
                Where-Object { "$($_['appTypes'])" -ceq $Type } | ForEach-Object { $_['label'] }
            $text | Should -Match ([regex]::Escape("| $label |"))
            # One row per card, under the Choices table's header.
            $choices = [regex]::Match($text, '(?s)## Choices.*?\|---\|---\|---\|\r?\n(?<rows>(\|[^\r\n]*\r?\n)+)').Groups['rows'].Value
            @($choices -split '\r?\n' | Where-Object { $_ }).Count | Should -Be @($intake['cards']).Count
            Should -Invoke Read-KitPreference -Times 0 -Exactly
        }

        # The app's history is what its secret scan and commit checks read, so it starts as New-KitApp's does.
        It 'starts its history with New-KitApp''s first commit, on main, with the commit-msg hook executable' {
            Test-Path -LiteralPath (Join-Path $app '.git') | Should -BeTrue
            git -C $app branch --show-current | Should -Be 'main'
            @(git -C $app log --format=%s) | Should -Be @('chore: start from dotnet-agent-kit unreleased')
            (git -C $app ls-files --stage -- .githooks/commit-msg) | Should -Match '^100755 '
            git -C $app status --porcelain | Should -BeNullOrEmpty
        }
    }
}
