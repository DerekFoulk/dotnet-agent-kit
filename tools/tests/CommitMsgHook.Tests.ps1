#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The commit-msg hook (ADR-0027): the same Conventional Commit rule as CI, applied before a commit exists,
# because a bad subject found by CI can only be fixed by rewriting history. It must never accept a
# subject CI rejects. CI skips only real merge commits, so the hook skips only a merge in progress.

BeforeAll {
    # Every repo these tests make runs with the same git settings (TestGit.psm1).
    Import-Module (Join-Path $PSScriptRoot 'TestGit.psm1') -Force
    $savedGit = Set-TestGitEnvironment
}
AfterAll { Restore-TestGitEnvironment -Saved $savedGit }

Describe 'commit-msg hook' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $script:hookScript = Join-Path $script:repoRoot '.githooks' 'commit-msg.ps1'

        function Invoke-Hook([string] $Message) {
            $file = Join-Path $TestDrive "msg-$(New-Guid).txt"
            Set-Content -Path $file -Value $Message -NoNewline
            $output = pwsh -NoProfile -File $script:hookScript $file 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }

        # A repo set up the way people do it: the hook files committed in .githooks and tools, and a
        # relative core.hooksPath.
        # -ToolsPath .kit/tools is an app repo, where Export-KitApp puts the kit's scripts (ADR-0032).
        function New-HookedRepo([string] $ToolsPath = 'tools') {
            $repo = Join-Path $TestDrive "repo-$(New-Guid)"
            New-Item -ItemType Directory -Path (Join-Path $repo '.githooks'), (Join-Path $repo $ToolsPath) | Out-Null
            Copy-Item -Path (Join-Path $script:repoRoot '.githooks' '*') -Destination (Join-Path $repo '.githooks')
            Copy-Item -Path (Join-Path $script:repoRoot 'tools' 'Test-ConventionalTitle.ps1') -Destination (Join-Path $repo $ToolsPath)
            git -C $repo init --quiet --initial-branch main 2>&1 | Out-Null
            git -C $repo config core.hooksPath .githooks
            $repo
        }

        function Invoke-InRepo([string] $Repo) {
            $output = git -C $Repo @args 2>&1 | Out-String
            [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
        }
    }

    Context 'the check' {
        It 'accepts <Message>' -ForEach @(
            @{ Message = "feat: add tags`n`nTDD: green`nCo-Authored-By: A <a@example.invalid>`n" }
            @{ Message = "fix(api): keep one bookmark per URL`n" }
            @{ Message = "revert: feat: add tags`n" }
            # git revert's own subject is valid when the reverted commit's was (Get-TitleProblem).
            @{ Message = "Revert `"feat: add tags`"`n`nThis reverts commit abc.`n" }
        ) {
            (Invoke-Hook $Message).ExitCode | Should -Be 0
        }

        It 'rejects a subject that is not a Conventional Commit, and says why' {
            $result = Invoke-Hook "add tags`n"

            $result.ExitCode | Should -Be 1
            $result.Output | Should -Match 'Conventional Commit'
        }

        It 'rejects a subject CI would reject even though git wrote it (<Message>)' -ForEach @(
            @{ Message = "Revert `"add tags`"`n" }
            @{ Message = "fixup! feat: add tags`n" }
            @{ Message = "squash! feat: add tags`n" }
            @{ Message = "amend! feat: add tags`n" }
            @{ Message = "Merge branch 'side' into work`n" }
        ) {
            (Invoke-Hook $Message).ExitCode | Should -Be 1
        }

        It 'checks the first line that is not blank or a comment' {
            (Invoke-Hook "`n# Please enter the commit message`nadd tags`n").ExitCode | Should -Be 1
            (Invoke-Hook "`n# Please enter the commit message`nfeat: add tags`n").ExitCode | Should -Be 0
        }
    }

    Context 'through git, with a relative core.hooksPath' {
        It 'blocks a commit with a bad subject and allows a good one' {
            $repo = New-HookedRepo

            $bad = Invoke-InRepo $repo commit --quiet --allow-empty --message 'add tags'
            $good = Invoke-InRepo $repo commit --quiet --allow-empty --message 'feat: add tags'

            $bad.ExitCode | Should -Not -Be 0 -Because $bad.Output
            $good.ExitCode | Should -Be 0 -Because $good.Output
            git -C $repo log --format=%s | Should -Be 'feat: add tags'
        }

        # git revert doesn't run the commit-msg hook at all, so the hook can't police its subject; instead
        # CI accepts git's revert form for a Conventional commit, and this checks the two agree.
        It 'lets git revert of a Conventional commit through, and CI accepts its subject too' {
            $repo = New-HookedRepo
            # A real change: reverting an empty commit fails on its own.
            Set-Content -Path (Join-Path $repo 'tags.txt') -Value 'tags'
            Invoke-InRepo $repo add tags.txt | Out-Null
            Invoke-InRepo $repo commit --quiet --message 'feat: add tags' | Out-Null

            $revert = Invoke-InRepo $repo revert --no-edit HEAD
            $ci = pwsh -NoProfile -File (Join-Path $script:repoRoot 'tools' 'Test-ConventionalTitle.ps1') -RepoPath $repo -Range 'HEAD~1..HEAD' 2>&1 | Out-String

            $revert.ExitCode | Should -Be 0 -Because $revert.Output
            $LASTEXITCODE | Should -Be 0 -Because $ci
        }

        It 'allows a real merge commit, which CI skips' {
            $repo = New-HookedRepo
            Invoke-InRepo $repo commit --quiet --allow-empty --message 'chore: initial' | Out-Null
            Invoke-InRepo $repo switch --quiet -c side | Out-Null
            Invoke-InRepo $repo commit --quiet --allow-empty --message 'feat: on the side' | Out-Null
            Invoke-InRepo $repo switch --quiet main | Out-Null

            $merge = Invoke-InRepo $repo merge --no-ff side --message "Merge branch 'side'"

            $merge.ExitCode | Should -Be 0 -Because $merge.Output
            git -C $repo log -1 --format=%s | Should -Be "Merge branch 'side'"
        }
    }

    Context 'in an app repo, where the kit''s scripts are in .kit/tools' {
        It 'blocks a commit with a bad subject and allows a good one' {
            $repo = New-HookedRepo -ToolsPath '.kit/tools'

            $bad = Invoke-InRepo $repo commit --quiet --allow-empty --message 'add tags'
            $good = Invoke-InRepo $repo commit --quiet --allow-empty --message 'feat: add tags'

            $bad.ExitCode | Should -Not -Be 0
            $bad.Output | Should -Match 'Conventional Commit'
            $good.ExitCode | Should -Be 0 -Because $good.Output
        }
    }
}
