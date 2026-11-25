#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

# New-FreshApp writes a fresh app of one app type, with a probe project of that type, for the kit's CI to check
# (GAP-049, ADR-0095).

Describe 'New-FreshApp' {
    BeforeAll {
        $root = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
        . (Join-Path $root 'tools' 'New-FreshApp.ps1')
    }

    # MAUI's leg waits for GAP-028 (the Windows and macOS jobs proven), and the owner put MAUI after the practice run.
    It 'refuses an app type it has no probe for, naming the gap that waits for it' {
        { New-FreshApp -Type maui -Destination (Join-Path $TestDrive 'maui') -KitRef HEAD -KitRoot $root } |
            Should -Throw -ExpectedMessage '*maui*GAP-028*'
    }
}
