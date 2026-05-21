using System.Text.Json;
using Chronicler.Api.Data;
using Chronicler.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Chronicler.Api.Services;

public class LibraryScanner(AppDbContext db, IWebHostEnvironment env, ILogger<LibraryScanner> logger)
{
    private static readonly string[] AudioExtensions = [".mp3", ".m4b", ".m4a", ".ogg", ".opus", ".flac", ".aac", ".wav"];
    private static readonly string[] CoverExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff"];

    public string LibraryRoot => Path.Combine(env.ContentRootPath, "Library");

    public async Task<int> ScanAsync(CancellationToken ct = default)
    {
        if (!Directory.Exists(LibraryRoot))
        {
            logger.LogWarning("Library directory not found: {Path}", LibraryRoot);
            return 0;
        }

        // Remove books whose audio files no longer exist
        var allBooks = await db.Books.Include(b => b.Chapters).ToListAsync(ct);
        var removed = 0;
        foreach (var book in allBooks)
        {
            if (!File.Exists(Path.Combine(LibraryRoot, book.FilePath)))
            {
                logger.LogInformation("Removing missing book: {Title}", book.Title);
                db.Books.Remove(book);
                removed++;
            }
        }
        if (removed > 0)
        {
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Removed {Count} missing book(s)", removed);
        }

        // Update cover/meta for existing books that have no cover set
        var booksNeedingUpdate = await db.Books.Where(b => b.CoverPath == null).ToListAsync(ct);
        var coverUpdates = 0;
        foreach (var book in booksNeedingUpdate)
        {
            var audioDir = Path.GetDirectoryName(Path.Combine(LibraryRoot, book.FilePath));
            if (audioDir is null) continue;

            var cover = FindCoverImage(audioDir);
            if (cover is not null)
            {
                book.CoverPath = Path.GetRelativePath(LibraryRoot, cover);
                coverUpdates++;
                logger.LogInformation("Updated cover for '{Title}': {Cover}", book.Title, book.CoverPath);
            }

            // Also update from meta.json if title/author look like defaults
            var meta = ReadMetaJson(audioDir);
            if (meta is not null)
            {
                if (meta.Title is not null) book.Title = meta.Title;
                if (meta.Author is not null) book.Author = meta.Author;
                if (meta.Narrator is not null) book.Narrator = meta.Narrator;
                if (meta.Year is not null) book.Year = meta.Year;
                if (meta.Description is not null) book.Description = meta.Description;
            }
        }
        if (coverUpdates > 0)
        {
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Updated covers for {Count} existing book(s)", coverUpdates);
        }

        var existingPaths = await db.Books.Select(b => b.FilePath).ToHashSetAsync(ct);
        var newBooks = new List<Book>();

        foreach (var dir in Directory.GetDirectories(LibraryRoot))
        {
            var audioFiles = Directory.GetFiles(dir)
                .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
                .OrderBy(f => f)
                .ToList();

            if (audioFiles.Count == 0) continue;

            var firstRelative = Path.GetRelativePath(LibraryRoot, audioFiles[0]);
            if (existingPaths.Contains(firstRelative)) continue;

            var dirName = Path.GetFileName(dir);
            var (defaultTitle, defaultAuthor) = ParseDirectoryName(dirName);
            var coverPath = FindCoverImage(dir);
            var meta = ReadMetaJson(dir);

            var book = new Book
            {
                Title = meta?.Title ?? defaultTitle,
                Author = meta?.Author ?? defaultAuthor,
                Narrator = meta?.Narrator,
                Description = meta?.Description,
                Year = meta?.Year,
                FilePath = firstRelative,
                CoverPath = coverPath is not null ? Path.GetRelativePath(LibraryRoot, coverPath) : null,
                AddedAt = DateTime.UtcNow
            };

            int track = 1;
            foreach (var audioFile in audioFiles)
            {
                book.Chapters.Add(new Chapter
                {
                    FilePath = Path.GetRelativePath(LibraryRoot, audioFile),
                    Title = ParseChapterTitle(Path.GetFileNameWithoutExtension(audioFile), track),
                    TrackNumber = track++
                });
            }

            newBooks.Add(book);
            logger.LogInformation("Found: {Title} by {Author} ({Chapters} chapters, cover={HasCover})",
                book.Title, book.Author, book.Chapters.Count, book.CoverPath is not null);
        }

        // Flat audio files in library root
        foreach (var file in Directory.GetFiles(LibraryRoot)
            .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant())))
        {
            var relativePath = Path.GetRelativePath(LibraryRoot, file);
            if (existingPaths.Contains(relativePath)) continue;

            var (title, author) = ParseDirectoryName(Path.GetFileNameWithoutExtension(file));
            newBooks.Add(new Book { Title = title, Author = author, FilePath = relativePath, AddedAt = DateTime.UtcNow });
        }

        foreach (var book in newBooks) db.Books.Add(book);
        if (newBooks.Count > 0) await db.SaveChangesAsync(ct);

        return newBooks.Count;
    }

    // Only match files named "cover.*"
    private static string? FindCoverImage(string dir) =>
        Directory.GetFiles(dir)
            .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)
                        && CoverExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .FirstOrDefault();

    private static readonly JsonSerializerOptions MetaJsonOpts = new(JsonSerializerDefaults.Web);

    private static BookMetaFile? ReadMetaJson(string dir)
    {
        var path = Path.Combine(dir, "meta.json");
        if (!File.Exists(path)) return null;
        try { return JsonSerializer.Deserialize<BookMetaFile>(File.ReadAllText(path), MetaJsonOpts); }
        catch { return null; }
    }

    private static string ParseChapterTitle(string fileName, int track)
    {
        var clean = fileName.Replace("_", " ")
            .TrimStart('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ' ', '-', '.').Trim();
        return string.IsNullOrWhiteSpace(clean) ? $"Chapter {track}" : clean;
    }

    private static (string title, string author) ParseDirectoryName(string name)
    {
        var parts = name.Split(" - ", 2);
        return parts.Length == 2 ? (parts[1].Trim(), parts[0].Trim()) : (name.Trim(), "Unknown");
    }

    public record BookMetaFile(string? Title, string? Author, string? Narrator, int? Year, string? Description);
}
