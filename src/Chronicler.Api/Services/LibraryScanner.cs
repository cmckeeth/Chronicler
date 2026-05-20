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
            var (title, author) = ParseDirectoryName(dirName);
            var coverPath = FindCoverImage(dir);

            var book = new Book
            {
                Title = title,
                Author = author,
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
                title, author, book.Chapters.Count);
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
