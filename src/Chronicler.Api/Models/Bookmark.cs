namespace Chronicler.Api.Models;

public class Bookmark
{
    public int Id { get; set; }
    public string UserId { get; set; } = "";
    public int BookId { get; set; }
    public double PositionSeconds { get; set; }
    public string? Label { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public AppUser User { get; set; } = null!;
    public Book Book { get; set; } = null!;
}
