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
    # Edge cases none of PRs 1-5 had: a title with brackets, an issue with no thread link, and a link
    # in the "What changed" part, which is not an issue.
    $script:edgeBody = @'
<!-- ccr-overview-v2 -->

### 🟡 Changes recommended

Two issues.

<details open>
<summary><strong>2 open issues</strong></summary>

- <picture><img src="x" alt="Low severity" width="62" height="18" align="texttop"></picture> [Handle `a[0]` indexing](https://github.com/o/r/pull/9#discussion_r111) · New
- <picture><img src="x" alt="Medium severity" width="62" height="18" align="texttop"></picture> Summary-only issue with no thread · New
</details>

<details>
<summary><strong>What changed in this PR</strong></summary>

- Follows the [GitHub docs](https://docs.github.com/x) for rulesets.
</details>
'@
}

Describe 'KitReview.psm1' {
    BeforeAll {
        Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitReview.psm1') -Force
        $script:changesBody = $changesBody
        $script:approvalBody = $approvalBody
        $script:edgeBody = $edgeBody
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

        It 'reads only the open-issue list: a title with brackets, an issue with no thread, and no links from elsewhere' {
            $summary = ConvertFrom-CopilotReviewBody -Body $script:edgeBody

            $summary.OpenIssueCount | Should -Be 2
            @($summary.Issues).Count | Should -Be 2
            $summary.Issues[0].Title | Should -Be 'Handle `a[0]` indexing'
            $summary.Issues[0].CommentId | Should -Be 111
            $summary.Issues[1].Title | Should -Be 'Summary-only issue with no thread'
            $summary.Issues[1].CommentId | Should -BeNullOrEmpty
            $summary.Issues[1].Severity | Should -Be 'Medium'
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
                $review.Body | Should -Be $Body -Because 'the skill reads an issue with no thread from the summary text'
            }
        }

        It 'returns nothing when Copilot has not reviewed (and never calls GitHub twice)' {
            InModuleScope KitReview {
                Mock Invoke-Gh { '[{ "id": 3, "user": { "login": "DerekFoulk" }, "state": "COMMENTED", "submitted_at": "2026-11-03T10:00:00Z", "commit_id": "c", "body": "" }]' }

                Get-CopilotReview -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5 | Should -BeNullOrEmpty
                Should -Invoke Invoke-Gh -Times 1 -Exactly
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

        # gh -F converts numbers, true, false and null, so a repository named "2048" would reach GitHub as
        # an Int and fail; owner and name go as strings (-f), the PR number as a typed value (-F).
        It 'sends owner and name as strings, and the number as a typed value' {
            InModuleScope KitReview -Parameters @{ Json = $script:threadsJson } {
                param($Json)
                $script:ghArgs = $null
                Mock Invoke-Gh { $script:ghArgs = @($args); $Json }

                Get-ReviewThread -Repository 'octocat/2048' -Number 5 | Out-Null

                $script:ghArgs[$script:ghArgs.IndexOf('owner=octocat') - 1] | Should -BeExactly '-f'
                $script:ghArgs[$script:ghArgs.IndexOf('name=2048') - 1] | Should -BeExactly '-f'
                $script:ghArgs[$script:ghArgs.IndexOf('number=5') - 1] | Should -BeExactly '-F'
            }
        }

        It 'returns every comment, so a reply from the owner is seen' {
            $json = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "pageInfo": { "hasNextPage": false }, "nodes": [
  { "id": "PRRT_1", "isResolved": false, "isOutdated": false, "path": "a.ps1", "line": 3,
    "comments": { "nodes": [
      { "databaseId": 11, "author": { "login": "copilot-pull-request-reviewer" }, "body": "Rename this." },
      { "databaseId": 12, "author": { "login": "DerekFoulk" }, "body": "Keep it; won''t fix." } ] } }
] } } } } }'
            InModuleScope KitReview -Parameters @{ Json = $json } {
                param($Json)
                Mock Invoke-Gh { $Json }

                $thread = Get-ReviewThread -Repository 'o/r' -Number 5

                $thread.CommentId | Should -Be 11 -Because 'replies go to the first comment'
                $thread.Comments.Count | Should -Be 2
                $thread.Comments[1].Author | Should -Be 'DerekFoulk'
                $thread.Comments[1].Body | Should -Be "Keep it; won't fix."
            }
        }

        It 'names a comment author whose account was deleted, rather than failing' {
            $json = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "pageInfo": { "hasNextPage": false }, "nodes": [
  { "id": "PRRT_1", "isResolved": false, "isOutdated": false, "path": "a.ps1", "line": 3,
    "comments": { "nodes": [ { "databaseId": 11, "author": null, "body": "An old finding." } ] } }
] } } } } }'
            InModuleScope KitReview -Parameters @{ Json = $json } {
                param($Json)
                Mock Invoke-Gh { $Json }

                (Get-ReviewThread -Repository 'o/r' -Number 5).Author | Should -Be '(deleted account)'
            }
        }

        It 'refuses to return a partial list when there are more than 100 threads' {
            $json = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "pageInfo": { "hasNextPage": true }, "nodes": [] } } } } }'
            InModuleScope KitReview -Parameters @{ Json = $json } {
                param($Json)
                Mock Invoke-Gh { $Json }

                { Get-ReviewThread -Repository 'o/r' -Number 5 } | Should -Throw '*100*'
            }
        }

        It 'says so when the pull request does not exist' {
            InModuleScope KitReview {
                Mock Invoke-Gh { '{ "data": { "repository": { "pullRequest": null } } }' }

                { Get-ReviewThread -Repository 'o/r' -Number 999 } | Should -Throw '*999*not found*'
            }
        }
    }

    Context 'Get-OpenFinding' {
        BeforeEach {
            # Copilot's summary lists three issues; the PR has four threads. Issue B's thread is resolved,
            # issue C has no thread, and two threads come from a person: one open, one resolved.
            InModuleScope KitReview {
                Mock Get-CopilotReview {
                    [pscustomobject]@{
                        Verdict = 'Changes recommended'; OpenIssueCount = 3; Body = 'summary'
                        Issues  = @(
                            [pscustomobject]@{ Severity = 'High'; Title = 'A'; CommentId = 1; Link = 'https://github.com/o/r/pull/5#discussion_r1' }
                            [pscustomobject]@{ Severity = 'Medium'; Title = 'B'; CommentId = 2; Link = 'https://github.com/o/r/pull/5#discussion_r2' }
                            [pscustomobject]@{ Severity = 'Low'; Title = 'C'; CommentId = $null; Link = $null }
                        )
                    }
                }
                Mock Get-ReviewThread {
                    foreach ($t in @(
                            @{ Id = 'T1'; CommentId = 1; Resolved = $false; Author = 'copilot-pull-request-reviewer'; Body = 'Finding A.' }
                            @{ Id = 'T2'; CommentId = 2; Resolved = $true; Author = 'copilot-pull-request-reviewer'; Body = 'Finding B.' }
                            @{ Id = 'T3'; CommentId = 3; Resolved = $false; Author = 'DerekFoulk'; Body = 'Why this name?' }
                            @{ Id = 'T4'; CommentId = 4; Resolved = $true; Author = 'DerekFoulk'; Body = 'Typo.' }
                        )) {
                        $comments = @([pscustomobject]@{ CommentId = $t.CommentId; Author = $t.Author; Body = $t.Body })
                        [pscustomobject]@{ ThreadId = $t.Id; IsResolved = $t.Resolved; IsOutdated = $false; Path = 'a.ps1'; Line = 1; CommentId = $t.CommentId; Author = $t.Author; Body = $t.Body; Comments = $comments }
                    }
                }
            }
        }

        It 'lists each summary issue whose thread is open, each issue with no thread, and open threads from people' {
            InModuleScope KitReview {
                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { if ($_.Thread) { $_.Thread.ThreadId } else { $_.Title } }) | Should -Be @('T1', 'C', 'T3')
                $findings[0].Title | Should -Be 'A'
                $findings[0].Severity | Should -Be 'High'
                $findings[1].Thread | Should -BeNullOrEmpty -Because 'issue C has no thread, so it is answered in a PR comment'
                $findings[2].Author | Should -Be 'DerekFoulk'
                $findings[2].Body | Should -Be 'Why this name?'
            }
        }

        It 'reads every thread, resolved ones too, to know which summary issues are already answered' {
            InModuleScope KitReview {
                Get-OpenFinding -Repository 'o/r' -Number 5 | Out-Null

                Should -Invoke Get-ReviewThread -Times 1 -Exactly -ParameterFilter { -not $Unresolved }
            }
        }

        It 'lists only open threads when Copilot has not reviewed' {
            InModuleScope KitReview {
                Mock Get-CopilotReview { }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { $_.Thread.ThreadId }) | Should -Be @('T1', 'T3')
            }
        }
    }

    Context 'Writing to GitHub' {
        BeforeEach {
            # Answers like GitHub: the PR's state, a posted reply or PR comment's URL, the resolved thread.
            # Records each call.
            InModuleScope KitReview {
                $script:calls = [System.Collections.Generic.List[string]]::new()
                $script:prState = 'OPEN'
                $script:openThread = [pscustomobject]@{ ThreadId = 'PRRT_1'; CommentId = 7; IsResolved = $false }
                Mock Invoke-Gh {
                    $joined = $args -join ' '
                    $script:calls.Add($joined)
                    if ($joined -like 'pr view*') { return $script:prState }
                    if ($joined -like '*/replies*') { return '{ "html_url": "https://github.com/o/r/pull/5#discussion_r1" }' }
                    if ($joined -like '*/issues/5/comments*') { return '{ "html_url": "https://github.com/o/r/pull/5#issuecomment-9" }' }
                    if ($joined -like 'api graphql*') { return '{ "data": { "resolveReviewThread": { "thread": { "isResolved": true } } } }' }
                    throw "unexpected gh call: $joined"
                }
            }
        }

        Context 'Resolve-ReviewThread' {
            It 'posts the reply first, then resolves the thread with the reason' {
                InModuleScope KitReview {
                    $result = Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread ([pscustomobject]@{ ThreadId = 'PRRT_1'; CommentId = 4452246621; IsResolved = $false }) -Reason ADDRESSED -Evidence 'Fixed in dd98eba (red 59ab976).'

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
                    Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread $script:openThread -Reason $Reason -Evidence 'The evidence.' | Out-Null

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

                    { Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread $script:openThread -Reason $Reason -Evidence $Evidence -OwnerApproved:$Approved } | Should -Throw $Expected

                    @($script:calls | Where-Object { $_ -like '*/replies*' -or $_ -like 'api graphql*' }).Count | Should -Be 0
                }
            }

            It "resolves as won't fix when the owner approved it" {
                InModuleScope KitReview {
                    $result = Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread $script:openThread -Reason WONT_FIX -Evidence 'Out of scope; the owner agreed on 2026-11-03.' -OwnerApproved

                    $result.Resolved | Should -BeTrue
                    ($script:calls | Where-Object { $_ -like '*/replies*' }) | Should -BeLike "*Resolution: won't fix.*"
                }
            }

            It 'refuses a thread that is already resolved, and changes nothing on GitHub' {
                InModuleScope KitReview {
                    $resolved = [pscustomobject]@{ ThreadId = 'PRRT_1'; CommentId = 7; IsResolved = $true }

                    { Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread $resolved -Reason ADDRESSED -Evidence 'Fixed.' } | Should -Throw '*already resolved*'

                    @($script:calls | Where-Object { $_ -like '*/replies*' -or $_ -like 'api graphql*' }).Count | Should -Be 0
                }
            }
        }

        Context 'Add-ReviewReply' {
            It 'replies in the thread and leaves it open' {
                InModuleScope KitReview {
                    $result = Add-ReviewReply -Repository 'o/r' -Number 5 -Thread $script:openThread -Body 'I recommend not fixing this: out of scope. Owner, your call.'

                    $result.Url | Should -Be 'https://github.com/o/r/pull/5#discussion_r1'
                    ($script:calls | Where-Object { $_ -like '*comments/7/replies*' }) | Should -BeLike '*body=I recommend not fixing this*'
                    @($script:calls | Where-Object { $_ -like 'api graphql*' }).Count | Should -Be 0 -Because 'only the owner decides to leave a finding unfixed'
                }
            }

            It 'answers a summary issue that has no thread with a pull request comment' {
                InModuleScope KitReview {
                    $result = Add-ReviewReply -Repository 'o/r' -Number 5 -Body 'Summary issue "C": fixed in abc1234.'

                    $result.Url | Should -Be 'https://github.com/o/r/pull/5#issuecomment-9'
                    ($script:calls | Where-Object { $_ -like '*repos/o/r/issues/5/comments*' }) | Should -BeLike '*body=Summary issue "C": fixed in abc1234.*'
                }
            }

            It 'refuses <Case>, and changes nothing on GitHub' -ForEach @(
                @{ Case = 'a pull request that is no longer open'; State = 'CLOSED'; Body = 'Fixed.'; Expected = '*not open*' }
                @{ Case = 'an empty reply'; State = 'OPEN'; Body = ' '; Expected = '*empty*' }
            ) {
                InModuleScope KitReview -Parameters @{ State = $State; Body = $Body; Expected = $Expected } {
                    param($State, $Body, $Expected)
                    $script:prState = $State

                    { Add-ReviewReply -Repository 'o/r' -Number 5 -Thread $script:openThread -Body $Body } | Should -Throw $Expected

                    @($script:calls | Where-Object { $_ -like '*/replies*' -or $_ -like '*/issues/*' -or $_ -like 'api graphql*' }).Count | Should -Be 0
                }
            }
        }
    }
}
