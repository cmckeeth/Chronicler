namespace Chronicler.Api.Models;

public class Chapter
{
    public int Id { get; set; }
    public int BookId { get; set; }
    public string Title { get; set; } = "";
    public string FilePath { get; set; } = "";
    public int TrackNumber { get; set; }
    public double DurationSeconds { get; set; }

    public Book Book { get; set; } = null!;
    public ICollection<ChapterProgress> Progresses { get; set; } = [];
}
