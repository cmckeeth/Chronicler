using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Chronicler.Api.Models;

namespace Chronicler.Api.Services;

public class MetadataService(ILogger<MetadataService> logger)
{
    private static readonly HttpClient Http = new()
    {
        Timeout = TimeSpan.FromSeconds(15),
        DefaultRequestHeaders = { { "User-Agent", "Chronicler/1.0 (audiobook library app)" } }
    };

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    public async Task EnrichAsync(Book book, string libraryRoot, CancellationToken ct = default)
    {
        logger.LogInformation("Metadata: enriching '{Title}' by '{Author}'", book.Title, book.Author);
        try
        {
            var result = await SearchAsync(book.Title, book.Author, ct);
            if (result is null)
            {
                logger.LogWarning("Metadata: no match found for '{Title}'", book.Title);
                return;
            }

            if (!string.IsNullOrWhiteSpace(result.Description))
                book.Description = result.Description;

            if (result.CoverUrl is not null && book.CoverPath is null)
            {
                var coverPath = await DownloadCoverAsync(result.CoverUrl, book, libraryRoot, ct);
                if (coverPath is not null)
                {
                    book.CoverPath = coverPath;
                    logger.LogInformation("Metadata: cover saved → {Path}", coverPath);
                }
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning("Metadata: fetch failed for '{Title}': {Error}", book.Title, ex.Message);
        }
    }

    private async Task<SearchResult?> SearchAsync(string title, string author, CancellationToken ct)
    {
        // The scanner parses "Author - Title" so `author` often contains the real book name.
        // Try several strategies in order of quality.
        var strategies = new (string label, string url)[]
        {
            // 1. OpenLibrary: search by title field using the "author" value (most likely to be the real title)
            ("OL title=author",  $"https://openlibrary.org/search.json?title={Uri.EscapeDataString(Clean(author))}&limit=3"),
            // 2. OpenLibrary: search by title field using the "title" value
            ("OL title=title",   $"https://openlibrary.org/search.json?title={Uri.EscapeDataString(Clean(title))}&limit=3"),
            // 3. OpenLibrary: combined general search
            ("OL q=combined",    $"https://openlibrary.org/search.json?q={Uri.EscapeDataString(Clean($"{author} {title}").Trim())}&limit=3"),
            // 4. Google Books: search by author value as the query
            ("GB author",        $"https://www.googleapis.com/books/v1/volumes?q={Uri.EscapeDataString(Clean(author))}&maxResults=3"),
        };

        foreach (var (label, url) in strategies)
        {
            try
            {
                logger.LogInformation("Metadata: [{Label}] {Url}", label, url);
                using var resp = await Http.GetAsync(url, ct);
                if (!resp.IsSuccessStatusCode)
                {
                    logger.LogWarning("Metadata: [{Label}] HTTP {Status}", label, (int)resp.StatusCode);
                    continue;
                }

                SearchResult? result = label.StartsWith("GB")
                    ? await ParseGoogleBooks(resp, ct)
                    : await ParseOpenLibrary(resp, ct);

                if (result?.CoverUrl is not null)
                {
                    logger.LogInformation("Metadata: [{Label}] found cover", label);
                    return result;
                }
                if (result is not null)
                    logger.LogWarning("Metadata: [{Label}] matched but no cover image", label);
            }
            catch (Exception ex)
            {
                logger.LogWarning("Metadata: [{Label}] error: {Error}", label, ex.Message);
            }
        }

        return null;
    }

    private static async Task<SearchResult?> ParseOpenLibrary(HttpResponseMessage resp, CancellationToken ct)
    {
        var response = await resp.Content.ReadFromJsonAsync<OLResponse>(JsonOpts, ct);
        var doc = response?.Docs?.FirstOrDefault(d => d.CoverId.HasValue && d.CoverId > 0)
                  ?? response?.Docs?.FirstOrDefault();
        if (doc is null) return null;

        var coverUrl = doc.CoverId.HasValue && doc.CoverId > 0
            ? $"https://covers.openlibrary.org/b/id/{doc.CoverId}-L.jpg"
            : null;

        return new SearchResult(coverUrl, doc.Description ?? doc.FirstSentence?.Value);
    }

    private static async Task<SearchResult?> ParseGoogleBooks(HttpResponseMessage resp, CancellationToken ct)
    {
        var response = await resp.Content.ReadFromJsonAsync<GBResponse>(JsonOpts, ct);
        var item = response?.Items?.FirstOrDefault(i => i.VolumeInfo?.ImageLinks?.Large is not null
                                                     || i.VolumeInfo?.ImageLinks?.Thumbnail is not null);
        if (item?.VolumeInfo is null) return null;

        var coverUrl = item.VolumeInfo.ImageLinks?.Large
                    ?? item.VolumeInfo.ImageLinks?.Thumbnail;

        // Force HTTPS and larger size
        if (coverUrl is not null)
            coverUrl = coverUrl.Replace("http://", "https://").Replace("&zoom=1", "&zoom=3");

        return new SearchResult(coverUrl, item.VolumeInfo.Description);
    }

    private static string Clean(string s) =>
        s.Replace('\u2019', ' ').Replace('\u2018', ' ')
         .Replace('\'', ' ').Replace('\u201C', ' ').Replace('\u201D', ' ')
         .Replace('\u2013', ' ').Replace('\u2014', ' ')
         .Replace("  ", " ").Trim();

    private async Task<string?> DownloadCoverAsync(string url, Book book, string libraryRoot, CancellationToken ct)
    {
        logger.LogInformation("Metadata: downloading cover from {Url}", url);
        var bytes = await Http.GetByteArrayAsync(url, ct);
        logger.LogInformation("Metadata: cover {Bytes} bytes", bytes.Length);

        if (bytes.Length < 2000)
        {
            logger.LogWarning("Metadata: cover too small ({Bytes}b), skipping", bytes.Length);
            return null;
        }

        var audioDir = Path.GetDirectoryName(Path.Combine(libraryRoot, book.FilePath));
        if (audioDir is null) return null;

        var coverFile = Path.Combine(audioDir, "cover.jpg");
        await File.WriteAllBytesAsync(coverFile, bytes, ct);
        return Path.GetRelativePath(libraryRoot, coverFile);
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────

    private record SearchResult(string? CoverUrl, string? Description);

    private record OLResponse([property: JsonPropertyName("docs")] List<OLDoc>? Docs);
    private record OLDoc(
        [property: JsonPropertyName("title")] string? Title,
        [property: JsonPropertyName("cover_i")] int? CoverId,
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("first_sentence")] OLSentence? FirstSentence);
    private record OLSentence([property: JsonPropertyName("value")] string? Value);

    private record GBResponse([property: JsonPropertyName("items")] List<GBItem>? Items);
    private record GBItem([property: JsonPropertyName("volumeInfo")] GBVolumeInfo? VolumeInfo);
    private record GBVolumeInfo(
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("imageLinks")] GBImageLinks? ImageLinks);
    private record GBImageLinks(
        [property: JsonPropertyName("large")] string? Large,
        [property: JsonPropertyName("thumbnail")] string? Thumbnail);
}
