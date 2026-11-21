#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Initialize-DevMachine.ps1')
}

Describe 'Test-SdkSatisfiesPin' {
    It 'is <Expected> for <Installed> against pin 10.0.403 (<RollForward>)' -ForEach @(
        @{ Installed = @('10.0.403'); RollForward = 'latestPatch'; Expected = $true }
        @{ Installed = @('10.0.405'); RollForward = 'latestPatch'; Expected = $true }
        @{ Installed = @('10.0.402'); RollForward = 'latestPatch'; Expected = $false }
        @{ Installed = @('10.0.500'); RollForward = 'latestPatch'; Expected = $false }
        @{ Installed = @('9.0.403'); RollForward = 'latestPatch'; Expected = $false }
        @{ Installed = @('9.0.320', '10.0.404'); RollForward = 'latestPatch'; Expected = $true }
        @{ Installed = @('10.0.404'); RollForward = 'disable'; Expected = $false }
        @{ Installed = @('10.0.403'); RollForward = 'disable'; Expected = $true }
        @{ Installed = @(); RollForward = 'latestPatch'; Expected = $false }
        @{ Installed = @('10.0.100-rc.2.25502.107', '10.0.403'); RollForward = 'latestPatch'; Expected = $true }
        @{ Installed = @('10.0.403-preview.1.25500.1'); RollForward = 'latestPatch'; Expected = $false }
        @{ Installed = @('11.0.100-preview.7.26401.1'); RollForward = 'disable'; Expected = $false }
    ) {
        Test-SdkSatisfiesPin -Installed $Installed -Pinned '10.0.403' -RollForward $RollForward | Should -Be $Expected
    }

    It 'rejects a roll-forward policy the kit does not use' {
        { Test-SdkSatisfiesPin -Installed @('10.0.403') -Pinned '10.0.403' -RollForward 'latestMajor' } | Should -Throw '*latestMajor*'
    }
}

Describe 'Get-PinnedSdk' {
    It 'reads the version and roll-forward policy from global.json' {
        $path = Join-Path $TestDrive 'global.json'
        Set-Content -Path $path -Value '{ "sdk": { "version": "10.0.403", "rollForward": "disable" } }'

        $pin = Get-PinnedSdk -GlobalJsonPath $path

        $pin.Version | Should -Be '10.0.403'
        $pin.RollForward | Should -Be 'disable'
    }

    It 'defaults the roll-forward policy to latestPatch, as the SDK does' {
        $path = Join-Path $TestDrive 'global.json'
        Set-Content -Path $path -Value '{ "sdk": { "version": "10.0.403" } }'

        (Get-PinnedSdk -GlobalJsonPath $path).RollForward | Should -Be 'latestPatch'
    }
}

