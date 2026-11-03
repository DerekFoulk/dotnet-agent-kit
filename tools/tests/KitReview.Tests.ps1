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

        It 'returns nothing when Copilot has not reviewed' {
            InModuleScope KitReview {
                Mock Invoke-Gh { '[{ "id": 3, "user": { "login": "DerekFoulk" }, "state": "COMMENTED", "submitted_at": "2026-11-03T10:00:00Z", "commit_id": "c", "body": "" }]' }

                Get-CopilotReview -Repository 'DerekFoulk/dotnet-agent-kit' -Number 5 | Should -BeNullOrEmpty
            }
        }
    }
}
