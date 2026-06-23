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

    public record ScanPreview(List<string> NewBooks, List<string> RemovedBooks, int CoverUpdates)
    {
        public ScanPreview() : this([], [], 0) { }
        public bool HasChanges => NewBooks.Count > 0 || RemovedBooks.Count > 0 || CoverUpdates > 0;
    }

    private List<string> AudioIn(string dir) =>
        Directory.GetFiles(dir)
            .Where(f => AudioExtensions.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .OrderBy(f => f).ToList();

    public async Task<ScanPreview> PreviewAsync(CancellationToken ct = default)
    {
        if (!Directory.Exists(LibraryRoot)) return new ScanPreview();

        var allBooks = await db.Books.Include(b => b.Chapters).ToListAsync(ct);
        var removed = allBooks
            .Where(b => !File.Exists(Path.Combine(LibraryRoot, b.FilePath)))
            .Select(b => b.Title).ToList();

        var existingPaths = await db.Books.Select(b => b.FilePath).ToHashSetAsync(ct);
        var added = new List<string>();

        void Consider(string dir)
        {
            var audio = AudioIn(dir);
            if (audio.Count == 0) return;
            var firstRel = Path.GetRelativePath(LibraryRoot, audio[0]);
            if (existingPaths.Contains(firstRel)) return;
            var meta = ReadMetaJson(dir);
            var (defaultTitle, _) = ParseDirectoryName(Path.GetFileName(dir));
            added.Add(meta?.Title ?? defaultTitle);
        }

        foreach (var dir in Directory.GetDirectories(LibraryRoot))
        {
            if (AudioIn(dir).Count > 0) { Consider(dir); continue; }
            // collection: child folders that contain audio
            foreach (var child in Directory.GetDirectories(dir).Where(c => AudioIn(c).Count > 0))
                Consider(child);
        }

        var coverUpdates = 0;
        foreach (var book in allBooks.Where(b => File.Exists(Path.Combine(LibraryRoot, b.FilePath))))
        {
            var audioDir = Path.GetDirectoryName(Path.Combine(LibraryRoot, book.FilePath));
            if (audioDir is null) continue;
            var coverFile = FindCoverImage(audioDir);
            var diskSize = coverFile is not null ? new FileInfo(coverFile).Length : 0L;
            if (diskSize != (book.CoverData?.LongLength ?? 0L)) coverUpdates++;
        }

        return new ScanPreview(added, removed, coverUpdates);
    }

    public async Task<int> ScanAsync(CancellationToken ct = default)
    {
        if (!Directory.Exists(LibraryRoot))
        {
            logger.LogWarning("Library directory not found: {Path}", LibraryRoot);
            return 0;
        }

        // 1. Remove books whose audio files no longer exist
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
        if (removed > 0) await db.SaveChangesAsync(ct);

        // 2. Remove orphan collections (folder gone, or no books left)
        var collections = await db.Collections.Include(c => c.Books).ToListAsync(ct);
        var removedCols = 0;
        foreach (var col in collections)
        {
            if (!Directory.Exists(Path.Combine(LibraryRoot, col.FolderPath)) || col.Books.Count == 0)
            {
                db.Collections.Remove(col);
                removedCols++;
            }
        }
        if (removedCols > 0) await db.SaveChangesAsync(ct);

        // 3. Sync book covers (cover.* may have been added/changed)
        foreach (var book in await db.Books.ToListAsync(ct))
        {
            var audioDir = Path.GetDirectoryName(Path.Combine(LibraryRoot, book.FilePath));
            if (audioDir is null) continue;
            var coverFile = FindCoverImage(audioDir);
            var newCoverData = coverFile is not null ? await File.ReadAllBytesAsync(coverFile, ct) : null;
            if (newCoverData?.Length != book.CoverData?.Length)
            {
                book.CoverData = newCoverData;
                book.CoverMimeType = coverFile is not null ? GuessMime(coverFile) : null;
            }
        }

        // 4. Sync collection covers
        foreach (var col in await db.Collections.ToListAsync(ct))
        {
            var dir = Path.Combine(LibraryRoot, col.FolderPath);
            if (!Directory.Exists(dir)) continue;
            var coverFile = FindCoverImage(dir);
            var data = coverFile is not null ? await File.ReadAllBytesAsync(coverFile, ct) : null;
            if (data?.Length != col.CoverData?.Length)
            {
                col.CoverData = data;
                col.CoverMimeType = coverFile is not null ? GuessMime(coverFile) : null;
            }
        }
        await db.SaveChangesAsync(ct);

        // 5. Add new books + collections
        var existingPaths = await db.Books.Select(b => b.FilePath).ToHashSetAsync(ct);
        var newBooks = new List<Book>();

        foreach (var dir in Directory.GetDirectories(LibraryRoot))
        {
            var audio = AudioIn(dir);
            if (audio.Count > 0)
            {
                // standalone (top-level) book
                var b = await BuildBookAsync(dir, audio, null, existingPaths, ct);
                if (b is not null) { newBooks.Add(b); existingPaths.Add(b.FilePath); }
                continue;
            }

            // collection: child folders containing audio
            var childDirs = Directory.GetDirectories(dir)
                .Where(c => AudioIn(c).Count > 0).OrderBy(c => c).ToList();
            if (childDirs.Count == 0) continue;

            var col = await EnsureCollectionAsync(dir, ct);
            foreach (var child in childDirs)
            {
                var b = await BuildBookAsync(child, AudioIn(child), col.Id, existingPaths, ct);
                if (b is not null) { newBooks.Add(b); existingPaths.Add(b.FilePath); }
            }
        }

        // Flat audio files directly in root → individual books
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

        // Clean up any collections that ended up with no books
        var empties = await db.Collections.Include(c => c.Books).Where(c => c.Books.Count == 0).ToListAsync(ct);
        if (empties.Count > 0) { db.Collections.RemoveRange(empties); await db.SaveChangesAsync(ct); }

        return newBooks.Count;
    }

    private async Task<Collection> EnsureCollectionAsync(string dir, CancellationToken ct)
    {
        var folder = Path.GetRelativePath(LibraryRoot, dir);
        var existing = await db.Collections.FirstOrDefaultAsync(c => c.FolderPath == folder, ct);
        if (existing is not null) return existing;

        var coverFile = FindCoverImage(dir);
        var col = new Collection
        {
            Name = ParseDirectoryName(Path.GetFileName(dir)).title,
            FolderPath = folder,
            CoverData = coverFile is not null ? await File.ReadAllBytesAsync(coverFile, ct) : null,
            CoverMimeType = coverFile is not null ? GuessMime(coverFile) : null,
            AddedAt = DateTime.UtcNow
        };
        db.Collections.Add(col);
        await db.SaveChangesAsync(ct);   // assign Id
        logger.LogInformation("Found collection: {Name}", col.Name);
        return col;
    }

    private async Task<Book?> BuildBookAsync(string dir, List<string> audioFiles, int? collectionId, HashSet<string> existingPaths, CancellationToken ct)
    {
        if (audioFiles.Count == 0) return null;
        var firstRelative = Path.GetRelativePath(LibraryRoot, audioFiles[0]);
        if (existingPaths.Contains(firstRelative)) return null;

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
            CollectionId = collectionId,
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

        logger.LogInformation("Found: {Title} by {Author} ({Chapters} chapters, collection={Col})",
            book.Title, book.Author, book.Chapters.Count, collectionId);
        return book;
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