Describe 'Get-DevMachineCheck' {
    BeforeAll {
        Set-Content -Path (Join-Path $TestDrive 'global.json') -Value '{ "sdk": { "version": "10.0.403", "rollForward": "latestPatch" } }'

        function Get-Check([string] $Name) {
            Get-DevMachineCheck -RepoRoot $TestDrive | Where-Object Name -EQ $Name
        }
    }

    It 'lists the full toolchain in order, required tools first' {
        $checks = Get-DevMachineCheck -RepoRoot $TestDrive

        $checks.Name | Should -Be @(
            'PowerShell 7.6+', 'Pester 6', 'Pester files signed', 'powershell-yaml', 'Git', 'GitHub CLI', 'GitHub CLI signed in',
            '.NET SDK 10.0.403', 'Claude Code', 'Git commit-msg hook', 'VS Code', 'VS Code PowerShell extension', 'Docker'
        )
        @($checks | Where-Object Required).Count | Should -Be 10
    }

    It 'turns the commit-msg hook on for this clone only' {
        (Get-Check 'Git commit-msg hook').InstallCommand | Should -Be "git -C '$TestDrive' config core.hooksPath .githooks"
    }

    It 'the hook check is <Expected> when core.hooksPath is <Value>' -ForEach @(
        @{ Value = '.githooks'; Expected = $true }
        @{ Value = ''; Expected = $false }
        @{ Value = '.husky'; Expected = $false }
    ) {
        Mock Test-CommandAvailable { $true }
        Mock Invoke-Native { [pscustomobject]@{ ExitCode = 1; Output = @() } }
        Mock Invoke-Native { [pscustomobject]@{ ExitCode = $(if ($Value) { 0 } else { 1 }); Output = @($Value) } } -ParameterFilter { $FilePath -eq 'git' -and ($Arguments -join ' ') -like '* config --get core.hooksPath' }

        & (Get-Check 'Git commit-msg hook').Test | Should -Be $Expected
    }

    It 'installs <Name> for the current user through PowerShell 7' -ForEach @(
        @{ Name = 'Pester 6'; Module = 'Pester'; Version = '6.2.0' }
        @{ Name = 'powershell-yaml'; Module = 'powershell-yaml'; Version = '0.4.12' }
    ) {
        (Get-Check $Name).InstallCommand | Should -Be "pwsh -NoProfile -Command `"Install-PSResource -Name $Module -Version $Version -Scope CurrentUser -Repository PSGallery -TrustRepository`""
    }

    # winget install upgrades an installed older pwsh too: only --no-upgrade stops it (ADR-0040).
    It 'installs or upgrades PowerShell with winget, without --no-upgrade' {
        (Get-Check 'PowerShell 7.6+').InstallCommand | Should -Be 'winget install --id Microsoft.PowerShell --exact'
    }

    It 'installs the exact pinned SDK version' {
        (Get-Check '.NET SDK 10.0.403').InstallCommand | Should -Be 'winget install --id Microsoft.DotNet.SDK.10 --exact --version 10.0.403'
    }

    It 'leaves GitHub sign-in to the owner, with no install command' {
        $check = Get-Check 'GitHub CLI signed in'

        $check.InstallCommand | Should -BeNullOrEmpty
        $check.ManualAction | Should -BeLike '*gh auth login*'
    }

    # Reinstalling is the owner's step ("Always ask"), so the check has no install command, and -Install never runs
    # it: it says which files changed and how to reinstall each Pester they're in.
    It 'names each file that isn''t validly signed, with the command that reinstalls its Pester, and installs nothing' {
        Mock Test-WindowsPlatform { $true }
        Mock Test-CommandAvailable { $true }
        Mock Invoke-Native { [pscustomobject]@{ ExitCode = 0; Output = @("6.2.0`tPester.ScriptScope.ps1`tNotSigned", "6.2.0`tbin\net8.0\Pester.dll`tHashMismatch") } } -ParameterFilter { $FilePath -eq 'pwsh' -and $Arguments -contains '-EncodedCommand' }

        $result = Invoke-DevMachineCheck -Check (Get-Check 'Pester files signed')

        $result.Status | Should -Be 'action'
        $result.InstallCommand | Should -BeNullOrEmpty
        $result.ManualAction | Should -BeLike '*Pester 6.2.0: Pester.ScriptScope.ps1 is NotSigned*'
        $result.ManualAction | Should -BeLike '*Pester 6.2.0: bin\net8.0\Pester.dll is HashMismatch*'
        $result.ManualAction | Should -BeLike "*$(Get-PwshModuleInstallCommand -Name 'Pester' -Version '6.2.0' -Reinstall)*"
    }

    # Get-AuthenticodeSignature exists only on Windows, and the check runs in PowerShell 7.
    It 'skips the Pester signature check, saying why, when <Case>' -ForEach @(
        @{ Case = 'not on Windows'; Windows = $false; Pwsh = $true; Reason = '*only on Windows*' }
        @{ Case = 'PowerShell 7 is missing'; Windows = $true; Pwsh = $false; Reason = '*PowerShell 7*' }
    ) {
        Mock Test-WindowsPlatform { $Windows }
        Mock Test-CommandAvailable { $Pwsh }
        Mock Invoke-Native { [pscustomobject]@{ ExitCode = 0; Output = @("6.2.0`tPester.psm1`tNotSigned") } }

        $result = Invoke-DevMachineCheck -Check (Get-Check 'Pester files signed')

        $result.Status | Should -Be 'skipped'
        $result.ManualAction | Should -BeLike $Reason
        Should -Invoke Invoke-Native -Times 0
    }

    It 'knows whether it runs on Windows' {
        Test-WindowsPlatform | Should -Be $IsWindows
    }

    It 'reinstalls a module with -Reinstall added to its install command' {
        Get-PwshModuleInstallCommand -Name 'Pester' -Version '6.2.0' -Reinstall |
            Should -Be 'pwsh -NoProfile -Command "Install-PSResource -Name Pester -Version 6.2.0 -Scope CurrentUser -Repository PSGallery -TrustRepository -Reinstall"'
    }

    Context 'probes' {
        It '<Name> passes when its command is on PATH' -ForEach @(
            @{ Name = 'Git'; Command = 'git' }
            @{ Name = 'GitHub CLI'; Command = 'gh' }
            @{ Name = 'Claude Code'; Command = 'claude' }
            @{ Name = 'VS Code'; Command = 'code' }
            @{ Name = 'Docker'; Command = 'docker' }
        ) {
            Mock Test-CommandAvailable { $true } -ParameterFilter { $Name -eq $Command }
            Mock Test-CommandAvailable { $false }

            & (Get-Check $Name).Test | Should -BeTrue
        }

        It '<Name> fails when its command is missing' -ForEach @(
            @{ Name = 'PowerShell 7.6+' }, @{ Name = 'Pester 6' }, @{ Name = 'powershell-yaml' }, @{ Name = 'Git' }, @{ Name = 'GitHub CLI' }, @{ Name = 'GitHub CLI signed in' },
            @{ Name = '.NET SDK 10.0.403' }, @{ Name = 'Claude Code' }, @{ Name = 'Git commit-msg hook' }, @{ Name = 'VS Code' },
            @{ Name = 'VS Code PowerShell extension' }, @{ Name = 'Docker' }
        ) {
            Mock Test-CommandAvailable { $false }

            & (Get-Check $Name).Test | Should -BeFalse
        }

        # The check runs in Windows PowerShell 5.1 too, so it asks pwsh itself rather than reading $PSVersionTable.
        It 'the PowerShell check is <Expected> when pwsh reports <Reported> and exits <ExitCode>' -ForEach @(
            @{ Reported = @('7.3.9'); ExitCode = 0; Expected = $false }
            @{ Reported = @('7.4.20'); ExitCode = 0; Expected = $false }
            @{ Reported = @('7.5.11'); ExitCode = 0; Expected = $false }
            @{ Reported = @('7.6.0'); ExitCode = 0; Expected = $true }
            @{ Reported = @('7.6.9'); ExitCode = 0; Expected = $true }
            @{ Reported = @('7.7.0-preview.3'); ExitCode = 0; Expected = $true }
            @{ Reported = @('8.0.0'); ExitCode = 0; Expected = $true }
            @{ Reported = @('7.6.9'); ExitCode = 1; Expected = $false }
            @{ Reported = @('a warning on stderr', '7.6.9'); ExitCode = 0; Expected = $true }
            @{ Reported = @('7.6.9', 'a warning on stderr'); ExitCode = 0; Expected = $true }
            @{ Reported = @('not a version'); ExitCode = 0; Expected = $false }
            @{ Reported = @(); ExitCode = 0; Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = 1; Output = @() } }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = $ExitCode; Output = $Reported } } -ParameterFilter { $FilePath -eq 'pwsh' -and ($Arguments -join ' ') -like '-NoProfile -Command *PSVersionTable.PSVersion*' }

            & (Get-Check 'PowerShell 7.6+').Test | Should -Be $Expected
        }

        It 'GitHub sign-in is <Expected> when gh auth status exits <ExitCode>' -ForEach @(
            @{ ExitCode = 0; Expected = $true }
            @{ ExitCode = 1; Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = $ExitCode; Output = @() } } -ParameterFilter { $FilePath -eq 'gh' -and ($Arguments -join ' ') -eq 'auth status' }

            & (Get-Check 'GitHub CLI signed in').Test | Should -Be $Expected
        }

        It 'the SDK check is <Expected> when dotnet lists <Listed>' -ForEach @(
            @{ Listed = @('9.0.320 [C:\Program Files\dotnet\sdk]', '10.0.404 [C:\Program Files\dotnet\sdk]'); Expected = $true }
            @{ Listed = @('10.0.500 [C:\Program Files\dotnet\sdk]'); Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = 0; Output = $Listed } } -ParameterFilter { $FilePath -eq 'dotnet' -and ($Arguments -join ' ') -eq '--list-sdks' }

            & (Get-Check '.NET SDK 10.0.403').Test | Should -Be $Expected
        }

        It 'the <Name> check is <Expected> when PowerShell 7 reports exit code <ExitCode>' -ForEach @(
            @{ Name = 'Pester 6'; ProbePattern = '*Pester*6.0.0*'; ExitCode = 0; Expected = $true }
            @{ Name = 'Pester 6'; ProbePattern = '*Pester*6.0.0*'; ExitCode = 1; Expected = $false }
            @{ Name = 'powershell-yaml'; ProbePattern = '*powershell-yaml*0.4.12*'; ExitCode = 0; Expected = $true }
            @{ Name = 'powershell-yaml'; ProbePattern = '*powershell-yaml*0.4.12*'; ExitCode = 1; Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = 1; Output = @() } }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = $ExitCode; Output = @() } } -ParameterFilter { $FilePath -eq 'pwsh' -and ($Arguments -join ' ') -like $ProbePattern }

            & (Get-Check $Name).Test | Should -Be $Expected
        }

        # ADR-0092: a file of Pester's that isn't validly signed any more was overwritten, as twice by a test run.
        It 'the Pester signature check is <Expected> when PowerShell 7 reports <Case>' -ForEach @(
            @{ Case = 'no file'; Reported = @(); ExitCode = 0; Expected = $true }
            @{ Case = 'a file that isn''t validly signed'; Reported = @("6.2.0`tPester.ScriptScope.ps1`tNotSigned"); ExitCode = 0; Expected = $false }
            @{ Case = 'nothing, and fails'; Reported = @('probe broke'); ExitCode = 1; Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = 1; Output = @() } }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = $ExitCode; Output = $Reported } } -ParameterFilter { $FilePath -eq 'pwsh' -and $Arguments -contains '-EncodedCommand' }

            & (Get-Check 'Pester files signed').Test | Should -Be $Expected
        }

        It 'the PowerShell extension check is <Expected> when VS Code lists <Listed>' -ForEach @(
            @{ Listed = @('github.copilot', 'ms-vscode.powershell'); Expected = $true }
            @{ Listed = @('github.copilot'); Expected = $false }
        ) {
            Mock Test-CommandAvailable { $true }
            Mock Invoke-Native { [pscustomobject]@{ ExitCode = 0; Output = $Listed } } -ParameterFilter { $FilePath -eq 'code' -and ($Arguments -join ' ') -eq '--list-extensions' }

            & (Get-Check 'VS Code PowerShell extension').Test | Should -Be $Expected
        }
    }
}

Describe 'the minimum PowerShell' {
    # One minimum (ADR-0040): a script that runs on an older pwsh than this check asks for is never tested there.
    It 'is what every kit script requires, except this one, which runs in Windows PowerShell 5.1' {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        $expected = "#Requires -Version $(Get-MinimumPwshVersion)"

        $scripts = @(git -C $root ls-files -- '*.ps1' '*.psm1' | Where-Object { $_ -ne 'tools/Initialize-DevMachine.ps1' })
        $wrong = foreach ($path in $scripts) {
            $first = Get-Content -LiteralPath (Join-Path $root $path) -TotalCount 1
            if ($first -ne $expected) { "$path ($first)" }
        }

        $scripts.Count | Should -BeGreaterThan 0
        @($wrong) | Should -BeNullOrEmpty -Because "each should start with '$expected'"
    }
}

Describe 'Invoke-DevMachineCheck' {
    It 'reports <Status> for a <Kind> check that <Outcome>' -ForEach @(
        @{ Kind = 'required'; Outcome = 'passes'; Required = $true; Passes = $true; Install = 'x'; Manual = $null; Status = 'ok' }
        @{ Kind = 'required'; Outcome = 'fails'; Required = $true; Passes = $false; Install = 'x'; Manual = $null; Status = 'missing' }
        @{ Kind = 'optional'; Outcome = 'fails'; Required = $false; Passes = $false; Install = 'x'; Manual = $null; Status = 'later' }
        @{ Kind = 'manual'; Outcome = 'fails'; Required = $true; Passes = $false; Install = $null; Manual = 'do it'; Status = 'action' }
    ) {
        $check = New-DevMachineCheck -Name 'Tool' -Required $Required -Test ([scriptblock]::Create("`$$Passes")) -InstallCommand $Install -ManualAction $Manual

        $result = Invoke-DevMachineCheck -Check $check

        $result.Status | Should -Be $Status
        $result.Name | Should -Be 'Tool'
    }
}

