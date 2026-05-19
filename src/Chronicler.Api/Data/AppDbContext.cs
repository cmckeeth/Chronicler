using Chronicler.Api.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Chronicler.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : IdentityDbContext<AppUser>(options)
{
    public DbSet<Book> Books => Set<Book>();
    public DbSet<UserProgress> Progresses => Set<UserProgress>();
    public DbSet<Bookmark> Bookmarks => Set<Bookmark>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<UserProgress>()
            .HasIndex(p => new { p.UserId, p.BookId })
            .IsUnique();

        builder.Entity<UserProgress>()
            .HasOne(p => p.User)
            .WithMany(u => u.Progresses)
            .HasForeignKey(p => p.UserId);

        builder.Entity<UserProgress>()
            .HasOne(p => p.Book)
            .WithMany(b => b.Progresses)
            .HasForeignKey(p => p.BookId);

        builder.Entity<Bookmark>()
            .HasOne(b => b.User)
            .WithMany(u => u.Bookmarks)
            .HasForeignKey(b => b.UserId);

        builder.Entity<Bookmark>()
            .HasOne(b => b.Book)
            .WithMany(bk => bk.Bookmarks)
            .HasForeignKey(b => b.BookId);
    }
}
