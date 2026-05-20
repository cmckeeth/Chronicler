using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using Chronicler.Api.Models;

namespace Chronicler.Api.Services;

public class MetadataService(ILogger<MetadataService> logger)
{
    private static readonly HttpClient Http = new()
    {
        Timeout = TimeSpan.FromSeconds(10),
        DefaultRequestHeaders = { { "User-Agent", "Chronicler/1.0 (audiobook library app)" } }
    };

    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    public async Task EnrichAsync(Book book, string libraryRoot, CancellationToken ct = default)
    {
        logger.LogInformation("Metadata: enriching '{Title}' by '{Author}'", book.Title, book.Author);
        try
        {
            var result = await SearchOpenLibraryAsync(book.Title, book.Author, ct);
            if (result is null)
            {
                logger.LogWarning("Metadata: no OpenLibrary match for '{Title}'", book.Title);
                return;
            }

            if (!string.IsNullOrWhiteSpace(result.Description))
                book.Description = result.Description;

            if (result.CoverId > 0 && book.CoverPath is null)
            {
                logger.LogInformation("Metadata: downloading cover id={CoverId} for '{Title}'", result.CoverId, book.Title);
                var coverPath = await DownloadCoverAsync(result.CoverId, book, libraryRoot, ct);
                if (coverPath is not null)
                {
                    book.CoverPath = coverPath;
                    logger.LogInformation("Metadata: cover saved → {Path}", coverPath);
                }
                else
                {
                    logger.LogWarning("Metadata: cover download returned empty/placeholder for '{Title}'", book.Title);
                }
            }
            else if (result.CoverId == 0)
            {
                logger.LogWarning("Metadata: OpenLibrary match has no cover image for '{Title}'", book.Title);
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning("Metadata: fetch failed for '{Title}': {Error}", book.Title, ex.Message);
        }
    }

    private async Task<OpenLibraryResult?> SearchOpenLibraryAsync(
        string title, string author, CancellationToken ct)
    {
        // Try multiple query strategies — directory names may have title/author swapped
        // or the "title" may be an edition/subtitle rather than the real book name
        var queries = new[]
        {
            author,                          // most likely the real book name (e.g. "Harry Potter...")
            $"{author} {title}",            // combined
            title,                           // fallback to raw title
        };

        foreach (var q in queries.Select(x => x.Trim()).Where(x => x.Length > 3).Distinct())
        {
            var encoded = Uri.EscapeDataString(q);
            var url = $"https://openlibrary.org/search.json?q={encoded}&limit=3&fields=title,author_name,cover_i,first_sentence,description";
            logger.LogInformation("Metadata: querying OpenLibrary q='{Query}'", q);

            try
            {
                var response = await Http.GetFromJsonAsync<OpenLibraryResponse>(url, JsonOpts, ct);
                var doc = response?.Docs?.FirstOrDefault(d => d.CoverId.HasValue && d.CoverId > 0)
                          ?? response?.Docs?.FirstOrDefault();

                if (doc is not null)
                {
                    logger.LogInformation("Metadata: matched '{Match}' (coverId={CoverId})", doc.Title, doc.CoverId);
                    return new OpenLibraryResult(doc.CoverId ?? 0, doc.Description ?? doc.FirstSentence?.Value);
                }

                logger.LogWarning("Metadata: no results for q='{Query}'", q);
            }
            catch (Exception ex)
            {
                logger.LogWarning("Metadata: query failed for '{Query}': {Error}", q, ex.Message);
            }
        }

        return null;
    }

    private async Task<string?> DownloadCoverAsync(
        int coverId, Book book, string libraryRoot, CancellationToken ct)
    {
        var url = $"https://covers.openlibrary.org/b/id/{coverId}-L.jpg";
        logger.LogInformation("Metadata: fetching cover from {Url}", url);
        var bytes = await Http.GetByteArrayAsync(url, ct);
        logger.LogInformation("Metadata: cover response {Bytes} bytes", bytes.Length);

        if (bytes.Length < 1000)
        {
            logger.LogWarning("Metadata: cover too small ({Bytes}b), likely placeholder — skipping", bytes.Length);
            return null;
        }

        var audioDir = Path.GetDirectoryName(Path.Combine(libraryRoot, book.FilePath));
        if (audioDir is null) return null;

        var coverFile = Path.Combine(audioDir, "cover.jpg");
        logger.LogInformation("Metadata: saving cover to {Path}", coverFile);
        await File.WriteAllBytesAsync(coverFile, bytes, ct);

        return Path.GetRelativePath(libraryRoot, coverFile);
    }

    // ── OpenLibrary DTOs ──────────────────────────────────────────────────────

    private record OpenLibraryResponse(
        [property: JsonPropertyName("docs")] List<OpenLibraryDoc>? Docs);

    private record OpenLibraryDoc(
        [property: JsonPropertyName("title")] string? Title,
        [property: JsonPropertyName("author_name")] List<string>? AuthorName,
        [property: JsonPropertyName("cover_i")] int? CoverId,
        [property: JsonPropertyName("description")] string? Description,
        [property: JsonPropertyName("first_sentence")] FirstSentence? FirstSentence);

    private record FirstSentence(
        [property: JsonPropertyName("value")] string? Value);

    private record OpenLibraryResult(int CoverId, string? Description);
}
