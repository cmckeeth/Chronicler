using System.Net.Http.Json;
using System.Text.Json;

namespace Chronicler.Shared.Services;

public record BookDto(int Id, string Title, string Author, string? Narrator,
    double DurationSeconds, bool HasCover, DateTime AddedAt,
    int ChapterCount = 0, int ListenedCount = 0, int? Year = null)
{
    public bool IsCompleted => ChapterCount > 0 && ListenedCount >= ChapterCount;
    public bool IsInProgress => ListenedCount > 0 && !IsCompleted;
}

public record BookmarkDto(int Id, int BookId, double PositionSeconds, string? Label, DateTime CreatedAt);

public record ChapterDto(int Id, int BookId, string Title, int TrackNumber);

public record ChapterProgressDto(double PositionSeconds, bool IsListened);
public record BookMetaDto(int Id, string Title, string Author, string? Narrator, string? Description, int? Year);

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

    public async Task<string?> GetCoverDataUriAsync(int bookId)
    {
        try
        {
            var bytes = await http.GetByteArrayAsync($"api/books/{bookId}/cover");
            if (bytes.Length < 100) return null;
            return $"data:image/jpeg;base64,{Convert.ToBase64String(bytes)}";
        }
        catch { return null; }
    }

    public async Task<bool> UploadCoverAsync(int bookId, byte[] imageBytes, string mimeType)
    {
        ApplyAuth();
        using var content = new MultipartFormDataContent();
        using var imgContent = new ByteArrayContent(imageBytes);
        imgContent.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue(mimeType);
        content.Add(imgContent, "cover", "cover.jpg");
        var resp = await http.PutAsync($"api/books/{bookId}/cover/upload", content);
        return resp.IsSuccessStatusCode;
    }

    public static void InvalidateCoverCache(int bookId) { } // no-op, kept for call-site compat
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

    public async Task<BookMetaDto?> GetBookMetaAsync(int bookId)
    {
        ApplyAuth();
        try { return await http.GetFromJsonAsync<BookMetaDto>($"/api/books/{bookId}/meta", JsonOpts); }
        catch { return null; }
    }

    public async Task<bool> SaveBookMetaAsync(int bookId, string title, string author, string? narrator, string? description, int? year)
    {
        ApplyAuth();
        var resp = await http.PutAsJsonAsync($"/api/books/{bookId}/meta",
            new { title, author, narrator, description, year });
        return resp.IsSuccessStatusCode;
    }


    public async Task<int> ScanLibraryAsync()
    {
        ApplyAuth();
        var resp = await http.PostAsync("/api/library/scan", null);
        var result = await resp.Content.ReadFromJsonAsync<ScanResult>(JsonOpts);
        return result?.Added ?? 0;
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
    private record VersionResult(string Version);
}
