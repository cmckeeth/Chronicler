using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicler.Api.Migrations
{
    public partial class PerUserFavorites : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // SQLite supports DROP COLUMN since 3.35 — safe on modern installs
            migrationBuilder.DropColumn(name: "IsFavorite", table: "Books");

            migrationBuilder.CreateTable(
                name: "UserBookFavorites",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "TEXT", nullable: false),
                    BookId = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserBookFavorites", x => new { x.UserId, x.BookId });
                });
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "UserBookFavorites");

            migrationBuilder.AddColumn<bool>(
                name: "IsFavorite",
                table: "Books",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }
    }
}
