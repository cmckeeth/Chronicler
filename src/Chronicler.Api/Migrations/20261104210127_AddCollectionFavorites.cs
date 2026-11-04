using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicler.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCollectionFavorites : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "UserCollectionFavorites",
                columns: table => new
                {
                    UserId = table.Column<string>(type: "TEXT", nullable: false),
                    CollectionId = table.Column<int>(type: "INTEGER", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserCollectionFavorites", x => new { x.UserId, x.CollectionId });
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "UserCollectionFavorites");
        }
    }
}
