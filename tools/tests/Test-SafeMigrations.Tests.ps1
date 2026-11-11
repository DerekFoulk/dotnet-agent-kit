#Requires -Version 7.6
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }

Describe 'Test-SafeMigrations.ps1' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..' 'Test-SafeMigrations.ps1')

        # A migration file as EF Core scaffolds it: Up, then Down, each taking a MigrationBuilder.
        function New-MigrationText {
            param(
                [string[]] $Up = @(),
                [string[]] $Down = @(),
                [string[]] $Header = @(),
                [string] $Builder = 'migrationBuilder'
            )

            $indent = '            '
            @(
                'using Microsoft.EntityFrameworkCore.Migrations;'
                ''
                '#nullable disable'
                ''
                'namespace Contoso.Orders.Infrastructure.Migrations'
                '{'
                $Header
                '    /// <inheritdoc />'
                '    public partial class ChangeOrders : Migration'
                '    {'
                '        /// <inheritdoc />'
                "        protected override void Up(MigrationBuilder $Builder)"
                '        {'
                ($Up | ForEach-Object { "$indent$_" })
                '        }'
                ''
                '        /// <inheritdoc />'
                "        protected override void Down(MigrationBuilder $Builder)"
                '        {'
                ($Down | ForEach-Object { "$indent$_" })
                '        }'
                '    }'
                '}'
            ) -join "`n"
        }

        function New-Migration {
            param([string] $Name = '20261111120000_ChangeOrders.cs')

            $folder = Join-Path $script:repo 'src/Contoso.Orders.Infrastructure/Migrations'
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            Set-Content -LiteralPath (Join-Path $folder $Name) -Value (New-MigrationText @args) -NoNewline
        }

        function Get-Message {
            @(Get-MigrationProblem -Path $script:repo) | ForEach-Object Message
        }
    }

    BeforeEach {
        $script:repo = Join-Path $TestDrive "repo-$(New-Guid)"
        New-Item -ItemType Directory -Path $script:repo | Out-Null
    }

    Context 'operations the running version can''t work with' {
        It 'reports a DropColumn in Up, with the file and line' {
            New-Migration -Up 'migrationBuilder.DropColumn(', '    name: "Notes",', '    table: "Orders");'

            Get-Message | Should -Be (
                "src/Contoso.Orders.Infrastructure/Migrations/20261111120000_ChangeOrders.cs:13: Up calls DropColumn, " +
                "which the version still running may need (DAT-003)")
        }
    }
}
