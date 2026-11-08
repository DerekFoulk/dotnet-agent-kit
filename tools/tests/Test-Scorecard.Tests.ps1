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

    It 'reports <Case>, which would count one thing twice' -ForEach @(
        @{ Case = 'a rule an area names twice'; Expected = '*STY-001*twice*' }
        @{ Case = 'two areas with the same id'; Expected = '*code*already*' }
    ) {
        # Review 1 of the scorecard PR: the row counted 2 rules in force for 1 rule, and the check passed.
        $areas = if ($Case -like '*twice') { @(New-Area -Override @{ rules = @('STY-001', 'STY-001') }) }
        else { @((New-Area), (New-Area -Override @{ name = 'Code again' })) }
        $paths = New-Fixture -Areas $areas

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike $Expected
    }

    It 'reports <Case> instead of failing with an error' -ForEach @(
        @{ Case = 'a gap written as plain text'; Expected = '*gap*not*id, gap and status*' }
        @{ Case = 'an area written as plain text'; Expected = '*area*not*' }
        @{ Case = 'a scorecard with no areas'; Expected = '*no areas*' }
        @{ Case = 'a scorecard with no front matter'; Expected = '*no areas*' }
    ) {
        # Review 1 of the scorecard PR: these crashed the check with a runtime error.
        $paths = New-Fixture
        $yaml = switch -Wildcard ($Case) {
            '*gap*' { ConvertTo-Yaml ([ordered]@{ areas = @(New-Area -Override @{ gaps = @('No benchmarks') }) }) }
            '*area written*' { ConvertTo-Yaml ([ordered]@{ areas = @((New-Area), 'Performance') }) }
            '*no areas' { "title: scorecard`n" }
            default { $null }
        }
        $text = if ($null -eq $yaml) { "# Quality scorecard`n" } else { "---`n$yaml---`n# Quality scorecard`n" }
        Set-Content -LiteralPath $paths.Scorecard -Value $text

        $script:problems = $null
        { $script:problems = @(Get-Problem $paths) } | Should -Not -Throw
        @($script:problems | Where-Object { $_.Message -like $Expected }) | Should -HaveCount 1
    }

    It 'reports a scorecard shaped wrong: <Case>' -ForEach @(
        @{ Case = 'front matter that is only text'; Yaml = 'areas'; Expected = '*no areas*' }
        @{ Case = 'areas written as one map'; Yaml = "areas:`n  id: code`n  name: Code"; Expected = '*areas*list*' }
        @{ Case = 'an empty area'; Yaml = "areas:`n  - id: code`n    name: Code`n  -"; Expected = '*area 2 is empty*' }
        @{ Case = 'a rule written as a map'; Yaml = "areas:`n  - id: code`n    rules:`n      - a: b"; Expected = '*rules*text*' }
        @{ Case = 'a source written as a map'; Yaml = "areas:`n  - id: code`n    sources:`n      - a: b"; Expected = '*sources*text*' }
        @{ Case = 'a gap id written as a map'; Yaml = "areas:`n  - id: code`n    gaps:`n      - id: { a: b }`n        gap: One.`n        status: proposed"; Expected = "*gap*'id'*text*" }
    ) {
        # Review 2 of PR 18: these crashed, passed quietly, or named "System.Collections.Hashtable".
        $paths = New-Fixture
        Set-Content -LiteralPath $paths.Scorecard -Value "---`n$Yaml`n---`n# Quality scorecard`n"

        $script:problems = $null
        { $script:problems = @(Get-Problem $paths) } | Should -Not -Throw
        @($script:problems | Where-Object { $_.Message -like $Expected }) | Should -HaveCount 1
        @($script:problems | Where-Object { $_.Message -like '*Hashtable*' }) | Should -BeNullOrEmpty
    }

    It 'reports <Owner> field <Field> written as <Shape> instead of text' -ForEach @(
        @{ Owner = 'an area'; Field = 'id'; Shape = 'a map'; Value = @{ a = 'b' } }
        @{ Owner = 'an area'; Field = 'name'; Shape = 'a map'; Value = @{ a = 'b' } }
        @{ Owner = 'an area'; Field = 'name'; Shape = 'a list'; Value = @('a', 'b') }
        @{ Owner = 'an area'; Field = 'perfect'; Shape = 'a map'; Value = @{ a = 'b' } }
        @{ Owner = 'a gap'; Field = 'id'; Shape = 'a list'; Value = @('a', 'b') }
        @{ Owner = 'a gap'; Field = 'gap'; Shape = 'a map'; Value = @{ a = 'b' } }
        @{ Owner = 'a gap'; Field = 'status'; Shape = 'a list'; Value = @('closed') }
        @{ Owner = 'a gap'; Field = 'needs'; Shape = 'a map'; Value = @{ a = 'b' } }
    ) {
        # Review 3 of PR 18: these passed quietly and printed "System.Collections.Hashtable" in the table.
        $gap = [ordered]@{ id = 'GAP-001'; gap = 'One.'; status = 'proposed' }
        if ($Owner -eq 'a gap') { $gap[$Field] = $Value }
        $area = New-Area -Override @{ gaps = @($gap) }
        if ($Owner -eq 'an area') { $area[$Field] = $Value }
        $paths = New-Fixture -Areas @($area)

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike "*'$Field'*text*"
        "$($problems[0].Area) $($problems[0].Message)" | Should -Not -BeLike '*Hashtable*'
    }

    It 'accepts a gap whose optional needs is left blank, and reports a blank name once' {
        # Review 4 of PR 18: nothing pinned that a blank value is "missing", not "not text".
        $gap = [ordered]@{ id = 'GAP-001'; gap = 'One.'; status = 'proposed'; needs = $null }
        Get-Problem (New-Fixture -Areas @(New-Area -Override @{ gaps = @($gap) })) | Should -BeNullOrEmpty

        $problems = @(Get-Problem (New-Fixture -Areas @(New-Area -Override @{ name = $null })))
        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike "*missing 'name'*"
    }

    It 'reports text written over several lines, which would break the table' {
        $paths = New-Fixture
        $yaml = (ConvertTo-Yaml ([ordered]@{ areas = @(New-Area) })) -replace '(?m)^(\s*)name: Code\s*$', "`$1name: |`n`$1  Code`n`$1  and more"
        Set-Content -LiteralPath $paths.Scorecard -Value "---`n$yaml---`n"

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike "*'name'*one line*"
    }

    It 'reports a gap''s text written over several lines, but not a one-line block ending in a line break' {
        # Review 5 of PR 18: only an area's name was tested. YAML reads "name: |" with one line as "Code`n".
        $paths = New-Fixture
        $gap = [ordered]@{ id = 'GAP-001'; gap = "One.`nTwo."; status = 'proposed' }
        $yaml = ConvertTo-Yaml ([ordered]@{ areas = @(New-Area -Override @{ name = "Code`n"; gaps = @($gap) }) })
        Set-Content -LiteralPath $paths.Scorecard -Value "---`n$yaml---`n"

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Message | Should -BeLike "*gap GAP-001 whose 'gap'*several lines*"
    }

    It 'says which area has an id that isn''t text' {
        $paths = New-Fixture -Areas @(New-Area -Override @{ id = @('a', 'b') })

        $problems = @(Get-Problem $paths)

        $problems | Should -HaveCount 1
        $problems[0].Area | Should -Be 'area 1'
    }

    It 'counts no area when ''areas'' is one map' {
        $paths = New-Fixture
        Set-Content -LiteralPath $paths.Scorecard -Value "---`nareas:`n  id: code`n  name: Code`n  rules: [STY-001]`n---`n"

        @(Get-ScorecardRow -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards) | Should -BeNullOrEmpty
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

    It 'counts "Advisory:" as advisory in any case, but not a word that only starts with it' {
        # Review 1 of the scorecard PR: case and the word boundary weren't pinned by any test.
        $paths = New-Fixture -Rules @(
            (New-Rule -Id 'STY-001' -Enforcement 'Advisory: capitalized'),
            (New-Rule -Id 'STY-002' -Enforcement 'advisoryboard: a made-up tool name')
        ) -Areas @(New-Area -Override @{ rules = @('STY-001', 'STY-002') })

        $row = @(Get-ScorecardRow -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards)[0]

        $row.Advisory | Should -Be 1
        $row.CheckedByTool | Should -Be 1
    }

    Context 'the table in the file' {
        # The table between the markers is written by -Update, like Build-AgentRules.ps1 writes the rule files, and
        # the check fails when it no longer matches the rules.
        BeforeAll {
            $start = '<!-- scorecard-table:start -->'
            $end = '<!-- scorecard-table:end -->'
        }

        It 'is reported as out of date until -Update rewrites it, which keeps the rest of the file' {
            Get-Command Update-ScorecardTable -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because '-Update writes the table'
            $paths = New-Fixture -Rules @((New-Rule -Id 'STY-001'), (New-Rule -Id 'STY-002' -Enforcement 'advisory: judgment')) -Areas @(
                New-Area -Override @{ rules = @('STY-001', 'STY-002') }) -Body "`n# Quality scorecard`n`nBefore.`n`n$start`nold table`n$end`n`nAfter.`n"
            $frontMatter = (Get-Content -Raw -LiteralPath $paths.Scorecard) -replace '(?s)^(---.*?---).*$', '$1'

            $stale = @(Get-ScorecardTableProblem -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards)
            $stale | Should -HaveCount 1
            $stale[0].Message | Should -BeLike '*out of date*-Update*'

            Update-ScorecardTable -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards
            Get-ScorecardTableProblem -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards | Should -BeNullOrEmpty
            $text = Get-Content -Raw -LiteralPath $paths.Scorecard
            $text | Should -BeLike "$([WildcardPattern]::Escape($frontMatter))*Before.*After.*"
            $text | Should -Not -Match 'old table'
        }

        It 'shows a row per area and a summary over every rule, each rule counted once' {
            $paths = New-Fixture -Rules @((New-Rule -Id 'STY-001'), (New-Rule -Id 'STY-002' -Enforcement 'advisory: judgment'),
                (New-Rule -Id 'STY-003' -Status 'proposed')) -Areas @(
                (New-Area -Override @{ rules = @('STY-001', 'STY-002', 'STY-003') }),
                (New-Area -Override @{ id = 'tests'; name = 'Tests'; rules = @('STY-001'); gaps = @([ordered]@{ id = 'GAP-001'; gap = 'Mutation.'; status = 'proposed' }) })
            ) -Body "`n$start`n$end`n"
            Get-Command Update-ScorecardTable -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because '-Update writes the table'

            Update-ScorecardTable -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards
            $lines = (Get-Content -Raw -LiteralPath $paths.Scorecard) -split "`r?`n"

            $lines | Should -Contain '| Area | Rules in force | Checked by a tool | Advisory | Proposed rules | Open gaps |'
            $lines | Should -Contain '| Code | 2 | 1 | 1 | 1 | 0 |'
            $lines | Should -Contain '| Tests | 1 | 1 | 0 | 0 | 1 |'
            # STY-001 is in two areas but is one rule.
            $lines | Should -Contain '**Overall:** 2 rules in force, 1 checked by a tool and 1 advisory; 1 proposed; 1 open gap.'
        }

        It 'lists the open gaps under the table, with their area, status and what they need, but not closed ones' {
            $gaps = @(
                [ordered]@{ id = 'GAP-001'; gap = 'No mutation testing.'; status = 'planned'; needs = 'a CI change' }
                [ordered]@{ id = 'GAP-002'; gap = 'No style guide.'; status = 'proposed' }
                [ordered]@{ id = 'GAP-003'; gap = 'Done already.'; status = 'closed' }
            )
            $paths = New-Fixture -Areas @(New-Area -Override @{ gaps = $gaps }) -Body "`n$start`n$end`n"

            Update-ScorecardTable -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards
            $lines = (Get-Content -Raw -LiteralPath $paths.Scorecard) -split "`r?`n"

            $lines | Should -Contain '- **GAP-001** (Code, planned; needs a CI change): No mutation testing.'
            $lines | Should -Contain '- **GAP-002** (Code, proposed): No style guide.'
            # The front matter still has GAP-003; the generated part doesn't.
            $generated = (Get-Content -Raw -LiteralPath $paths.Scorecard) -replace '(?s)^.*?<!-- scorecard-table:start -->', ''
            $generated | Should -Not -Match 'GAP-003'
        }

        It 'is reported missing when the file has no table markers' {
            $paths = New-Fixture -Body "`n# Quality scorecard`n"
            Get-Command Get-ScorecardTableProblem -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'the check reads the table'

            $problems = @(Get-ScorecardTableProblem -ScorecardPath $paths.Scorecard -StandardsPath $paths.Standards)

            $problems | Should -HaveCount 1
            $problems[0].Message | Should -BeLike "*$start*"
        }
    }

    It 'passes on the kit''s own scorecard' {
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $real = @{
            Scorecard = Join-Path $repoRoot 'docs' 'quality' 'scorecard.md'
            Standards = Join-Path $repoRoot 'docs' 'standards'
            Adr       = Join-Path $repoRoot 'docs' 'adr'
        }
        Test-Path -LiteralPath $real.Scorecard | Should -BeTrue -Because 'the kit defines a "perfect" app in docs/quality/scorecard.md (ADR-0034)'

        $problems = @(Get-Problem $real) + @(Get-ScorecardTableProblem -ScorecardPath $real.Scorecard -StandardsPath $real.Standards)

        @($problems | Where-Object { $_ } | ForEach-Object { "$($_.Area): $($_.Message)" }) | Should -BeNullOrEmpty
    }

    Context 'run as a command' {
        BeforeAll {
            function Invoke-Check([hashtable] $Paths, [string[]] $Extra = @()) {
                $output = pwsh -NoProfile -File $script -ScorecardPath $Paths.Scorecard -StandardsPath $Paths.Standards -AdrPath $Paths.Adr @Extra 2>&1 | Out-String
                [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
            }
            $markers = "`n<!-- scorecard-table:start -->`n<!-- scorecard-table:end -->`n"
        }

        It 'exits 1 and names each problem' {
            $paths = New-Fixture -Areas @(New-Area -Override @{ rules = @('STY-001', 'STY-999') }) -Body $markers

            $result = Invoke-Check $paths

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'code: names rule STY-999'
            $result.Output | Should -Match 'out of date'
        }

        It 'exits 1 with a reason, not an error, when the scorecard has no areas' {
            $paths = New-Fixture
            Set-Content -LiteralPath $paths.Scorecard -Value "---`ntitle: scorecard`n---`n$markers"

            $result = Invoke-Check $paths

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'no areas'
            $result.Output | Should -Not -Match 'null'
        }

        It 'exits 1 with reasons, not an error, for a gap and an area written as plain text' {
            # Review 2 of the scorecard PR: the table and count code crashed on these too, and only the problem
            # list was tested.
            $paths = New-Fixture
            $yaml = ConvertTo-Yaml ([ordered]@{ areas = @((New-Area -Override @{ gaps = @('none yet') }), 'Performance') })
            Set-Content -LiteralPath $paths.Scorecard -Value "---`n$yaml---$markers"

            $result = Invoke-Check $paths

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match "gap 'none yet' that is not a map"
            $result.Output | Should -Match "area 2 \('Performance'\) is not a map"
            $result.Output | Should -Not -Match 'Cannot|Exception'
        }

        It 'exits 0 once -Update has written the table' {
            $paths = New-Fixture -Body $markers

            (Invoke-Check $paths -Extra '-Update').ExitCode | Should -Be 0
            $result = Invoke-Check $paths

            $result.ExitCode | Should -Be 0 -Because $result.Output
            $result.Output | Should -Match '1 area'
        }
    }
}
