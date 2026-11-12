#Requires -Version 7.6
# A stand-in for PMD's launcher in Test-Duplication.Tests.ps1, so the check runs without Java: it writes the report
# that KIT_FAKE_CPD_REPORT names to the --report-file it's given (or to its output, without one), and exits with
# KIT_FAKE_CPD_EXIT.
$at = [array]::IndexOf($args, '--report-file')
if ($env:KIT_FAKE_CPD_REPORT) {
    if ($at -ge 0) { Copy-Item -LiteralPath $env:KIT_FAKE_CPD_REPORT -Destination $args[$at + 1] }
    else { Get-Content -LiteralPath $env:KIT_FAKE_CPD_REPORT }
}
exit [int] $env:KIT_FAKE_CPD_EXIT
