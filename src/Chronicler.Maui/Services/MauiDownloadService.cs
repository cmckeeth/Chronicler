using System.Text.Json;
using Chronicler.Shared.Services;

namespace Chronicler.Maui.Services;

public class MauiDownloadService : IDownloadService
{
    private static readonly string DownloadsDir =
        Path.Combine(FileSystem.AppDataDirectory, "downloads");
    private static readonly string ManifestPath =
        Path.Combine(DownloadsDir, "manifest.json");

    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };
    private static readonly JsonSerializerOptions JsonOpts = new(JsonSerializerDefaults.Web)
        { WriteIndented = true };

    private Dictionary<int, DownloadedChapter> _manifest = [];
    private readonly SemaphoreSlim _lock = new(1, 1);
    private bool _loaded;

    public event Action? OnChanged;

    private async Task EnsureLoadedAsync()
    {
        if (_loaded) return;
        await _lock.WaitAsync();
        try
        {
            if (_loaded) return;
            Directory.CreateDirectory(DownloadsDir);
            if (File.Exists(ManifestPath))
            {
                var json = await File.ReadAllTextAsync(ManifestPath);
                _manifest = JsonSerializer.Deserialize<Dictionary<int, DownloadedChapter>>(json, JsonOpts)
                            ?? [];
                // Remove entries whose files no longer exist
                foreach (var key in _manifest.Keys.ToList())
                    if (!File.Exists(_manifest[key].LocalPath))
                        _manifest.Remove(key);
            }
            _loaded = true;
        }
        finally { _lock.Release(); }
    }

    private async Task SaveManifestAsync()
    {
        var json = JsonSerializer.Serialize(_manifest, JsonOpts);
        await File.WriteAllTextAsync(ManifestPath, json);
    }

    public async Task<bool> IsDownloadedAsync(int chapterId)
    {
        await EnsureLoadedAsync();
        return _manifest.ContainsKey(chapterId) && File.Exists(_manifest[chapterId].LocalPath);
    }

    public async Task<string?> GetLocalPathAsync(int chapterId)
    {
        await EnsureLoadedAsync();
        return _manifest.TryGetValue(chapterId, out var ch) && File.Exists(ch.LocalPath)
            ? ch.LocalPath : null;
    }

    public async Task<IReadOnlyList<DownloadedChapter>> GetAllDownloadsAsync()
    {
        await EnsureLoadedAsync();
        return _manifest.Values.OrderBy(c => c.BookTitle).ThenBy(c => c.TrackNumber).ToList();
    }

    public async Task DownloadAsync(int chapterId, int bookId, string bookTitle,
        string chapterTitle, int trackNumber, string audioUrl,
        IProgress<double>? progress = null, CancellationToken ct = default)
    {
        await EnsureLoadedAsync();

        Directory.CreateDirectory(DownloadsDir);
        var ext = Path.GetExtension(audioUrl.Split('?')[0]);
        if (string.IsNullOrEmpty(ext)) ext = ".mp3";
        var localPath = Path.Combine(DownloadsDir, $"{chapterId}{ext}"); // may be updated after Content-Type check

        using var resp = await Http.GetAsync(audioUrl, HttpCompletionOption.ResponseHeadersRead, ct);
        resp.EnsureSuccessStatusCode();

        // Determine extension from Content-Type if URL has none
        if (string.IsNullOrEmpty(ext) || ext == ".mp3")
        {
            var ct2 = resp.Content.Headers.ContentType?.MediaType;
            ext = ct2 switch
            {
                "audio/ogg" or "audio/opus" => ".opus",
                "audio/mp4" or "audio/x-m4a" or "audio/m4a" => ".m4a",
                "audio/aac" => ".aac",
                "audio/flac" => ".flac",
                "audio/wav" => ".wav",
                _ => ext
            };
            localPath = Path.Combine(DownloadsDir, $"{chapterId}{ext}");
        }

        var total = resp.Content.Headers.ContentLength ?? -1;
        long downloaded = 0;

        await using var stream = await resp.Content.ReadAsStreamAsync(ct);
        await using var file = File.Create(localPath);

        var buf = new byte[81920];
        int read;
        while ((read = await stream.ReadAsync(buf, ct)) > 0)
        {
            await file.WriteAsync(buf.AsMemory(0, read), ct);
            downloaded += read;
            if (total > 0) progress?.Report((double)downloaded / total);
        }

        var entry = new DownloadedChapter(
            chapterId, bookId, bookTitle, chapterTitle, trackNumber,
            localPath, downloaded, DateTime.UtcNow);

        _manifest[chapterId] = entry;
        await SaveManifestAsync();
        OnChanged?.Invoke();
    }

    public async Task DeleteChapterAsync(int chapterId)
    {
        await EnsureLoadedAsync();
        if (_manifest.TryGetValue(chapterId, out var ch))
        {
            if (File.Exists(ch.LocalPath)) File.Delete(ch.LocalPath);
            _manifest.Remove(chapterId);
            await SaveManifestAsync();
            OnChanged?.Invoke();
        }
    }

    public async Task DeleteBookAsync(int bookId)
    {
        await EnsureLoadedAsync();
        var toDelete = _manifest.Values.Where(c => c.BookId == bookId).ToList();
        foreach (var ch in toDelete)
        {
            if (File.Exists(ch.LocalPath)) File.Delete(ch.LocalPath);
            _manifest.Remove(ch.ChapterId);
        }
        await SaveManifestAsync();
        OnChanged?.Invoke();
    }

    public async Task DeleteAllAsync()
    {
        await EnsureLoadedAsync();
        foreach (var ch in _manifest.Values)
            if (File.Exists(ch.LocalPath)) File.Delete(ch.LocalPath);
        _manifest.Clear();
        await SaveManifestAsync();
        OnChanged?.Invoke();
    }

    public async Task<long> GetTotalSizeAsync()
    {
        await EnsureLoadedAsync();
        return _manifest.Values.Sum(c => c.FileSize);
    }
}
