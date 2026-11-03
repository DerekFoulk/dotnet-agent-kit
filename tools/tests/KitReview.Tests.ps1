#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# The review bodies below are real Copilot code review summaries from this repo (PR 5 and PR 3,
# captured 2026-11-03), shortened to the lines the module reads.

BeforeDiscovery {
    $script:changesBody = @'
<!-- ccr-overview-v2 -->

### 🟡 Changes recommended

CI enables locked restores for fresh test fixtures without lock files, causing restores to fail and blocking the new kit-checks job.

<details open>
<summary><strong>2 open issues</strong></summary>

- <picture><source media="(prefers-color-scheme: dark)" srcset="https://github.githubassets.com/static/images/icons/copilot-code-review/high-v2-dark.svg"><img src="https://github.githubassets.com/static/images/icons/copilot-code-review/high-v2-light.png" alt="High severity" width="62" height="18" align="texttop"></picture> [Fixture restores fail in CI without lock files](https://github.com/DerekFoulk/dotnet-agent-kit/pull/5#discussion_r4452246557) · New
- <picture><img src="https://github.githubassets.com/static/images/icons/copilot-code-review/medium-v2-light.png" alt="Medium severity" width="62" height="18" align="texttop"></picture> [Edited PR titles skip validation](https://github.com/DerekFoulk/dotnet-agent-kit/pull/5#discussion_r4452246590) · New
</details>

<details>
<summary><strong>What changed in this PR</strong></summary>
'@
    $script:approvalBody = @'
<!-- ccr-overview-v2 -->

### 🟢 Approval recommended

No active review issues are reported for the rule-source validation and standards updates.

**No open issues** 🎉

<details>
<summary><strong>What changed in this PR</strong></summary>
'@
}

Describe 'KitReview.psm1' {
    BeforeAll {
        Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitReview.psm1') -Force
        $script:changesBody = $changesBody
        $script:approvalBody = $approvalBody
    }

    Context 'ConvertFrom-CopilotReviewBody' {
        It 'reads a "Changes recommended" summary: verdict, count and each linked issue' {
            $summary = ConvertFrom-CopilotReviewBody -Body $script:changesBody

            $summary.Verdict | Should -Be 'Changes recommended'
            $summary.OpenIssueCount | Should -Be 2
            $summary.Issues.Count | Should -Be 2
            $summary.Issues[0].Severity | Should -Be 'High'
            $summary.Issues[0].Title | Should -Be 'Fixture restores fail in CI without lock files'
            $summary.Issues[0].CommentId | Should -Be 4452246557
            $summary.Issues[1].Severity | Should -Be 'Medium'
            $summary.Issues[1].CommentId | Should -Be 4452246590
        }

        It 'reads an "Approval recommended" summary with no open issues' {
            $summary = ConvertFrom-CopilotReviewBody -Body $script:approvalBody

            $summary.Verdict | Should -Be 'Approval recommended'
            $summary.OpenIssueCount | Should -Be 0
            @($summary.Issues).Count | Should -Be 0
        }

        It 'reports an unknown verdict as Unknown rather than guessing' {
            (ConvertFrom-CopilotReviewBody -Body 'Some other review text.').Verdict | Should -Be 'Unknown'
        }
    }

    Context 'Get-CopilotReview' {
        It 'returns the latest review by Copilot, ignoring reviews by people' {
            InModuleScope KitReview -Parameters @{ Body = $script:changesBody } {
                param($Body)
                Mock Invoke-Gh {
                    @(
                        @{ id = 1; user = @{ login = 'copilot-pull-request-reviewer[bot]' }; state = 'COMMENTED'; submitted_at = '2026-11-03T08:00:00Z'; commit_id = 'aaaaaaa1'; body = 'old' }
                        @{ id = 2; user = @{ login = 'copilot-pull-request-reviewer[bot]' }; state = 'COMMENTED'; submitted_at = '2026-11-03T09:00:00Z'; commit_id = 'bbbbbbb2'; body = $Body }
                        @{ id = 3; user = @{ login = 'DerekFoulk' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; commit_id = 'ccccccc3'; body = '' }
                    ) | ConvertTo-Json -Depth 5
                }

                $review = Get-CopilotReview -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5

                $review.ReviewId | Should -Be 2
                $review.Commit | Should -Be 'bbbbbbb2'
                $review.Verdict | Should -Be 'Changes recommended'
                $review.OpenIssueCount | Should -Be 2
            }
        }

        It 'returns nothing when Copilot has not reviewed (and never calls GitHub twice)' {
            InModuleScope KitReview {
                Mock Invoke-Gh { '[{ "id": 3, "user": { "login": "DerekFoulk" }, "state": "COMMENTED", "submitted_at": "2026-11-03T10:00:00Z", "commit_id": "c", "body": "" }]' }

                Get-CopilotReview -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5 | Should -BeNullOrEmpty
            }
        }
    }

    Context 'Get-ReviewThread' {
        BeforeAll {
            # The shape of GitHub's GraphQL reviewThreads response (PR 5, 2026-11-03).
            $script:threadsJson = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "nodes": [
  { "id": "PRRT_resolved", "isResolved": true, "isOutdated": false, "path": ".github/workflows/ci.yml", "line": 5,
    "comments": { "nodes": [ { "databaseId": 4452246590, "author": { "login": "copilot-pull-request-reviewer" }, "body": "Include edited." } ] } },
  { "id": "PRRT_open", "isResolved": false, "isOutdated": true, "path": "tools/Test-DeprecatedPackages.ps1", "line": null,
    "comments": { "nodes": [ { "databaseId": 4452246657, "author": { "login": "copilot-pull-request-reviewer" }, "body": "Reject a nonzero exit code." } ] } }
] } } } } }'
        }

        It 'maps each thread to its id, state, file, first comment and author' {
            InModuleScope KitReview -Parameters @{ Json = $script:threadsJson } {
                param($Json)
                Mock Invoke-Gh { $Json }

                $threads = @(Get-ReviewThread -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5)

                $threads.Count | Should -Be 2
                $threads[1].ThreadId | Should -Be 'PRRT_open'
                $threads[1].IsResolved | Should -BeFalse
                $threads[1].IsOutdated | Should -BeTrue
                $threads[1].Path | Should -Be 'tools/Test-DeprecatedPackages.ps1'
                $threads[1].CommentId | Should -Be 4452246657
                $threads[1].Author | Should -Be 'copilot-pull-request-reviewer'
                $threads[1].Body | Should -Be 'Reject a nonzero exit code.'
            }
        }

        It 'returns only unresolved threads with -Unresolved' {
            InModuleScope KitReview -Parameters @{ Json = $script:threadsJson } {
                param($Json)
                Mock Invoke-Gh { $Json }

                $threads = @(Get-ReviewThread -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5 -Unresolved)

                ($threads | ForEach-Object ThreadId) | Should -Be @('PRRT_open')
            }
        }

        It 'asks GitHub for the named repository and pull request' {
            InModuleScope KitReview -Parameters @{ Json = $script:threadsJson } {
                param($Json)
                Mock Invoke-Gh { $Json }

                Get-ReviewThread -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5 | Out-Null

                Should -Invoke Invoke-Gh -ParameterFilter { $joined = $args -join ' '; $joined -like '*owner=DerekFoulk*' -and $joined -like '*name=dotnet-agent-kit*' -and $joined -like '*number=5*' }
            }
        }
    }

    Context 'Resolve-ReviewThread' {
        BeforeEach {
            # Answers like GitHub: the PR's state, the posted reply's URL, the resolved thread. Records each call.
            InModuleScope KitReview {
                $script:calls = [System.Collections.Generic.List[string]]::new()
                $script:prState = 'OPEN'
                Mock Invoke-Gh {
                    $joined = $args -join ' '
                    $script:calls.Add($joined)
                    if ($joined -like 'pr view*') { return $script:prState }
                    if ($joined -like '*/replies*') { return '{ "html_url": "https://github.com/o/r/pull/5#discussion_r1" }' }
                    if ($joined -like 'api graphql*') { return '{ "data": { "resolveReviewThread": { "thread": { "isResolved": true } } } }' }
                    throw "unexpected gh call: $joined"
                }
            }
        }

        It 'posts the reply first, then resolves the thread with the reason' {
            InModuleScope KitReview {
                $result = Resolve-ReviewThread -Repository 'o/r' -Number 5 -ThreadId 'PRRT_1' -CommentId 4452246621 -Reason ADDRESSED -Evidence 'Fixed in dd98eba (red 59ab976).'

                $result.Resolved | Should -BeTrue
                $result.ReplyUrl | Should -Be 'https://github.com/o/r/pull/5#discussion_r1'
                $replyIndex = $script:calls.FindIndex({ param($c) $c -like '*comments/4452246621/replies*' })
                $resolveIndex = $script:calls.FindIndex({ param($c) $c -like 'api graphql*resolveReviewThread*' })
                $replyIndex | Should -BeGreaterThan -1
                $resolveIndex | Should -BeGreaterThan $replyIndex
                $script:calls[$resolveIndex] | Should -BeLike '*reason=ADDRESSED*'
                $script:calls[$resolveIndex] | Should -BeLike '*id=PRRT_1*'
            }
        }

        It 'starts the reply with the resolution: <Reason> reads "<Prefix>"' -ForEach @(
            @{ Reason = 'ADDRESSED'; Prefix = 'Resolution: addressed.' }
            @{ Reason = 'INVALID'; Prefix = 'Resolution: incorrect.' }
        ) {
            InModuleScope KitReview -Parameters @{ Reason = $Reason; Prefix = $Prefix } {
                param($Reason, $Prefix)
                Resolve-ReviewThread -Repository 'o/r' -Number 5 -ThreadId 'PRRT_1' -CommentId 7 -Reason $Reason -Evidence 'The evidence.' | Out-Null

                $reply = $script:calls | Where-Object { $_ -like '*/replies*' }
                $reply | Should -BeLike "*body=$Prefix The evidence.*"
            }
        }

        It 'refuses <Case>, and changes nothing on GitHub' -ForEach @(
            @{ Case = 'a pull request that is no longer open'; State = 'MERGED'; Reason = 'ADDRESSED'; Evidence = 'Fixed.'; Approved = $false; Expected = '*not open*' }
            @{ Case = 'an empty reply'; State = 'OPEN'; Reason = 'ADDRESSED'; Evidence = '   '; Approved = $false; Expected = '*evidence*' }
            @{ Case = "won't fix without the owner's OK"; State = 'OPEN'; Reason = 'WONT_FIX'; Evidence = 'Out of scope.'; Approved = $false; Expected = '*owner*' }
        ) {
            InModuleScope KitReview -Parameters @{ State = $State; Reason = $Reason; Evidence = $Evidence; Approved = $Approved; Expected = $Expected } {
                param($State, $Reason, $Evidence, $Approved, $Expected)
                $script:prState = $State

                { Resolve-ReviewThread -Repository 'o/r' -Number 5 -ThreadId 'PRRT_1' -CommentId 7 -Reason $Reason -Evidence $Evidence -OwnerApproved:$Approved } | Should -Throw $Expected

                @($script:calls | Where-Object { $_ -like '*/replies*' -or $_ -like 'api graphql*' }).Count | Should -Be 0
            }
        }

        It "resolves as won't fix when the owner approved it" {
            InModuleScope KitReview {
                $result = Resolve-ReviewThread -Repository 'o/r' -Number 5 -ThreadId 'PRRT_1' -CommentId 7 -Reason WONT_FIX -Evidence 'Out of scope; the owner agreed on 2026-11-03.' -OwnerApproved

                $result.Resolved | Should -BeTrue
                ($script:calls | Where-Object { $_ -like '*/replies*' }) | Should -BeLike "*Resolution: won't fix.*"
            }
        }
    }
}
