#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The commit-msg hook (ADR-0027): the same Conventional Commit rule as CI, applied before a commit exists,
# because a bad subject found by CI can only be fixed by rewriting history.

Describe 'commit-msg hook' {
    BeforeAll {
        $script:hooks = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '.githooks')).Path
        $script:hookScript = Join-Path $script:hooks 'commit-msg.ps1'

        function Invoke-Hook([string] $Message) {
            $file = Join-Path $TestDrive "msg-$(New-Guid).txt"
            Set-Content -Path $file -Value $Message -NoNewline
            $output = pwsh -NoProfile -File $script:hookScript $file 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    Context 'the check' {
        It 'accepts <Message>' -ForEach @(
            @{ Message = "feat: add tags`n`nTDD: green`nCo-Authored-By: A <a@example.invalid>`n" }
            @{ Message = "fix(api): keep one bookmark per URL`n" }
        ) {
            (Invoke-Hook $Message).ExitCode | Should -Be 0
        }

        It 'rejects a subject that is not a Conventional Commit, and says why' {
            $result = Invoke-Hook "add tags`n"

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'Conventional Commit'
        }

        It 'skips a subject git writes itself (<Message>)' -ForEach @(
            @{ Message = "Merge branch 'side' into work`n" }
            @{ Message = "Revert `"feat: add tags`"`n`nThis reverts commit abc.`n" }
            @{ Message = "fixup! feat: add tags`n" }
            @{ Message = "squash! feat: add tags`n" }
        ) {
            (Invoke-Hook $Message).ExitCode | Should -Be 0
        }

        It 'checks the first line that is not blank or a comment' {
            (Invoke-Hook "`n# Please enter the commit message`nadd tags`n").ExitCode | Should -Be 1
            (Invoke-Hook "`n# Please enter the commit message`nfeat: add tags`n").ExitCode | Should -Be 0
        }
    }

    Context 'through git' {
        It 'blocks a commit with a bad subject and allows a good one' {
            $repo = Join-Path $TestDrive "repo-$(New-Guid)"
            New-Item -ItemType Directory -Path $repo | Out-Null
            git -C $repo init --quiet --initial-branch main 2>&1 | Out-Null
            $commit = { param($Subject) git -C $repo -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false -c "core.hooksPath=$($script:hooks)" commit --quiet --allow-empty --message $Subject 2>&1 | Out-String; $LASTEXITCODE }

            $bad = & $commit 'add tags'
            $good = & $commit 'feat: add tags'

            $bad[-1] | Should -Not -Be 0 -Because ($bad -join '')
            $good[-1] | Should -Be 0 -Because ($good -join '')
            git -C $repo log --format=%s | Should -Be 'feat: add tags'
        }
    }
}
