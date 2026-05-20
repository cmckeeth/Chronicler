using System.Net.Http.Json;
using System.Text.Json;

namespace Chronicler.Shared.Services;

public record BookDto(int Id, string Title, string Author, string? Narrator,
    double DurationSeconds, bool HasCover, DateTime AddedAt);

public record BookmarkDto(int Id, int BookId, double PositionSeconds, string? Label, DateTime CreatedAt);

public class ApiClient(HttpClient http)
{
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    // ── Auth ──────────────────────────────────────────────────────────────────

    public async Task<string?> LoginAsync(string email, string password)
    {
        var resp = await http.PostAsJsonAsync("/api/auth/login", new { email, password });
        if (!resp.IsSuccessStatusCode) return null;
        var result = await resp.Content.ReadFromJsonAsync<TokenResponse>(JsonOpts);
        return result?.Token;
    }

    public async Task<string?> RegisterAsync(string email, string password)
    {
        var resp = await http.PostAsJsonAsync("/api/auth/register", new { email, password });
        if (!resp.IsSuccessStatusCode) return null;
        var result = await resp.Content.ReadFromJsonAsync<TokenResponse>(JsonOpts);
        return result?.Token;
    }

    // ── Books ─────────────────────────────────────────────────────────────────

    public async Task<List<BookDto>> GetBooksAsync(string? search = null)
    {
        var url = string.IsNullOrWhiteSpace(search)
            ? "/api/books"
            : $"/api/books?q={Uri.EscapeDataString(search)}";
        return await http.GetFromJsonAsync<List<BookDto>>(url, JsonOpts) ?? [];
    }

    public async Task<BookDto?> GetBookAsync(int id) =>
        await http.GetFromJsonAsync<BookDto>($"/api/books/{id}", JsonOpts);

    public string GetCoverUrl(int bookId) => $"{http.BaseAddress}api/books/{bookId}/cover";
    public string GetAudioUrl(int bookId) => $"{http.BaseAddress}api/books/{bookId}/audio";

    public async Task<int> ScanLibraryAsync()
    {
        var resp = await http.PostAsync("/api/library/scan", null);
        var result = await resp.Content.ReadFromJsonAsync<ScanResult>(JsonOpts);
        return result?.Added ?? 0;
    }

    public async Task<int> EnrichLibraryAsync()
    {
        var resp = await http.PostAsync("/api/library/enrich", null);
        var result = await resp.Content.ReadFromJsonAsync<EnrichResult>(JsonOpts);
        return result?.Enriched ?? 0;
    }

    // ── Progress ──────────────────────────────────────────────────────────────

    public async Task<double> GetProgressAsync(int bookId)
    {
        var result = await http.GetFromJsonAsync<ProgressResult>($"/api/progress/{bookId}", JsonOpts);
        return result?.PositionSeconds ?? 0;
    }

    public async Task SaveProgressAsync(int bookId, double positionSeconds) =>
        await http.PutAsJsonAsync($"/api/progress/{bookId}", new { positionSeconds });

    // ── Bookmarks ─────────────────────────────────────────────────────────────

    public async Task<List<BookmarkDto>> GetBookmarksAsync(int bookId) =>
        await http.GetFromJsonAsync<List<BookmarkDto>>($"/api/bookmarks/{bookId}", JsonOpts) ?? [];

    public async Task<BookmarkDto?> AddBookmarkAsync(int bookId, double positionSeconds, string? label = null)
    {
        var resp = await http.PostAsJsonAsync($"/api/bookmarks/{bookId}", new { positionSeconds, label });
        if (!resp.IsSuccessStatusCode) return null;
        return await resp.Content.ReadFromJsonAsync<BookmarkDto>(JsonOpts);
    }

    public async Task DeleteBookmarkAsync(int id) =>
        await http.DeleteAsync($"/api/bookmarks/{id}");

    // ── Updates ───────────────────────────────────────────────────────────────

    public async Task<string?> GetLatestVersionAsync()
    {
        try
        {
            var result = await http.GetFromJsonAsync<VersionResult>("/api/update/version", JsonOpts);
            return result?.Version;
        }
        catch { return null; }
    }

    public string GetApkDownloadUrl() => $"{http.BaseAddress}api/update/apk";

    private record TokenResponse(string Token);
    private record ProgressResult(double PositionSeconds);
    private record ScanResult(int Added);
    private record EnrichResult(int Enriched);
    private record VersionResult(string Version);
}