Describe 'Initialize-DevMachine' {
    BeforeAll {
        function New-FakeCheck([string] $Name, [bool] $Required, [bool] $Passes, [string] $Install, [string] $Manual) {
            New-DevMachineCheck -Name $Name -Required $Required -Test ([scriptblock]::Create("`$$Passes")) -InstallCommand $Install -ManualAction $Manual
        }
    }

    BeforeEach {
        Mock Write-Host {}
        Mock Invoke-InstallCommand {}
    }

    Context 'a required tool is missing' {
        BeforeEach {
            Mock Get-DevMachineCheck {
                New-FakeCheck -Name 'Present' -Required $true -Passes $true -Install 'install present'
                New-FakeCheck -Name 'Needed' -Required $true -Passes $false -Install 'install needed'
                New-FakeCheck -Name 'Sign-in' -Required $true -Passes $false -Manual 'sign in yourself'
                New-FakeCheck -Name 'Later' -Required $false -Passes $false -Install 'install later'
            }
        }

        It 'returns 1 and installs nothing without -Install' {
            Initialize-DevMachine -RepoRoot $TestDrive | Should -Be 1
            Should -Invoke Invoke-InstallCommand -Times 0
        }

        It 'shows each missing tool with the command that installs it' {
            Initialize-DevMachine -RepoRoot $TestDrive | Out-Null
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*`[missing`]*Needed*install needed*' }
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*`[action`]*Sign-in*sign in yourself*' }
        }

        It 'with -Install, installs each failing tool that has an install command, in order' {
            $script:installed = @()
            Mock Invoke-InstallCommand { $script:installed += $Command }

            Initialize-DevMachine -RepoRoot $TestDrive -Install | Should -Be 1

            $script:installed | Should -Be @('install needed', 'install later')
        }

        It 'with -Install, reports a failed install and carries on with the rest' {
            $script:installed = @()
            Mock Invoke-InstallCommand { $script:installed += $Command; throw 'pwsh is not on PATH yet' } -ParameterFilter { $Command -eq 'install needed' }
            Mock Invoke-InstallCommand { $script:installed += $Command }

            Initialize-DevMachine -RepoRoot $TestDrive -Install | Should -Be 1

            $script:installed | Should -Be @('install needed', 'install later')
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Needed*failed*pwsh is not on PATH yet*' }
        }

        It 'with -Install -WhatIf, installs nothing' {
            Initialize-DevMachine -RepoRoot $TestDrive -Install -WhatIf | Should -Be 1
            Should -Invoke Invoke-InstallCommand -Times 0
        }
    }

    It 'shows a skipped check with its reason, and returns 0 when nothing else is missing' {
        Mock Get-DevMachineCheck {
            New-FakeCheck -Name 'Present' -Required $true -Passes $true -Install 'install present'
            New-DevMachineCheck -Name 'Signatures' -Required $true -Test { $false } -Skip { 'not on this platform' }
        }

        Initialize-DevMachine -RepoRoot $TestDrive | Should -Be 0
        Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*`[skipped`]*Signatures*not on this platform*' }
    }

    It 'returns 0 when only optional tools are missing' {
        Mock Get-DevMachineCheck {
            New-FakeCheck -Name 'Present' -Required $true -Passes $true -Install 'install present'
            New-FakeCheck -Name 'Later' -Required $false -Passes $false -Install 'install later'
        }

        Initialize-DevMachine -RepoRoot $TestDrive | Should -Be 0
    }
}

