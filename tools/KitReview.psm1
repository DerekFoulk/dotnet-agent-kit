#Requires -Version 7.0
# Reads Copilot code reviews and resolves review threads on GitHub pull requests (ADR-0028).
# Every GitHub call goes through Invoke-Gh, the one place the tests replace. It isn't exported:
# callers use the functions below, not a raw gh passthrough.

Set-StrictMode -Version Latest

# Copilot's login: REST adds [bot], GraphQL doesn't.
$script:CopilotLogin = 'copilot-pull-request-reviewer[bot]'
$script:CopilotGraphQLLogin = 'copilot-pull-request-reviewer'

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
            $text = ($line -replace '^- ', '' -replace '(?s)<picture>.*?</picture>', '' -replace '\s+·\s+[^·()\[\]]*$', '').Trim()
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
# Commit is the commit Copilot reviewed, which can be behind the branch head.
function Get-CopilotReview {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $reviews = Invoke-Gh api --paginate "repos/$Repository/pulls/$Number/reviews" | ConvertFrom-Json -AsHashtable
    $latest = @($reviews | Where-Object { $_['user'] -and $_['user']['login'] -eq $script:CopilotLogin }) |
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

# GitHub returns a null author for a deleted account.
function Get-AuthorLogin {
    param($Author)
    if ($null -eq $Author) { '(deleted account)' } else { $Author['login'] }
}

# The pull request's review threads, each with every comment: the first is the finding, the rest are
# replies (an owner's "keep this" included). Refuses to return a partial list past 100 threads.
function Get-ReviewThread {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number, [switch] $Unresolved)

    $owner, $name = $Repository -split '/', 2
    $query = 'query($owner: String!, $name: String!, $number: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $number) { reviewThreads(first: 100) { pageInfo { hasNextPage } nodes { id isResolved isOutdated path line comments(first: 100) { pageInfo { hasNextPage } nodes { databaseId author { login } body } } } } } } }'
    # -f sends a string; -F would turn a repository named "2048" into a number. The PR number is an Int.
    $response = Invoke-Gh api graphql -f "query=$query" -f "owner=$owner" -f "name=$name" -F "number=$Number" | ConvertFrom-Json -AsHashtable

    $pullRequest = $response['data']['repository']['pullRequest']
    if ($null -eq $pullRequest) {
        throw "Pull request #$Number not found in $Repository."
    }
    $threads = $pullRequest['reviewThreads']
    if ($threads.ContainsKey('pageInfo') -and $threads['pageInfo'] -and $threads['pageInfo']['hasNextPage']) {
        throw "Pull request #$Number has more than 100 review threads; this module reads at most 100, so it won't return a partial list."
    }

    foreach ($node in @($threads['nodes'])) {
        if ($Unresolved -and $node['isResolved']) { continue }
        $page = $node['comments']['pageInfo']
        if ($page -and $page['hasNextPage']) {
            throw "Thread $($node['id']) has more than 100 comments; this module reads at most 100, so it won't return a partial thread."
        }
        $comments = @(foreach ($comment in @($node['comments']['nodes'])) {
                [pscustomobject]@{
                    CommentId = [long] $comment['databaseId']
                    Author    = Get-AuthorLogin $comment['author']
                    Body      = $comment['body']
                }
            })
        # A thread whose only comment was deleted has none; it has nothing to reply to.
        $first = if ($comments.Count) { $comments[0] } else { [pscustomobject]@{ CommentId = $null; Author = $null; Body = $null } }
        [pscustomobject]@{
            ThreadId   = $node['id']
            IsResolved = [bool] $node['isResolved']
            IsOutdated = [bool] $node['isOutdated']
            Path       = $node['path']
            Line       = $node['line']
            CommentId  = $first.CommentId
            Author     = $first.Author
            Body       = $first.Body
            Comments   = $comments
        }
    }
}

# Everything on the pull request still waiting for an answer, in this order:
# - each issue in Copilot's latest summary whose thread is unresolved;
# - each summary issue with no thread (Thread is $null): answer it in a PR comment;
# - each other unresolved thread, such as a person's comment or an older Copilot finding.
# Copilot's summary can lag behind its threads, so a summary issue whose thread is resolved is left out.
function Get-OpenFinding {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $threads = @(Get-ReviewThread -Repository $Repository -Number $Number)
    $byComment = @{}
    foreach ($thread in $threads) { $byComment[[long] $thread.CommentId] = $thread }
    $listed = [System.Collections.Generic.HashSet[string]]::new()

    $review = Get-CopilotReview -Repository $Repository -Number $Number
    $issues = if ($review) { @($review.Issues) } else { @() }
    $prComments = $null
    foreach ($issue in $issues) {
        $thread = if ($null -ne $issue.CommentId) { $byComment[[long] $issue.CommentId] } else { $null }
        if ($thread) {
            [void] $listed.Add($thread.ThreadId)
            if ($thread.IsResolved) { continue }
        }
        else {
            # No thread to resolve: it's answered once a PR comment names it (Add-ReviewReply -IssueTitle).
            if ($null -eq $prComments) { $prComments = @(Get-PullRequestCommentBody -Repository $Repository -Number $Number) }
            $prefix = Get-SummaryAnswerPrefix -Title $issue.Title
            if (@($prComments | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }).Count) { continue }
        }
        [pscustomobject]@{
            Severity = $issue.Severity
            Title    = $issue.Title
            Author   = if ($thread) { $thread.Author } else { $script:CopilotGraphQLLogin }
            Body     = if ($thread) { $thread.Body } else { $null }
            Thread   = $thread
        }
    }

    foreach ($thread in $threads) {
        if ($thread.IsResolved -or $listed.Contains($thread.ThreadId)) { continue }
        [pscustomobject]@{
            Severity = $null
            Title    = $null
            Author   = $thread.Author
            Body     = $thread.Body
            Thread   = $thread
        }
    }
}

