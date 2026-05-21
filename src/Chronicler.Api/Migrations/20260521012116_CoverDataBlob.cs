using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicler.Api.Migrations
{
    /// <inheritdoc />
    public partial class CoverDataBlob : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "CoverPath",
                table: "Books",
                newName: "CoverMimeType");

            migrationBuilder.AddColumn<byte[]>(
                name: "CoverData",
                table: "Books",
                type: "BLOB",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CoverData",
                table: "Books");

            migrationBuilder.RenameColumn(
                name: "CoverMimeType",
                table: "Books",
                newName: "CoverPath");
        }
    }
}
