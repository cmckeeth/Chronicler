using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicler.Api.Migrations
{
    public partial class AddBookIsFavorite : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsFavorite",
                table: "Books",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsFavorite",
                table: "Books");
        }
    }
}
