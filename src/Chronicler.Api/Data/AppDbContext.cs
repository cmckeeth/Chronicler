using Chronicler.Api.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace Chronicler.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : IdentityDbContext<AppUser>(options)
{
    public DbSet<Book> Books => Set<Book>();
    public DbSet<Chapter> Chapters => Set<Chapter>();
    public DbSet<ChapterProgress> ChapterProgresses => Set<ChapterProgress>();

    protected override void OnModelCreating(ModelBuilder builder)
    {
        base.OnModelCreating(builder);

        builder.Entity<Book>()
            .HasIndex(b => b.FilePath).IsUnique();

        builder.Entity<Chapter>()
            .HasOne(c => c.Book)
            .WithMany(b => b.Chapters)
            .HasForeignKey(c => c.BookId);

        builder.Entity<Chapter>()
            .HasIndex(c => c.FilePath);

        builder.Entity<ChapterProgress>()
            .HasIndex(p => new { p.UserId, p.ChapterId })
            .IsUnique();

        builder.Entity<ChapterProgress>()
            .HasOne(p => p.Chapter)
            .WithMany(c => c.Progresses)
            .HasForeignKey(p => p.ChapterId);
    }
}
