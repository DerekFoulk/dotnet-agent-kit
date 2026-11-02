#Requires -Version 7.0
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
