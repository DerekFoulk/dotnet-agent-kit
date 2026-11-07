#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }, @{ ModuleName = 'powershell-yaml'; ModuleVersion = '0.4.12' }

# The quality scorecard (docs/quality/scorecard.md, ADR-0034) maps each quality area of a .NET app to the kit's
# rules and lists what's missing. The check keeps it honest: every rule it names exists, every rule in force has
# an area, and its table of counts matches the rules.

Describe 'Test-Scorecard.ps1' {
    BeforeAll {
        $script = Join-Path $PSScriptRoot '..' 'Test-Scorecard.ps1'
        if (Test-Path -LiteralPath $script) { . $script }

        function New-Rule {
            param([string] $Id, [string] $Status = 'accepted', [string] $Enforcement = 'ci: a check')
            [ordered]@{
                id = $Id; statement = "Rule $Id."; layer = 'owner'; status = $Status
                sources = @('owner, 2026-11-07'); enforcement = $Enforcement
            }
        }

        function New-Area {
            param([hashtable] $Override = @{}, [string[]] $Remove = @())
            $area = [ordered]@{
                id      = 'code'
                name    = 'Code'
                perfect = 'Idiomatic C# with every analyzer on and no warnings.'
                sources = @('https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions, retrieved 2026-11-07')
                rules   = @('STY-001')
                gaps    = @()
            }
            foreach ($key in $Override.Keys) { $area[$key] = $Override[$key] }
            foreach ($key in $Remove) { $area.Remove($key) }
            $area
        }

        # Writes the standards, ADR folder and scorecard into a fresh folder; returns the paths.
        function New-Fixture {
            param(
                [object[]] $Rules = @(New-Rule -Id 'STY-001'),
                [object[]] $Areas = @(New-Area),
                [string] $Body = "`n# Quality scorecard`n"
            )
            $root = Join-Path $TestDrive "scorecard-$(New-Guid)"
            $paths = @{
                Standards = Join-Path $root 'standards'
                Adr       = Join-Path $root 'adr'
                Scorecard = Join-Path $root 'quality' 'scorecard.md'
            }
            New-Item -ItemType Directory -Path $paths.Standards, $paths.Adr, (Split-Path $paths.Scorecard) | Out-Null
            Set-Content -LiteralPath (Join-Path $paths.Adr '0034-quality-scorecard.md') -Value '# ADR-0034'
            $standard = ConvertTo-Yaml ([ordered]@{ topic = 'style'; rules = $Rules })
            Set-Content -LiteralPath (Join-Path $paths.Standards 'code-style.md') -Value "---`n$standard---`n`n# Style`n"
            $scorecard = ConvertTo-Yaml ([ordered]@{ areas = $Areas })
            Set-Content -LiteralPath $paths.Scorecard -Value "---`n$scorecard---$Body"
            $paths
        }

        function Get-Problem([hashtable] $Paths) {
            @(Get-ScorecardProblem -ScorecardPath $Paths.Scorecard -StandardsPath $Paths.Standards -AdrPath $Paths.Adr)
        }
    }

    It 'finds no problems in a scorecard whose areas name existing rules and cover every rule in force' {
        Get-Command Get-ScorecardProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'Test-Scorecard.ps1 checks the scorecard'
        $paths = New-Fixture

        Get-Problem $paths | Should -BeNullOrEmpty
    }

    It 'reports a rule an area names that no standard has, with the area' {
        $paths = New-Fixture -Areas @(New-Area -Override @{ rules = @('STY-001', 'STY-999') })

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Area | Should -Be 'code'
        $problems[0].Message | Should -BeLike "*STY-999*"
    }

    It 'reports a retired rule an area still names' {
        # A retired rule is no longer in force, so it can't count toward an area.
        $paths = New-Fixture -Rules @((New-Rule -Id 'STY-001'), (New-Rule -Id 'STY-002' -Status 'retired')) -Areas @(
            New-Area -Override @{ rules = @('STY-001', 'STY-002') })

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*STY-002*retired*'
    }

    It 'reports a rule in force that no area names, but not a proposed one' {
        # A new rule must say which quality area it serves; a proposed rule isn't in force yet.
        $paths = New-Fixture -Rules @(
            (New-Rule -Id 'STY-001'), (New-Rule -Id 'STY-002'), (New-Rule -Id 'STY-003' -Status 'proposed'))

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike '*STY-002*no area*'
    }

    It 'reports an area missing <Field>' -ForEach @(
        @{ Field = 'id'; Empty = '' }, @{ Field = 'name'; Empty = '' }, @{ Field = 'perfect'; Empty = ' ' }, @{ Field = 'sources'; Empty = @() }
    ) {
        # Without what "perfect" means and where that comes from, an area's score measures nothing.
        foreach ($areas in @((New-Area -Remove $Field), (New-Area -Override @{ $Field = $Empty }))) {
            $paths = New-Fixture -Areas @($areas)

            $problems = @(Get-Problem $paths)

            $problems | Should -HaveCount 1
            $problems[0].Message | Should -BeLike "*$Field*"
        }
    }

    It 'reports a source that can''t be traced: <Source>' -ForEach @(
        @{ Source = 'https://learn.microsoft.com/dotnet/core/testing' }   # no retrieval date
        @{ Source = 'ADR-0999' }                                           # no such ADR
        @{ Source = 'owner' }                                              # no date
        @{ Source = 'a blog post' }
    ) {
        # The same formats as rule sources (Test-RuleSources.ps1): owner and date, an ADR, or a URL and its date.
        $paths = New-Fixture -Areas @(New-Area -Override @{ sources = @('ADR-0034', $Source) })

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Area | Should -Be 'code'
        $problems[0].Message | Should -BeLike "*$Source*"
    }

    It 'reports an area with no rules and no gaps, which nobody has looked at' {
        $paths = New-Fixture -Areas @(
            (New-Area),
            (New-Area -Override @{ id = 'performance'; name = 'Performance'; rules = @(); gaps = @() }))

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Area | Should -Be 'performance'
        $problems[0].Message | Should -BeLike '*no rules and no gaps*'
    }

    It 'accepts an area with gaps but no rules yet' {
        $gap = [ordered]@{ id = 'GAP-001'; gap = 'No benchmarks or budgets.'; status = 'proposed' }
        $paths = New-Fixture -Areas @(
            (New-Area),
            (New-Area -Override @{ id = 'performance'; name = 'Performance'; rules = @(); gaps = @($gap) }))

        Get-Problem $paths | Should -BeNullOrEmpty
    }

    It 'reports a gap that <Case>' -ForEach @(
        @{ Case = 'reuses another gap''s id'; Expected = '*GAP-001*already*'
            Gaps = @([ordered]@{ id = 'GAP-001'; gap = 'One.'; status = 'proposed' }, [ordered]@{ id = 'GAP-001'; gap = 'Two.'; status = 'planned' }) }
        @{ Case = 'has an unknown status'; Expected = '*status*done*'
            Gaps = @([ordered]@{ id = 'GAP-001'; gap = 'One.'; status = 'done' }) }
        @{ Case = 'has no id'; Expected = '*id*'
            Gaps = @([ordered]@{ gap = 'One.'; status = 'proposed' }) }
        @{ Case = 'doesn''t say what''s missing'; Expected = '*gap*'
            Gaps = @([ordered]@{ id = 'GAP-001'; status = 'proposed' }) }
    ) {
        $paths = New-Fixture -Areas @(New-Area -Override @{ gaps = $Gaps })

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Area | Should -Be 'code'
        $problems[0].Message | Should -BeLike $Expected
    }

    It 'counts each area''s rules from the standards: in force, checked by a tool, advisory, proposed, open gaps' {
        # Only the start of 'enforcement' decides: "advisory: ..." is advisory; "build:", "ci:", "ruleset:" and the
        # rest are checked by a tool, even when they add that some part is advisory.
        $paths = New-Fixture -Rules @(
            (New-Rule -Id 'STY-001' -Enforcement 'ci: a check'),
            (New-Rule -Id 'STY-002' -Enforcement 'advisory: no tool can judge it'),
            (New-Rule -Id 'STY-003' -Enforcement 'claude settings: asks first; the rest is advisory'),
            (New-Rule -Id 'STY-004' -Status 'proposed' -Enforcement 'ci: not yet')
        ) -Areas @(New-Area -Override @{
                rules = @('STY-001', 'STY-002', 'STY-003', 'STY-004')
                gaps  = @([ordered]@{ id = 'GAP-001'; gap = 'Open.'; status = 'planned' }, [ordered]@{ id = 'GAP-002'; gap = 'Done.'; status = 'closed' })
            })

        Get-Command Get-ScorecardRow -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'the check counts each area'
        $rows = @(Get-ScorecardRow -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards)

        $rows | Should -HaveCount 1
        $rows[0].Area | Should -Be 'Code'
        $rows[0].InForce | Should -Be 3
        $rows[0].CheckedByTool | Should -Be 2
        $rows[0].Advisory | Should -Be 1
        $rows[0].Proposed | Should -Be 1
        $rows[0].OpenGaps | Should -Be 1
    }
}
