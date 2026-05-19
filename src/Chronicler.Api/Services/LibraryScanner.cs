using Chronicler.Api.Data;
using Chronicler.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Chronicler.Api.Services;

public class LibraryScanner(AppDbContext db, IWebHostEnvironment env, ILogger<LibraryScanner> logger)
{
    private static readonly string[] AudioExtensions = [".mp3", ".m4b", ".m4a", ".ogg", ".flac", ".aac", ".wav"];

    public string LibraryRoot => Path.Combine(env.ContentRootPath, "Library");

    public async Task<int> ScanAsync(CancellationToken ct = default)
    {
        if (!Directory.Exists(LibraryRoot))
        {
            logger.LogWarning("Library directory not found: {Path}", LibraryRoot);
            return 0;
        }

        var existingPaths = await db.Books.Select(b => b.FilePath).ToHashSetAsync(ct);
        int added = 0;

        foreach (var dir in Directory.GetDirectories(LibraryRoot))
        {
            var audioFile = Directory.GetFiles(dir)
                .FirstOrDefault(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()));

            if (audioFile is null) continue;

            var relativePath = Path.GetRelativePath(LibraryRoot, audioFile);

            if (existingPaths.Contains(relativePath)) continue;

            var dirName = Path.GetFileName(dir);
            var (title, author) = ParseDirectoryName(dirName);
            var coverPath = FindCoverImage(dir);

            var book = new Book
            {
                Title = title,
                Author = author,
                FilePath = relativePath,
                CoverPath = coverPath is not null ? Path.GetRelativePath(LibraryRoot, coverPath) : null,
                AddedAt = DateTime.UtcNow
            };

            db.Books.Add(book);
            added++;
            logger.LogInformation("Added book: {Title} by {Author}", title, author);
        }

        // also scan flat audio files in root
        foreach (var file in Directory.GetFiles(LibraryRoot)
            .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant())))
        {
            var relativePath = Path.GetRelativePath(LibraryRoot, file);
            if (existingPaths.Contains(relativePath)) continue;

            var nameWithoutExt = Path.GetFileNameWithoutExtension(file);
            var (title, author) = ParseDirectoryName(nameWithoutExt);

            db.Books.Add(new Book
            {
                Title = title,
                Author = author,
                FilePath = relativePath,
                AddedAt = DateTime.UtcNow
            });
            added++;
        }

        await db.SaveChangesAsync(ct);
        return added;
    }

    private static (string title, string author) ParseDirectoryName(string name)
    {
        // Expects: "Author Name - Book Title" or just "Book Title"
        var parts = name.Split(" - ", 2);
        return parts.Length == 2
            ? (parts[1].Trim(), parts[0].Trim())
            : (name.Trim(), "Unknown");
    }

    private static string? FindCoverImage(string dir)
    {
        string[] imageNames = ["cover.jpg", "cover.png", "folder.jpg", "folder.png", "thumb.jpg"];
        foreach (var name in imageNames)
        {
            var path = Path.Combine(dir, name);
            if (File.Exists(path)) return path;
        }

        return Directory.GetFiles(dir, "*.jpg").FirstOrDefault()
            ?? Directory.GetFiles(dir, "*.png").FirstOrDefault();
    }
}
