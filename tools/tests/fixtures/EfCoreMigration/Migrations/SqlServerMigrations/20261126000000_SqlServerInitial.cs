using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EfCoreMigration.Migrations.SqlServerMigrations
{
    /// <inheritdoc />
    public partial class SqlServerInitial : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Bookmarks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OwnerId = table.Column<string>(type: "nvarchar(255)", maxLength: 255, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Url = table.Column<string>(type: "nvarchar(2048)", maxLength: 2048, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Title = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Bookmarks", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Bookmarks_OwnerId_CreatedAt",
                table: "Bookmarks",
                columns: new[] { "OwnerId", "CreatedAt" })
                .Annotation("SqlServer:Include", new[] { "Url" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Bookmarks");
        }
    }
}