# Replies to a thread with the evidence, then resolves it. -Thread is an object from Get-ReviewThread
# (or a finding's .Thread from Get-OpenFinding), so the thread and the comment replied to always match.
function Resolve-ReviewThread {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [int] $Number,
        [Parameter(Mandatory)] [ValidateScript({ $_.ThreadId -and $_.CommentId }, ErrorMessage = 'Pass a thread from Get-ReviewThread or Get-OpenFinding.')] [psobject] $Thread,
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
    if ($Thread.IsResolved) {
        throw "Thread $($Thread.ThreadId) is already resolved; read the threads again with Get-OpenFinding."
    }
    Assert-PullRequestOpen -Repository $Repository -Number $Number

    # The reply goes first, so a thread is never resolved without its evidence.
    $label = @{ ADDRESSED = 'addressed'; WONT_FIX = "won't fix"; INVALID = 'incorrect' }[$Reason]
    $body = "Resolution: $label. $($Evidence.Trim())"
    $reply = Invoke-Gh api -X POST "repos/$Repository/pulls/$Number/comments/$($Thread.CommentId)/replies" -f "body=$body" | ConvertFrom-Json -AsHashtable

    $mutation = 'mutation($id: ID!, $reason: PullRequestReviewThreadResolutionReason) { resolveReviewThread(input: {threadId: $id, resolutionReason: $reason}) { thread { isResolved } } }'
    $resolved = Invoke-Gh api graphql -f "query=$mutation" -f "id=$($Thread.ThreadId)" -f "reason=$Reason" | ConvertFrom-Json -AsHashtable

    [pscustomobject]@{
        ReplyUrl = $reply['html_url']
        Resolved = [bool] $resolved['data']['resolveReviewThread']['thread']['isResolved']
    }
}

# Posts a reply without resolving anything: in -Thread when given, otherwise as a pull request comment
# (for a summary issue that has no thread). Use it to leave a finding open with a recommendation for the
# owner, or to answer a question.
function Add-ReviewReply {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [int] $Number,
        [AllowNull()] [psobject] $Thread,
        [string] $IssueTitle,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body
    )

    # An empty -Thread (a finding with no thread) means a PR comment; any other thread needs a comment to reply to.
    if ($Thread -and -not ($Thread.PSObject.Properties['CommentId'] -and $Thread.CommentId)) {
        throw 'Pass a thread from Get-ReviewThread or Get-OpenFinding, or no -Thread for a pull request comment.'
    }
    if ($Thread -and $IssueTitle) {
        throw '-IssueTitle is for a summary issue with no thread; a reply in a thread already points at its finding.'
    }
    if ([string]::IsNullOrWhiteSpace($Body)) {
        throw 'The reply is empty.'
    }
    Assert-PullRequestOpen -Repository $Repository -Number $Number

    $text = $Body.Trim()
    if ($IssueTitle) { $text = "$(Get-SummaryAnswerPrefix -Title $IssueTitle) $text" }
    $endpoint = if ($Thread) { "repos/$Repository/pulls/$Number/comments/$($Thread.CommentId)/replies" } else { "repos/$Repository/issues/$Number/comments" }
    $posted = Invoke-Gh api -X POST $endpoint -f "body=$text" | ConvertFrom-Json -AsHashtable
    [pscustomobject]@{ Url = $posted['html_url'] }
}

# The text of every comment in the pull request's conversation (not the review threads).
function Get-PullRequestCommentBody {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $comments = Invoke-Gh api --paginate "repos/$Repository/issues/$Number/comments" | ConvertFrom-Json -AsHashtable
    foreach ($comment in @($comments)) { "$($comment['body'])" }
}

# How a PR comment names the summary issue it answers, so Get-OpenFinding can tell it was answered.
function Get-SummaryAnswerPrefix {
    param([Parameter(Mandatory)] [string] $Title)
    "Copilot summary issue `"$Title`":"
}

# Writing to a merged or closed pull request helps no one; new commits belong on a fresh branch.
function Assert-PullRequestOpen {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $state = "$(Invoke-Gh pr view $Number --repo $Repository --json state --jq .state)".Trim()
    if ($state -ne 'OPEN') {
        throw "Pull request #$Number is not open ($state); put new commits on a fresh branch instead (docs/corrections-log.md)."
    }
}

Export-ModuleMember -Function ConvertFrom-CopilotReviewBody, Get-CopilotReview, Get-ReviewThread, Get-OpenFinding, Resolve-ReviewThread, Add-ReviewReply