Describe 'Initialize-DevMachine.ps1 as a script' -Tag 'Machine' {
    # Runs the real, read-only check: a new machine starts in Windows PowerShell 5.1, before PowerShell 7 exists.
    It 'runs its check in Windows PowerShell 5.1' -Skip:(-not (Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue)) {
        $script = Join-Path $PSScriptRoot '..' 'Initialize-DevMachine.ps1'

        $output = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | Out-String

        $output | Should -Match 'Checking the dotnet-agent-kit toolchain'
        # The banner prints before any check runs; only the closing line shows that every check ran in 5.1.
        $output | Should -Match 'All required tools are ready|Fix the items above' -Because $output
        $LASTEXITCODE | Should -BeIn 0, 1 -Because $output
    }

    # A probe such as `gh auth status` writes to stderr when it fails. In 5.1, with $ErrorActionPreference = 'Stop',
    # captured native stderr becomes a terminating error unless Invoke-Native allows it.
    It 'Invoke-Native in Windows PowerShell 5.1 returns the exit code and stderr of a failing command' -Skip:(-not (Get-Command -Name 'powershell.exe' -ErrorAction SilentlyContinue)) {
        $script = Join-Path $PSScriptRoot '..' 'Initialize-DevMachine.ps1'
        $driver = Join-Path $TestDrive 'Invoke-NativeDriver.ps1'
        Set-Content -Path $driver -Value @"
`$ErrorActionPreference = 'Stop'
. '$script'
`$result = Invoke-Native -FilePath 'pwsh' -Arguments '-NoProfile', '-Command', '[Console]::Error.WriteLine(''probe-error''); exit 3'
"EXIT=`$(`$result.ExitCode) OUTPUT=`$(`$result.Output -join '|')"
"@

        $output = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $driver 2>&1 | Out-String

        $output | Should -Match 'EXIT=3 OUTPUT=.*probe-error'
    }
}

