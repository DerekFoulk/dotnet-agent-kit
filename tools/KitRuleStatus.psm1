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
    $statuses = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
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

Export-ModuleMember -Function Get-RuleStatus
