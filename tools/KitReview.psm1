#Requires -Version 7.0
# Reads Copilot code reviews and resolves review threads on GitHub pull requests (ADR-0028).

Set-StrictMode -Version Latest

function Invoke-Gh {
    gh @args
}

function ConvertFrom-CopilotReviewBody {
    param([Parameter(Mandatory)] [AllowEmptyString()] [string] $Body)
    [pscustomobject]@{ Verdict = $null; OpenIssueCount = -1; Issues = @() }
}

function Get-CopilotReview {
    param([Parameter(Mandatory)] [string] $Repository, [Parameter(Mandatory)] [int] $Number)
    [pscustomobject]@{ ReviewId = $null; Commit = $null; Verdict = $null; OpenIssueCount = -1 }
}

Export-ModuleMember -Function Invoke-Gh, ConvertFrom-CopilotReviewBody, Get-CopilotReview