Describe 'Get-PesterSignatureProblem on this machine' -Tag 'Machine' -Skip:(-not $IsWindows) {
    # A fake Pester 6.99.0 next to the real one (Get-Module -ListAvailable leaves out a second copy of a version it
    # already lists): its own manifest, unsigned; a renamed copy of the running Pester's signed Pester.ScriptScope.ps1,
    # still valid, since a script's signature covers its text, not its name; a script with no signature, standing in
    # for an overwritten file; and a text file, which Authenticode can't sign.
    BeforeAll {
        $fakeModules = Join-Path $TestDrive "modules-$(New-Guid)"
        $fakeBase = Join-Path $fakeModules 'Pester' '6.99.0'
        New-Item -ItemType Directory -Path $fakeBase -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fakeBase 'Pester.psd1') -Value "@{ ModuleVersion = '6.99.0' }"
        Copy-Item -LiteralPath (Join-Path (Get-Module -Name Pester).ModuleBase 'Pester.ScriptScope.ps1') -Destination (Join-Path $fakeBase 'Signed.ps1')
        Set-Content -LiteralPath (Join-Path $fakeBase 'Overwritten.ps1') -Value '"no signature here"'
        Set-Content -LiteralPath (Join-Path $fakeBase 'notes.txt') -Value 'not a signable file'
        # An older Pester, which the kit doesn't run, with an unsigned manifest of its own.
        $oldBase = Join-Path $fakeModules 'Pester' '5.99.0'
        New-Item -ItemType Directory -Path $oldBase -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $oldBase 'Pester.psd1') -Value "@{ ModuleVersion = '5.99.0' }"
        $savedModulePath = $env:PSModulePath
        $env:PSModulePath = $fakeModules + [IO.Path]::PathSeparator + $env:PSModulePath
    }

    AfterAll {
        $env:PSModulePath = $savedModulePath
    }

    It 'reports each file of a type Authenticode signs whose signature isn''t valid, and no other' {
        $texts = @(@(Get-PesterSignatureProblem) | ForEach-Object Text)

        $texts | Should -Contain 'Pester 6.99.0: Overwritten.ps1 is NotSigned'
        $texts | Should -Contain 'Pester 6.99.0: Pester.psd1 is NotSigned'
        $texts | Should -Not -BeLike '*Signed.ps1 is*' -Because 'a validly signed file is fine'
        $texts | Should -Not -BeLike '*notes.txt*' -Because 'Authenticode can''t sign a text file'
        $texts | Should -Not -BeLike 'Pester 5.99.0*' -Because 'the kit runs Pester 6 or later'
    }
}

