namespace Chronicler.Api.Models;

public class Book
{
    public int Id { get; set; }
    public string Title { get; set; } = "";
    public string Author { get; set; } = "";
    public string? Narrator { get; set; }
    public string? Description { get; set; }
    public int? Year { get; set; }
    public string FilePath { get; set; } = "";
    public byte[]? CoverData { get; set; }
    public string? CoverMimeType { get; set; }
    public double DurationSeconds { get; set; }
    public DateTime AddedAt { get; set; } = DateTime.UtcNow;
    public bool IsFavorite { get; set; }

    public ICollection<Chapter> Chapters { get; set; } = [];
}
