namespace Chronicler.Shared.Services;

public record DownloadedChapter(
    int ChapterId,
    int BookId,
    string BookTitle,
    string ChapterTitle,
    int TrackNumber,
    string LocalPath,
    long FileSize,
    DateTime DownloadedAt);

public interface IDownloadService
{
    Task<bool> IsDownloadedAsync(int chapterId);
    Task<string?> GetLocalPathAsync(int chapterId);
    Task<IReadOnlyList<DownloadedChapter>> GetAllDownloadsAsync();
    Task DownloadAsync(int chapterId, int bookId, string bookTitle, string chapterTitle,
        int trackNumber, string audioUrl, IProgress<double>? progress = null,
        CancellationToken ct = default);
    Task DeleteChapterAsync(int chapterId);
    Task DeleteBookAsync(int bookId);
    Task DeleteAllAsync();
    Task<long> GetTotalSizeAsync();
    event Action? OnChanged;
}
