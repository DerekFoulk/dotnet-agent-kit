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

    # Only the bullets inside the "N open issues" block are issues; the rest of the summary (such as
    # "What changed in this PR") can hold ordinary links.
    $inIssues = $false
    $issues = @(foreach ($line in $Body -split "`r?`n") {
            if ($line -match '<strong>\d+ open issues?</strong>') { $inIssues = $true; continue }
            if ($inIssues -and $line -match '</details>') { break }
            if (-not $inIssues -or $line -notmatch '^- ') { continue }

            $severity = if ($line -match 'alt="(\w+) severity"') { $Matches[1] } else { $null }
            $text = ($line -replace '^- ', '' -replace '(?s)<picture>.*?</picture>', '' -replace '\s+·\s+\w+\s*$', '').Trim()
            $title = $text
            $link = $null
            $commentId = $null
            # Greedy, so a title may itself contain brackets ("Handle `a[0]` indexing").
            if ($text -match '^\[(.+)\]\((https?://[^)\s]+)\)$') {
                $title = $Matches[1]
                $link = $Matches[2]
                if ($link -match '#discussion_r(\d+)$') { $commentId = [long] $Matches[1] }
            }
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
        Body           = "$($latest['body'])"
    }
}

# The pull request's review threads (up to 100), each with its first comment: the finding itself.
function Get-ReviewThread {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number, [switch] $Unresolved)

    $owner, $name = $Repository -split '/', 2
    $query = 'query($owner: String!, $name: String!, $number: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $number) { reviewThreads(first: 100) { nodes { id isResolved isOutdated path line comments(first: 1) { nodes { databaseId author { login } body } } } } } } }'
    $response = Invoke-Gh api graphql -f "query=$query" -F "owner=$owner" -F "name=$name" -F "number=$Number" | ConvertFrom-Json -AsHashtable

    foreach ($node in @($response['data']['repository']['pullRequest']['reviewThreads']['nodes'])) {
        if ($Unresolved -and $node['isResolved']) { continue }
        $first = @($node['comments']['nodes'])[0]
        [pscustomobject]@{
            ThreadId   = $node['id']
            IsResolved = [bool] $node['isResolved']
            IsOutdated = [bool] $node['isOutdated']
            Path       = $node['path']
            Line       = $node['line']
            CommentId  = [long] $first['databaseId']
            Author     = $first['author']['login']
            Body       = $first['body']
            Comments   = @()
        }
    }
}

function Resolve-ReviewThread {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [int] $Number,
        [Parameter(Mandatory)] [string] $ThreadId,
        [Parameter(Mandatory)] [long] $CommentId,
        [Parameter(Mandatory)] [ValidateSet('ADDRESSED', 'WONT_FIX', 'INVALID')] [string] $Reason,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Evidence,
        [switch] $OwnerApproved
    )

    # Every refusal happens before anything changes on GitHub.
    if ([string]::IsNullOrWhiteSpace($Evidence)) {
        throw 'A resolution needs evidence: the fixing commits, or what disproved the finding.'
    }
    if ($Reason -eq 'WONT_FIX' -and -not $OwnerApproved) {
        throw "Won't fix leaves a valid finding unfixed, which is the owner's call: get the owner's OK, then pass -OwnerApproved."
    }
    $state = Invoke-Gh pr view $Number --repo $Repository --json state --jq .state
    if ("$state".Trim() -ne 'OPEN') {
        throw "Pull request #$Number is not open ($("$state".Trim())); put new commits on a fresh branch instead (docs/corrections-log.md)."
    }

    # The reply goes first, so a thread is never resolved without its evidence.
    $label = @{ ADDRESSED = 'addressed'; WONT_FIX = "won't fix"; INVALID = 'incorrect' }[$Reason]
    $body = "Resolution: $label. $($Evidence.Trim())"
    $reply = Invoke-Gh api -X POST "repos/$Repository/pulls/$Number/comments/$CommentId/replies" -f "body=$body" | ConvertFrom-Json -AsHashtable

    $mutation = 'mutation($id: ID!, $reason: PullRequestReviewThreadResolutionReason) { resolveReviewThread(input: {threadId: $id, resolutionReason: $reason}) { thread { isResolved } } }'
    $resolved = Invoke-Gh api graphql -f "query=$mutation" -f "id=$ThreadId" -f "reason=$Reason" | ConvertFrom-Json -AsHashtable

    [pscustomobject]@{
        ReplyUrl = $reply['html_url']
        Resolved = [bool] $resolved['data']['resolveReviewThread']['thread']['isResolved']
    }
}

Export-ModuleMember -Function Invoke-Gh, ConvertFrom-CopilotReviewBody, Get-CopilotReview, Get-ReviewThread, Resolve-ReviewThread
