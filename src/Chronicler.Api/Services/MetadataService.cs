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
        try
        {
            var result = await SearchOpenLibraryAsync(book.Title, book.Author, ct);
            if (result is null) return;

            if (!string.IsNullOrWhiteSpace(result.Description))
                book.Description = result.Description;

            if (result.CoverId > 0 && book.CoverPath is null)
            {
                var coverPath = await DownloadCoverAsync(result.CoverId, book, libraryRoot, ct);
                if (coverPath is not null)
                    book.CoverPath = coverPath;
            }
        }
        catch (Exception ex)
        {
            logger.LogWarning("Metadata fetch failed for '{Title}': {Error}", book.Title, ex.Message);
        }
    }

    private async Task<OpenLibraryResult?> SearchOpenLibraryAsync(
        string title, string author, CancellationToken ct)
    {
        var query = Uri.EscapeDataString($"{title} {author}".Trim());
        var url = $"https://openlibrary.org/search.json?q={query}&limit=3&fields=title,author_name,cover_i,first_sentence,description";

        var response = await Http.GetFromJsonAsync<OpenLibraryResponse>(url, JsonOpts, ct);
        var doc = response?.Docs?.FirstOrDefault();
        if (doc is null) return null;

        logger.LogInformation("OpenLibrary match for '{Title}': {Match}", title, doc.Title);

        return new OpenLibraryResult(
            doc.CoverId ?? 0,
            doc.Description ?? doc.FirstSentence?.Value);
    }

    private async Task<string?> DownloadCoverAsync(
        int coverId, Book book, string libraryRoot, CancellationToken ct)
    {
        var url = $"https://covers.openlibrary.org/b/id/{coverId}-L.jpg";
        var bytes = await Http.GetByteArrayAsync(url, ct);
        if (bytes.Length < 1000) return null; // tiny = placeholder, skip

        // Save next to the audio file
        var audioDir = Path.GetDirectoryName(Path.Combine(libraryRoot, book.FilePath));
        if (audioDir is null) return null;

        var coverFile = Path.Combine(audioDir, "cover.jpg");
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
