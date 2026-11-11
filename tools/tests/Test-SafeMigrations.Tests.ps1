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

        It 'reports <Operation> in Up' -ForEach @(
            @{ Operation = 'DropTable'; Call = 'migrationBuilder.DropTable(name: "Orders");' }
            @{ Operation = 'RenameTable'; Call = 'migrationBuilder.RenameTable(name: "Orders", newName: "Purchases");' }
            @{ Operation = 'RenameColumn'; Call = 'migrationBuilder.RenameColumn(name: "Notes", table: "Orders", newName: "Remarks");' }
            @{ Operation = 'AlterColumn'; Call = 'migrationBuilder.AlterColumn<string>(name: "Notes", table: "Orders", maxLength: 100);' }
            @{ Operation = 'Sql'; Call = 'migrationBuilder.Sql("UPDATE Orders SET Notes = NULL");' }
            @{ Operation = 'DropSchema'; Call = 'migrationBuilder.DropSchema(name: "sales");' }
            @{ Operation = 'DropSequence'; Call = 'migrationBuilder.DropSequence(name: "OrderNumbers");' }
            @{ Operation = 'RenameSequence'; Call = 'migrationBuilder.RenameSequence(name: "OrderNumbers", newName: "Numbers");' }
            @{ Operation = 'DeleteData'; Call = 'migrationBuilder.DeleteData(table: "Statuses", keyColumn: "Id", keyValue: 3);' }
        ) {
            New-Migration -Up $Call

            Get-Message | Should -BeLike "*:13: Up calls $Operation, *"
        }

        It 'reports every unsafe call in a migration, in order' {
            New-Migration -Up 'migrationBuilder.DropColumn(name: "Notes", table: "Orders");', 'migrationBuilder.DropTable(name: "Lines");'

            $messages = @(Get-Message)
            $messages.Count | Should -Be 2
            $messages[0] | Should -BeLike '*:13: Up calls DropColumn, *'
            $messages[1] | Should -BeLike '*:14: Up calls DropTable, *'
        }

        It 'reads a builder parameter with another name' {
            New-Migration -Builder 'builder' -Up 'builder.DropColumn(name: "Notes", table: "Orders");'

            Get-Message | Should -BeLike '*:13: Up calls DropColumn, *'
        }
    }

    Context 'what it leaves alone' {
        It 'passes a repo with no migrations' {
            Get-Message | Should -BeNullOrEmpty
        }

        It 'passes operations that only add to the schema' {
            New-Migration -Up 'migrationBuilder.CreateTable(name: "Lines", columns: table => new { Id = table.Column<int>(nullable: false) });',
                'migrationBuilder.AddColumn<string>(name: "Notes", table: "Orders", nullable: true);',
                'migrationBuilder.CreateIndex(name: "IX_Orders_Notes", table: "Orders", column: "Notes");'

            Get-Message | Should -BeNullOrEmpty
        }

        It 'ignores Down, which undoes Up' {
            New-Migration -Up 'migrationBuilder.AddColumn<string>(name: "Notes", table: "Orders", nullable: true);' `
                -Down 'migrationBuilder.DropColumn(name: "Notes", table: "Orders");'

            Get-Message | Should -BeNullOrEmpty
        }

        It 'ignores a migration''s designer file and the model snapshot, which have no Up' {
            $folder = Join-Path $script:repo 'Migrations'
            New-Item -ItemType Directory -Path $folder | Out-Null
            Set-Content -LiteralPath (Join-Path $folder '20261111120000_ChangeOrders.Designer.cs') -Value (
                'partial class ChangeOrders { protected override void BuildTargetModel(ModelBuilder modelBuilder) { modelBuilder.DropColumn(); } }')
            Set-Content -LiteralPath (Join-Path $folder 'OrdersDbContextModelSnapshot.cs') -Value (
                'partial class OrdersDbContextModelSnapshot { protected override void BuildModel(ModelBuilder modelBuilder) { } }')

            Get-Message | Should -BeNullOrEmpty
        }

        It 'skips build output in <Folder>' -ForEach @(@{ Folder = 'bin' }, @{ Folder = 'obj' }) {
            $folder = Join-Path $script:repo "src/$Folder"
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'Copy.cs') -Value (New-MigrationText -Up 'migrationBuilder.DropTable(name: "Orders");')

            Get-Message | Should -BeNullOrEmpty
        }
    }
}
