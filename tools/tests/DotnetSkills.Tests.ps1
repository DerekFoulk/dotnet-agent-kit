#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The kit carries a curated copy of skills from Microsoft's dotnet/skills repo, pinned to one upstream commit
# (ADR-0042). tools/dotnet-skills.json records the commit and git's blob id for every copied file, so an edit to a
# copy fails here instead of drifting from upstream unnoticed. Update-DotnetSkills.ps1 moves the copy to a newer
# commit.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Update-DotnetSkills.ps1')
}

Describe 'Get-DotnetSkillBlobId' {
    It 'gives git''s blob id for a file, the same with LF or CRLF line endings' {
        $lf = Join-Path $TestDrive 'lf.md'
        $crlf = Join-Path $TestDrive 'crlf.md'
        [IO.File]::WriteAllText($lf, "# Title`n`nText.`n")
        [IO.File]::WriteAllText($crlf, "# Title`r`n`r`nText.`r`n")
        $expected = (git hash-object --no-filters -- $lf | Out-String).Trim()

        Get-DotnetSkillBlobId -Path $lf | Should -Be $expected
        Get-DotnetSkillBlobId -Path $crlf | Should -Be $expected
    }
}

Describe 'Get-DotnetSkillDrift' {
    BeforeAll {
        # A skills folder with one curated skill of two files, and the lock entry that matches it.
        function New-Copy {
            $skills = Join-Path $TestDrive "skills-$(New-Guid)"
            New-Item -ItemType Directory -Force -Path (Join-Path $skills 'tidy' 'references') | Out-Null
            [IO.File]::WriteAllText((Join-Path $skills 'tidy' 'SKILL.md'), "---`nname: tidy`n---`n")
            [IO.File]::WriteAllText((Join-Path $skills 'tidy' 'references' 'more.md'), "More.`n")
            $files = [ordered]@{}
            foreach ($file in 'SKILL.md', 'references/more.md') { $files[$file] = Get-DotnetSkillBlobId -Path (Join-Path $skills 'tidy' $file) }
            $lock = @{ skills = @(@{ name = 'tidy'; source = 'plugins/p/skills/tidy'; files = $files }) }
            @{ Skills = $skills; Lock = $lock }
        }
    }

    It 'finds nothing when every file matches the lock' {
        $copy = New-Copy
        @(Get-DotnetSkillDrift -SkillsRoot $copy.Skills -Lock $copy.Lock) | Should -BeNullOrEmpty
    }

    It 'reports a file whose content differs from the lock' {
        $copy = New-Copy
        Add-Content -LiteralPath (Join-Path $copy.Skills 'tidy' 'references' 'more.md') -Value 'An edit.'

        @(Get-DotnetSkillDrift -SkillsRoot $copy.Skills -Lock $copy.Lock) | Should -Be @('tidy/references/more.md differs from the upstream commit')
    }

    It 'reports a file the lock lists that is missing' {
        $copy = New-Copy
        Remove-Item -LiteralPath (Join-Path $copy.Skills 'tidy' 'SKILL.md')

        @(Get-DotnetSkillDrift -SkillsRoot $copy.Skills -Lock $copy.Lock) | Should -Be @('tidy/SKILL.md is missing')
    }

    It 'reports a file in a curated skill''s folder that the lock doesn''t list' {
        $copy = New-Copy
        [IO.File]::WriteAllText((Join-Path $copy.Skills 'tidy' 'extra.md'), "Extra.`n")

        @(Get-DotnetSkillDrift -SkillsRoot $copy.Skills -Lock $copy.Lock) | Should -Be @('tidy/extra.md isn''t in the upstream commit')
    }

    It 'leaves alone folders of skills the lock doesn''t name, such as the kit''s own' {
        $copy = New-Copy
        New-Item -ItemType Directory -Path (Join-Path $copy.Skills 'start-work') | Out-Null
        [IO.File]::WriteAllText((Join-Path $copy.Skills 'start-work' 'SKILL.md'), "Kit skill.`n")

        @(Get-DotnetSkillDrift -SkillsRoot $copy.Skills -Lock $copy.Lock) | Should -BeNullOrEmpty
    }
}
