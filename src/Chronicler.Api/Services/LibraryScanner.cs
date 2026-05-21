using System.Text.Json;
using System.Text.Json.Serialization;
using Chronicler.Api.Data;
using Chronicler.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace Chronicler.Api.Services;

public class LibraryScanner(
    AppDbContext db,
    IWebHostEnvironment env,
    MetadataService metadata,
    ILogger<LibraryScanner> logger)
{
    private static readonly string[] AudioExtensions = [".mp3", ".m4b", ".m4a", ".ogg", ".opus", ".flac", ".aac", ".wav"];

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
            var fullPath = Path.Combine(LibraryRoot, book.FilePath);
            if (!File.Exists(fullPath))
            {
                logger.LogInformation("Removing missing book: {Title} ({Path})", book.Title, book.FilePath);
                db.Books.Remove(book);
                removed++;
            }
        }
        if (removed > 0)
        {
            await db.SaveChangesAsync(ct);
            logger.LogInformation("Removed {Count} missing book(s) from library", removed);
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

            // Skip if we already have this book (check first file)
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

            // Create chapters for each audio file
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
            logger.LogInformation("Found new book: {Title} by {Author} ({Chapters} chapters)",
                book.Title, book.Author, book.Chapters.Count);
        }

        // Flat audio files in root
        foreach (var file in Directory.GetFiles(LibraryRoot)
            .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant())))
        {
            var relativePath = Path.GetRelativePath(LibraryRoot, file);
            if (existingPaths.Contains(relativePath)) continue;

            var nameWithoutExt = Path.GetFileNameWithoutExtension(file);
            var (title, author) = ParseDirectoryName(nameWithoutExt);

            newBooks.Add(new Book
            {
                Title = title,
                Author = author,
                FilePath = relativePath,
                AddedAt = DateTime.UtcNow
            });
        }

        // Fetch metadata for books that don't have covers yet
        foreach (var book in newBooks)
        {
            await metadata.EnrichAsync(book, LibraryRoot, ct);
            db.Books.Add(book);
        }

        if (newBooks.Count > 0)
            await db.SaveChangesAsync(ct);

        return newBooks.Count;
    }

    private static string ParseChapterTitle(string fileName, int track)
    {
        // Clean up filenames like "01 - Chapter One" or "Chapter_01" → "Chapter One"
        var clean = fileName
            .Replace("_", " ")
            .TrimStart('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', ' ', '-', '.')
            .Trim();

        return string.IsNullOrWhiteSpace(clean) ? $"Chapter {track}" : clean;
    }

    private static (string title, string author) ParseDirectoryName(string name)
    {
        var parts = name.Split(" - ", 2);
        return parts.Length == 2
            ? (parts[1].Trim(), parts[0].Trim())
            : (name.Trim(), "Unknown");
    }

    private static readonly string[] ImageExtensions = [".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp", ".tiff"];

    private static string? FindCoverImage(string dir)
    {
        // Check common named files first
        string[] preferred = ["cover.jpg", "cover.jpeg", "cover.png", "cover.webp",
                               "folder.jpg", "folder.jpeg", "folder.png", "thumb.jpg"];
        foreach (var name in preferred)
        {
            var path = Path.Combine(dir, name);
            if (File.Exists(path)) return path;
        }

        // Fall back to any image file in the directory
        return Directory.GetFiles(dir)
            .Where(f => ImageExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .FirstOrDefault();
    }

    private static readonly JsonSerializerOptions MetaJsonOpts = new(JsonSerializerDefaults.Web);

    private static BookMetaFile? ReadMetaJson(string dir)
    {
        var path = Path.Combine(dir, "meta.json");
        if (!File.Exists(path)) return null;
        try
        {
            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<BookMetaFile>(json, MetaJsonOpts);
        }
        catch { return null; }
    }

    public record BookMetaFile(
        string? Title, string? Author, string? Narrator,
        int? Year, string? Description);
}
