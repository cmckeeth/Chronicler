using System.Net.Http.Json;
using System.Text.Json;

namespace Chronicler.Shared.Services;

public record BookDto(int Id, string Title, string Author, string? Narrator,
    double DurationSeconds, bool HasCover, DateTime AddedAt);

public record BookmarkDto(int Id, int BookId, double PositionSeconds, string? Label, DateTime CreatedAt);

public record ChapterDto(int Id, int BookId, string Title, int TrackNumber);

public record ChapterProgressDto(double PositionSeconds, bool IsListened);

public class ApiClient(HttpClient http, AuthState auth)
{
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web);

    private void ApplyAuth()
    {
        http.DefaultRequestHeaders.Authorization = auth.Token is not null
            ? new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", auth.Token)
            : null;
    }

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
        ApplyAuth();
        var url = string.IsNullOrWhiteSpace(search) ? "/api/books" : $"/api/books?q={Uri.EscapeDataString(search)}";
        return await http.GetFromJsonAsync<List<BookDto>>(url, JsonOpts) ?? [];
    }

    public async Task<BookDto?> GetBookAsync(int id)
    {
        ApplyAuth();
        return await http.GetFromJsonAsync<BookDto>($"/api/books/{id}", JsonOpts);
    }

    public string GetCoverUrl(int bookId) => $"{http.BaseAddress}api/books/{bookId}/cover";
    public string GetAudioUrl(int bookId) => $"{http.BaseAddress}api/books/{bookId}/audio";
    public string GetChapterAudioUrl(int chapterId) => $"{http.BaseAddress}api/chapters/{chapterId}/audio";

    public async Task<List<ChapterDto>> GetChaptersAsync(int bookId)
    {
        ApplyAuth();
        return await http.GetFromJsonAsync<List<ChapterDto>>($"/api/books/{bookId}/chapters", JsonOpts) ?? [];
    }

    public async Task<ChapterProgressDto> GetChapterProgressAsync(int chapterId)
    {
        ApplyAuth();
        var result = await http.GetFromJsonAsync<ChapterProgressDto>($"/api/chapters/{chapterId}/progress", JsonOpts);
        return result ?? new ChapterProgressDto(0, false);
    }

    public async Task SaveChapterProgressAsync(int chapterId, double position, double duration)
    {
        ApplyAuth();
        await http.PutAsJsonAsync($"/api/chapters/{chapterId}/progress", new { positionSeconds = position, durationSeconds = duration });
    }

    public async Task ResetChapterAsync(int chapterId)
    {
        ApplyAuth();
        await http.PostAsync($"/api/chapters/{chapterId}/reset", null);
    }

    public async Task ResetBookAsync(int bookId)
    {
        ApplyAuth();
        await http.PostAsync($"/api/books/{bookId}/reset", null);
    }

    public async Task<int> ScanLibraryAsync()
    {
        ApplyAuth();
        var resp = await http.PostAsync("/api/library/scan", null);
        var result = await resp.Content.ReadFromJsonAsync<ScanResult>(JsonOpts);
        return result?.Added ?? 0;
    }

    public async Task<int> EnrichLibraryAsync()
    {
        ApplyAuth();
        var resp = await http.PostAsync("/api/library/enrich", null);
        var result = await resp.Content.ReadFromJsonAsync<EnrichResult>(JsonOpts);
        return result?.Enriched ?? 0;
    }

    // ── Progress ──────────────────────────────────────────────────────────────

    public async Task<double> GetProgressAsync(int bookId)
    {
        ApplyAuth();
        var result = await http.GetFromJsonAsync<ProgressResult>($"/api/progress/{bookId}", JsonOpts);
        return result?.PositionSeconds ?? 0;
    }

    public async Task SaveProgressAsync(int bookId, double positionSeconds)
    {
        ApplyAuth();
        await http.PutAsJsonAsync($"/api/progress/{bookId}", new { positionSeconds });
    }

    // ── Bookmarks ─────────────────────────────────────────────────────────────

    public async Task<List<BookmarkDto>> GetBookmarksAsync(int bookId)
    {
        ApplyAuth();
        return await http.GetFromJsonAsync<List<BookmarkDto>>($"/api/bookmarks/{bookId}", JsonOpts) ?? [];
    }

    public async Task<BookmarkDto?> AddBookmarkAsync(int bookId, double positionSeconds, string? label = null)
    {
        ApplyAuth();
        var resp = await http.PostAsJsonAsync($"/api/bookmarks/{bookId}", new { positionSeconds, label });
        if (!resp.IsSuccessStatusCode) return null;
        return await resp.Content.ReadFromJsonAsync<BookmarkDto>(JsonOpts);
    }

    public async Task DeleteBookmarkAsync(int id)
    {
        ApplyAuth();
        await http.DeleteAsync($"/api/bookmarks/{id}");
    }

    // ── Updates / Diag ────────────────────────────────────────────────────────

    public async Task DiagAsync(string message)
    {
        try { await http.PostAsJsonAsync("/api/diag", new { message }); } catch { }
    }

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
