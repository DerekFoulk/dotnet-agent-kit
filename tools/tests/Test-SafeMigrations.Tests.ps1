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
            @{ Operation = 'UpdateData'; Call = 'migrationBuilder.UpdateData(table: "Statuses", keyColumn: "Id", keyValue: 3, column: "Name", value: "Closed");' }
            @{ Operation = 'AlterSequence'; Call = 'migrationBuilder.AlterSequence(name: "OrderNumbers", incrementBy: 10);' }
            @{ Operation = 'RestartSequence'; Call = 'migrationBuilder.RestartSequence(name: "OrderNumbers", startValue: 1L);' }
            @{ Operation = 'AlterDatabase'; Call = 'migrationBuilder.AlterDatabase(collation: "Latin1_General_100_BIN2");' }
            @{ Operation = 'AlterTable'; Call = 'migrationBuilder.AlterTable(name: "Orders", comment: "Every order");' }
            @{ Operation = 'AlterColumn'; Call = 'migrationBuilder.AlterColumn<List<string>>(name: "Tags", table: "Orders", type: "text[]");' }
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

        It 'names files relative to a relative -Path, resolved from the current location' {
            New-Migration -Up 'migrationBuilder.DropTable(name: "Orders");'

            Push-Location -LiteralPath $script:repo
            try { $messages = @(Get-MigrationProblem -Path '.') | ForEach-Object Message }
            finally { Pop-Location }

            $messages | Should -BeLike 'src/Contoso.Orders.Infrastructure/Migrations/20261111120000_ChangeOrders.cs:13: *'
        }

        It 'reads Up when Down comes first in the file' {
            $folder = Join-Path $script:repo 'Migrations'
            New-Item -ItemType Directory -Path $folder | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'M.cs') -Value (@(
                    'public partial class M : Migration {'
                    '    protected override void Down(MigrationBuilder b) { b.DropTable(name: "Lines"); }'
                    '    protected override void Up(MigrationBuilder b) { b.CreateTable(name: "Lines"); }'
                    '}') -join "`n")

            Get-Message | Should -BeNullOrEmpty
        }

        It 'reads a builder parameter with another name' {
            New-Migration -Builder 'builder' -Up 'builder.DropColumn(name: "Notes", table: "Orders");'

            Get-Message | Should -BeLike '*:13: Up calls DropColumn, *'
        }
    }

    Context 'a reviewed contract step' {
        It 'passes a call with a DAT-003 comment directly above it that says why it''s safe' {
            New-Migration -Up '// Notes moved to OrderNotes in 1.3.',
                '// DAT-003: release 1.4 stopped reading Notes, and every instance runs 1.4 or later.',
                'migrationBuilder.DropColumn(', '    name: "Notes",', '    table: "Orders");'

            Get-Message | Should -BeNullOrEmpty
        }

        It 'passes a call with a DAT-003 comment at the end of its line' {
            New-Migration -Up 'migrationBuilder.DropColumn(name: "Notes", table: "Orders"); // DAT-003: unused since 1.4.'

            Get-Message | Should -BeNullOrEmpty
        }

        It 'still reports another unsafe call in the same migration' {
            New-Migration -Up '// DAT-003: release 1.4 stopped reading Notes.',
                'migrationBuilder.DropColumn(name: "Notes", table: "Orders");',
                'migrationBuilder.RenameColumn(name: "Total", table: "Orders", newName: "Amount");'

            Get-Message | Should -BeLike '*:15: Up calls RenameColumn, *'
        }

        It 'doesn''t take a DAT-003 comment that isn''t directly above the call' {
            New-Migration -Header '    // DAT-003: release 1.4 stopped reading Notes.' `
                -Up 'migrationBuilder.DropColumn(name: "Notes", table: "Orders");' `
                -Down '// DAT-003: release 1.4 stopped reading Notes.'

            Get-Message | Should -BeLike '*:14: Up calls DropColumn, *'
        }

        It 'reports a DAT-003 comment with no reason, and still reports the call' {
            New-Migration -Up '// DAT-003:   ', 'migrationBuilder.DropColumn(name: "Notes", table: "Orders");'

            $messages = @(Get-Message)
            $messages.Count | Should -Be 2
            $messages[0] | Should -BeLike '*:13: the DAT-003 comment must say why the version still running works after this call'
            $messages[1] | Should -BeLike '*:14: Up calls DropColumn, *'
        }

        It 'doesn''t report a call that''s commented out' {
            New-Migration -Up '// migrationBuilder.DropColumn(name: "Notes", table: "Orders");',
                'migrationBuilder.AddColumn<string>(name: "Remarks", table: "Orders", nullable: true); // migrationBuilder.DropTable('

            Get-Message | Should -BeNullOrEmpty
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

        It 'passes an empty C# file' {
            $folder = Join-Path $script:repo 'src'
            New-Item -ItemType Directory -Path $folder | Out-Null
            New-Item -ItemType File -Path (Join-Path $folder 'Placeholder.cs') | Out-Null

            { Get-Message } | Should -Not -Throw
            Get-Message | Should -BeNullOrEmpty
        }

        It 'skips build output and git''s files in <Folder>' -ForEach @(@{ Folder = 'bin' }, @{ Folder = 'obj' }, @{ Folder = '.git' }) {
            $folder = Join-Path $script:repo "src/$Folder"
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            Set-Content -LiteralPath (Join-Path $folder 'Copy.cs') -Value (New-MigrationText -Up 'migrationBuilder.DropTable(name: "Orders");')

            Get-Message | Should -BeNullOrEmpty
        }
    }

    Context 'the result' {
        BeforeEach {
            Mock Write-Host { }
        }

        It 'returns 0 and says so when every migration is safe' {
            New-Migration -Up 'migrationBuilder.AddColumn<string>(name: "Notes", table: "Orders", nullable: true);'

            Invoke-SafeMigrationsCheck -Path $script:repo | Should -Be 0
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*migration*safe*' }
        }

        It 'returns 1 and prints each problem' {
            New-Migration -Up 'migrationBuilder.DropTable(name: "Orders");'

            Invoke-SafeMigrationsCheck -Path $script:repo | Should -Be 1
            Should -Invoke Write-Host -ParameterFilter { "$Object" -like '*Up calls DropTable*' }
        }

        It 'exits 1 when run as a script against an unsafe migration' {
            New-Migration -Up 'migrationBuilder.RenameColumn(name: "Notes", table: "Orders", newName: "Remarks");'
            $script = Join-Path $PSScriptRoot '..' 'Test-SafeMigrations.ps1'

            $output = pwsh -NoProfile -File $script -Path $script:repo 2>&1 | Out-String

            $LASTEXITCODE | Should -Be 1 -Because $output
            $output | Should -Match 'Up calls RenameColumn'
        }
    }
}
