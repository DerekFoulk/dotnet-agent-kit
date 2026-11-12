#Requires -Version 7.6
# A stand-in for PMD's launcher in Test-Duplication.Tests.ps1, so the check runs without Java. PMD logs to stderr; this
# logs a line there too, and one to stdout in case a CPD version prints there. It writes the report that
# KIT_FAKE_CPD_REPORT names to the --report-file it's given (or to stdout, without one), and exits with
# KIT_FAKE_CPD_EXIT.
Write-Error '[WARN] A log line PMD writes to stderr.' -ErrorAction Continue # the error stream, as a native PMD's stderr
'[INFO] A console line that must never reach the report.'
$at = [array]::IndexOf($args, '--report-file')
if ($env:KIT_FAKE_CPD_REPORT) {
    if ($at -ge 0) { Copy-Item -LiteralPath $env:KIT_FAKE_CPD_REPORT -Destination $args[$at + 1] }
    else { Get-Content -LiteralPath $env:KIT_FAKE_CPD_REPORT }
}
exit [int] $env:KIT_FAKE_CPD_EXIT
