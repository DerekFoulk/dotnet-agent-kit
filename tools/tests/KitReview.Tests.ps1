#Requires -Version 7.6
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
    # A real summary from PR 64 (2026-11-13), shortened: a third verdict, no open issues, and one issue Copilot missed
    # in an earlier review, which it lists in its own block with no thread.
    $script:missedBody = @'
<!-- ccr-overview-v2 -->

### 🔵 Needs a closer look

The enforcement docs still assign plan review to Copilot.

**No open issues** 🎉

<details>
<summary><strong>1 previously missed issue</strong></summary>

In code that hasn't changed since last review

<details>
<summary><picture><img src="https://github.githubassets.com/static/images/icons/copilot-code-review/low-v2-light.png" alt="Low severity" width="62" height="18" align="texttop"></picture> Update enforcement docs to assign plan checks to local checklist</summary>

`docs/​standards/​architecture.md:91`

**Should fix**: This assigns plan review to Copilot. Same issue in `docs/standards/testing.md:33`.
</details>
</details>

<details>
<summary><strong>2 resolved since last review</strong></summary>

- <picture><img alt="Low severity"></picture> [Restore upstream release-tag verification](https://github.com/o/r/pull/64#discussion_r4565819871)
</details>
'@
}

Describe 'KitReview.psm1' {
    BeforeAll {
        Import-Module -Name (Join-Path $PSScriptRoot '..' 'KitReview.psm1') -Force
        $script:changesBody = $changesBody
        $script:approvalBody = $approvalBody
        $script:edgeBody = $edgeBody
        $script:missedBody = $missedBody
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

        It 'keeps the thread link when the status after the title is "<Status>"' -ForEach @(
            @{ Status = 'New' }
            @{ Status = 'Still open' }
            @{ Status = 'Re-opened' }
        ) {
            $body = "<strong>1 open issue</strong>`n`n- <picture><img alt=`"High severity`"></picture> [Title](https://github.com/o/r/pull/9#discussion_r111) · $Status`n</details>"

            $issue = (ConvertFrom-CopilotReviewBody -Body $body).Issues[0]

            $issue.Title | Should -Be 'Title'
            $issue.CommentId | Should -Be 111
        }

        It 'reads a "Needs a closer look" verdict' {
            (ConvertFrom-CopilotReviewBody -Body $script:missedBody).Verdict | Should -Be 'Needs a closer look'
        }

        It 'lists a previously missed issue, with its text and no thread, and no issue resolved since the last review' {
            $summary = ConvertFrom-CopilotReviewBody -Body $script:missedBody

            @($summary.Issues).Count | Should -Be 1
            $summary.Issues[0].Severity | Should -Be 'Low'
            $summary.Issues[0].Title | Should -Be 'Update enforcement docs to assign plan checks to local checklist'
            $summary.Issues[0].CommentId | Should -BeNullOrEmpty
            $summary.Issues[0].Body | Should -Match '\*\*Should fix\*\*: This assigns plan review to Copilot'
            $summary.Issues[0].Body | Should -Match 'architecture\.md:91'
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
                    ) | ConvertTo-Json -Depth 5 -Compress
                }

                $review = Get-CopilotReview -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5

                $review.ReviewId | Should -Be 2
                $review.Commit | Should -Be 'bbbbbbb2'
                $review.Verdict | Should -Be 'Changes recommended'
                $review.OpenIssueCount | Should -Be 2
                $review.Body | Should -Be $Body -Because 'the agent can read the summary in full'
            }
        }

        It 'skips a review by a deleted account rather than failing' {
            InModuleScope KitReview {
                Mock Invoke-Gh { '[{ "id": 1, "user": null, "submitted_at": "2026-11-03T08:00:00Z", "commit_id": "a", "body": "" }, { "id": 2, "user": { "login": "copilot-pull-request-reviewer[bot]" }, "submitted_at": "2026-11-03T09:00:00Z", "commit_id": "b", "body": "" }]' }

                { $script:review = Get-CopilotReview -Repository 'o/r' -Number 5 } | Should -Not -Throw
                $script:review.ReviewId | Should -Be 2
            }
        }

        # Older gh versions print one JSON array per page; --jq '.[]' prints one item per line on any version.
        It 'reads every page of reviews, one review per line, whatever the gh version' {
            InModuleScope KitReview {
                Mock Invoke-Gh { "{ `"id`": 1, `"user`": { `"login`": `"copilot-pull-request-reviewer[bot]`" }, `"submitted_at`": `"2026-11-03T08:00:00Z`", `"commit_id`": `"a`", `"body`": `"`" }`n{ `"id`": 2, `"user`": { `"login`": `"copilot-pull-request-reviewer[bot]`" }, `"submitted_at`": `"2026-11-03T09:00:00Z`", `"commit_id`": `"b`", `"body`": `"`" }" }

                { $script:review = Get-CopilotReview -Repository 'o/r' -Number 5 } | Should -Not -Throw
                $script:review.ReviewId | Should -Be 2
                Should -Invoke Invoke-Gh -ParameterFilter { $args -contains '--paginate' -and $args -contains '--jq' -and $args -contains '.[]' }
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

        It 'refuses to return a partial thread when it has more than 100 comments' {
            $json = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "pageInfo": { "hasNextPage": false }, "nodes": [
  { "id": "PRRT_1", "isResolved": false, "isOutdated": false, "path": "a.ps1", "line": 3,
    "comments": { "pageInfo": { "hasNextPage": true }, "nodes": [ { "databaseId": 11, "author": { "login": "a" }, "body": "x" } ] } }
] } } } } }'
            InModuleScope KitReview -Parameters @{ Json = $json } {
                param($Json)
                Mock Invoke-Gh { $Json }

                { Get-ReviewThread -Repository 'o/r' -Number 5 } | Should -Throw '*100 comments*'
            }
        }

        It 'handles a thread with no comments rather than failing' {
            $json = '{ "data": { "repository": { "pullRequest": { "reviewThreads": { "pageInfo": { "hasNextPage": false }, "nodes": [
  { "id": "PRRT_1", "isResolved": false, "isOutdated": false, "path": "a.ps1", "line": 3, "comments": { "nodes": [] } }
] } } } } }'
            InModuleScope KitReview -Parameters @{ Json = $json } {
                param($Json)
                Mock Invoke-Gh { $Json }

                { $script:empty = Get-ReviewThread -Repository 'o/r' -Number 5 } | Should -Not -Throw
                $script:empty.ThreadId | Should -Be 'PRRT_1'
                $script:empty.CommentId | Should -BeNullOrEmpty
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
                        ReviewId = 50; Verdict = 'Changes recommended'; OpenIssueCount = 3; Body = 'summary'
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
                # The signed-in account is the one agents post with; its comments are the PR side's answers.
                Mock Get-SignedInLogin { 'DerekFoulk' }
                Mock Get-PullRequestComment { [pscustomobject]@{ Author = 'mallory'; Body = 'Looks good to me.' } }
                Mock Get-PullRequestReview { }
                Mock Invoke-Gh { '{"headRefOid":"head2"}' } -ParameterFilter { $args -contains 'view' }
            }
        }

        # Copilot's seventh review of PR #73: Wait-PullRequest returns Reviewed for the head commit's review, so the
        # findings must come from that review too, not from a later review of an older commit.
        It 'lists the summary issues of Copilot''s review of the head commit, even when a review of an older commit came later' {
            InModuleScope KitReview {
                Mock Get-CopilotReview {
                    [pscustomobject]@{ ReviewId = 61; Commit = 'head1'; Verdict = 'Approval recommended'; OpenIssueCount = 0; Body = 'summary'; Issues = @() }
                }
                Mock Get-CopilotReview {
                    [pscustomobject]@{
                        ReviewId = 60; Commit = 'head2'; Verdict = 'Needs a closer look'; OpenIssueCount = 0; Body = 'summary'
                        Issues  = @([pscustomobject]@{ Severity = 'High'; Title = 'E'; CommentId = $null; Link = $null; Body = '**Blocking**: missed.' })
                    }
                } -ParameterFilter { $Commit -eq 'head2' }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                @($findings | ForEach-Object { "$($_.Title) of $($_.ReviewId)" }) | Should -Contain 'E of 60'
            }
        }

        It 'gives a summary issue with no thread the text Copilot wrote for it' {
            InModuleScope KitReview {
                Mock Get-CopilotReview {
                    [pscustomobject]@{
                        ReviewId = 51; Verdict = 'Needs a closer look'; OpenIssueCount = 0; Body = 'summary'
                        Issues  = @([pscustomobject]@{ Severity = 'Low'; Title = 'D'; CommentId = $null; Link = $null; Body = '**Should fix**: missed.' })
                    }
                }

                $finding = @(Get-OpenFinding -Repository 'o/r' -Number 5) | Where-Object { $_.Title -eq 'D' }

                $finding.Body | Should -Be '**Should fix**: missed.'
            }
        }

        It 'leaves out a summary issue with no thread once the signed-in account has resolved it for that review' {
            InModuleScope KitReview {
                Mock Get-PullRequestComment { [pscustomobject]@{ Author = 'DerekFoulk'; Body = 'Answer to review 50, "C": Resolution: addressed. Fixed in abc1234.' } }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { $_.Title }) | Should -Not -Contain 'C'
                $findings.Count | Should -Be 2
            }
        }

        It 'keeps a summary issue whose only answer is <Case>' -ForEach @(
            @{ Case = 'for an older review'; Author = 'DerekFoulk'; Body = 'Answer to review 49, "C": Resolution: addressed. Fixed in abc1234.' }
            @{ Case = 'from someone other than the signed-in account'; Author = 'mallory'; Body = 'Answer to review 50, "C": Resolution: addressed. Fixed.' }
            @{ Case = 'not a final resolution'; Author = 'DerekFoulk'; Body = 'Answer to review 50, "C": I recommend not fixing this. Owner, your call.' }
        ) {
            InModuleScope KitReview -Parameters @{ Author = $Author; Body = $Body } {
                param($Author, $Body)
                $script:answer = [pscustomobject]@{ Author = $Author; Body = $Body }
                Mock Get-PullRequestComment { $script:answer }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { $_.Title }) | Should -Contain 'C'
            }
        }

        It "lists each person's latest review that requests changes or comments, except the signed-in account's" {
            InModuleScope KitReview {
                Mock Get-PullRequestReview {
                    @{ id = 60; user = @{ login = 'alice' }; state = 'CHANGES_REQUESTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'Please split this function.' }
                    @{ id = 61; user = @{ login = 'bob' }; state = 'COMMENTED'; submitted_at = '2026-11-03T09:00:00Z'; body = 'Rename it.' }
                    @{ id = 62; user = @{ login = 'bob' }; state = 'APPROVED'; submitted_at = '2026-11-03T11:00:00Z'; body = '' }
                    @{ id = 63; user = @{ login = 'DerekFoulk' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'Agent note.' }
                    @{ id = 64; user = @{ login = 'copilot-pull-request-reviewer[bot]' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'summary' }
                    @{ id = 65; user = $null; state = 'CHANGES_REQUESTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'Gone.' }
                    @{ id = 66; user = @{ login = 'carol' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; body = '' }
                }

                $people = @(Get-OpenFinding -Repository 'o/r' -Number 5 | Where-Object { -not $_.Thread -and $_.Title -ne 'C' })

                $people.Count | Should -Be 1
                $people[0].Author | Should -Be 'alice'
                $people[0].Title | Should -Be 'Review by alice'
                $people[0].Body | Should -Be 'Please split this function.'
                $people[0].ReviewId | Should -Be 60
            }
        }

        # On a PR someone else opened (Dependabot, a teammate), the agent still posts as the signed-in account.
        It 'counts answers from the signed-in account on a PR someone else opened' {
            InModuleScope KitReview {
                Mock Get-PullRequestComment { [pscustomobject]@{ Author = 'DerekFoulk'; Body = 'Answer to review 50, "C": Resolution: addressed. Fixed in abc1234.' } }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { $_.Title }) | Should -Not -Contain 'C'
            }
        }

        It "lists a review by someone who opened the PR, and leaves out the signed-in account's own" {
            InModuleScope KitReview {
                Mock Get-PullRequestReview {
                    @{ id = 70; user = @{ login = 'alice' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'I left a question on the design.' }
                    @{ id = 71; user = @{ login = 'DerekFoulk' }; state = 'COMMENTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'Agent note.' }
                }

                $titles = @(Get-OpenFinding -Repository 'o/r' -Number 5 | ForEach-Object { $_.Title })

                $titles | Should -Contain 'Review by alice'
                $titles | Should -Not -Contain 'Review by DerekFoulk'
            }
        }

        It "leaves out a person's review once the signed-in account has resolved it" {
            InModuleScope KitReview {
                Mock Get-PullRequestReview { @{ id = 60; user = @{ login = 'alice' }; state = 'CHANGES_REQUESTED'; submitted_at = '2026-11-03T10:00:00Z'; body = 'Please split this function.' } }
                Mock Get-PullRequestComment { [pscustomobject]@{ Author = 'DerekFoulk'; Body = 'Answer to review 60, "Review by alice": Resolution: addressed. Split in abc1234.' } }

                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                ($findings | ForEach-Object { $_.Title }) | Should -Not -Contain 'Review by alice'
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

        It "names Copilot the same way for an issue with or without a thread" {
            InModuleScope KitReview {
                $findings = @(Get-OpenFinding -Repository 'o/r' -Number 5)

                $findings[1].Author | Should -Be $findings[0].Author
            }
        }

        It 'leaves out an open thread with no comments, since it has nothing to reply to' {
            InModuleScope KitReview {
                Mock Get-CopilotReview { }
                Mock Get-ReviewThread {
                    [pscustomobject]@{ ThreadId = 'T9'; IsResolved = $false; IsOutdated = $false; Path = 'a.ps1'; Line = 1; CommentId = $null; Author = $null; Body = $null; Comments = @() }
                }

                @(Get-OpenFinding -Repository 'o/r' -Number 5).Count | Should -Be 0
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

    Context 'Get-PullRequestComment' {
        It 'reads every page of conversation comments, one per line, with each author' {
            InModuleScope KitReview {
                Mock Invoke-Gh { "{ `"user`": { `"login`": `"alice`" }, `"body`": `"first`" }`n{ `"user`": null, `"body`": `"second`" }" }

                $comments = @(Get-PullRequestComment -Repository 'o/r' -Number 5)

                ($comments | ForEach-Object { $_.Body }) | Should -Be @('first', 'second')
                ($comments | ForEach-Object { $_.Author }) | Should -Be @('alice', '(deleted account)')
                Should -Invoke Invoke-Gh -ParameterFilter { $args -contains '--jq' -and $args -contains '.[]' }
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

            # ValidateSet ignores case, but GitHub's enum doesn't: a lowercase reason would fail after the reply posts.
            It 'sends the reason in capitals even when it is given in lowercase' {
                InModuleScope KitReview {
                    Resolve-ReviewThread -Repository 'o/r' -Number 5 -Thread $script:openThread -Reason 'addressed' -Evidence 'Fixed.' | Out-Null

                    ($script:calls | Where-Object { $_ -like 'api graphql*' }) | Should -MatchExactly 'reason=ADDRESSED'
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

        Context 'Resolve-ReviewFinding' {
            It 'answers a finding with no thread in a PR comment that names its review and resolution' {
                InModuleScope KitReview {
                    $finding = [pscustomobject]@{ Title = 'C'; ReviewId = 50; Thread = $null }

                    $result = Resolve-ReviewFinding -Repository 'o/r' -Number 5 -Finding $finding -Reason ADDRESSED -Evidence 'Fixed in abc1234.'

                    $result.ReplyUrl | Should -Be 'https://github.com/o/r/pull/5#issuecomment-9'
                    ($script:calls | Where-Object { $_ -like '*repos/o/r/issues/5/comments*' }) | Should -BeLike '*body=Answer to review 50, "C": Resolution: addressed. Fixed in abc1234.'
                    @($script:calls | Where-Object { $_ -like 'api graphql*' }).Count | Should -Be 0
                }
            }

            It 'answers a finding with a thread by replying in it and resolving it' {
                InModuleScope KitReview {
                    $finding = [pscustomobject]@{ Title = 'A'; ReviewId = 50; Thread = $script:openThread }

                    $result = Resolve-ReviewFinding -Repository 'o/r' -Number 5 -Finding $finding -Reason INVALID -Evidence 'The test at line 9 shows it.'

                    $result.Resolved | Should -BeTrue
                    ($script:calls | Where-Object { $_ -like '*comments/7/replies*' }) | Should -BeLike '*body=Resolution: incorrect. The test at line 9 shows it.*'
                    ($script:calls | Where-Object { $_ -like 'api graphql*' }) | Should -BeLike '*reason=INVALID*'
                }
            }

            It "refuses won't fix without the owner's OK for a finding with no thread, and writes nothing" {
                InModuleScope KitReview {
                    $finding = [pscustomobject]@{ Title = 'C'; ReviewId = 50; Thread = $null }

                    { Resolve-ReviewFinding -Repository 'o/r' -Number 5 -Finding $finding -Reason WONT_FIX -Evidence 'Out of scope.' } | Should -Throw '*owner*'

                    @($script:calls | Where-Object { $_ -like '*/issues/*' -or $_ -like 'api graphql*' }).Count | Should -Be 0
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

            It "posts a pull request comment for a finding whose Thread is empty" {
                InModuleScope KitReview {
                    $finding = [pscustomobject]@{ Title = 'C'; Thread = $null }

                    { $script:posted = Add-ReviewReply -Repository 'o/r' -Number 5 -Thread $finding.Thread -Body 'Fixed in abc1234.' } | Should -Not -Throw
                    $script:posted.Url | Should -Be 'https://github.com/o/r/pull/5#issuecomment-9'
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

    # The kit's own watcher (owner, 2026-11-14): an agent waits for Copilot's review of the head commit and for CI
    # with this, in any tool, instead of a host's monitor that reports only failures or a script of its own.
    Context 'Wait-PullRequest' {
        BeforeAll {
            # The GraphQL response the rollup read gets, built from each check's fields (shape checked against PR #73,
            # 2026-11-14): a CheckRun's app, workflow run and own id sit in checkSuite and databaseId. Global so the
            # InModuleScope blocks below see it; removed in AfterAll.
            function global:ConvertTo-RollupJson {
                param([object[]] $Checks = @(), [string] $State = 'OPEN', [string] $Head = 'head2')
                $nodes = @($Checks | ForEach-Object {
                        if ($_['__typename'] -eq 'StatusContext') { @{ __typename = 'StatusContext'; context = $_['context']; state = $_['state'] } }
                        else {
                            $run = if ($_.ContainsKey('workflowName') -or $_.ContainsKey('runId')) { @{ databaseId = $_['runId']; workflow = @{ name = $_['workflowName'] } } } else { $null }
                            @{
                                __typename = 'CheckRun'; databaseId = $_['id']; name = $_['name']; status = $_['status']; conclusion = $_['conclusion']; startedAt = $_['startedAt']
                                checkSuite = @{ app = @{ slug = $_['app'] ?? 'github-actions' }; workflowRun = $run }
                            }
                        }
                    })
                $rollup = @{ contexts = @{ pageInfo = @{ hasNextPage = $false; endCursor = $null }; nodes = $nodes } }
                @{ data = @{ repository = @{ pullRequest = @{ state = $State; headRefOid = $Head; commits = @{ nodes = @(@{ commit = @{ statusCheckRollup = $rollup } }) } } } } } |
                    ConvertTo-Json -Depth 15 -Compress
            }
        }
        AfterAll { Remove-Item -Path Function:\ConvertTo-RollupJson -ErrorAction SilentlyContinue }

        It 'returns Reviewed once Copilot has reviewed the head commit, not an older one' {
            Get-Command Wait-PullRequest -Module KitReview -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'the module waits for a review'
            InModuleScope KitReview {
                Mock Get-PullRequestStatus { [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @() } }
                $script:reviewCalls = 0
                Mock Get-CopilotReview {
                    $script:reviewCalls++
                    $commit = if ($script:reviewCalls -lt 2) { 'head1' } else { 'head2' }
                    [pscustomobject]@{ ReviewId = 9; Commit = $commit; Verdict = 'Approval recommended'; OpenIssueCount = 0; Issues = @() }
                }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'Reviewed'
                $result.Review.Commit | Should -Be 'head2'
                $result.Message | Should -Match 'Copilot reviewed head2: Approval recommended, 0 open issues'
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 20 }
            }
        }

        # Copilot's eighth review of PR #73: the head and the review are two reads, and a push can land between them, so
        # a review of the commit that was the head isn't a review of the head. The head is read again before Reviewed.
        It 'returns HeadMoved when a push lands between reading the head and finding its review' {
            InModuleScope KitReview {
                $script:statusCalls = 0
                Mock Get-PullRequestStatus { $script:statusCalls++; [pscustomobject]@{ State = 'OPEN'; HeadSha = $(if ($script:statusCalls -lt 2) { 'head2' } else { 'head3' }); Checks = @() } }
                Mock Get-CopilotReview { [pscustomobject]@{ ReviewId = 9; Commit = 'head2'; Verdict = 'Approval recommended'; OpenIssueCount = 0; Issues = @() } } -ParameterFilter { $Commit -eq 'head2' }
                Mock Get-CopilotReview { }
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'HeadMoved'
                $result.HeadSha | Should -Be 'head3'
            }
        }

        # Copilot's eleventh review of PR #73: with -For Either, the review read comes between the status read and the CI
        # result, and a push or close can land during it. The state and head are read again before any CI result.
        It 'returns <Outcome> when the pull request is <Change> during an empty review read, before a CI result' -ForEach @(
            @{ Change = 'pushed to'; State = 'OPEN'; Head = 'head3'; Outcome = 'HeadMoved' }
            @{ Change = 'closed'; State = 'CLOSED'; Head = 'head2'; Outcome = 'Closed' }
        ) {
            InModuleScope KitReview -Parameters @{ State = $State; Head = $Head; Outcome = $Outcome } {
                param($State, $Head, $Outcome)
                $script:later = [pscustomobject]@{ State = $State; Head = $Head }
                $script:statusCalls = 0
                # The first two polls find CI passed at head2 (a pass and its confirmation); the read after that sees the change.
                Mock Get-PullRequestStatus {
                    $script:statusCalls++
                    $state = if ($script:statusCalls -le 2) { 'OPEN' } else { $script:later.State }
                    $head = if ($script:statusCalls -le 2) { 'head2' } else { $script:later.Head }
                    [pscustomobject]@{ State = $state; HeadSha = $head; Checks = @([pscustomobject]@{ Name = 'dotnet / Build'; Result = 'Passed' }); PendingRuns = @(); FailedRuns = @() }
                }
                Mock Get-CopilotReview { }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Either -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be $Outcome
            }
        }

        # Copilot's ninth review of PR #73: the second read can find the pull request merged or closed, not only moved; a
        # merged PR's review is nothing to answer.
        It 'returns <Outcome> when the pull request is <State> between reading the head and finding its review' -ForEach @(
            @{ State = 'MERGED'; Outcome = 'Merged' }
            @{ State = 'CLOSED'; Outcome = 'Closed' }
        ) {
            InModuleScope KitReview -Parameters @{ State = $State; Outcome = $Outcome } {
                param($State, $Outcome)
                $script:statusCalls = 0
                $script:later = $State
                Mock Get-PullRequestStatus { $script:statusCalls++; [pscustomobject]@{ State = $(if ($script:statusCalls -lt 2) { 'OPEN' } else { $script:later }); HeadSha = 'head2'; Checks = @() } }
                Mock Get-CopilotReview { [pscustomobject]@{ ReviewId = 9; Commit = 'head2'; Verdict = 'Approval recommended'; OpenIssueCount = 0; Issues = @() } }
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be $Outcome
            }
        }

        # Copilot's sixth review of PR #73: a review of an older commit can land after the head's review, so the latest
        # review isn't always the head's. The head commit's own review counts, wherever it falls.
        It 'returns Reviewed when Copilot reviewed the head commit, even if a review of an older commit came later' {
            InModuleScope KitReview {
                Mock Get-PullRequestStatus { [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @() } }
                Mock Invoke-Gh {
                    '[{ "id": 11, "user": { "login": "copilot-pull-request-reviewer[bot]" }, "submitted_at": "2026-11-14T09:00:00Z", "commit_id": "head2", "body": "### 🟢 Approval recommended" }, { "id": 12, "user": { "login": "copilot-pull-request-reviewer[bot]" }, "submitted_at": "2026-11-14T09:05:00Z", "commit_id": "head1", "body": "### 🟡 Changes recommended" }]'
                }
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'Reviewed'
                $result.Message | Should -Be 'Copilot reviewed head2: Approval recommended, 0 open issues.'
            }
        }

        # Copilot's review of PR #73: the limit is elapsed time on a clock the tests control (TST-010), not a count of
        # polls, so fast or slow GitHub calls, or an interval longer than the limit, can't end it early or late.
        It 'returns TimedOut at the time limit, saying what it still waits for, and sleeps only between polls' {
            Get-Command Wait-PullRequest -Module KitReview -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because 'the module waits for a review'
            InModuleScope KitReview {
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                Mock Get-PullRequestStatus { [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @(); PendingRuns = @() } }
                Mock Get-CopilotReview { }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'TimedOut'
                $result.Message | Should -Match "Timed out after 1 minute at head2: no review from Copilot of head2 yet"
                Should -Invoke Get-PullRequestStatus -Times 4 -Exactly -Because 'it polls at 0, 20, 40 and 60 seconds'
                Should -Invoke Start-Sleep -Times 3 -Exactly
            }
        }

        It 'never sleeps past the limit: <Case>' -ForEach @(
            @{ Case = 'an interval longer than the limit waits only the time left'; Interval = 600; CallSeconds = 0; Polls = 2; Sleeps = @(60) }
            @{ Case = 'slow GitHub calls count toward the limit'; Interval = 20; CallSeconds = 30; Polls = 2; Sleeps = @(20) }
        ) {
            InModuleScope KitReview -Parameters @{ Interval = $Interval; CallSeconds = $CallSeconds; Polls = $Polls; Sleeps = $Sleeps } {
                param($Interval, $CallSeconds, $Polls, $Sleeps)
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                $script:callSeconds = $CallSeconds
                $script:slept = [System.Collections.Generic.List[int]]::new()
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:slept.Add($Seconds); $script:now = $script:now.AddSeconds($Seconds) }
                Mock Get-PullRequestStatus { $script:now = $script:now.AddSeconds($script:callSeconds); [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @(); PendingRuns = @() } }
                Mock Get-CopilotReview { }

                (Wait-PullRequest -Repository 'o/r' -Number 5 -For Review -TimeoutMinutes 1 -IntervalSeconds $Interval).Event | Should -Be 'TimedOut'

                Should -Invoke Get-PullRequestStatus -Times $Polls -Exactly
                @($script:slept) | Should -Be $Sleeps
            }
        }

        # A rollup holds CheckRuns, with status and conclusion, and StatusContexts, with context and state (seen on PR #72,
        # 2026-11-14).
        It 'keeps waiting while there are no checks yet or one is running, then returns <Outcome> naming <What>' -ForEach @(
            # A pass waits one more poll to be confirmed (Copilot's ninth review of PR #73); a failure is final at once.
            @{ Outcome = 'ChecksPassed'; What = 'every check'; Conclusion = 'SUCCESS'; Expected = 'CI finished at head2: every check passed (2 passed, 1 skipped)'; Sleeps = 3 }
            @{ Outcome = 'ChecksFailed'; What = 'the failed one'; Conclusion = 'FAILURE'; Expected = 'CI finished at head2: 1 of 3 checks failed: dotnet / Build'; Sleeps = 2 }
        ) {
            InModuleScope KitReview -Parameters @{ Conclusion = $Conclusion; Outcome = $Outcome; Expected = $Expected; Sleeps = $Sleeps } {
                param($Conclusion, $Outcome, $Expected, $Sleeps)
                function New-View([object[]] $Checks) { ConvertTo-RollupJson -Checks $Checks }
                $done = @(
                    @{ __typename = 'CheckRun'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = $Conclusion }
                    @{ __typename = 'CheckRun'; name = 'Refresh NuGet lock files'; status = 'COMPLETED'; conclusion = 'SKIPPED' }
                    @{ __typename = 'StatusContext'; context = 'PR title'; state = 'SUCCESS' }
                )
                $running = @($done[1], $done[2], @{ __typename = 'CheckRun'; name = 'dotnet / Build'; status = 'IN_PROGRESS'; conclusion = $null })
                $script:views = @((New-View @()), (New-View $running), (New-View $done))
                $script:viewCalls = 0
                Mock Invoke-Gh { $script:views[[Math]::Min($script:viewCalls++, 2)] } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                # The run stays in progress until the last poll, as it does while a check is still running.
                $script:runs = @('{"workflow_runs":[{"name":"ci","status":"in_progress","conclusion":null}]}', '{"workflow_runs":[{"name":"ci","status":"in_progress","conclusion":null}]}', '{"workflow_runs":[{"name":"ci","status":"completed","conclusion":"success"}]}')
                $script:runCalls = 0
                Mock Invoke-Gh { $script:runs[[Math]::Min($script:runCalls++, 2)] } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be $Outcome
                $result.Message | Should -Match ([regex]::Escape($Expected))
                Should -Invoke Start-Sleep -Times $Sleeps -Exactly
            }
        }

        # Copilot's review of PR #73: a job that needs another isn't a check until its turn comes, so every registered
        # check done isn't CI done. The head commit's workflow runs have to be completed too.
        It 'keeps waiting while a workflow run is still going, even when every check so far has passed' {
            InModuleScope KitReview {
                function New-View([object[]] $Checks) { ConvertTo-RollupJson -Checks $Checks }
                $found = @{ __typename = 'CheckRun'; name = 'dotnet / Find UI projects'; status = 'COMPLETED'; conclusion = 'SUCCESS' }
                $build = @{ __typename = 'CheckRun'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE' }
                $script:views = @((New-View @($found)), (New-View @($found, $build)))
                $script:runs = @(
                    '{"workflow_runs":[{"name":"ci","status":"in_progress","conclusion":null}]}'
                    '{"workflow_runs":[{"name":"ci","status":"completed","conclusion":"failure"}]}'
                )
                $script:viewCalls = 0; $script:runCalls = 0
                Mock Invoke-Gh { $script:views[[Math]::Min($script:viewCalls++, 1)] } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { $script:runs[[Math]::Min($script:runCalls++, 1)] } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match 'dotnet / Build'
                Should -Invoke Start-Sleep -Times 1 -Exactly
            }
        }

        # Copilot's re-review of PR #73: the checks and the runs are two reads, and a job can fail between them, so the
        # checks read before the runs completed say nothing about it. The checks are read again, and a failed run is a
        # failure in its own right.
        It 'reports a job that fails between its two reads as failed: <Case>' -ForEach @(
            @{ Case = 'the checks read again show it'; Fresh = 'build'; Expected = 'dotnet / Build' }
            @{ Case = 'only its workflow run shows it'; Fresh = 'partial'; Expected = 'ci' }
        ) {
            InModuleScope KitReview -Parameters @{ Fresh = $Fresh; Expected = $Expected } {
                param($Fresh, $Expected)
                function New-View([object[]] $Checks) { ConvertTo-RollupJson -Checks $Checks }
                $found = @{ __typename = 'CheckRun'; name = 'dotnet / Find UI projects'; status = 'COMPLETED'; conclusion = 'SUCCESS' }
                $build = @{ __typename = 'CheckRun'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE' }
                $second = if ($Fresh -eq 'build') { New-View @($found, $build) } else { New-View @($found) }
                $script:views = @((New-View @($found)), $second)
                $script:viewCalls = 0
                Mock Invoke-Gh { $script:views[[Math]::Min($script:viewCalls++, 1)] } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"name":"ci","status":"completed","conclusion":"failure"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match ([regex]::Escape($Expected))
            }
        }

        # PR #73's own rollup listed "PR title" twice: a workflow that runs again on the same commit (here, when the
        # description was edited) keeps its earlier run in the rollup. Only each check's latest run counts.
        It 'counts only the latest run of a check that ran twice on the head commit' {
            InModuleScope KitReview {
                $view = ConvertTo-RollupJson -Checks @(
                        @{ __typename = 'CheckRun'; workflowName = 'PR title'; name = 'PR title'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:06Z' }
                        @{ __typename = 'CheckRun'; workflowName = 'PR title'; name = 'PR title'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:38Z' }
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:10Z' }
                    )
                $script:view = $view
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                # Copilot's review of PR #73: the workflow runs repeat too; the earlier failed run of PR title must not count.
                Mock Invoke-Gh { '{"workflow_runs":[{"name":"PR title","workflow_id":11,"event":"pull_request","created_at":"2026-11-14T04:56:05Z","status":"completed","conclusion":"failure"},{"name":"PR title","workflow_id":11,"event":"pull_request","created_at":"2026-11-14T04:56:37Z","status":"completed","conclusion":"success"},{"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksPassed'
                $result.Message | Should -Match 'every check passed \(2 passed, 0 skipped\)'
            }
        }

        # Copilot's fourth review of PR #73: a replaced run's job can start after its replacement's, so start order alone
        # can pick the old failure. A check belongs to the workflow run GitHub names for it; a replaced run's checks don't count.
        It 'drops the checks of a replaced workflow run, even when its job started after the replacement''s' {
            InModuleScope KitReview {
                $view = ConvertTo-RollupJson -Checks @(
                        @{ __typename = 'CheckRun'; workflowName = 'PR title'; name = 'PR title'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:57:00Z'; runId = 100; id = 1 }
                        @{ __typename = 'CheckRun'; workflowName = 'PR title'; name = 'PR title'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:40Z'; runId = 101; id = 2 }
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:10Z'; runId = 102; id = 3 }
                    )
                $script:view = $view
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":100,"name":"PR title","workflow_id":11,"event":"pull_request","created_at":"2026-11-14T04:56:05Z","status":"completed","conclusion":"failure"},{"id":101,"name":"PR title","workflow_id":11,"event":"pull_request","created_at":"2026-11-14T04:56:37Z","status":"completed","conclusion":"success"},{"id":102,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksPassed'
                $result.Message | Should -Match 'every check passed \(2 passed, 0 skipped\)'
            }
        }

        # Copilot's sixth review of PR #73: start and creation times are to the second, so two attempts of a check, or two
        # runs of a workflow, can tie, and a job that hasn't started has no start time at all. GitHub numbers jobs and runs
        # in order, so the higher id is the later one, wherever it falls in the list.
        It 'picks the later of two by id, not by list order: <Case>' -ForEach @(
            @{ Case = 'two attempts of a check started in the same second'; Expected = 'ChecksFailed'
                Checks = @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 400; id = 2 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:10Z'; runId = 400; id = 1 }
                )
                Runs = '{"workflow_runs":[{"id":400,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' }
            @{ Case = 'a re-run of a check that hasn''t started yet'; Expected = 'TimedOut'
                Checks = @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'QUEUED'; conclusion = $null; startedAt = $null; runId = 400; id = 2 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:10Z'; runId = 400; id = 1 }
                )
                Runs = '{"workflow_runs":[{"id":400,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' }
            @{ Case = 'two runs of a workflow created in the same second'; Expected = 'ChecksFailed'
                Checks = @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 501; id = 2 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:11Z'; runId = 500; id = 1 }
                )
                Runs = '{"workflow_runs":[{"id":501,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"failure"},{"id":500,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' }
        ) {
            InModuleScope KitReview -Parameters @{ Checks = $Checks; Runs = $Runs; Expected = $Expected } {
                param($Checks, $Runs, $Expected)
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                $script:view = ConvertTo-RollupJson -Checks $Checks
                $script:runsJson = $Runs
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { $script:runsJson } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be $Expected
                $result.Message | Should -Match 'dotnet / Build'
            }
        }

        # Copilot's tenth review of PR #73: checks come from any app, not only GitHub Actions. Two apps can post checks of the
        # same name, and an app's re-run of a check is a new check with a higher id that hasn't started yet.
        It 'reads checks from other apps right: <Case>' -ForEach @(
            @{ Case = 'two apps'' checks of the same name are two checks'; Expected = 'ChecksFailed'
                Checks = @(
                    @{ __typename = 'CheckRun'; name = 'build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; app = 'ci-a'; id = 1 }
                    @{ __typename = 'CheckRun'; name = 'build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:20Z'; app = 'ci-b'; id = 2 }
                ) }
            @{ Case = 'a re-run that hasn''t started is the latest attempt'; Expected = 'TimedOut'
                Checks = @(
                    @{ __typename = 'CheckRun'; name = 'build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:10Z'; app = 'ci-a'; id = 7 }
                    @{ __typename = 'CheckRun'; name = 'build'; status = 'QUEUED'; conclusion = $null; startedAt = $null; app = 'ci-a'; id = 8 }
                ) }
        ) {
            InModuleScope KitReview -Parameters @{ Checks = $Checks; Expected = $Expected } {
                param($Checks, $Expected)
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                $script:view = ConvertTo-RollupJson -Checks $Checks
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be $Expected
            }
        }

        # The rollup is read 100 checks to a page (gh api graphql --paginate --slurp: one array holding each page), so a
        # failure past the first page counts; and a push between pages makes the pages disagree on the head, so that read
        # gives no checks, and the push from the first page's head is HeadMoved (Copilot's twelfth review of PR #73).
        It 'reads the rollup''s pages as one: <Case>' -ForEach @(
            @{ Case = 'a failure on the second page counts'; Second = 'head2'; Expected = 'ChecksFailed' }
            @{ Case = 'pages that disagree on the head are a push from the first page''s head'; Second = 'head3'; Expected = 'HeadMoved' }
        ) {
            InModuleScope KitReview -Parameters @{ Second = $Second; Expected = $Expected } {
                param($Second, $Expected)
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                $first = ConvertTo-RollupJson -Checks @(@{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; runId = 1; id = 1 })
                $second = ConvertTo-RollupJson -Head $Second -Checks @(@{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Lint'; status = 'COMPLETED'; conclusion = 'FAILURE'; runId = 1; id = 2 })
                $script:onePage = $first
                $script:everyPage = "[$first,$second]"
                Mock Invoke-Gh { if ($args -contains '--paginate' -and $args -contains '--slurp') { $script:everyPage } else { $script:onePage } } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":1,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be $Expected
            }
        }

        # Copilot's eleventh review of PR #73: the first poll reads the rollup twice, and a push between the reads changes
        # the head. The head it started from is the one the wait is for, so the push is HeadMoved, not a new baseline.
        It 'returns HeadMoved when the head changes between the two rollup reads of the first poll' {
            InModuleScope KitReview {
                $passing = @(@{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; runId = 1; id = 1 })
                $script:views = @((ConvertTo-RollupJson -Head 'head2' -Checks $passing), (ConvertTo-RollupJson -Head 'head3' -Checks $passing))
                $script:viewCalls = 0
                Mock Invoke-Gh { $script:views[[Math]::Min($script:viewCalls++, 1)] } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":1,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'HeadMoved'
                $result.Message | Should -Be 'The head moved from head2 to head3: wait again for the new commit.'
            }
        }

        # Copilot's twelfth review of PR #73: re-running an older run of a workflow starts a new attempt of it, and it keeps
        # its creation time. The run started last (run_started_at, its latest attempt's start) is the one that counts.
        It 'counts a re-run of an older workflow run as the latest, so its pending checks keep it waiting' {
            InModuleScope KitReview {
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                $script:view = ConvertTo-RollupJson -Checks @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'build'; status = 'QUEUED'; conclusion = $null; startedAt = $null; runId = 100; id = 5 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:40Z'; runId = 101; id = 2 }
                )
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":100,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:05Z","run_started_at":"2026-11-14T05:10:00Z","run_attempt":2,"status":"queued","conclusion":null},{"id":101,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:37Z","run_started_at":"2026-11-14T04:56:37Z","run_attempt":1,"status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'TimedOut'
                $result.Message | Should -Match '1 checks still running: build'
            }
        }

        # Copilot's eleventh review of PR #73: two runs of one workflow for different triggers both count, and so do their
        # checks of the same name. A job with continue-on-error fails without failing its run, so only its check shows it.
        It 'keeps the same-named checks of two independent runs apart' {
            InModuleScope KitReview {
                $script:view = ConvertTo-RollupJson -Checks @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 10; id = 1 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:12Z'; runId = 11; id = 2 }
                )
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":10,"name":"ci","workflow_id":12,"event":"push","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"},{"id":11,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:11Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match '1 of 2 checks failed: build'
            }
        }

        # Copilot's sixth review of PR #73: the head commit can be on another branch too (another pull request from the same
        # commit), and the runs listed by head_sha include that branch's. A run there never replaces a run on this one.
        It 'keeps a failed workflow run when a later run of the same workflow ran on another branch' {
            InModuleScope KitReview {
                $script:view = ConvertTo-RollupJson -Checks @(
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 300; id = 1 }
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:57:01Z'; runId = 301; id = 2 }
                    )
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":300,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"failure"},{"id":301,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/b","created_at":"2026-11-14T04:57:00Z","status":"completed","conclusion":"success"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match 'workflow runs failed: ci'
            }
        }

        # Copilot's eighth review of PR #73: a branch name doesn't pick out one pull request. Two pull requests can come
        # from the same branch (into different bases), and a fork can have a branch of the same name; their runs of one
        # workflow are separate runs, and neither replaces the other.
        It 'keeps a failed workflow run when a later run of the same workflow was for <Case>' -ForEach @(
            @{ Case = 'another pull request from the same branch'; Later = '"head_repository":{"full_name":"o/r"},"pull_requests":[{"number":6}]' }
            @{ Case = 'a fork''s branch of the same name'; Later = '"head_repository":{"full_name":"fork/r"},"pull_requests":[]' }
        ) {
            InModuleScope KitReview -Parameters @{ Later = $Later } {
                param($Later)
                $script:view = ConvertTo-RollupJson -Checks @(
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 700; id = 1 }
                        @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:57:01Z'; runId = 701; id = 2 }
                    )
                $script:runsJson = '{"workflow_runs":[{"id":700,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","head_repository":{"full_name":"o/r"},"pull_requests":[{"number":5}],"created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"failure"},{"id":701,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a",' + $Later + ',"created_at":"2026-11-14T04:57:00Z","status":"completed","conclusion":"success"}]}'
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { $script:runsJson } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match 'workflow runs failed: ci'
            }
        }

        # Copilot's ninth review of PR #73: a pass rests on one read, and a workflow run created just after it (seconds
        # after a push, or between the runs read and the checks read) isn't in it. A pass counts only once the next poll
        # finds it again; a failure is final at once.
        It 'reports a pass only when the next poll confirms it, so a run created just after the first read counts' {
            InModuleScope KitReview {
                function New-View([object[]] $Checks) { ConvertTo-RollupJson -Checks $Checks }
                $build = @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; runId = 1; id = 1 }
                $labelQueued = @{ __typename = 'CheckRun'; workflowName = 'Labeler'; name = 'label'; status = 'QUEUED'; conclusion = $null; runId = 2; id = 2 }
                $labelFailed = @{ __typename = 'CheckRun'; workflowName = 'Labeler'; name = 'label'; status = 'COMPLETED'; conclusion = 'FAILURE'; runId = 2; id = 2 }
                $ci = '{"id":1,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}'
                $script:views = @((New-View @($build)), (New-View @($build, $labelQueued)), (New-View @($build, $labelFailed)))
                $script:runs = @(
                    "{`"workflow_runs`":[$ci]}"
                    "{`"workflow_runs`":[$ci,{`"id`":2,`"name`":`"Labeler`",`"workflow_id`":13,`"event`":`"pull_request`",`"created_at`":`"2026-11-14T04:56:30Z`",`"status`":`"queued`",`"conclusion`":null}]}"
                    "{`"workflow_runs`":[$ci,{`"id`":2,`"name`":`"Labeler`",`"workflow_id`":13,`"event`":`"pull_request`",`"created_at`":`"2026-11-14T04:56:30Z`",`"status`":`"completed`",`"conclusion`":`"failure`"}]}"
                )
                # Each poll sees the state after as many sleeps as have passed.
                $script:polls = 0
                Mock Start-Sleep { $script:polls++ }
                Mock Invoke-Gh { $script:views[[Math]::Min($script:polls, 2)] } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { $script:runs[[Math]::Min($script:polls, 2)] } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match '1 of 2 checks failed: label'
            }
        }

        It 'says at the time limit that a pass seen once is waiting for its second read' {
            InModuleScope KitReview {
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                # The one poll takes the whole minute, so the pass it finds can't be read again before the limit.
                Mock Get-PullRequestStatus {
                    $script:now = $script:now.AddMinutes(1)
                    [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @([pscustomobject]@{ Name = 'dotnet / Build'; Result = 'Passed' }); PendingRuns = @(); FailedRuns = @() }
                }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'TimedOut'
                $result.Message | Should -Be 'Timed out after 1 minute at head2: every check passed once, waiting for a second read to confirm it.'
            }
        }

        # Copilot's ninth review of PR #73: Group-Object ignores case unless told not to, but branch names and check names
        # are case-sensitive, so two that differ only in case are two different things.
        It 'tells apart two <Case> that differ only in case' -ForEach @(
            @{ Case = 'branches'
                Checks = @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 800; id = 1 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:57:01Z'; runId = 801; id = 2 }
                )
                Runs = '{"workflow_runs":[{"id":800,"name":"ci","workflow_id":12,"event":"push","head_branch":"Feat/A","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"failure"},{"id":801,"name":"ci","workflow_id":12,"event":"push","head_branch":"feat/a","created_at":"2026-11-14T04:57:00Z","status":"completed","conclusion":"success"}]}'
                Expected = 'workflow runs failed: ci' }
            @{ Case = 'checks'
                Checks = @(
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'Build'; status = 'COMPLETED'; conclusion = 'FAILURE'; startedAt = '2026-11-14T04:56:10Z'; runId = 802; id = 1 }
                    @{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'build'; status = 'COMPLETED'; conclusion = 'SUCCESS'; startedAt = '2026-11-14T04:56:11Z'; runId = 802; id = 2 }
                )
                Runs = '{"workflow_runs":[{"id":802,"name":"ci","workflow_id":12,"event":"pull_request","head_branch":"feat/a","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}'
                Expected = '1 of 2 checks failed: Build' }
        ) {
            InModuleScope KitReview -Parameters @{ Checks = $Checks; Runs = $Runs; Expected = $Expected } {
                param($Checks, $Runs, $Expected)
                $script:view = ConvertTo-RollupJson -Checks $Checks
                $script:runsJson = $Runs
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { $script:runsJson } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match ([regex]::Escape($Expected))
            }
        }

        # Copilot's fifth review of PR #73: GitHub lists the runs 100 to a page, so a head commit with more runs has
        # some on later pages. Every page is read (gh api --paginate --slurp: one array holding each page).
        It 'reads every page of the head commit''s workflow runs' {
            InModuleScope KitReview {
                $script:view = ConvertTo-RollupJson -Checks @(@{ __typename = 'CheckRun'; workflowName = 'ci'; name = 'dotnet / Build'; status = 'COMPLETED'; conclusion = 'SUCCESS' })
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                $first = '{"workflow_runs":[{"id":1,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"success"}]}'
                $second = '{"workflow_runs":[{"id":2,"name":"Labeler","workflow_id":13,"event":"pull_request_target","created_at":"2026-11-14T04:56:11Z","status":"completed","conclusion":"failure"}]}'
                $script:onePage = $first
                $script:everyPage = "[$first,$second]"
                Mock Invoke-Gh { if ($args -contains '--paginate' -and $args -contains '--slurp') { $script:everyPage } else { $script:onePage } } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Match 'workflow runs failed: Labeler'
            }
        }

        # Copilot's fifth review of PR #73: a workflow that fails before it starts a job (a startup failure, such as an
        # invalid workflow file) adds no check to the rollup, so "no checks yet" can be CI that already failed.
        It 'returns ChecksFailed when a workflow run failed without adding a check' {
            InModuleScope KitReview {
                $script:now = [DateTimeOffset]'2026-11-14T00:00:00Z'
                Mock Get-KitUtcNow { $script:now }
                Mock Start-Sleep { $script:now = $script:now.AddSeconds($Seconds) }
                $script:view = ConvertTo-RollupJson -Checks @()
                Mock Invoke-Gh { $script:view } -ParameterFilter { "$args" -match 'statusCheckRollup' }
                Mock Invoke-Gh { '{"workflow_runs":[{"id":7,"name":"ci","workflow_id":12,"event":"pull_request","created_at":"2026-11-14T04:56:09Z","status":"completed","conclusion":"startup_failure"}]}' } -ParameterFilter { "$($args[1])" -like '*/actions/runs*' }

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Checks -TimeoutMinutes 1 -IntervalSeconds 20

                $result.Event | Should -Be 'ChecksFailed'
                $result.Message | Should -Be 'CI finished at head2: workflow runs failed: ci.'
            }
        }

        # A push while it waits makes the old head's review and checks beside the point.
        It 'returns HeadMoved, with the new head, when someone pushes while it waits' {
            InModuleScope KitReview {
                $script:statusCalls = 0
                Mock Get-PullRequestStatus { $script:statusCalls++; [pscustomobject]@{ State = 'OPEN'; HeadSha = $(if ($script:statusCalls -lt 2) { 'head1' } else { 'head2' }); Checks = @() } }
                Mock Get-CopilotReview { }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Either -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be 'HeadMoved'
                $result.HeadSha | Should -Be 'head2'
                $result.Message | Should -Match 'The head moved from head1 to head2'
            }
        }

        It 'returns <Outcome> at once when the pull request is <State>' -ForEach @(
            @{ State = 'MERGED'; Outcome = 'Merged' }
            @{ State = 'CLOSED'; Outcome = 'Closed' }
        ) {
            InModuleScope KitReview -Parameters @{ State = $State; Outcome = $Outcome } {
                param($State, $Outcome)
                $script:prState = $State
                Mock Get-PullRequestStatus { [pscustomobject]@{ State = $script:prState; HeadSha = 'head2'; Checks = @() } }
                Mock Get-CopilotReview { }
                Mock Start-Sleep {}

                $result = Wait-PullRequest -Repository 'o/r' -Number 5 -For Either -TimeoutMinutes 5 -IntervalSeconds 20

                $result.Event | Should -Be $Outcome
                $result.Message | Should -Match "Pull request #5 is $($Outcome.ToLowerInvariant())"
                Should -Invoke Start-Sleep -Times 0 -Exactly
            }
        }

        It 'returns the first event with -For Either: a review while CI still runs' {
            InModuleScope KitReview {
                Mock Get-PullRequestStatus { [pscustomobject]@{ State = 'OPEN'; HeadSha = 'head2'; Checks = @([pscustomobject]@{ Name = 'Build'; Result = 'Pending' }) } }
                Mock Get-CopilotReview { [pscustomobject]@{ ReviewId = 9; Commit = 'head2'; Verdict = 'Changes recommended'; OpenIssueCount = 2; Issues = @() } }
                Mock Start-Sleep {}

                (Wait-PullRequest -Repository 'o/r' -Number 5 -For Either -TimeoutMinutes 5 -IntervalSeconds 20).Event | Should -Be 'Reviewed'
            }
        }
    }
}
