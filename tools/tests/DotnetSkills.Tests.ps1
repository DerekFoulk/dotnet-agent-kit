#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The kit carries a curated copy of skills from Microsoft's dotnet/skills repo, pinned to one upstream commit
# (ADR-0042). tools/dotnet-skills.json records the commit and git's blob id for every copied file, so an edit to a
# copy fails here instead of drifting from upstream unnoticed. Update-DotnetSkills.ps1 moves the copy to a newer
# commit.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Update-DotnetSkills.ps1')
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

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

Describe 'Update-DotnetSkill' {
    BeforeAll {
        function Write-Text([string] $Path, [string] $Text) {
            New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
            [IO.File]::WriteAllText($Path, $Text)
        }

        # A stand-in for dotnet/skills: commit 1 has the "tidy" skill with an old reference file; main (commit 2)
        # changes SKILL.md, drops the old reference and adds a new one.
        $upstream = Join-Path $TestDrive 'upstream'
        Write-Text (Join-Path $upstream 'plugins/p/skills/tidy/SKILL.md') "---`nname: tidy`n---`nOne.`n"
        Write-Text (Join-Path $upstream 'plugins/p/skills/tidy/references/old.md') "Old.`n"
        Write-Text (Join-Path $upstream 'plugins/q/skills/other/SKILL.md') "---`nname: other`n---`n"
        git -C $upstream init -q -b main
        git -C $upstream add -A
        git -C $upstream commit -q -m 'first'
        $first = (git -C $upstream rev-parse HEAD).Trim()
        Write-Text (Join-Path $upstream 'plugins/p/skills/tidy/SKILL.md') "---`nname: tidy`n---`nTwo.`n"
        Remove-Item -LiteralPath (Join-Path $upstream 'plugins/p/skills/tidy/references/old.md')
        Write-Text (Join-Path $upstream 'plugins/p/skills/tidy/references/new.md') "New.`n"
        git -C $upstream add -A
        git -C $upstream commit -q -m 'second'
        $second = (git -C $upstream rev-parse HEAD).Trim()

        # A kit with its own skill and a lock that lists "tidy" but has no copy yet.
        function New-Kit([string] $Source = 'plugins/p/skills/tidy') {
            $kit = Join-Path $TestDrive "kit-$(New-Guid)"
            Write-Text (Join-Path $kit '.claude/skills/start-work/SKILL.md') "Kit skill.`n"
            $lock = [ordered]@{
                repository = 'dotnet/skills'; url = $upstream; commit = ''; retrieved = ''
                skills = @([ordered]@{ name = 'tidy'; source = $Source; files = [ordered]@{} })
            }
            Write-Text (Join-Path $kit 'tools/dotnet-skills.json') ($lock | ConvertTo-Json -Depth 5)
            $kit
        }
        function Read-Lock([string] $Kit) { Get-Content -Raw -LiteralPath (Join-Path $Kit 'tools/dotnet-skills.json') | ConvertFrom-Json -AsHashtable -DateKind String }
    }

    It 'copies each listed skill at the commit and records the commit, the date and each file''s blob id' {
        $kit = New-Kit

        Update-DotnetSkill -RepoRoot $kit -Commit $first -RepositoryUrl $upstream -Retrieved '2026-11-10'

        $lock = Read-Lock $kit
        $lock['commit'] | Should -Be $first
        $lock['retrieved'] | Should -Be '2026-11-10'
        $files = $lock['skills'][0]['files']
        @($files.Keys) | Should -Be @('SKILL.md', 'references/old.md')
        $files['SKILL.md'] | Should -Be (git -C $upstream rev-parse "${first}:plugins/p/skills/tidy/SKILL.md").Trim()
        Get-Content -Raw -LiteralPath (Join-Path $kit '.claude/skills/tidy/SKILL.md') | Should -Be "---`nname: tidy`n---`nOne.`n"
        @(Get-DotnetSkillDrift -SkillsRoot (Join-Path $kit '.claude/skills') -Lock $lock) | Should -BeNullOrEmpty
    }

    It 'moves to a later commit by branch name, dropping files that are gone upstream' {
        $kit = New-Kit
        Update-DotnetSkill -RepoRoot $kit -Commit $first -RepositoryUrl $upstream -Retrieved '2026-11-10'

        Update-DotnetSkill -RepoRoot $kit -Commit 'main' -RepositoryUrl $upstream -Retrieved '2026-11-11'

        $lock = Read-Lock $kit
        $lock['commit'] | Should -Be $second
        @($lock['skills'][0]['files'].Keys) | Should -Be @('SKILL.md', 'references/new.md')
        Join-Path $kit '.claude/skills/tidy/references/old.md' | Should -Not -Exist
        Get-Content -Raw -LiteralPath (Join-Path $kit '.claude/skills/tidy/SKILL.md') | Should -Be "---`nname: tidy`n---`nTwo.`n"
    }

    It 'leaves the kit''s own skills and skills the lock doesn''t list alone' {
        $kit = New-Kit

        Update-DotnetSkill -RepoRoot $kit -Commit $second -RepositoryUrl $upstream -Retrieved '2026-11-10'

        Get-Content -Raw -LiteralPath (Join-Path $kit '.claude/skills/start-work/SKILL.md') | Should -Be "Kit skill.`n"
        Join-Path $kit '.claude/skills/other' | Should -Not -Exist
    }
}
