#Requires -Version 7.6
# Tells a check whether the rule it enforces is in force (ADR-0089): a proposed rule's findings are warnings, shown on
# the pull request as GitHub annotations, and don't fail the check; an accepted rule's findings fail it. The statuses
# come from rule-status.json beside this module, which Build-AgentRules.ps1 writes from docs/standards. JSON, since the
# shared CI that runs the checks has no YAML module. In an app's CI the kit's own copy is read, so the kit version
# the app pins decides whether a rule is in force.

Set-StrictMode -Version Latest

# Generated beside the module: tools/ in the kit, .kit/tools/ in an app.
$script:DefaultPath = Join-Path $PSScriptRoot 'rule-status.json'

$script:Statuses = 'proposed', 'accepted', 'retired'

# A rule's status: proposed, accepted or retired. An id the file doesn't list throws, so a typo in a check can't turn
# its gate into warnings, and so does a status the kit doesn't know.
function Get-RuleStatus {
    [OutputType([string])]
    param([Parameter(Mandatory)] [string] $Id, [string] $Path)

    if (-not $Path) { $Path = $script:DefaultPath }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "The rule statuses file $Path doesn't exist, so no check can tell whether its rule is in force. Run Build-AgentRules.ps1."
    }
    $text = Get-Content -Raw -LiteralPath $Path
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "The rule statuses file $Path is empty, so no check can tell whether its rule is in force. Run Build-AgentRules.ps1."
    }
    $statuses = $text | ConvertFrom-Json
    $entry = $statuses.PSObject.Properties | Where-Object { $_.Name -ceq $Id }
    if (-not $entry) {
        throw "Rule $Id isn't in $Path, so its check can't tell whether it's in force. Check the id, or run Build-AgentRules.ps1."
    }
    $status = "$($entry.Value)"
    if ($status -cnotin $script:Statuses) {
        throw "Rule $Id has the status '$status' in $Path, which isn't one of $($script:Statuses -join ', ')."
    }
    $status
}

# Writes one finding of rule Id and returns whether it counts toward the check's failure; the rule's status alone
# decides. A proposed rule's finding is a GitHub warning annotation ("::warning::<id>: <message>", or
# "::warning file=<file>,line=<line>,col=<column>::<id>: <message>" when its place is given), which the pull
# request shows without failing, and doesn't count. An accepted rule's finding is written as it is, in red, as the
# checks wrote their errors before, and counts: an MSBuild-format line stays readable by setup-dotnet's problem
# matcher. A retired rule isn't in force and its check should be gone, so a finding for it throws. -File, -Line and
# -Column name the finding's place in the warning, so the pull request shows it on that line of the diff; GitHub's
# warning command takes them as file, line and col:
#   https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands  retrieved 2026-11-18
function Write-RuleFinding {
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string] $Id, [Parameter(Mandatory)] [string] $Message, [string] $Path, [string] $File, [int] $Line, [int] $Column)

    $status = Get-RuleStatus -Id $Id -Path $Path
    if ($status -ceq 'proposed') {
        # GitHub ends a workflow command at the line's end, and decodes these three in its message; a property also
        # ends at a comma, and its name at a colon, so those are escaped in one too, as @actions/core does.
        $data = $Message.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A')
        $place = @(
            if ($File) { 'file=' + $File.Replace('%', '%25').Replace("`r", '%0D').Replace("`n", '%0A').Replace(':', '%3A').Replace(',', '%2C') }
            if ($Line -gt 0) { "line=$Line" }
            if ($Column -gt 0) { "col=$Column" }
        )
        $properties = if ($place) { ' ' + ($place -join ',') } else { '' }
        Write-Host "::warning${properties}::${Id}: $data"
        return $false
    }
    if ($status -ceq 'accepted') {
        Write-Host $Message -ForegroundColor Red
        return $true
    }
    throw "Rule $Id is $status, so it isn't in force and no check should report it; take its check out."
}

Export-ModuleMember -Function Get-RuleStatus, Write-RuleFinding
