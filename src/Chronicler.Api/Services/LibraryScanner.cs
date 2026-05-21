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

        // Sync cover + meta for ALL existing books
        var existing = await db.Books.ToListAsync(ct);
        var coverUpdates = 0;
        foreach (var book in existing)
        {
            var audioDir = Path.GetDirectoryName(Path.Combine(LibraryRoot, book.FilePath));
            if (audioDir is null) continue;

            var coverFile = FindCoverImage(audioDir);
            var newCoverData = coverFile is not null ? await File.ReadAllBytesAsync(coverFile, ct) : null;
            var newMime = coverFile is not null ? GuessMime(coverFile) : null;

            // Update if cover changed (compare lengths as a cheap check)
            if (newCoverData?.Length != book.CoverData?.Length)
            {
                book.CoverData = newCoverData;
                book.CoverMimeType = newMime;
                coverUpdates++;
                logger.LogInformation("Cover synced for '{Title}' ({Bytes}b)", book.Title, newCoverData?.Length ?? 0);
            }

            // Sync meta.json
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
            logger.LogInformation("Synced covers for {Count} book(s)", coverUpdates);
        }

        // Add new books
        var existingPaths = await db.Books.Select(b => b.FilePath).ToHashSetAsync(ct);
        var newBooks = new List<Book>();

        foreach (var dir in Directory.GetDirectories(LibraryRoot))
        {
            var audioFiles = Directory.GetFiles(dir)
                .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
                .OrderBy(f => f).ToList();

            if (audioFiles.Count == 0) continue;

            var firstRelative = Path.GetRelativePath(LibraryRoot, audioFiles[0]);
            if (existingPaths.Contains(firstRelative)) continue;

            var meta = ReadMetaJson(dir);
            var (defaultTitle, defaultAuthor) = ParseDirectoryName(Path.GetFileName(dir));
            var coverFile = FindCoverImage(dir);

            var book = new Book
            {
                Title = meta?.Title ?? defaultTitle,
                Author = meta?.Author ?? defaultAuthor,
                Narrator = meta?.Narrator,
                Description = meta?.Description,
                Year = meta?.Year,
                FilePath = firstRelative,
                CoverData = coverFile is not null ? await File.ReadAllBytesAsync(coverFile, ct) : null,
                CoverMimeType = coverFile is not null ? GuessMime(coverFile) : null,
                AddedAt = DateTime.UtcNow
            };

            int track = 1;
            foreach (var audioFile in audioFiles)
                book.Chapters.Add(new Chapter
                {
                    FilePath = Path.GetRelativePath(LibraryRoot, audioFile),
                    Title = ParseChapterTitle(Path.GetFileNameWithoutExtension(audioFile), track),
                    TrackNumber = track++
                });

            newBooks.Add(book);
            logger.LogInformation("Found: {Title} by {Author} ({Chapters} chapters, cover={HasCover})",
                book.Title, book.Author, book.Chapters.Count, book.CoverData is not null);
        }

        // Flat audio files in root
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

    private static string? FindCoverImage(string dir) =>
        Directory.GetFiles(dir)
            .Where(f => Path.GetFileNameWithoutExtension(f).Equals("cover", StringComparison.OrdinalIgnoreCase)
                        && CoverExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .FirstOrDefault();

    private static string GuessMime(string path) => Path.GetExtension(path).ToLower() switch
    {
        ".png" => "image/png",
        ".webp" => "image/webp",
        ".gif" => "image/gif",
        _ => "image/jpeg"
    };

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