Describe 'Invoke-InstallCommand' {
    # Real native commands, no mocks: winget and friends report failure by exit code, not by throwing.
    It 'throws when the installer exits nonzero, naming the exit code' {
        { Invoke-InstallCommand -Command 'pwsh -NoProfile -Command "exit 5"' } | Should -Throw '*exit code 5*'
    }

    It 'does not throw when the installer succeeds' {
        { Invoke-InstallCommand -Command 'pwsh -NoProfile -Command "exit 0"' } | Should -Not -Throw
    }

    It 'ignores an exit code left over from an earlier command when the installer runs no native command' {
        $global:LASTEXITCODE = 7

        { Invoke-InstallCommand -Command 'Get-Date | Out-Null' } | Should -Not -Throw
    }

    It 'shows installer output on the host instead of returning it' {
        $returned = @(Invoke-InstallCommand -Command 'pwsh -NoProfile -Command "''installer-noise''"' 6>$null)

        $returned.Count | Should -Be 0
    }

    It 'leaves Initialize-DevMachine -Install returning only its exit status' {
        Mock Write-Host {}
        Mock Get-DevMachineCheck {
            New-DevMachineCheck -Name 'Noisy' -Required $true -Test { $false } -InstallCommand 'pwsh -NoProfile -Command "''installer-noise''"'
        }

        $returned = @(Initialize-DevMachine -RepoRoot $TestDrive -Install 6>$null)

        $returned.Count | Should -Be 1 -Because "got: $($returned -join ', ')"
        $returned[0] | Should -Be 1
    }
}
