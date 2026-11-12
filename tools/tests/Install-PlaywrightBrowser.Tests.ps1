#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Install-PlaywrightBrowser.ps1 installs the browser an app's Playwright tests need, in the shared CI, before the tests
# run (GAP-004, ADR-0061). It asks MSBuild where each project's restore graph and build output are, and runs the
# playwright.ps1 the Microsoft.Playwright package puts beside a test assembly, as Playwright's CI guide does. The
# projects here are evaluated by MSBuild but never restored or built: each test writes the assets file and the
# playwright.ps1 a restore and a build would leave, and the fake script records the arguments it was run with.

Describe 'Install-PlaywrightBrowser.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Install-PlaywrightBrowser.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }

        # A project at src/<Name>/<Name>.csproj. With -Libraries, its restore graph (obj/project.assets.json) holds those
        # packages; with -Built, its output in -Configuration holds a playwright.ps1 that appends its arguments to
        # calls.txt (and exits with -ExitCode).
        function New-Project([string] $Repo, [string] $Name, [string[]] $Libraries = @(), [switch] $Built, [string] $Configuration = 'Release', [int] $ExitCode = 0) {
            $folder = Join-Path $Repo "src/$Name"
            New-Item -ItemType Directory -Force -Path (Join-Path $folder 'obj') | Out-Null
            '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>' |
                Set-Content -LiteralPath (Join-Path $folder "$Name.csproj")
            $assets = [ordered]@{ version = 3; libraries = [ordered]@{} }
            foreach ($library in $Libraries) { $assets.libraries[$library] = @{ type = 'package' } }
            $assets | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'obj/project.assets.json')
            if ($Built) {
                $out = Join-Path $folder "bin/$Configuration/net10.0"
                New-Item -ItemType Directory -Force -Path $out | Out-Null
                "Add-Content -LiteralPath '$(Join-Path $Repo 'calls.txt')' -Value `"$Name`: `$(`$args -join ' ')`"; exit $ExitCode" |
                    Set-Content -LiteralPath (Join-Path $out 'playwright.ps1')
            }
        }

        function New-Solution([string] $Repo, [string[]] $Names) {
            $entries = $Names | ForEach-Object { "<Project Path=`"src/$_/$_.csproj`" />" }
            "<Solution>$($entries -join '')</Solution>" | Set-Content -LiteralPath (Join-Path $Repo 'App.slnx')
            Join-Path $Repo 'App.slnx'
        }

        function Get-Call([string] $Repo) {
            $calls = Join-Path $Repo 'calls.txt'
            if (Test-Path -LiteralPath $calls) { @(Get-Content -LiteralPath $calls) } else { @() }
        }
    }

    It 'installs nothing, and says so, when no project uses Playwright' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'none'
        New-Project $repo 'Api' -Libraries 'xunit.v3/4.0.3' -Built
        $solution = New-Solution $repo 'Api'

        $output = Install-PlaywrightBrowser -Solution $solution -Configuration Release *>&1 | Out-String

        Get-Call $repo | Should -BeNullOrEmpty
        $output | Should -Match 'No project uses Playwright'
    }

    It 'runs "install chromium" with the playwright.ps1 the build put beside a Playwright project''s assembly' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'one'
        New-Project $repo 'Api' -Libraries 'xunit.v3/4.0.3' -Built
        New-Project $repo 'App.E2E.Tests' -Libraries 'Deque.AxeCore.Playwright/4.14.0', 'Microsoft.Playwright/1.64.1' -Built
        $solution = New-Solution $repo 'Api', 'App.E2E.Tests'

        Install-PlaywrightBrowser -Solution $solution -Configuration Release *> $null

        Get-Call $repo | Should -Be @('App.E2E.Tests: install chromium')
    }

    # Linux needs the browser's system libraries too; Playwright's --with-deps installs them (as root, through apt).
    It 'adds --with-deps with -WithDependencies, as CI asks on Linux' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'deps'
        New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Built
        $solution = New-Solution $repo 'App.E2E.Tests'

        Install-PlaywrightBrowser -Solution $solution -Configuration Release -WithDependencies *> $null

        Get-Call $repo | Should -Be @('App.E2E.Tests: install --with-deps chromium')
    }

    # Each Playwright version pins its own browser build, so one install per version is enough; central package
    # management keeps every project on one version.
    It 'installs once for two projects on the same Playwright version, and once more for another version' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'versions'
        New-Project $repo 'A.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Built
        New-Project $repo 'B.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Built
        New-Project $repo 'C.E2E.Tests' -Libraries 'Microsoft.Playwright/1.63.0' -Built
        $solution = New-Solution $repo 'A.E2E.Tests', 'B.E2E.Tests', 'C.E2E.Tests'

        Install-PlaywrightBrowser -Solution $solution -Configuration Release *> $null

        Get-Call $repo | Should -Be @('A.E2E.Tests: install chromium', 'C.E2E.Tests: install chromium')
    }

    # Without the build there's no playwright.ps1, so the browser can't be installed: say what to do, don't skip it.
    It 'fails, naming the project and the configuration, when a Playwright project isn''t built' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'unbuilt'
        New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
        $solution = New-Solution $repo 'App.E2E.Tests'

        { Install-PlaywrightBrowser -Solution $solution -Configuration Release *> $null } |
            Should -Throw '*App.E2E.Tests*Release*'
    }

    # A local dotnet test builds Debug; CI builds Release.
    It 'finds the build of the configuration it''s given' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'debug'
        New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Built -Configuration Debug
        $solution = New-Solution $repo 'App.E2E.Tests'

        Install-PlaywrightBrowser -Solution $solution -Configuration Debug *> $null

        Get-Call $repo | Should -Be @('App.E2E.Tests: install chromium')
    }

    # A failed download must stop CI here, not as a puzzling browser error in the tests.
    It 'fails, with the installer''s exit code, when the install fails' {
        Get-Command Install-PlaywrightBrowser -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $repo = Join-Path $TestDrive 'failing'
        New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Built -ExitCode 3
        $solution = New-Solution $repo 'App.E2E.Tests'

        { Install-PlaywrightBrowser -Solution $solution -Configuration Release *> $null } |
            Should -Throw '*exit code 3*'
    }
}
