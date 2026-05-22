using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Chronicler.Api.Migrations
{
    /// <inheritdoc />
    public partial class CleanupIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Bookmarks_AspNetUsers_UserId",
                table: "Bookmarks");

            migrationBuilder.DropForeignKey(
                name: "FK_Bookmarks_Books_BookId",
                table: "Bookmarks");

            migrationBuilder.DropForeignKey(
                name: "FK_Progresses_AspNetUsers_UserId",
                table: "Progresses");

            migrationBuilder.DropForeignKey(
                name: "FK_Progresses_Books_BookId",
                table: "Progresses");

            migrationBuilder.DropPrimaryKey(
                name: "PK_Progresses",
                table: "Progresses");

            migrationBuilder.DropIndex(
                name: "IX_Progresses_UserId_BookId",
                table: "Progresses");

            migrationBuilder.DropPrimaryKey(
                name: "PK_Bookmarks",
                table: "Bookmarks");

            migrationBuilder.RenameTable(
                name: "Progresses",
                newName: "UserProgress");

            migrationBuilder.RenameTable(
                name: "Bookmarks",
                newName: "Bookmark");

            migrationBuilder.RenameIndex(
                name: "IX_Progresses_BookId",
                table: "UserProgress",
                newName: "IX_UserProgress_BookId");

            migrationBuilder.RenameIndex(
                name: "IX_Bookmarks_UserId",
                table: "Bookmark",
                newName: "IX_Bookmark_UserId");

            migrationBuilder.RenameIndex(
                name: "IX_Bookmarks_BookId",
                table: "Bookmark",
                newName: "IX_Bookmark_BookId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_UserProgress",
                table: "UserProgress",
                column: "Id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_Bookmark",
                table: "Bookmark",
                column: "Id");

            migrationBuilder.CreateIndex(
                name: "IX_Chapters_FilePath",
                table: "Chapters",
                column: "FilePath");

            migrationBuilder.CreateIndex(
                name: "IX_Books_FilePath",
                table: "Books",
                column: "FilePath",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_UserProgress_UserId",
                table: "UserProgress",
                column: "UserId");

            migrationBuilder.AddForeignKey(
                name: "FK_Bookmark_AspNetUsers_UserId",
                table: "Bookmark",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Bookmark_Books_BookId",
                table: "Bookmark",
                column: "BookId",
                principalTable: "Books",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserProgress_AspNetUsers_UserId",
                table: "UserProgress",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_UserProgress_Books_BookId",
                table: "UserProgress",
                column: "BookId",
                principalTable: "Books",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Bookmark_AspNetUsers_UserId",
                table: "Bookmark");

            migrationBuilder.DropForeignKey(
                name: "FK_Bookmark_Books_BookId",
                table: "Bookmark");

            migrationBuilder.DropForeignKey(
                name: "FK_UserProgress_AspNetUsers_UserId",
                table: "UserProgress");

            migrationBuilder.DropForeignKey(
                name: "FK_UserProgress_Books_BookId",
                table: "UserProgress");

            migrationBuilder.DropIndex(
                name: "IX_Chapters_FilePath",
                table: "Chapters");

            migrationBuilder.DropIndex(
                name: "IX_Books_FilePath",
                table: "Books");

            migrationBuilder.DropPrimaryKey(
                name: "PK_UserProgress",
                table: "UserProgress");

            migrationBuilder.DropIndex(
                name: "IX_UserProgress_UserId",
                table: "UserProgress");

            migrationBuilder.DropPrimaryKey(
                name: "PK_Bookmark",
                table: "Bookmark");

            migrationBuilder.RenameTable(
                name: "UserProgress",
                newName: "Progresses");

            migrationBuilder.RenameTable(
                name: "Bookmark",
                newName: "Bookmarks");

            migrationBuilder.RenameIndex(
                name: "IX_UserProgress_BookId",
                table: "Progresses",
                newName: "IX_Progresses_BookId");

            migrationBuilder.RenameIndex(
                name: "IX_Bookmark_UserId",
                table: "Bookmarks",
                newName: "IX_Bookmarks_UserId");

            migrationBuilder.RenameIndex(
                name: "IX_Bookmark_BookId",
                table: "Bookmarks",
                newName: "IX_Bookmarks_BookId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_Progresses",
                table: "Progresses",
                column: "Id");

            migrationBuilder.AddPrimaryKey(
                name: "PK_Bookmarks",
                table: "Bookmarks",
                column: "Id");

            migrationBuilder.CreateIndex(
                name: "IX_Progresses_UserId_BookId",
                table: "Progresses",
                columns: new[] { "UserId", "BookId" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Bookmarks_AspNetUsers_UserId",
                table: "Bookmarks",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Bookmarks_Books_BookId",
                table: "Bookmarks",
                column: "BookId",
                principalTable: "Books",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Progresses_AspNetUsers_UserId",
                table: "Progresses",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_Progresses_Books_BookId",
                table: "Progresses",
                column: "BookId",
                principalTable: "Books",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
