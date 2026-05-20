namespace Chronicler.Api.Models;

public class Book
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Author { get; set; } = "";
    public string? Narrator { get; set; }
    public string? Description { get; set; }
    public string FilePath { get; set; } = "";
    public string? CoverPath { get; set; }
    public double DurationSeconds { get; set; }
    public DateTime AddedAt { get; set; } = DateTime.UtcNow;

    public ICollection<UserProgress> Progresses { get; set; } = [];
    public ICollection<Bookmark> Bookmarks { get; set; } = [];
    public ICollection<Chapter> Chapters { get; set; } = [];
}
