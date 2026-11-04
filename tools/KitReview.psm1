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

    $reviews = @(Get-PullRequestReview -Repository $Repository -Number $Number)
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
# - each summary issue with no thread (Thread is $null), until the signed-in account resolves it for that review;
# - each person's latest review that requests changes or has a body (Thread is $null), likewise;
# - each other unresolved thread, such as a person's comment or an older Copilot finding.
# Copilot's summary can lag behind its threads, so a summary issue whose thread is resolved is left out.
# Each finding has Severity, Title, Author, Body, ReviewId and Thread; answer it with Resolve-ReviewFinding.
function Get-OpenFinding {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $threads = @(Get-ReviewThread -Repository $Repository -Number $Number)
    $byComment = @{}
    foreach ($thread in $threads) { if ($null -ne $thread.CommentId) { $byComment[[long] $thread.CommentId] = $thread } }
    $listed = [System.Collections.Generic.HashSet[string]]::new()

    # A finding with no thread is answered once the signed-in account (the one agents post with) posts a
    # final resolution for it and for that review: see Resolve-ReviewFinding.
    $cache = @{ Answers = $null }
    $isAnswered = {
        param($ReviewId, $Title)
        if ($null -eq $cache.Answers) {
            $self = Get-SignedInLogin
            $cache.Answers = @(Get-PullRequestComment -Repository $Repository -Number $Number |
                    Where-Object { $_.Author -eq $self } | ForEach-Object { "$($_.Body)" })
        }
        $prefix = Get-AnswerPrefix -ReviewId $ReviewId -Title $Title
        [bool] @($cache.Answers | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }).Count
    }

    $review = Get-CopilotReview -Repository $Repository -Number $Number
    $issues = if ($review) { @($review.Issues) } else { @() }
    foreach ($issue in $issues) {
        $thread = if ($null -ne $issue.CommentId) { $byComment[[long] $issue.CommentId] } else { $null }
        if ($thread) {
            [void] $listed.Add($thread.ThreadId)
            if ($thread.IsResolved) { continue }
        }
        elseif (& $isAnswered $review.ReviewId $issue.Title) { continue }
        [pscustomobject]@{
            Severity = $issue.Severity
            Title    = $issue.Title
            Author   = if ($thread) { $thread.Author } else { $script:CopilotGraphQLLogin }
            Body     = if ($thread) { $thread.Body } else { $null }
            ReviewId = $review.ReviewId
            Thread   = $thread
        }
    }

    # People's review bodies. The signed-in account's own reviews are left out: agents post with it,
    # and the owner's decisions come in chat.
    $self = $null
    $latest = @(Get-PullRequestReview -Repository $Repository -Number $Number) |
        Where-Object { $_['user'] -and $_['user']['login'] -ne $script:CopilotLogin } |
        Group-Object { $_['user']['login'] } |
        ForEach-Object { $_.Group | Sort-Object { [datetimeoffset] $_['submitted_at'] } | Select-Object -Last 1 }
    foreach ($personReview in @($latest)) {
        $login = $personReview['user']['login']
        $body = "$($personReview['body'])".Trim()
        $asks = $personReview['state'] -eq 'CHANGES_REQUESTED' -or ($personReview['state'] -eq 'COMMENTED' -and $body)
        if (-not $asks) { continue }
        if ($null -eq $self) { $self = Get-SignedInLogin }
        if ($login -eq $self) { continue }
        $title = "Review by $login"
        if (& $isAnswered $personReview['id'] $title) { continue }
        [pscustomobject]@{
            Severity = $null
            Title    = $title
            Author   = $login
            Body     = $body
            ReviewId = $personReview['id']
            Thread   = $null
        }
    }

    foreach ($thread in $threads) {
        # A thread with no comments has nothing to reply to, so it can't be answered here.
        if ($thread.IsResolved -or $listed.Contains($thread.ThreadId) -or $null -eq $thread.CommentId) { continue }
        [pscustomobject]@{
            Severity = $null
            Title    = $null
            Author   = $thread.Author
            Body     = $thread.Body
            ReviewId = $null
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

    # ValidateSet ignores case, but GitHub's enum doesn't.
    $Reason = $Reason.ToUpperInvariant()

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

# Posts a reply without resolving anything: in -Thread when given, otherwise as a pull request comment.
# Use it to leave a finding open with a recommendation for the owner, or to answer a question. It never
# marks a finding as answered; Resolve-ReviewFinding does that.
function Add-ReviewReply {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [int] $Number,
        [AllowNull()] [psobject] $Thread,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Body
    )

    # An empty -Thread (a finding with no thread) means a PR comment; any other thread needs a comment to reply to.
    if ($Thread -and -not ($Thread.PSObject.Properties['CommentId'] -and $Thread.CommentId)) {
        throw 'Pass a thread from Get-ReviewThread or Get-OpenFinding, or no -Thread for a pull request comment.'
    }
    if ([string]::IsNullOrWhiteSpace($Body)) {
        throw 'The reply is empty.'
    }
    Assert-PullRequestOpen -Repository $Repository -Number $Number

    $endpoint = if ($Thread) { "repos/$Repository/pulls/$Number/comments/$($Thread.CommentId)/replies" } else { "repos/$Repository/issues/$Number/comments" }
    $posted = Invoke-Gh api -X POST $endpoint -f "body=$($Body.Trim())" | ConvertFrom-Json -AsHashtable
    [pscustomobject]@{ Url = $posted['html_url'] }
}

# Answers any finding from Get-OpenFinding with a final resolution. A finding with a thread gets a
# reply and a resolved thread (Resolve-ReviewThread). One without a thread gets a PR comment starting
# 'Answer to review <id>, "<title>": Resolution: ...', which is how Get-OpenFinding knows it's answered.
function Resolve-ReviewFinding {
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [int] $Number,
        [Parameter(Mandatory)] [psobject] $Finding,
        [Parameter(Mandatory)] [ValidateSet('ADDRESSED', 'WONT_FIX', 'INVALID')] [string] $Reason,
        [Parameter(Mandatory)] [AllowEmptyString()] [string] $Evidence,
        [switch] $OwnerApproved
    )

    if ($Finding.Thread) {
        return Resolve-ReviewThread -Repository $Repository -Number $Number -Thread $Finding.Thread -Reason $Reason -Evidence $Evidence -OwnerApproved:$OwnerApproved
    }

    # Every refusal happens before anything changes on GitHub.
    $Reason = $Reason.ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($Evidence)) {
        throw 'A resolution needs evidence: the fixing commits, or what disproved the finding.'
    }
    if ($Reason -eq 'WONT_FIX' -and -not $OwnerApproved) {
        throw "Won't fix leaves a valid finding unfixed, which is the owner's call: get the owner's OK, then pass -OwnerApproved."
    }
    if (-not $Finding.ReviewId -or -not $Finding.Title) {
        throw 'A finding without a thread needs its ReviewId and Title: pass a finding from Get-OpenFinding.'
    }
    Assert-PullRequestOpen -Repository $Repository -Number $Number

    $label = @{ ADDRESSED = 'addressed'; WONT_FIX = "won't fix"; INVALID = 'incorrect' }[$Reason]
    $body = "$(Get-AnswerPrefix -ReviewId $Finding.ReviewId -Title $Finding.Title)$label. $($Evidence.Trim())"
    $posted = Invoke-Gh api -X POST "repos/$Repository/issues/$Number/comments" -f "body=$body" | ConvertFrom-Json -AsHashtable
    [pscustomobject]@{ ReplyUrl = $posted['html_url']; Resolved = $true }
}

