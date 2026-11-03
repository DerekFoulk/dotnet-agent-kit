#Requires -Version 7.0
# Reads Copilot code reviews and resolves review threads on GitHub pull requests (ADR-0028).
# Every GitHub call goes through Invoke-Gh, the one place the tests replace.

Set-StrictMode -Version Latest

$script:CopilotLogin = 'copilot-pull-request-reviewer[bot]'

function Invoke-Gh {
    $output = gh @args
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($args -join ' ') failed with exit code $LASTEXITCODE."
    }
    $output -join "`n"
}

# Reads Copilot's summary comment ("ccr-overview-v2"): the verdict line ("### 🟡 Changes recommended",
# "### 🟢 Approval recommended"), the open-issue count, and one bullet per open issue with its severity
# and a link to its comment thread (#discussion_r<comment id>). An issue with no link has no thread.
function ConvertFrom-CopilotReviewBody {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Body)

    $verdict = 'Unknown'
    if ($Body -match '(?m)^###\s+\S*\s*(Changes recommended|Approval recommended)\s*$') {
        $verdict = $Matches[1]
    }

    $count = 0
    if ($Body -match '<strong>(\d+) open issues?</strong>') {
        $count = [int] $Matches[1]
    }

    $issues = @(foreach ($line in $Body -split "`r?`n") {
            if ($line -notmatch '^- ') { continue }
            $severity = if ($line -match 'alt="(\w+) severity"') { $Matches[1] } else { $null }
            if ($line -notmatch '\[([^\]]+)\]\(([^)]+)\)') { continue }
            $title = $Matches[1]
            $link = $Matches[2]
            $commentId = if ($link -match '#discussion_r(\d+)') { [long] $Matches[1] } else { $null }
            [pscustomobject]@{ Severity = $severity; Title = $title; CommentId = $commentId; Link = $link }
        })

    [pscustomobject]@{ Verdict = $verdict; OpenIssueCount = $count; Issues = $issues }
}

# Copilot's latest review on the pull request, with its summary read; nothing if Copilot hasn't reviewed.
# Copilot may update one review in place, so Commit is where it started, not necessarily the latest push.
function Get-CopilotReview {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $reviews = Invoke-Gh api --paginate "repos/$Repository/pulls/$Number/reviews" | ConvertFrom-Json -AsHashtable
    $latest = @($reviews | Where-Object { $_['user']['login'] -eq $script:CopilotLogin }) |
        Sort-Object { [datetimeoffset] $_['submitted_at'] } |
        Select-Object -Last 1
    if (-not $latest) {
        return
    }

    $summary = ConvertFrom-CopilotReviewBody -Body "$($latest['body'])"
    [pscustomobject]@{
        ReviewId       = $latest['id']
        SubmittedAt    = $latest['submitted_at']
        Commit         = $latest['commit_id']
        Verdict        = $summary.Verdict
        OpenIssueCount = $summary.OpenIssueCount
        Issues         = $summary.Issues
    }
}

Export-ModuleMember -Function Invoke-Gh, ConvertFrom-CopilotReviewBody, Get-CopilotReview
