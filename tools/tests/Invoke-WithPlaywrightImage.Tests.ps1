#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# Invoke-WithPlaywrightImage.ps1 runs a command (the shared CI's tests, the mutation run's Stryker) inside Microsoft's
# Playwright .NET image, pinned by tag and digest, when the solution has Playwright tests, so the browser they drive is
# the one the digest names, never an unchecked download (GAP-033, ADR-0061). Without Playwright tests it runs the
# command on the runner, as before. The projects here are evaluated by MSBuild but never restored: each test writes the
# restore graph a restore would leave. docker is mocked: these tests check what the script asks of it.

Describe 'Invoke-WithPlaywrightImage.ps1' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..' 'Invoke-WithPlaywrightImage.ps1'
        if (Test-Path $scriptPath) { . $scriptPath }
        $digest = 'sha256:' + ('a' * 64)

        # A project at src/<Name>/<Name>.csproj whose restore graph (obj/project.assets.json) holds -Libraries.
        function New-Project([string] $Repo, [string] $Name, [string[]] $Libraries = @(), [string] $Frameworks) {
            $folder = Join-Path $Repo "src/$Name"
            New-Item -ItemType Directory -Force -Path (Join-Path $folder 'obj') | Out-Null
            $target = if ($Frameworks) { "<TargetFrameworks>$Frameworks</TargetFrameworks>" } else { '<TargetFramework>net10.0</TargetFramework>' }
            "<Project Sdk=`"Microsoft.NET.Sdk`"><PropertyGroup>$target</PropertyGroup></Project>" |
                Set-Content -LiteralPath (Join-Path $folder "$Name.csproj")
            $assets = [ordered]@{ version = 3; libraries = [ordered]@{} }
            foreach ($library in $Libraries) { $assets.libraries[$library] = @{ type = 'package' } }
            $assets | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $folder 'obj/project.assets.json')
        }

        function New-Solution([string] $Repo, [string[]] $Names) {
            $entries = $Names | ForEach-Object { "<Project Path=`"src/$_/$_.csproj`" />" }
            "<Solution>$($entries -join '')</Solution>" | Set-Content -LiteralPath (Join-Path $Repo 'App.slnx')
            Join-Path $Repo 'App.slnx'
        }

        function New-Pin([string] $Repo, [string] $Text) {
            $path = Join-Path $Repo '.config/playwright/Dockerfile'
            New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
            Set-Content -LiteralPath $path -Value $Text
            $path
        }

        # A command for the runner that leaves a file behind and exits with -ExitCode.
        function New-HostCommand([string] $Repo, [int] $ExitCode = 0) {
            $marker = Join-Path $Repo 'ran.txt'
            , @('pwsh', '-NoProfile', '-Command', "Set-Content -LiteralPath '$marker' -Value ran; exit $ExitCode")
        }
    }

    Context 'a solution without Playwright tests' {
        It 'runs the command on the runner, says so, and keeps its exit code' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'none'
            New-Project $repo 'Api' -Libraries 'xunit.v3/4.0.3'
            $solution = New-Solution $repo 'Api'
            Mock docker { }

            $output = Invoke-WithPlaywrightImage -Solution $solution -Pin (Join-Path $repo 'missing/Dockerfile') -Command (New-HostCommand $repo -ExitCode 3) *>&1 | Out-String

            $LASTEXITCODE | Should -Be 3
            Test-Path -LiteralPath (Join-Path $repo 'ran.txt') | Should -BeTrue
            $output | Should -Match 'No project uses Playwright'
            Should -Invoke docker -Times 0
        }
    }

    Context 'a solution with Playwright tests' {
        BeforeAll {
            # The runner's user and Docker group come from id and stat, on Linux only; the tests run anywhere.
            if (Get-Command Get-RunnerIdentity -ErrorAction SilentlyContinue) {
                Mock Get-RunnerIdentity { [pscustomobject]@{ User = '1001:1002'; DockerSocketGroup = '118' } }
            }
        }

        BeforeEach {
            $env:DOTNET_ROOT = '/usr/share/dotnet'
        }

        AfterEach {
            Remove-Item Env:DOTNET_ROOT -ErrorAction SilentlyContinue
        }

        It 'runs the command in the image the pin names, by tag and digest, and keeps docker''s exit code' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'pinned'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Deque.AxeCore.Playwright/4.14.0', 'Microsoft.Playwright/1.64.1'
            $solution = New-Solution $repo 'App.E2E.Tests'
            $pin = New-Pin $repo "# The image.`nFROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { $script:dockerArguments = $args; $global:LASTEXITCODE = 4 }

            Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test', '--no-build' *> $null

            $LASTEXITCODE | Should -Be 4
            $image = "mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            $script:dockerArguments[0] | Should -Be 'run'
            $at = [array]::IndexOf([string[]] $script:dockerArguments, $image)
            $at | Should -BeGreaterThan 0 -Because 'docker runs the pinned image'
            $script:dockerArguments[($at + 5)..($script:dockerArguments.Count - 1)] | Should -Be @('dotnet', 'test', '--no-build')
        }

        # Playwright finds only its own version's browsers in the image, so a pin for another version fails here, with
        # both versions named, rather than as "Executable doesn't exist" in every browser test.
        It 'fails, naming both versions, when the pin is for another Playwright version than the projects use' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'mismatch'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.65.0'
            $solution = New-Solution $repo 'App.E2E.Tests'
            $pin = New-Pin $repo "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null } | Should -Throw '*1.65.0*1.64.1*'
            Should -Invoke docker -Times 0
        }

        It 'fails, naming the pin''s path, when a Playwright project has no pin' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'unpinned'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
            $solution = New-Solution $repo 'App.E2E.Tests'
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin (Join-Path $repo '.config/playwright/Dockerfile') -Command 'dotnet', 'test' *> $null } |
                Should -Throw '*App.E2E.Tests*1.64.1*.config*playwright*Dockerfile*'
        }

        # A tag alone can be moved to other content; only a digest names one image. Another image would hold other
        # browsers, or none.
        It 'refuses a pin that <Case>' -ForEach @(
            @{ Case = 'has no digest'; Text = 'FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble' }
            @{ Case = 'has no tag'; Text = "FROM mcr.microsoft.com/playwright/dotnet@$digest" }
            @{ Case = 'names another image'; Text = "FROM mcr.microsoft.com/playwright:v1.64.1-noble@$digest" }
            @{ Case = 'has two FROM lines'; Text = "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest`nFROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest" }
        ) {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive "bad-$(New-Guid)"
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
            $solution = New-Solution $repo 'App.E2E.Tests'
            $pin = New-Pin $repo $Text
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null } | Should -Throw '*FROM*tag and digest*'
            Should -Invoke docker -Times 0
        }

        # One image holds one Playwright version's browsers. Central package management keeps every project on one
        # version; the check is for a repo that overrides it. The version is Microsoft.Playwright's own, not that of a
        # package named like it, such as Playwright's MSTest adapter.
        It 'fails, naming both versions, when two projects use different Playwright versions' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'two'
            New-Project $repo 'A.E2E.Tests' -Libraries 'Microsoft.Playwright.MSTest/1.63.0', 'Microsoft.Playwright/1.64.1'
            New-Project $repo 'B.E2E.Tests' -Libraries 'Microsoft.Playwright/1.63.0'
            $solution = New-Solution $repo 'A.E2E.Tests', 'B.E2E.Tests'
            $pin = New-Pin $repo "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null } | Should -Throw '*1.63.0*1.64.1*'
        }

        # The image's own .NET SDK is the 10.0.1xx band of its base image, which can't match a global.json pin such
        # as 10.0.403, so the container runs the SDK actions/setup-dotnet installed on the runner, which sets DOTNET_ROOT.
        It 'fails, saying what sets it, when DOTNET_ROOT isn''t set' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Remove-Item Env:DOTNET_ROOT
            $repo = Join-Path $TestDrive 'no-root'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
            $solution = New-Solution $repo 'App.E2E.Tests'
            $pin = New-Pin $repo "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null } | Should -Throw '*DOTNET_ROOT*setup-dotnet*'
        }

        It 'reads a multi-targeted Playwright project' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'multi'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1' -Frameworks 'net10.0;net9.0'
            $solution = New-Solution $repo 'App.E2E.Tests'
            $pin = New-Pin $repo "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { $global:LASTEXITCODE = 0 }

            Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null

            Should -Invoke docker -Times 1
        }

        # Linux has no MAUI workload, so MSBuild can't evaluate a MAUI project there (ADR-0059). This one would fail to
        # evaluate anywhere: it imports a file that isn't there.
        It 'skips the UI projects Get-UiProject.ps1 names, without asking MSBuild about them' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'ui'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
            New-Project $repo 'App.Maui'
            '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><UseMaui>true</UseMaui></PropertyGroup><Import Project="missing.props" /></Project>' |
                Set-Content -LiteralPath (Join-Path $repo 'src/App.Maui/App.Maui.csproj')
            $solution = New-Solution $repo 'App.Maui', 'App.E2E.Tests'
            $pin = New-Pin $repo "FROM mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            Mock docker { $global:LASTEXITCODE = 0 }

            Invoke-WithPlaywrightImage -Solution $solution -Pin $pin -Command 'dotnet', 'test' *> $null

            Should -Invoke docker -Times 1
        }

        It 'fails, naming the project, when it isn''t restored' {
            Get-Command Invoke-WithPlaywrightImage -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            $repo = Join-Path $TestDrive 'unrestored'
            New-Project $repo 'App.E2E.Tests' -Libraries 'Microsoft.Playwright/1.64.1'
            Remove-Item -LiteralPath (Join-Path $repo 'src/App.E2E.Tests/obj/project.assets.json')
            $solution = New-Solution $repo 'App.E2E.Tests'
            Mock docker { }

            { Invoke-WithPlaywrightImage -Solution $solution -Pin (New-Pin $repo "FROM x") -Command 'dotnet', 'test' *> $null } |
                Should -Throw '*App.E2E.Tests*restore*'
        }
    }

    # What the container gets, from Playwright's Docker page (--init, --ipc=host) and from what the tests need.
    Context 'the container''s arguments' {
        BeforeAll {
            $image = "mcr.microsoft.com/playwright/dotnet:v1.64.1-noble@$digest"
            $common = @{
                Image            = $image
                Command          = 'dotnet', 'test'
                WorkingDirectory = '/home/runner/work/app/app'
                HomePath         = '/home/runner'
                DotnetRoot       = '/usr/share/dotnet'
                User             = '1001:1002'
            }
        }

        It 'starts the image with an init process, the host''s IPC and network, as the runner''s user, then runs the command' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $arguments = @(Get-PlaywrightContainerArgument @common)

            $arguments[0..1] | Should -Be @('run', '--rm')
            $arguments | Should -Contain '--init'
            $arguments | Should -Contain '--ipc=host'
            ($arguments -join ' ') | Should -Match '--network host'
            ($arguments -join ' ') | Should -Match '--user 1001:1002'
            ($arguments -join ' ') | Should -Match '-w /home/runner/work/app/app'
            $arguments[-7..-1] | Should -Be @($image, 'sh', '-c', 'PATH="$DOTNET_ROOT:$PATH" exec "$@"', 'sh', 'dotnet', 'test')
        }

        # Review round 1: the SDK goes first on the image's own PATH, inside the container, so the kit keeps no copy of
        # the image's PATH that a new image could make wrong.
        It 'shares the home folder and the runner''s .NET SDK, read-only, at the same paths, and puts the SDK first on the image''s PATH' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $arguments = @(Get-PlaywrightContainerArgument @common)

            $arguments | Should -Contain '/home/runner:/home/runner'
            $arguments | Should -Contain '/usr/share/dotnet:/usr/share/dotnet:ro'
            $arguments | Should -Contain 'HOME=/home/runner'
            $arguments | Should -Contain 'DOTNET_ROOT=/usr/share/dotnet'
            ($arguments -join ' ') | Should -Not -Match '-e PATH=' -Because 'the image keeps its own PATH'
            $arguments | Should -Contain 'PATH="$DOTNET_ROOT:$PATH" exec "$@"'
        }

        # Review round 1: inside a container, Testcontainers looks for Docker's ports at a network gateway. With the
        # runner's network, its containers' ports are on localhost, which TESTCONTAINERS_HOST_OVERRIDE ("the host that
        # exposes Docker's ports") says. A value the repo sets itself is passed on instead.
        It 'tells Testcontainers its containers'' ports are on localhost, unless the repo sets that itself' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $default = @(Get-PlaywrightContainerArgument @common)
            $own = @(Get-PlaywrightContainerArgument @common -KeepTestcontainersHost)

            $default | Should -Contain 'TESTCONTAINERS_HOST_OVERRIDE=localhost'
            $own | Should -Contain 'TESTCONTAINERS_HOST_OVERRIDE'
            $own | Should -Not -Contain 'TESTCONTAINERS_HOST_OVERRIDE=localhost'
        }

        It 'shares a folder outside the home folder once, and none already inside a shared one' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $arguments = @(Get-PlaywrightContainerArgument @common -Share '/home/runner/work/_temp', '/opt/kit', '/opt/kit')

            @($arguments | Where-Object { $_ -like '/opt/kit:*' }) | Should -Be @('/opt/kit:/opt/kit')
            $arguments | Should -Not -Contain '/home/runner/work/_temp:/home/runner/work/_temp'
            $arguments | Should -Not -Contain '/home/runner/work/app/app:/home/runner/work/app/app'
        }

        # Tests that start containers of their own (Testcontainers) reach the runner's Docker through its socket.
        It 'shares the Docker socket, with its group, when the runner has one' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $with = @(Get-PlaywrightContainerArgument @common -DockerSocketGroup '118')
            $without = @(Get-PlaywrightContainerArgument @common)

            ($with -join ' ') | Should -Match '--group-add 118'
            $with | Should -Contain '/var/run/docker.sock:/var/run/docker.sock'
            $without | Should -Not -Contain '/var/run/docker.sock:/var/run/docker.sock'
        }

        It 'passes on CI''s own variables by name, so their values never sit in the command line' {
            Get-Command Get-PlaywrightContainerArgument -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty

            $arguments = @(Get-PlaywrightContainerArgument @common)

            foreach ($name in 'CI', 'GITHUB_ACTIONS', 'DOTNET_NOLOGO', 'DOTNET_CLI_TELEMETRY_OPTOUT') {
                $arguments | Should -Contain $name
            }
        }
    }

    # The kit's own pin, which apps start from (Export-KitApp copies it), names the image of the Playwright version the
    # kit's Directory.Packages.props pins.
    It 'has a pin in the kit for the Playwright version Directory.Packages.props names' {
        Get-Command Get-PlaywrightImagePin -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $props = [xml](Get-Content -Raw -LiteralPath (Join-Path $root 'Directory.Packages.props'))
        $version = $props.SelectSingleNode('//PackageVersion[@Include="Microsoft.Playwright"]').Version

        (Get-PlaywrightImagePin -Path (Join-Path $root '.config/playwright/Dockerfile')).Version | Should -Be $version
    }

    # CI calls the script from a pwsh step, where "--" ends its parameters, so the command's own options (-NoProfile
    # here, --no-build in CI) reach the command. GitHub ends every pwsh step with "exit $LASTEXITCODE", as the step
    # file here does.
    It 'exits with the command''s exit code when run as a script, as CI runs it' {
        Test-Path $scriptPath | Should -BeTrue
        $repo = Join-Path $TestDrive 'script'
        New-Project $repo 'Api' -Libraries 'xunit.v3/4.0.3'
        $solution = New-Solution $repo 'Api'
        $marker = Join-Path $repo 'ran.txt'
        $step = Join-Path $repo 'step.ps1'
        "& '$scriptPath' -Solution '$solution' -Pin '$(Join-Path $repo 'none')' -- pwsh -NoProfile -Command `"Set-Content -LiteralPath '$marker' -Value ran; exit 5`"", 'exit $LASTEXITCODE' |
            Set-Content -LiteralPath $step

        & pwsh -NoProfile -File $step *> $null

        $LASTEXITCODE | Should -Be 5
        Test-Path -LiteralPath (Join-Path $repo 'ran.txt') | Should -BeTrue
    }
}
