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