# Every comment in the pull request's conversation (not the review threads), with its author.
function Get-PullRequestComment {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    foreach ($comment in @(Get-GhList -Endpoint "repos/$Repository/issues/$Number/comments")) {
        [pscustomobject]@{ Author = Get-AuthorLogin $comment['user']; Body = "$($comment['body'])" }
    }
}

# Every review on the pull request, as GitHub's REST API returns it.
function Get-PullRequestReview {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)
    Get-GhList -Endpoint "repos/$Repository/pulls/$Number/reviews"
}

# The GitHub account gh is signed in with: the one agents post with, whoever opened the pull request.
function Get-SignedInLogin {
    "$(Invoke-Gh api user --jq .login)".Trim()
}

# How a PR comment names the finding it resolves: its review, its title, and that it's final.
function Get-AnswerPrefix {
    param([Parameter(Mandatory)] $ReviewId, [Parameter(Mandatory)] [string] $Title)
    "Answer to review $ReviewId, `"$Title`": Resolution: "
}

# Every item of a paginated REST list. --jq '.[]' prints one item per line whatever the gh version;
# older versions print one JSON array per page, which doesn't parse as a whole.
function Get-GhList {
    param([Parameter(Mandatory)] [string] $Endpoint)

    foreach ($line in ((Invoke-Gh api --paginate $Endpoint --jq '.[]') -split "`r?`n")) {
        if ($line.Trim()) { $line | ConvertFrom-Json -AsHashtable }
    }
}

# Writing to a merged or closed pull request helps no one; new commits belong on a fresh branch.
function Assert-PullRequestOpen {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)

    $state = "$(Invoke-Gh pr view $Number --repo $Repository --json state --jq .state)".Trim()
    if ($state -ne 'OPEN') {
        throw "Pull request #$Number is not open ($state); put new commits on a fresh branch instead (docs/corrections-log.md)."
    }
}

Export-ModuleMember -Function ConvertFrom-CopilotReviewBody, Get-CopilotReview, Get-ReviewThread, Get-OpenFinding, Resolve-ReviewFinding, Resolve-ReviewThread, Add-ReviewReply
